# From an evaluator to a finite analysis: an implementation study

## Abstract

This study implements the core construction of Van Horn and Might's *Abstracting
Abstract Machines* in OCaml. Starting from weak, left-to-right call-by-value
lambda evaluation, it makes bindings and continuations store allocated and
replaces fresh addresses with finite allocation policies. Joined cells induce
nondeterministic transitions, whose reachable states are explored by a worklist.
The implementation also supports conditionals, mutation, first-class continuations,
and deterministic garbage collection.

Validation combines generated terms, whole-state comparisons, local simulation,
an independent capture-avoiding substitution evaluator, and an informal correctness
argument. A reproducible twelve-program experiment separates precision, state counts,
store footprint, and timing. Results expose allocation-dependent imprecision,
benefits and limits of GC, and incomplete coarse-pool searches. The outcome is
a reviewable implementation study with explicit boundaries on its claims.

## 1. Research question and source

Higher-order functions complicate static analysis because closures contain
environments and evaluation uses recursively structured continuations. The paper
asks how to derive a computable conservative analysis from an operational
evaluator. Its central answer is to redirect recursive structure through a store,
then bound addresses and allocation history.

The source is David Van Horn and Matthew Might, *Abstracting Abstract Machines:
A Systematic Approach to Higher-Order Program Analysis*, supplied
arXiv:1105.1743v1, 9 May 2011, identifying ICFP 2010 as the original publication.
Page references refer to the eight-page [supplied PDF](<Abstracting Abstract Machines.pdf>).
This study focuses on Sections 2-4 and Figures 1-7.
[PAPER_NOTES.md](PAPER_NOTES.md) explains the interpretation;
[PAPER_TO_CODE.md](PAPER_TO_CODE.md) maps constructions to executable rules.

The implementation question is narrower than full reproduction: can these
constructions be made inspectable, checked against independent pure evaluation,
and used to measure allocation and collection effects on small programs?

## 2. From concrete evaluation to finite analysis

The core language consists of variables, lambda abstractions, and applications.
Programs must be closed. Evaluation is weak: lambda bodies are evaluated only
when applied. Applications evaluate the operator before the operand, and an
unused argument is still evaluated. Programs are algebraic data types so the
study can concentrate on semantic rules rather than parser behavior.

The CEK machine represents a control expression, lexical environment, and
continuation. Environments bind names to closures. An argument frame remembers
the operand and its environment; a function frame remembers the evaluated
operator. Application enters a closure's body in its saved environment extended
with the actual argument. Shadowing replaces the binding visible at that name.

The store machine redirects bindings and continuation tails through addresses.
Fresh execution allocates a new serial at each allocation event and has singleton
cells. Concrete address provenance records source site and role, making
abstraction executable without changing fresh behavior. The halt address is
reserved and allocation starts at one. Environment/store comparison is
extensional, so map insertion history cannot introduce duplicate semantic states.

Finite allocation reuses addresses. Insertion unions alternatives and lookup
explores every compatible storable. Two simple policies are implemented:

* A bounded pool fills N addresses, then always reuses address one. An explicit
  phase is capped at N; allocation is independent of store cardinality and is
  not round-robin.
* Site allocation uses syntax occurrence labels and separate constructors for
  bindings and frame roles. Its phase is constant.

Neither policy is claimed to reproduce a named k-CFA analysis exactly. Each state
retains its own store; there is no global store widening. For a fixed finite
program and finite policy, the mathematical state domain is finite. The complete
analyzer computes its reachable fixed point, subject to sufficient resources.
Finiteness alone does not ensure practical scalability.

## 3. State, control, and collection

The Section 3 extension adds false, conditionals, assignment, `call/cc`, and
captured continuations. Only false selects a conditional's alternative branch.
Assignment returns the old value, following the supplied rules, and restores
its saved environment when returning a closure. Fresh mutation replaces the
unique cell; abstract mutation joins alternatives.

Continuations can be returned, stored, and invoked repeatedly. Invocation
replaces the current continuation while preserving the current store: mutations
survive a jump. Applying false or passing false to `call/cc` produces stuck
concrete execution. The CEK and substitution evaluators remain pure references.

