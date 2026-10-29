# Abstracting Abstract Machines: an implementation study

This OCaml project studies how an evaluator becomes a conservative higher-order
program analysis. It implements the main construction of David Van Horn and
Matthew Might's *Abstracting Abstract Machines*: pure CEK execution, a fresh
store-allocated machine, finite-address analysis, state and control extensions,
and deterministic garbage collection.

The purpose is to demonstrate research-paper interpretation, implementation,
and verification. The repository adds an independent pure substitution evaluator,
explicit correctness arguments, generated tests, and reproducible experiments.
These are implementation-study contributions; the analysis algorithm comes from
the paper. [REPORT.md](REPORT.md) presents the study and its boundaries.

## Build, verify, reproduce

The review environment fixes OCaml **4.14.1** and Dune **3.23.1** in
[`abstracting_abstract_machines.opam`](abstracting_abstract_machines.opam).
The OCaml implementation uses only standard libraries. Python 3.8+ is needed
only to regenerate experiments; the recorded experiments used Python 3.12.3.

On Ubuntu (including Ubuntu under WSL), install opam and compiler prerequisites:

```sh
sudo apt-get update
sudo apt-get install -y opam build-essential m4 pkg-config unzip bubblewrap git
opam init --bare --no-setup
```

Run `opam init` only when opam has not already been initialized. From a fresh
checkout, create an isolated local switch and install the declared dependencies:

```sh
git clone https://github.com/cicixgliamici/abstracting-abstract-machines.git
cd abstracting-abstract-machines
opam update
opam switch create . ocaml-base-compiler.4.14.1 --no-install
opam install . --deps-only --with-test --yes
opam exec -- ocamlc -version
opam exec -- dune --version
opam exec -- dune build @all
opam exec -- dune runtest --force
```

The version commands should print `4.14.1` and `3.23.1`. The local switch is
stored in ignored `_opam/`; `opam exec --` selects it without changing shell
startup files. For an existing checkout, start at `opam switch create`; if its
local switch already exists, skip creation and reinstall dependencies instead.

To regenerate experiments, install Python separately and use the same switch:

```sh
sudo apt-get install -y python3
opam exec -- python3 scripts/run_experiments.py
```

On Windows, run the setup above inside an Ubuntu WSL terminal. After setup,
build and test from PowerShell with the actual path of your checkout:

```powershell
wsl -d Ubuntu -- bash -lc 'cd /mnt/c/Progetti/abstracting-abstract-machines && opam exec -- dune build @all && opam exec -- dune runtest --force'
```

The [CI workflow](.github/workflows/ci.yml) runs on pushes, pull requests, and
manual dispatches using Ubuntu 24.04 and the same compiler and dependency file.
Each job starts from a clean checkout, disables the setup action's opam cache,
clears Dune build output, builds all targets, and forces the complete test suite.
Experiments remain a separate manual step because their timings depend on the
host. Exact compiler/Dune versions make the review toolchain repeatable; this
does not freeze Ubuntu packages, opam repository metadata, or benchmark timings.

The Python command regenerates twelve programs, 120 configurations, 360 raw trials,
four measurement tables, a completion table, and toolchain/source metadata in
[`results/representative/`](results/representative/tables.md). It uses explicit
state, CPU, and wall limits and marks interrupted searches as incomplete.
[EXPERIMENTS.md](EXPERIMENTS.md) explains the measurements and configuration flags.
Programs are OCaml ASTs; there is no source parser or file-input CLI.

## Identifiable review artifact

[`VERSION`](VERSION) names the review series. [`ARTIFACT.json`](ARTIFACT.json)
identifies the exact source/documentation/result payload with SHA-256 checksums;
the identity is independent of whether the working tree has been committed.
The archive includes sources, tests, CI, documentation, the supplied paper, and
all checked-in results, but excludes Git history, switches, and build output.

```sh
python3 scripts/run_experiments.py --verify
python3 scripts/artifact.py --verify
```

To regenerate all measurements and then produce a shareable archive:

```sh
opam exec -- python3 scripts/run_experiments.py --milestones
python3 scripts/artifact.py
```

The ZIP and its external SHA-256 file are written to ignored `artifacts/`.
After extraction, run `python3 scripts/artifact.py --verify` before following
the local-switch setup above. Archive contents use LF text line endings on all
platforms. The checksum establishes payload identity, not authorship or a formal
correctness certificate. [ARTIFACT.md](ARTIFACT.md) explains verification and updates.

