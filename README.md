# Abstracting Abstract Machines: an implementation study

[![Build and test](https://github.com/cicixgliamici/abstracting-abstract-machines/actions/workflows/ci.yml/badge.svg)](https://github.com/cicixgliamici/abstracting-abstract-machines/actions/workflows/ci.yml)

An OCaml study of Van Horn and Might's *Abstracting Abstract Machines*: pure CEK
execution, store-allocated bindings and continuations, finite-address analysis,
mutation, first-class control, and deterministic garbage collection.

The analysis construction comes from the paper. This repository adds an
inspectable implementation, independent pure and extended evaluators, generated
semantic checks, an informal correctness argument, and reproducible experiments.
Programs are OCaml ASTs; there is no source parser or file-input CLI.

The reproduction covers the central constructions of Sections 2-4 of the
supplied eight-page paper, with specialized allocation policies and deterministic
GC. The [scope assessment](docs/PAPER_TO_CODE.md#reproduction-scope) distinguishes
implemented constructions, specializations, and excluded variants.
An [extended reference](docs/details/EXTENDED_REFERENCE.md) checks mutation and
control independently; [allocation callbacks](docs/details/ALLOCATORS.md) prepare
experiments with alternative time and address policies.

**Start with the [documentation guide](docs/README.md).** It provides a short
reading route and separates the report from technical appendices.

## Build and check

The review toolchain is **OCaml 4.14.1** and **Dune 3.23.1**, declared in the
[opam package](abstracting_abstract_machines.opam). Python 3.8+ with its standard
library is used for artifact checks and experiment reproduction.
On Windows, use Ubuntu under WSL with the checkout in the Linux home directory.

From the repository root, after the
[first-time setup](docs/REPRODUCIBILITY.md#first-time-setup):

```sh
opam exec -- dune build @all
opam exec -- dune runtest --force
python3 -m unittest discover -s test -p '*_checks.py' -v
python3 scripts/run_experiments.py --verify
python3 scripts/artifact.py --verify
```

Run `opam exec -- dune exec bin/guided_example.exe` for a worked example of
concrete execution, abstract branching, and the effect of GC.

## Repository map

| Directory | Contents |
| --- | --- |
| [docs/](docs/README.md) | Reading guide, report, reproduction instructions, technical appendices, and reference paper |
| `lib/` | Machine semantics, allocation, GC, reference evaluator, and experiment support |
| `bin/` | Runnable examples and comparisons |
| `test/` | Semantic suites, generated terms, and artifact-tooling checks |
| `scripts/` | Experiment reproduction and artifact packaging |
| [results/](results/representative/tables.md) | Recorded measurements, generated trace, and provenance |
| [.github/workflows/](.github/workflows/ci.yml) | Clean build, tests, and recorded-evidence verification |

## Evidence and limits

The [report](docs/REPORT.md) presents the research question, results, and scope.
The proof argument is informal and generated checks are bounded. Workloads are
small semantic examples; timings do not establish general performance claims.

CI runs on Ubuntu 24.04 with the pinned OCaml/Dune versions. It builds all targets,
runs the OCaml and Python suites, and verifies recorded provenance and the review
manifest. It verifies existing measurements without rerunning benchmarks.
The badge links to the run history for checking a specific revision.

[Reproduction instructions](docs/REPRODUCIBILITY.md) cover clean setup, all CI
commands, experiment regeneration, archive verification, and reproducibility limits.
