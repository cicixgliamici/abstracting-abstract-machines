# Validation and allocation comparison

## Scope and reproducibility

The pinned review toolchain and fresh-checkout setup are documented in
[README.md](README.md#build-verify-reproduce). The package file fixes OCaml
4.14.1 and Dune 3.23.1. GitHub Actions runs a clean build and the full test suite
on Ubuntu 24.04 without an opam or Dune build cache, using that same package file.
This workflow checks compilation and semantic validation; it does not regenerate
the recorded performance experiments.

`dune build @all` also checks the explicit `Syntax`, `Cek`, and `Store_machine`
interfaces against their implementations and all executable/test callers.
`API.md` explains why inspection types remain visible and documents the boundary
between source entry points and low-level supported-state operations.

Run `dune build`, `dune runtest`, and `dune exec bin/main.exe`. The last command
prints CSV; redirect it to a file to repeat the checked-in comparison in
`results/allocation-comparison.csv`. The current run's timestamp, toolchain,
source identity, and CSV checksums are recorded in `results/milestone-metadata.json`.
These counts are deterministic; no runtime benchmark or cross-platform
performance claim is included.

## Executed checks

The generator enumerates all closed terms of 1-6 AST nodes over binder names
`x` and `y`: 286 terms, without randomness or sampling. Reusing names permits
shadowing. Seven hand-written examples bring the total to 293 programs.
Concrete trace prefixes contain at most 40 transitions; finite prefixes do not
establish divergence or general termination.

- CEK/CESK*: dereference the concrete store and compare control, captured closure
  environments, and the entire continuation against CEK at each observed step.
  Environment ordering is normalized because lists and maps represent the same
  mathematical binding function. Both machines must agree on halting.
- Local simulation: for each observed step and each of pool-1, pool-2, and site
  allocation, check that a successor of alpha(state) covers alpha(next state).
  Repeat after enlarging the starting store with the union of all projected
  cells in the trace. This exercises joined cells and allocation independence
  from store cardinality, rather than checking only exact abstractions.
- Reachability: compute complete fixed points for all 286 generated terms under
  all three policies and all seven named examples under site allocation. Check
  injection membership, every concrete prefix state's coverage, and successor
  closure. Large pooled examples are explored separately by the comparison
  executable instead of repeatedly scanned by routine tests.
- Targeted assertions: lexical capture returns the outer argument; shadowing
  returns the inner argument; a returned closure retains its captured binding;
  nested applications return the expected function. Labels are unique and
  deterministic even for shared source subtrees. Address roles are distinct,
  updates join, equivalent environment maps compare equally regardless of
  insertion order, and invalid inputs are rejected. An unused omega argument
  still exhausts concrete fuel, and the operator is evaluated before the operand.

These checks are stronger implementation evidence than final-result agreement,
but are not a formal soundness proof. Generated terms cover a bounded grammar;
enlarged-store tests cover specific approximating stores, not all stores.

## Allocation design

Every syntax occurrence receives a deterministic preorder label on injection.
The same input is labelled identically by both machines. Labels are metadata:
evaluation still follows lexical, left-to-right call-by-value semantics.

The site allocator uses `Binding_site(lambda_label)` for arguments bound by a
lambda and `Argument_site(application_label)` / `Function_site(application_label)`
for the two frame kinds. An argument frame carries its original application
label so evaluating the operator does not lose the site for its function frame.
Repeated execution at a site still joins values, so this is context-insensitive
and can remain imprecise. This baseline uses no store widening and has GC disabled.

Concrete addresses retain the role/site and an otherwise unique serial. Their
projection gives an executable alpha for each policy. Pool allocation now uses
an explicit capped allocation phase: deriving the next address from store size
would fail simulation when an upper store contains extra locations.

## Observations

Lexical capture and shadowing each have 11891 pooled reachable states versus
8 site-based states. Pooled lexical capture has four distinct final lambda terms;
site allocation has just the expected identity term. The returned-closure example
has two pooled terms and one site term. Omega has no final state under either
strategy; the analysis still reaches a finite fixed point.

The CSV reports reachable states, final states, and distinct final lambda syntax
(printed without labels). Final states are not distinct values; printed terms
also omit captured environments, so syntax counts are a limited precision
measure. The targeted lexical tests and whole-state simulation complement them.

Earlier unlabelled counts cannot be used as a direct before/after benchmark:
occurrence labels distinguish syntax previously merged by structural equality,
and argument frames now retain application origins. State and storable ordering
also compare maps extensionally; comparing internal balanced-tree shapes would
count duplicate semantic environments as different values or states. The
checked-in comparison holds these choices fixed between policies. The observations
support this allocator on this suite, not a universal state-count improvement.

## Garbage collection validation

The optional collector from Section 4 is now implemented on this same labelled
baseline. An eighth example exercises repeated calls to one closure, bringing
the GC suite to 294 programs. Tests cover ordinary-plus-GC simulation, collection
simulation under enlarged stores, live CEK correspondence, fixed-point coverage,
transitive roots, joined alternatives, cyclic graphs, idempotence, and reclaimed
site reuse. The original checks still run with GC off.

See [GC_EXPERIMENT.md](GC_EXPERIMENT.md) for the concrete GC comparison relation,
measurement method, results, and limitations. The GC experiment CSV is generated
by `dune exec bin/gc_comparison.exe`; the earlier allocation CSV remains the
comparison with collection disabled.

## Section 3 validation

The extended store machines add conditionals, false, mutation, and first-class
continuations. `test/section3_checks.ml` checks 872 closed extended terms with
1-5 nodes and 22 named cases. Local simulation uses all three allocation policies,
exact and enlarged upper stores, and GC off/on. Complete site-based fixed points
cover concrete trace prefixes and are closed under the extended transition rules.
Named cases have expected concrete outcomes, including escapes, shared mutation,
old-value returns, continuation reuse, and invalid applications reported as stuck.

The original CEK/GC suites retain their pure-language scope. Extended GC checks
add runtime continuation roots and mutation targets; they do not claim CEK
correspondence for a CEK language without mutable bindings. See
[SECTION3_NOTES.md](SECTION3_NOTES.md) for rule choices and proof limits, and
[results/section3-comparison.csv](results/section3-comparison.csv) for paired results
from `dune exec bin/section3_comparison.exe`.

## Independent pure reference validation

`Reference_semantics` uses a separate unlabelled AST and independently implements
name analysis, capture-avoiding substitution, and weak call-by-value reduction.
`Closure_reification` unfolds closures and evaluation contexts without using
reference substitution. `test/reference_checks.ml` checks 4034 closed terms of
1-8 nodes and 12 named examples against CEK/CESK*, with GC off/on.

Generated final values agree modulo alpha equivalence. Projected intermediate
programs match one reference reduction per beta transition and no reduction
per administrative transition, for prefixes up to 120 transitions. Another
1212 cases check the substitution free-variable law; direct cases exercise
capture hazards, shadowing, evaluation order, weak values, and reification limits.
Reference fuel counts reductions; machine fuel counts transitions. The named
CSV marks incomplete execution without a value-agreement claim.

See [REFERENCE_SEMANTICS.md](REFERENCE_SEMANTICS.md) and
[results/reference-comparison.csv](results/reference-comparison.csv). This
supports the pure evaluator correspondence but remains bounded experimental
validation; it is not an independent Section 3 semantics or general proof.

## Mathematical argument and invariant audit

[CORRECTNESS.md](CORRECTNESS.md) contains the informal mathematical argument
separately from the experimental results. It gives quantified model statements
and rule cases, with supported-state, integer, and resource assumptions. Proof
mechanization and compiled-code refinement remain open.

`test/invariant_checks.ml` checks 34 named entries and 154 extended terms of
1-4 nodes. It audits supporting FV/value/frame edges, role separation, singleton
concrete cells, allocation ranges, concrete collection commutation, and the
natural-number measure for pure administrative steps. This audit corroborates
the clauses used in the proofs; it does not establish universal quantifiers.

## Representative experiment harness

`test/experiment_checks.ml` compares all twelve representative programs under site
allocation, with GC off/on, against the original complete analyzer. It checks
explicit state/CPU cutoff statuses and completion of a graph exactly at its cap.
The runner checks full pure concrete values against the independent reference
and concrete final syntax inclusion in complete terminating analyses.
[EXPERIMENTS.md](EXPERIMENTS.md) documents the 360 raw trials and separately
reported precision, graph size, store peaks, and times. Interrupted searches
are measured prefixes and do not inherit complete fixed-point guarantees.

Small pooled graphs additionally agree with complete analysis for pool sizes
1, 4, 16, and 64 with GC off/on. Python regression checks reject changed/added
measurement sources, altered results, and modified artifact inventories; they
also check portable line endings, repeatable ZIP creation, verification after
extraction, and completion summaries with mixed trial outcomes. Run them with
`python3 -m unittest discover -s test -p '*_checks.py' -v`. CI also verifies the
checked-in provenance and artifact manifest without regenerating timings.

## Guided example

`test/guided_example_checks.ml` exercises the repeated-call walkthrough against
the independent pure reference, checks the shared binding and both reachable
final successors with their captured environments, and verifies singleton
parameter lookups and the unique final syntax with GC. The renderer uses the
production machines; it does not duplicate their rules. `--milestones` also
regenerates `results/guided-example.md` and records its checksum alongside the
four comparison CSVs. [WALKTHROUGH.md](WALKTHROUGH.md) explains every phase.
