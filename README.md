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

Requirements: OCaml 4.13+, Dune 2.9+, and Python 3.8+ for experiments. The OCaml
implementation uses only standard libraries. The recorded toolchain is OCaml
4.14.1, Dune 3.23.1, and Python 3.12.3 in Ubuntu WSL.

```sh
dune build
dune runtest
python3 scripts/run_experiments.py
```

Run from the repository root. On Windows with Ubuntu WSL:

```powershell
wsl -d Ubuntu -- bash -lc 'cd /mnt/c/Progetti/abstracting-abstract-machines && dune build && dune runtest && python3 scripts/run_experiments.py'
```

The Python command regenerates ten programs, 40 configurations, 120 raw trials,
four separate tables, and toolchain/source metadata in
[`results/representative/`](results/representative/tables.md). It uses explicit
state, CPU, and wall limits and marks interrupted searches as incomplete.
[EXPERIMENTS.md](EXPERIMENTS.md) explains the measurements and configuration flags.
Programs are OCaml ASTs; there is no source parser or file-input CLI.

The smaller milestone comparisons remain available:

```sh
dune exec bin/main.exe
dune exec bin/gc_comparison.exe
dune exec bin/section3_comparison.exe
dune exec bin/reference_comparison.exe
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

In the representative results, site allocation completes all 20 configurations.
Fourteen pool configurations hit the state cap. GC reduces shared-write states
from 85 to 33 and multi-shot continuation states from 736 to 96; it does not
remove every spurious result. Results distinguish precision proxies, graph size,
store footprint, and timing rather than treating one as evidence for another.

Printed final-value syntax omits closure environments and continuation identity.
Fuel exhaustion does not establish divergence, and an abstract final state does
not establish concrete termination. The project supplies an informal correctness
argument under idealized integer/resource assumptions, not a machine-checked
certificate for the executable. An independent extended-language semantics,
context-sensitive allocation, and global store widening remain outside scope.
