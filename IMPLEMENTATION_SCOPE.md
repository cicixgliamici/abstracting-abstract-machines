# Implementation scope

## Implemented milestones

- Closed untyped lambda terms represented by OCaml algebraic data types.
- Lexical, left-to-right call-by-value CEK execution.
- Fresh-address CESK* execution with bindings and continuations in the store.
- Bounded-address nondeterministic analysis with joined store cells.
- Deterministic syntax labels and allocation by binder/application site, with
  disjoint address constructors for bindings and the two continuation-frame roles.
- Explicit pooled allocation phase and executable alpha maps for both policies.
- Per-state-store reachability by an explicit worklist and visited set.
- Identity, application, lexical capture, shadowing, returned closure, nested
  application, and omega examples.
- 286 systematically generated closed terms over two binder names (1-6 nodes).
- Whole-state CEK/CESK* projection, local simulation under enlarged stores,
  fixed-point closure, and coverage of concrete trace prefixes.
- Reproducible CSV comparison of pool-1 and site-based allocation.
- Optional concrete and abstract deterministic garbage collection from Section 4,
  scheduled after every transition, with free-variable roots and cycle-safe marking.
- An eighth example demonstrating a precision gain when a reclaimed binder site
  is reused; GC simulation and reachability checks on 294 programs.
- GC off/on CSV comparison with state counts, final-term counts, reached-store
  address/value peaks, and median CPU timing over three repetitions.
- Section 3 store-machine extensions: false, conditionals, mutation returning
  the old value, call/cc, and first-class, reusable captured continuations.
- Strong concrete and weak abstract mutation; runtime-address alpha and GC roots
  for the new values and frames. Stuck execution is separate from halting/fuel.
- 872 generated extended terms (1-5 nodes) and 22 named Section 3 examples, with
  simulation under all three policies and complete site fixed points, GC off/on.
- Independent Section 2.1 reduction evaluator with its own unlabelled AST,
  capture-avoiding substitution, free-variable analysis, and alpha equivalence.
- Pure closure reification and complete-program projection from CEK/CESK states,
  without reference substitution and compatible with GC.
- Differential checks on 4034 pure closed terms (1-8 nodes), 12 named examples,
  and 1212 open substitution-law cases; CSV with reified final values.
- Informal correctness chapter with explicit invariants, pure evaluator
  correspondence, allocation/update lemmas, all raw rule simulation cases,
  GC preservation/simulation, and finite worklist correctness.
- Invariant audit on 34 named entries and 154 tiny extended terms, covering live
  edge support, roles, counters, concrete GC commutation, and administrative descent.
- Twelve representative programs, 120 configurations, and 360 raw trials regenerated
  by a standard-library Python harness, with source hashes and environment metadata.
- Sites and pools of 1/4/16/64 addresses, pipeline/Church sizes 2/4/8, and explicit
  per-policy completion rates under equal budgets.
- Content-addressed review archive and manifest with source/result provenance
  verification, independent of a dirty or missing Git checkout.
- Separate precision, graph-size, store-footprint, and CPU/wall timing tables;
  bounded experimental searches report cutoffs and omit incomplete precision.
- A consolidated implementation report in [REPORT.md](REPORT.md) and reviewer
  reading/source routes in [README.md](README.md).
- An executable guided example with the full CEK trace, the first site-based
  abstract choice, and the GC precision gain, explained in `WALKTHROUGH.md` and
  checked against independent evaluation and actual closure alternatives.

Concrete execution reports fuel exhaustion separately from successful evaluation.
Fuel exhaustion does not prove divergence. The library `Store_machine.analyze`
has no cutoff: a returned set is a complete fixed point for its abstract system.
The separate experimental explorer may return an explicitly incomplete prefix.
It may contain spurious results. An abstract final state does not prove concrete
termination.

## Deliberate boundaries

No parser, arithmetic, context sensitivity, global store widening, or production
compiler integration. The CEK reference covers only the pure lambda subset;
the store machines cover Section 3 as well.
Examples are ASTs to keep semantic rules visible. `CORRECTNESS.md` supplies an
informal mathematical argument; machine-checked verification and refinement
of its integer/resource assumptions to compiled execution remain open.
Recorded CPU timings do not establish general performance improvement. Maps and
sets use extensional comparison so internal tree shape does not create duplicate
states. Large state spaces will require profiling and more efficient representations.

## MVP completion and subsequent work

The repository-based MVP includes the implementation, validation, informal
correctness chapter, representative experiments, and consolidated report.
The pure reference semantics and pure value reification are implemented;
these are not novelty claims. Subsequent research work includes proof
mechanization, resource/representation refinement, an independent Section 3
semantics, extended/cyclic denotations, context-sensitive allocation, and larger
application workloads. A submission-specific PDF/layout can be prepared once
the destination's requirements are known.
