# Section 3: state and control

This milestone implements Section 3 and Figure 6 of the supplied Van Horn/Might
paper (pages 5-6). It extends the fresh-address concrete CESK* and its finite
abstract variants with conditionals, mutation, and first-class continuations.
The optional Section 4 collector covers the new values and frames as well.

## Language and values

Source expressions add `Conditional`, `Assign`, `False`, and `Callcc`. Builders
are `conditional condition yes no`, `assign name value`, `false_value`, and
`callcc`; the printer uses `if`, `set!`, `#f`, and `call/cc`. Application still
evaluates its operator then operand before applying the value.

`Captured_continuation address` is a runtime-only value. Injection rejects this
constructor in source programs. Lambda, false, call/cc, and captured continuations
are values; the last three kinds extend the formerly lambda-only value domain.
Printed captured continuations use `#<continuation>` and hide address identity.

The existing `Closure(value, environment)` store constructor is a generalized
value/environment pair, including primitive and continuation values. This avoids
duplicating binding and variable-lookup rules. Addresses are defined in `Syntax`
and re-exported by `Store_machine` so runtime values and the store use one typed
domain without a module dependency cycle.

## Conditional rules

Evaluating an `if` pushes a conditional frame containing both branches and their
environment, then evaluates the condition. Exactly `#f` selects the alternative;
every other value, including call/cc and captured continuations, selects the
consequent. Only the selected branch runs. Conditional frames have their own
site-address role, distinct from argument, function, and binding roles.

## Mutation rules

`set! x e` saves x's target address in an assignment frame and evaluates e.
At the update transition, it reads the old value from the current store, writes
the new value, and returns the OLD value, as specified in Section 3. An old lambda
restores its saved environment when returned; using the RHS's environment would
break lexical capture. Nested assignments read the old value after RHS effects.

Fresh execution strongly replaces the unique binding cell. Abstract execution
weakly joins the new value and explores every possible old denoted value, retaining
other cell alternatives. Aliased closures refer to the same address, so they see
the mutation; shadowed parameters have separate binding sites.

Assignment targets are free variables of source expressions. Pending assignment
frames also keep their target address live during RHS evaluation, even if the
RHS itself never reads x. Assignment frames have a separate allocation-site role.

## First-class control rules

The function frame for `call/cc` contains the caller's remaining continuation.
When its evaluated argument is a lambda, the machine binds the parameter to a
value representing that remaining continuation and evaluates the lambda body.
It captures the continuation AFTER the primitive's own function frame.

Applying a captured continuation to a value discards the current continuation
and installs the captured address. The argument's value and environment, and
the current store, survive the jump. A continuation restores control, not an
earlier store snapshot. It can be saved, returned, passed to call/cc, and invoked
more than once.

Figure 6 also applies call/cc to an already captured continuation. In this case,
the captured target is installed and receives the current remaining continuation
as its argument. `callcc_continuation` exercises this separate rule.

The machine allocates no new continuation cell merely to capture: it reifies an
existing address. Binding a receiver lambda's parameter still uses its binder
site, with fresh or finite allocation as configured. Runtime continuation values
reuse a source label as finite provenance metadata; their address is projected
by alpha in control, stored values, and saved function frames.

## Collection and abstraction

Control containing a continuation value roots the captured address. A denoted
continuation in a store cell, or a captured continuation waiting in a function
frame, also links to its saved continuation. Conditional frames root free-variable
addresses in both branches and their tail. Assignment frames root their target
and tail. Marking follows all possibilities and handles cycles, including a
mutable binding that refers to its own saved continuation or closure.

`abstract_state` maps runtime addresses embedded in control and values in addition
to environments, frame targets/tails, and store keys. Omitting this projection
would compare concrete continuation identities with abstract identities and
break step simulation. Source syntax and its labels stay unchanged under alpha.

## Execution outcomes and scope

The concrete store runner distinguishes `Finished`, `Fuel_exhausted`, and `Stuck`.
Applying false or passing false to call/cc has no transition in Figure 6 and is
reported as stuck. The abstract analyzer retains such reachable states in its
fixed point; `is_stuck` identifies states with no applicable transition that are
not final. It is a state diagnostic, not a complete proof of runtime safety.

