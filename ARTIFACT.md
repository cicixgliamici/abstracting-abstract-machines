# Review artifact identity and reproduction

The review series is named in `VERSION`. `ARTIFACT.json` is the authoritative
inventory of source files, documentation, and results. Its artifact ID consists
of the series name and the first 16 hex digits of a SHA-256 payload digest; the
full digest and every individual file checksum are included. It deliberately
does not rely on a Git commit that might omit local changes.

## Verify before review

```sh
python3 scripts/artifact.py --verify
```

Verification checks the inventory, file hashes, payload identity, and both
measurement provenance records. Added source/result files also invalidate the
manifest. Text hashes normalize CRLF to LF, matching `.gitattributes`; the paper
PDF is hashed as binary. Git history and an OCaml installation are unnecessary
for this check. Python 3.8+ and its standard library suffice.

`results/representative/metadata.json` and `results/milestone-metadata.json`
record the complete measurement-source manifest, its SHA-256 identity, versions,
configuration, and output checksums. Measurement sources include implementation,
executables, tests, Python tooling, dependency declarations, and CI. Documentation
and the paper are in the artifact inventory but excluded from the measurement
identity, so observations can be written after a run without changing its code.
Git revision/status are retained only as supplementary context. Measurement-source
changes during a run are rejected. These checks detect stale or altered files;
they do not establish that a claimed experiment was honestly executed.

## Regenerate and package

Use the pinned environment in `README.md`, then run:

```sh
opam exec -- dune build @all
opam exec -- dune runtest --force
python3 -m unittest discover -s test -p '*_checks.py' -v
opam exec -- python3 scripts/run_experiments.py --milestones
python3 scripts/run_experiments.py --verify
python3 scripts/artifact.py
```

The final command first rejects stale measurement sources or altered results,
then writes `ARTIFACT.json`, `artifacts/<artifact-id>.zip`, and its `.zip.sha256`
sidecar. Review the manifest and results with the source changes. Commit them
together if publishing a repository revision; no commit or tag is created by
these commands. Future source changes require remeasurement before repackaging.

Archive entries have stable order, timestamps, and permissions. Repackaging the
same payload with the same Python/zlib toolchain produces the same ZIP bytes.
Across compression-tool versions, use the payload manifest as the authoritative
identity and verify the downloaded ZIP against its accompanying checksum.

The archive can be extracted and verified independently of this checkout.
Create a local opam switch in the extracted directory to repeat build and tests.
Rerunning timings will generally change result hashes and therefore artifact
identity, even when deterministic graph measurements agree. The artifact is
not a frozen operating-system image or a signed release.
