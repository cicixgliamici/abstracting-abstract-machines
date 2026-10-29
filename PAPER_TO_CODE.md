# Paper-to-code mapping

| Paper location | Construction | Implementation | Evidence / boundary |
| --- | --- | --- | --- |
| Section 2.1, p. 2 | Lambda syntax; closed programs | `lib/syntax.ml`, `Reference_semantics.of_syntax` | Source labels ignored by an independent core AST and closedness check |
| Section 2.1, p. 2 | Beta-value reduction and evaluation contexts | `Reference_semantics.substitute`, `step`, `run` | Capture avoidance, operator/operand order, and weak evaluation checked |
| Sections 2.2-2.3, pp. 3-4 | Closure denotation (`real`) and evaluator correctness | `Closure_reification`, `test/reference_checks.ml` | 4034 closed terms; program projection and reified results, GC off/on; experimental evidence for Lemmas 1/3 |
| Figure 1, p. 3 | CEK state and four transitions | `lib/cek.ml`, `initial`, `step`, `run` | Complete state projection in `test/concrete_projection.ml` |
| Figure 2, p. 4 | Store-allocated bindings and frames | `lib/store_machine.ml`, `Fresh`, `successors` | Fresh singleton cells and deterministic traces |
| Figure 3, p. 4 | Allocation and timestamps | `allocate`, `next_phase` | Explicit concrete counter, capped pooled phase, singleton site phase |
| Figure 4, p. 5 | Joined store; nondeterministic lookup | `insert`, `lookup`, `continue`, `successors`, `Bounded`, `Site_based` | Pool and role-separated site policies compared in CSV |
| Reachable-state semantics, Section 2.5 | Reflexive transitive closure | `analyze`, `States` | Initial state included; successor closure checked |
| Figure 5, p. 5 | Structural abstraction | `abstract_state`, `abstract_value`, `approximates` | Local simulation for pools 1/2 and sites, including enlarged stores |
| Theorems 1-2, p. 5 | Soundness and decidability | `CORRECTNESS.md`, Sections 6-11 | Informal allocation/raw/collected simulation and finite-worklist proofs; mechanization/resource refinement open |
| Section 4, p. 6 | Free-variable roots and live-location least fixed point | `expression_addresses`, `storable_addresses`, `live_addresses` | Joined cells, saved-frame roots, transitive captures, and cyclic graphs tested |
| Figure 7 and deterministic scheduling, p. 7 | Store restriction after every ordinary step | `collect`, `successors ~gc:true`, `run ~gc:true`, `analyze ~gc:true` | Live CEK correspondence, GC simulation, fixed points, and repeated-site precision |
| Section 4, pp. 6-7 | Precision and analysis-cost effects | `bin/gc_comparison.ml`, `GC_EXPERIMENT.md` | Paired state/store/result counts and median CPU timing; no universal speedup claim |
| Figure 6, pp. 5-6 | False and conditional frames | `Syntax.Conditional`, `Conditional_frame`, `continue` | False/non-false branches, skipped omega, saved branch environments |
| Figure 6, p. 6 | Mutation and old-value result | `Syntax.Assign`, `Assignment_frame`, `mutate` | Strong/weak updates, aliases, shadowing, nested assignment, old closure environment |
| Figure 6, p. 6 | call/cc and applying captured addresses | `apply_callcc`, `apply_function`, `Captured_continuation` | Escape, pending caller work, returned continuations, repeated invocation, current-store preservation |
| Sections 3-4 | Extended roots and abstraction | `expression_addresses`, `storable_addresses`, `abstract_value`, `abstract_state` | Captured roots and assignment targets; 872 generated terms and 22 named cases |
| Lemmas 1-3 and Section 4 | Proof assumptions and preservation audit | `CORRECTNESS.md`, `test/invariant_checks.ml` | FV-based support, no infinite administrative stuttering, concrete GC commutation; bounded corroboration |
| Implementation-study addition | Representative experiments and explicit cutoffs | `lib/experiment_examples.ml`, `lib/experiment_analysis.ml`, `bin/experiments.ml`, `scripts/run_experiments.py` | Twelve programs, five policies, 360 trials, completion rates, source/result metadata; partial searches are not complete reachability |
| Implementation-study addition | Identifiable review payload | `scripts/artifact.py`, `ARTIFACT.json`, `ARTIFACT.md` | Source/result checksum verification and self-contained ZIP, independent of Git history |
| Implementation-study addition | Consolidated interpretation and results | `REPORT.md`, `EXPERIMENTS.md` | Distinguishes reproduced algorithms, verification additions, metric limits, and open work |