Optional collection follows each ordinary step. Roots include the current
continuation, control free-variable bindings, captured addresses, saved branches,
and pending assignment targets. Marking traverses every alternative in a live
cell and terminates on cycles. Collection restricts the store and preserves
allocation phase. Unused environment entries may point to removed cells because
subsequent reads require only supported free-variable bindings.

The deterministic schedule matters: arbitrary standalone GC steps would also
retain uncollected paths. GC cannot remove an obsolete alternative from a
still-live joined cell. [SECTION3_NOTES.md](SECTION3_NOTES.md) and
[GC_EXPERIMENT.md](GC_EXPERIMENT.md) give targeted examples and rule details.

## 4. Correctness argument and validation

Two machines sharing transition code could agree because of a shared error.
The independent pure evaluator therefore uses its own unlabelled AST, name
analysis, capture-avoiding substitution, and evaluation contexts. Closure
reification reconstructs pure programs from lexical values and pending frames
without calling reference substitution. Alpha equivalence compares results
without depending on binder spelling.

Tests check projected transitions as well as final values. Administrative steps
preserve the reconstructed program; beta steps match reference reduction.
Reification supports pure singleton acyclic stores, not joined abstract cells
or cyclic extended values. [REFERENCE_SEMANTICS.md](REFERENCE_SEMANTICS.md)
documents the independence boundary.

| Layer | Executed coverage and purpose |
| --- | --- |
| Core machines | 286 closed terms, 1-6 nodes, plus seven named examples; whole-state projection and local simulation |
| GC | 294 programs; collected correspondence, cycles, address reuse, and simulation |
| State/control | 872 generated terms, 1-5 nodes, and 22 named examples; simulation and site fixed points |
| Independent pure semantics | 4,034 closed terms, 1-8 nodes, 12 named examples, and 1,212 open substitution-law cases |
| Invariant audit | 34 named entries and 154 tiny extended terms; support, roles, phases, fresh GC commutation, administrative descent |
| Experiment search | Twelve programs, sites with GC off/on and small graphs for pools 1/4/16/64; complete graphs agree with the original analyzer and cutoffs are explicit |

Generated grammars and trace prefixes are bounded. Coverage overlaps across
suites, so counts should not be summed as independent samples. Open substitution
cases exercise capture hazards that closed result comparisons can miss.
[VALIDATION.md](VALIDATION.md) records methods and budgets.

[CORRECTNESS.md](CORRECTNESS.md) supplies the mathematical layer: supported
environment/store edges, reserved halt, singleton concrete cells, role separation,
allocation phases, pure correspondence, and per-rule forward simulation. Strong
concrete updates are covered by weak abstract updates. GC simulation uses
`alpha(G(s)) <= G(alpha(s))` and monotonicity, without assuming abstraction
commutes with collection. An administrative-work measure excludes infinite
pure stuttering. Worklist correctness concerns the complete analyzer, not
interrupted experiments.

The argument assumes natural-number counters, well-formed states, mathematical
maps/sets, and sufficient memory/stack resources. It is an informal model proof,
not Lean/Coq verification or compiled-code refinement. Extended abstract
soundness is relative to the concrete Section 3 rules; those rules lack an
independent extended-language oracle here.

## 5. Reproducible experiments and results

The corpus combines identity pipelines and Church iteration of lengths two/four/eight,
repeated closure calls, shared writes, old-closure environment restoration,
continuation escape, multi-shot invocation, and omega. Each runs under sites and
pools of 1, 4, 16, and 64 addresses, with GC off/on, in three fresh processes:
120 configurations and 360 trials. The harness records exact printed sources,
toolchain/platform metadata, settings, Git state, and source/result hashes.
`ARTIFACT.json` identifies the complete review payload independently of Git;
`ARTIFACT.md` documents verification and packaging.

Defaults cap exploration at 5,000 states or two CPU seconds, with a 15-second
process watchdog. Every search reports completion or its cutoff. Interrupted
graphs are reached prefixes and have no assessed final-result precision. The
complete library analyzer retains its original unbounded contract.

