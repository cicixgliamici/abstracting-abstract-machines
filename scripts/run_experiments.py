"""Regenerate bounded experiments using only Python's standard library and Dune."""

import argparse
import csv
import io
import json
import platform
from pathlib import Path
import statistics
import subprocess
import sys
from datetime import datetime, timezone
from artifact import digest, hashes, measurement_sources, verify_provenance

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ["example", "allocation", "gc", "status", "concrete_outcome",
          "concrete_value_syntax", "concrete_syntax_included", "extra_final_syntax",
          "reachable_states", "final_states", "max_store_addresses", "max_store_values",
          "cpu_seconds", "wall_seconds", "possible_final_value_syntax"]


def command(*arguments):
    return subprocess.check_output(arguments, cwd=ROOT, text=True).strip()


def write_csv(path, fields, rows):
    with path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def git_context():
    # An extracted review archive is independently identifiable without .git.
    try:
        if Path(command("git", "rev-parse", "--show-toplevel")).resolve() != ROOT:
            return {"git_revision": None, "git_status": None}
        return {"git_revision": command("git", "rev-parse", "HEAD"),
                "git_status": command("git", "status", "--short")}
    except (FileNotFoundError, subprocess.CalledProcessError):
        return {"git_revision": None, "git_status": None}


def metadata(sources, paths, options):
    if measurement_sources() != sources:
        raise RuntimeError("Measurement sources changed during the run; discard these results")
    return {"utc": datetime.now(timezone.utc).isoformat(), "configuration": vars(options),
            "artifact_version": (ROOT / "VERSION").read_text().strip(),
            "platform": platform.platform(), "python": sys.version,
            "ocaml": command("ocamlc", "-version"), "dune": command("dune", "--version"),
            **git_context(), "source_sha256": sources, "source_snapshot_sha256": digest(sources),
            "result_sha256": hashes(paths)}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def trials(binary, catalog, options):
    rows = []
    for example in catalog:
        for allocation in options.allocators:
            for gc in ("false", "true"):
                for trial in range(1, options.repetitions + 1):
                    arguments = [str(binary), example["example"], allocation, gc,
                                 str(options.max_states), str(options.cpu_limit)]
                    try:
                        output = subprocess.check_output(arguments, cwd=ROOT, text=True,
                                                         timeout=options.wall_limit)
                        row = next(csv.DictReader(io.StringIO(output), fieldnames=FIELDS))
                    except subprocess.TimeoutExpired:
                        # The watchdog kills a process that cannot reach the next CPU check.
                        # Its partial graph is unavailable, so do not invent measurements.
                        row = dict.fromkeys(FIELDS, "")
                        row.update(example=example["example"], allocation=allocation,
                                   gc=gc, status="wall_timeout")
                    row["trial"] = trial
                    rows.append(row)
                print(f"{example['example']}: {allocation}, GC={gc}: {rows[-1]['status']}",
                      flush=True)
    return rows


def tables(rows, output):
    sections = []
    dimensions = {
        "precision": ["concrete_outcome", "concrete_syntax_included", "extra_final_syntax"],
        "states": ["reachable_states", "final_states"],
        "store": ["max_store_addresses", "max_store_values"],
        "timing": ["cpu_seconds", "wall_seconds"],
    }
    keys = list(dict.fromkeys((row["example"], row["allocation"], row["gc"]) for row in rows))
    for dimension, measurements in dimensions.items():
        fields = ["example", "allocation", "gc", "status"] + measurements
        summaries = []
        for key in keys:
            samples = [row for row in rows if (row["example"], row["allocation"], row["gc"]) == key]
            statuses = sorted({row["status"] for row in samples})
            summary = dict(zip(fields[:3], key))
            summary["status"] = " / ".join(statuses)
            for metric in measurements:
                values = [row[metric] for row in samples]
                if dimension == "timing":
                    available = [float(value) for value in values if value != ""]
                    summary[metric] = f"{statistics.median(available):.9f}" if len(available) == len(samples) else ""
                else:
                    # Counts describe one graph, not averages of different partial graphs.
                    summary[metric] = values[0] if len(set(values)) == 1 else "varies"
                    if dimension == "precision" and statuses != ["complete"]:
                        summary[metric] = ""
            summaries.append(summary)
        write_csv(output / f"{dimension}.csv", fields, summaries)
        sections.extend([f"## {dimension.capitalize()}", "",
                         "| " + " | ".join(fields) + " |",
                         "| " + " | ".join("---" for _ in fields) + " |"])
        sections.extend("| " + " | ".join(str(row[field]) for field in fields) + " |"
                        for row in summaries)
        sections.append("")
    (output / "tables.md").write_text("\n".join(sections), encoding="utf-8")