The original CEK remains the pure lambda-calculus reference and explicitly
rejects extended input. Mutation needs shared binding identity, supplied here
by the concrete store machine. Refitting the closure-list CEK with mutable OCaml
references would change its model and undermine immutable trace comparisons.
CEK correspondence tests therefore retain their original pure-language scope.

## Validation

The Section 3 suite enumerates 872 closed extended source terms with 1-5 nodes
over binder names x and y, and tests 22 named examples. Ill-applied source values
are included; captured-continuation literals are excluded. Existing pure-language
and GC suites still run unchanged in scope.

- Expected concrete results are checked with GC off/on, including all truthy
  value kinds, branch captures, nested assignment, old-value returns, shared
  mutation, lexical shadowing, and the old closure's environment.
- Escape examples abandon a divergent body and correctly resume pending work.
  A returned continuation is invoked, and call/cc receives a continuation.
- Reentry keeps mutations across a jump; a two-flag example invokes the SAME
  captured continuation twice and finishes with false. A self-referential lambda
  binding exercises concrete GC on a cyclic value graph.
- Every traced concrete step, up to 80 transitions, is simulated under pools 1/2
  and sites, with GC off/on. Both exact alpha states and upper stores containing
  the union of traced cells are used. The union deliberately contains old and
  new values from mutation; concrete stores are no longer monotonic.
- Concrete/abstract collection simulation is checked. Complete site-based fixed
  points with GC off/on cover the concrete prefixes and are closed under successors.
- Targeted graph checks preserve captured-continuation roots and pending mutation
  targets. Additional checks distinguish strong/weak updates, reject open mutation
  targets and source continuation literals, identify the CEK boundary, and verify
  that the sequencing helper avoids capturing an outer variable.

Generated terms are small and the named expected results are manually specified;
these are experimental checks, not an independent extended-language evaluator
or a general proof of soundness. Full extended fixed points are tested under
sites; pools are checked by local simulation rather than expensive named analyses.

## Reproduce and inspect results

```sh
dune build
dune runtest
dune exec bin/section3_comparison.exe > results/section3-comparison.csv
```

The CSV compares fresh concrete results with complete site-based analysis for
each named example with GC off/on. It reports reachable states, final states,
stuck states, peak reached-store addresses, and possible printed final values.
The two earlier CSVs remain pure-language baselines; new summaries use value
syntax instead of the older lambda-only column name.

Recorded on 12 October 2026 using OCaml 4.14.1 and Dune 3.23.1 in Ubuntu WSL.
The 22 examples produce 44 paired configurations. The pure-language allocation
CSV was regenerated separately and matches the earlier baseline exactly.

| Example | Concrete result | States GC off / on | Possible final syntax GC off / on |
| --- | --- | ---: | ---: |
| Read after assignment | False | 11 / 11 | 2 / 2 |
| Escape skips omega | Constant function | 10 / 10 | 1 / 1 |
| Saved continuation reentry | Constant function | 109 / 44 | 2 / 1 |
| Same continuation invoked twice | False | 736 / 96 | 3 / 2 |
| False used as a function | Stuck | 3 / 3 | 0 / 0 |

Reentry still has one abstract stuck state in either mode despite successful
concrete evaluation; two-shot invocation has five without GC and two with GC.
These expose retained false alternatives in weakly updated saved-continuation
bindings. They are spurious paths for these particular concrete examples, not
failures of their actual execution. GC improves some results without proving
that all mutation/control examples become precise.

Weak mutation can retain a truthy old value after writing false. Thus analysis
may predict both branches or even spurious stuck states. GC cannot remove an
old alternative from a cell that is still live. Printed values omit lexical
environments and continuation identities, so these summaries are not full
denotation counts. The whole-state simulation tests provide separate evidence.

The implementation now covers the principal Section 3 constructions as well as
the core derivation and deterministic GC. Proof mechanization, compiled-code
resource/representation refinement, an independent extended-language semantics,
cyclic/extended value representations, and larger application benchmarks remain
separate work. [REPORT.md](REPORT.md) consolidates the implementation study;
[EXPERIMENTS.md](EXPERIMENTS.md) includes representative control/mutation workloads.
The pure reduction evaluator and pure closure reification are implemented in
the later milestone documented in `REFERENCE_SEMANTICS.md`.
`CORRECTNESS.md` now supplies an informal per-rule simulation argument for the
Section 3 model, including both call/cc receiver cases, weak mutation, and GC.