| Quantity | Definition | Interpretation limit |
| --- | --- | --- |
| Precision proxy | Extra final syntaxes beyond a finished concrete result, plus concrete syntax inclusion | Omits labels, environments, and continuation identity |
| Graph size | Reached/final state cardinalities | Partial counts are not fixed-point sizes |
| Store footprint | Maximum addresses and storable alternatives in a reached state | Post-GC peaks; excludes transient stores and whole-process memory |
| Timing | Median exploration CPU/wall seconds | Excludes startup, reference checks, compilation, summarization; cutoff time is not completion time |

The completion table reports per-policy results under the same budget, requiring
every repetition to finish before counting a configuration as complete. Partial
graphs expose a budget boundary, not impossibility of completion with more
resources. Selected complete site results:

| Program | States, GC off / on | Extra final syntax, off / on | Peak store addresses, off / on |
| --- | ---: | ---: | ---: |
| Repeated calls | 18 / 17 | 1 / 0 | 12 / 4 |
| Shared writes | 85 / 33 | 2 / 2 | 22 / 5 |
| Church iteration, four applications | 28 / 28 | 0 / 0 | 16 / 7 |
| Multi-shot continuation | 736 / 96 | 2 / 1 | 34 / 8 |

Repeated calls show a precision-proxy gain when a dead argument is reclaimed
before binder-site reuse. Shared writes show fewer states without fewer spurious
syntaxes. Church iteration shows a smaller store without a smaller graph.
Multi-shot invocation shows graph reduction while an extra result remains.
These observations justify separating the metrics.

The expanded allocator comparison completes 89 of 120 configurations; the
remaining 31 hit the state cap in every repetition. Sites complete 12/12 programs
with GC off and on; pools 1, 4, 16, and 64 complete respectively 4/4, 6/8, 9/12,
and 11/11 programs (off/on). Pool16 with GC completes `multi_shot` at 173 states,
whereas pool64 reaches the cap; sites with GC need 96 states. Increasing the
pool postpones saturation but does not guarantee smaller graphs or completion.
For `church_8`, sites and pool64 both have 48 states; pool16 with GC needs 965
and retains two extra final syntaxes. These comparisons expose intermediate
allocation effects beyond the deliberately extreme one-cell baseline.

Tiny runs and local medians do not establish general speedups. The separate complete
pool-one baseline also illustrates allocation imprecision: lexical capture has
11,891 states and four final lambda syntaxes, versus eight states and one syntax
under sites. That separate protocol must not be merged with capped experiments
as one dataset. [EXPERIMENTS.md](EXPERIMENTS.md), the
[tables](results/representative/tables.md), and [raw trials](results/representative/raw.csv)
provide the full method and observations.

## 6. Contributions, limitations, and conclusion

The reproduced contribution is the paper's evaluator-to-analysis construction,
including state/control and deterministic GC. Repository-specific choices
include source labels, allocation provenance, reserved halt, explicit pooled
phase, role-separated sites, and extensional comparison. They make the
construction inspectable without constituting a novel analysis algorithm.

The study adds independent pure substitution/reification, generated simulation
checks, an invariant audit, an informal proof chapter, and reproducible experiments.
These demonstrate research interpretation and verification rather than a new
theoretical result.

There is no parser, arithmetic, type system, or production compiler integration.
The corpus contains small semantic workloads, not representative applications.
Context-sensitive allocation and global store widening are outside scope.
An independent Section 3 semantics, extended/cyclic denotation, proof mechanization,
and compiled resource refinement remain open. Fuel exhaustion is not a divergence
certificate, and abstract final states are possibilities rather than concrete
termination witnesses.

The MVP provides a repository-based implementation report with traceable rules,
evidence, and explicit limits. Further research extensions can be assessed
separately. Reproduce it with `dune build`, `dune runtest`, and
`python3 scripts/run_experiments.py`; the [README](README.md) gives the WSL command
and reading route. A venue-specific submission still requires the requested
layout, bibliography style, and packaging; no submission format is assumed.
