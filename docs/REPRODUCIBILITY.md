# Build, CI, and reproducibility

Run all commands from the repository root. The supported review environment is
Ubuntu, including Ubuntu under WSL, with OCaml **4.14.1**, Dune **3.23.1**, and
Python **3.8+**. The OCaml implementation and Python tooling use standard libraries.
The [opam package](../abstracting_abstract_machines.opam) fixes OCaml and Dune;
`dune-project` declares the accepted Dune language version, not the installed
tool version.

## First-time setup

On a fresh Ubuntu installation:

```sh
sudo apt-get update
sudo apt-get install -y opam build-essential m4 pkg-config unzip bubblewrap git python3
opam init --bare --no-setup
```

Run `opam init` only if opam has not already been initialized. On WSL, clone into
the Linux home directory (`cd ~`), as in the PowerShell example below. Clone the
repository and create an isolated local switch:

```sh
git clone https://github.com/cicixgliamici/abstracting-abstract-machines.git
cd abstracting-abstract-machines
opam update
opam switch create . ocaml-base-compiler.4.14.1 --no-install
opam install . --deps-only --with-test --yes
opam exec -- ocamlc -version
opam exec -- dune --version
python3 --version
```

The OCaml and Dune commands should print `4.14.1` and `3.23.1`. The ignored
`_opam/` directory holds the local switch. `opam exec --` selects it without
editing shell startup files. For an existing checkout, skip cloning; if its local
switch already exists, skip creation and install the declared dependencies.

On Windows, run setup inside an Ubuntu WSL terminal. Once installed, checks can
also be launched from PowerShell; this example assumes the checkout is in the
Linux home directory:

```powershell
wsl -d Ubuntu -- bash -lc 'cd ~/abstracting-abstract-machines && opam exec -- dune build @all && opam exec -- dune runtest --force'
```

## Build and run all CI checks

```sh
opam lint abstracting_abstract_machines.opam
opam exec -- dune clean
opam exec -- dune build @all
opam exec -- dune runtest --force
python3 -m unittest discover -s test -p '*_checks.py' -v
python3 scripts/run_experiments.py --verify
python3 scripts/artifact.py --verify
```

| Check | What a passing result establishes |
| --- | --- |
| Package lint and clean build | The declared dependencies build all targets; module interfaces match implementations and callers |
| OCaml suites | The bounded semantic, simulation, invariant, reference, and experiment checks pass; see [VALIDATION.md](VALIDATION.md) |
| Python suites | Packaging, corruption detection, nested documentation, line endings, and completion summaries pass their regression checks |
| Experiment verification | Recorded result hashes and measurement-source snapshots match this checkout |
| Artifact verification | The complete review payload matches `ARTIFACT.json` |

The [workflow](../.github/workflows/ci.yml) runs on pushes, pull requests, and
manual dispatches, with Ubuntu 24.04 and the same package file. Actions are pinned
to commit hashes, token permissions are read-only, setup caching is disabled,
and Dune output is cleaned before building. Python comes from the Ubuntu runner.
The workflow verifies recorded experiments without rerunning their timings.
Check the [run history](https://github.com/cicixgliamici/abstracting-abstract-machines/actions/workflows/ci.yml)
for the revision being reviewed; local changes need a new remote run after push.

## Reproduce the examples and measurements

```sh
opam exec -- dune exec bin/guided_example.exe
opam exec -- python3 scripts/run_experiments.py --milestones
python3 scripts/run_experiments.py --verify
```

The first command prints the [worked trace](../results/guided-example.md).
The runner regenerates twelve programs, 120 configurations, and 360 raw trials
with explicit state, CPU, and wall limits. `--milestones` also regenerates four
separate comparison CSVs and the trace, retaining their complete-analysis
protocols. [EXPERIMENTS.md](EXPERIMENTS.md) defines metrics, budgets, and options;
the [GC appendix](details/GARBAGE_COLLECTION.md) defines the separate GC protocol.
Results are overwritten, so keep a separate copy before comparing runs.

## Verify and package a review archive

[`VERSION`](../VERSION) names the review series. [`ARTIFACT.json`](../ARTIFACT.json)
identifies the payload using SHA-256 file hashes and an artifact ID independent
of Git history. It includes sources, tests, CI, all documentation and the paper,
and checked-in results. It excludes switches, build output, and Git history.

```sh
python3 scripts/artifact.py --verify
python3 scripts/artifact.py
```

Packaging first rejects stale measurement sources or altered results, then writes
the manifest, `artifacts/<artifact-id>.zip`, and a `.zip.sha256` sidecar. After
extraction, run `python3 scripts/artifact.py --verify`, then follow the setup and
checks above; skip cloning because the extracted directory is already the root.

The two measurement metadata files record full source manifests, output hashes,
tool versions, configuration, and platform. Added or changed executable sources,
tests, tooling, dependency declarations, or CI invalidate the recorded run and
require remeasurement before repackaging. Documentation and the paper contribute
to artifact identity but do not invalidate measurements. Commit updated sources,
results, and manifest together when publishing a revision.

## Reproducibility boundaries

Builds and semantic checks are repeatable with the declared toolchain. Complete
graph measurements are deterministic for fixed inputs and policies. CPU/wall
times and resource cutoffs depend on the host, so rerunning may change results
and artifact identity; incomplete searches are explicitly marked.

This is not a hermetic environment: Ubuntu packages, opam repository metadata,
opam itself, and Python are not all pinned. Native Windows/macOS compatibility
is not covered by CI. A clean archive build with an installed pinned toolchain
checks payload completeness; it does not retest provisioning a fresh machine.

In this checkout on `/mnt/c`, `dune clean` repeatedly emitted an internal
`Unix.ENOENT` error from `Global_lock.Lock.unlock` while the subsequent build
and tests still passed. Use a checkout on the Linux filesystem for the clean
review workflow. The extracted archive was also checked on that filesystem.

Text hashes normalize CRLF to LF; the PDF is hashed as binary. ZIP entries use
stable order, timestamps, and permissions. The same payload and Python/zlib
toolchain produce repeatable ZIP bytes; across compression versions, use the
payload manifest as the identity. Checksums detect stale or changed content,
but do not establish authorship, honest execution, or a correctness certificate.
