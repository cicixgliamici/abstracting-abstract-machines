"""Regenerate bounded experiments using only Python's standard library and Dune."""

import argparse
import csv
import hashlib
import io
import json
import platform
from pathlib import Path
import statistics
import subprocess
import sys
from datetime import datetime, timezone

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


def fingerprints():
    # Hash the sources and harness, because a dirty commit alone is ambiguous.
    paths = [ROOT / "dune-project", ROOT / "scripts/run_experiments.py"]
    for directory in ("lib", "bin"):
        paths.extend(path for path in (ROOT / directory).rglob("*") if path.is_file())
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(paths)}


def trials(binary, catalog, options):
    rows = []
    for example in catalog:
        for allocation in ("sites", "pool1"):
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--max-states", type=int, default=5000)
    parser.add_argument("--cpu-limit", type=float, default=2.0)
    parser.add_argument("--wall-limit", type=float, default=15.0)
    options = parser.parse_args()
    if min(options.repetitions, options.max_states, options.cpu_limit, options.wall_limit) <= 0:
        parser.error("All limits and repetitions must be positive")
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
    metadata = {"utc": datetime.now(timezone.utc).isoformat(), "configuration": vars(options),
                "platform": platform.platform(), "python": sys.version,
                "ocaml": command("ocamlc", "-version"), "dune": command("dune", "--version"),
                "git_revision": command("git", "rev-parse", "HEAD"),
                "git_status": command("git", "status", "--short"),
                "source_sha256": fingerprints(),
                "timing_scope": "Explorer only; excludes concrete/reference checks and metric summarization",
                "clock": "Sys.time CPU; Unix.gettimeofday wall; no warm-up; fresh process per trial"}
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