def completion_table(rows, output):
    # Report trial and configuration completion separately; mixed repetitions
    # must never turn a partially explored configuration into a completed one.
    fields = ["allocation", "gc", "configurations", "complete_configurations",
              "complete_fraction", "trials", "complete_trials", "state_limit_trials",
              "cpu_limit_trials", "wall_timeout_trials"]
    summaries = []
    for allocation, gc in dict.fromkeys((row["allocation"], row["gc"]) for row in rows):
        samples = [row for row in rows if (row["allocation"], row["gc"]) == (allocation, gc)]
        names = set(row["example"] for row in samples)
        complete = sum(all(row["status"] == "complete" for row in samples if row["example"] == name)
                       for name in names)
        summary = dict(allocation=allocation, gc=gc, configurations=len(names),
                       complete_configurations=complete, complete_fraction=f"{complete / len(names):.3f}",
                       trials=len(samples))
        for status in ("complete", "state_limit", "cpu_limit", "wall_timeout"):
            summary[f"{status}_trials"] = sum(row["status"] == status for row in samples)
        summaries.append(summary)
    write_csv(output / "completion.csv", fields, summaries)
    with (output / "tables.md").open("a", encoding="utf-8") as table:
        table.write("\n## Completion\n\n| " + " | ".join(fields) + " |\n")
        table.write("| " + " | ".join("---" for _ in fields) + " |\n")
        for row in summaries:
            table.write("| " + " | ".join(str(row[field]) for field in fields) + " |\n")


def regenerate_milestones(options, sources):
    paths = []
    for executable, filename in (("main", "allocation"), ("gc_comparison", "gc"),
                                 ("section3_comparison", "section3"),
                                 ("reference_comparison", "reference")):
        path = ROOT / "results" / f"{filename}-comparison.csv"
        # Each milestone keeps its documented protocol, separate from capped runs.
        subprocess.run(["dune", "build", f"bin/{executable}.exe"], cwd=ROOT, check=True)
        with path.open("w", encoding="utf-8", newline="") as output:
            subprocess.run([str(ROOT / f"_build/default/bin/{executable}.exe")],
                           cwd=ROOT, stdout=output, check=True)
        paths.append(path)
        print(f"Regenerated {path.name}", flush=True)
    record = metadata(sources, paths, options)
    record["protocol"] = "Separate complete milestone comparisons; see VALIDATION.md and companion documents"
    write_json(ROOT / "results/milestone-metadata.json", record)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--max-states", type=int, default=5000)
    parser.add_argument("--cpu-limit", type=float, default=2.0)
    parser.add_argument("--wall-limit", type=float, default=15.0)
    parser.add_argument("--allocators", nargs="+", default=["sites", "pool1", "pool4", "pool16", "pool64"])
    parser.add_argument("--milestones", action="store_true", help="Also regenerate the four legacy comparisons")
    parser.add_argument("--verify", action="store_true", help="Check source/result provenance without rerunning")
    options = parser.parse_args()
    if options.verify:
        verify_provenance(ROOT)
        print("Source snapshots and result checksums verified")
        return
    if min(options.repetitions, options.max_states, options.cpu_limit, options.wall_limit) <= 0:
        parser.error("All limits and repetitions must be positive")
    for name in options.allocators:
        if name != "sites" and not (name.startswith("pool") and name[4:].isdigit() and int(name[4:]) > 0):
            parser.error("Allocators must be sites or poolN with positive N")
    if len(set(options.allocators)) != len(options.allocators):
        parser.error("Allocators must not be repeated")
    sources = measurement_sources()
    subprocess.run(["dune", "build", "bin/experiments.exe"], cwd=ROOT, check=True)
    binary = ROOT / "_build/default/bin/experiments.exe"
    catalog = list(csv.DictReader(io.StringIO(command(str(binary), "--catalog")),
                                  fieldnames=["example", "family", "source"]))
    output = ROOT / "results/representative"
    output.mkdir(parents=True, exist_ok=True)
    write_csv(output / "programs.csv", ["example", "family", "source"], catalog)
    rows = trials(binary, catalog, options)
    write_csv(output / "raw.csv", ["trial"] + FIELDS, rows)
    tables(rows, output)
    completion_table(rows, output)
    paths = [path for path in output.iterdir() if path.is_file() and path.name != "metadata.json"]
    record = metadata(sources, paths, options)
    record.update(timing_scope="Explorer only; excludes concrete/reference checks and metric summarization",
                  clock="Sys.time CPU; Unix.gettimeofday wall; no warm-up; fresh process per trial")
    write_json(output / "metadata.json", record)
    if options.milestones:
        regenerate_milestones(options, sources)


if __name__ == "__main__":
    main()
