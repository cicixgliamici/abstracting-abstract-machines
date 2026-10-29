"""Package and verify a content-addressed review artifact using the standard library."""

import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIRECTORIES = ("lib", "bin", "test", "scripts", ".github")


def source_paths(root=ROOT):
    paths = list(root.glob("*.md")) + list(root.glob("*.opam"))
    paths += [root / name for name in ("dune-project", ".gitignore", ".gitattributes", "VERSION")]
    paths += list(root.glob("*.pdf"))
    for directory in SOURCE_DIRECTORIES:
        paths += [path for path in (root / directory).rglob("*")
                  if path.is_file() and "__pycache__" not in path.parts]
    return sorted(paths)


def file_bytes(path):
    content = path.read_bytes()
    # Git's text conversion must not invalidate evidence on another platform.
    return content if path.suffix == ".pdf" else content.replace(b"\r\n", b"\n")


def hashes(paths, root=ROOT):
    return {path.relative_to(root).as_posix(): hashlib.sha256(file_bytes(path)).hexdigest()
            for path in sorted(paths)}


def digest(manifest):
    # Canonical JSON makes identity independent of dictionary insertion order.
    encoded = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def measurement_sources(root=ROOT):
    # Documentation may explain observations after measurement. All executable
    # sources, tests, CI, and dependency declarations still identify the run.
    return hashes([path for path in source_paths(root)
                   if path.suffix not in (".md", ".pdf")], root)


def result_paths(root=ROOT):
    return sorted(path for path in (root / "results").rglob("*") if path.is_file())


def verify_provenance(root):
    expected = measurement_sources(root)
    for relative in ("results/representative/metadata.json", "results/milestone-metadata.json"):
        metadata = json.loads((root / relative).read_text(encoding="utf-8"))
        if metadata["source_sha256"] != expected:
            raise ValueError(f"Results do not match current measurement sources: {relative}")
        if metadata["source_snapshot_sha256"] != digest(expected):
            raise ValueError(f"Invalid source snapshot identity: {relative}")
        for name, checksum in metadata["result_sha256"].items():
            if hashes([root / name], root)[name] != checksum:
                raise ValueError(f"Result checksum mismatch: {name}")


def create_manifest(root=ROOT):
    verify_provenance(root)
    payload = hashes(source_paths(root) + result_paths(root), root)
    version = (root / "VERSION").read_text().strip()
    return {"schema_version": 1, "version": version,
            "artifact_id": f"{version}-{digest(payload)[:16]}",
            "payload_sha256": digest(payload), "files": payload}


def verify(root=ROOT):
    recorded = json.loads((root / "ARTIFACT.json").read_text(encoding="utf-8"))
    if recorded != create_manifest(root):
        raise ValueError("Artifact manifest differs from the source/result payload")
    print(f"Verified {recorded['artifact_id']}: {len(recorded['files'])} files")


def package(root=ROOT):
    manifest = create_manifest(root)
    content = json.dumps(manifest, indent=2) + "\n"
    with (root / "ARTIFACT.json").open("w", encoding="utf-8", newline="\n") as output_file:
        output_file.write(content)
    output = root / "artifacts"
    output.mkdir(exist_ok=True)
    archive = output / f"{manifest['artifact_id']}.zip"
    # Stable entry order, timestamps, and permissions make repeated packaging
    # byte-identical on the same Python/zlib toolchain.
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zipped:
        for name in sorted(list(manifest["files"]) + ["ARTIFACT.json"]):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            zipped.writestr(info, file_bytes(root / name))
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{checksum}  {archive.name}\n", encoding="ascii")
    print(archive)
    verify(root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Verify the existing manifest only")
    options = parser.parse_args()
    if options.verify:
        verify()
    else:
        package()


if __name__ == "__main__":
    main()