The smaller milestone comparisons remain available:

```sh
opam exec -- dune exec bin/main.exe
opam exec -- dune exec bin/gc_comparison.exe
opam exec -- dune exec bin/section3_comparison.exe
opam exec -- dune exec bin/reference_comparison.exe
```

Each prints CSV to standard output. These comparisons use their documented
budgets; their abstract analyses compute complete fixed points without cutoffs.
Some pooled examples exceed 11,000 states. They complement the bounded
representative experiment rather than sharing its limits or timing protocol.

## Reading route for reviewers

| Read | Purpose |
| --- | --- |
| [REPORT.md](REPORT.md) | Research question, implementation, evidence, results, and limitations |
| [PAPER_NOTES.md](PAPER_NOTES.md) | Interpretation of the supplied paper and allocation choices |
| [PAPER_TO_CODE.md](PAPER_TO_CODE.md) | Trace each construction to its implementation and checks |
| [CORRECTNESS.md](CORRECTNESS.md) | Invariants and informal simulation/correctness proofs |
| [EXPERIMENTS.md](EXPERIMENTS.md) and [tables](results/representative/tables.md) | Reproduce and interpret the results |
| [IMPLEMENTATION_SCOPE.md](IMPLEMENTATION_SCOPE.md) | Implemented scope and remaining work |

Detailed companion documents are [VALIDATION.md](VALIDATION.md) for test coverage,
[GC_EXPERIMENT.md](GC_EXPERIMENT.md) for the original GC comparison,
[SECTION3_NOTES.md](SECTION3_NOTES.md) for mutation/control, and
[REFERENCE_SEMANTICS.md](REFERENCE_SEMANTICS.md) for independent pure validation.
The source reference is the supplied [paper PDF](<Abstracting Abstract Machines.pdf>).

## Source navigation

| Component | Entry point |
| --- | --- |
| Syntax, labels, free variables | [lib/syntax.ml](lib/syntax.ml) |
| Pure concrete CEK | [lib/cek.ml](lib/cek.ml) |
| Fresh/finite store machines, abstraction, GC, complete worklist | [lib/store_machine.ml](lib/store_machine.ml) |
| Independent pure reduction and closure reification | [lib/reference_semantics.ml](lib/reference_semantics.ml), [lib/closure_reification.ml](lib/closure_reification.ml) |
| Bounded experiment search and corpus | [lib/experiment_analysis.ml](lib/experiment_analysis.ml), [lib/experiment_examples.ml](lib/experiment_examples.ml) |
| Experiment executable and regeneration | [bin/experiments.ml](bin/experiments.ml), [scripts/run_experiments.py](scripts/run_experiments.py) |
| Test-suite entry point | [test/machines_test.ml](test/machines_test.ml) |

Library calls inside the `Aam` namespace:

```ocaml
Store_machine.run Examples.lexical_capture
Store_machine.analyze ~policy:Store_machine.Site_based Examples.lexical_capture
Store_machine.analyze ~policy:(Store_machine.Bounded 1) Examples.lexical_capture
Store_machine.analyze ~policy:Store_machine.Site_based ~gc:true Examples.repeated_calls
```

## What the evidence supports

Tests cover machine-state correspondence, local abstract simulation, reachability,
GC, mutation/control, and independent pure evaluation. The reference suite checks
4,034 generated closed terms and 1,212 open substitution-law cases. The informal
proof chapter states mathematical assumptions separately from bounded tests.

The representative comparison includes sites and pools of 1, 4, 16, and 64
addresses, with GC off/on and pipeline/Church sizes 2, 4, and 8. The
[completion table](results/representative/completion.csv) reports how many
configurations finish under the shared resource budget. GC reduces shared-write states
from 85 to 33 and multi-shot continuation states from 736 to 96; it does not
remove every spurious result. Results distinguish precision proxies, graph size,
store footprint, and timing rather than treating one as evidence for another.
In this run, sites and pool16 with GC complete all twelve programs; pool64
completes eleven. Increasing a pool is therefore not a guarantee of completion.

Printed final-value syntax omits closure environments and continuation identity.
Fuel exhaustion does not establish divergence, and an abstract final state does
not establish concrete termination. The project supplies an informal correctness
argument under idealized integer/resource assumptions, not a machine-checked
certificate for the executable. An independent extended-language semantics,
context-sensitive allocation, and global store widening remain outside scope.
