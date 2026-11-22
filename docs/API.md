# Core module interfaces

The `.mli` files are the compiler-checked contracts for the core and reference modules.
Read them before their `.ml` implementations to see available operations, input
requirements, result meanings, and the intended inspection surface.

| Interface | Responsibility | Main entry points |
| --- | --- | --- |
| [syntax.mli](../lib/syntax.mli) | Source AST, labels, free variables, runtime address vocabulary | Builders, `label`, `free_variables` |
| [cek.mli](../lib/cek.mli) | Concrete evaluation of the pure language | `initial`, `step`, `run` |
| [store_machine.mli](../lib/store_machine.mli) | Concrete/abstract store machines, collection, abstraction | `run`, `analyze`, `successors`, `collect`, `abstract_state` |
| [extended_reference.mli](../lib/extended_reference.mli) | Independent concrete state/control evaluation | `of_syntax`, `run`, `value_syntax` |

## Source-level use

Build a closed AST with `Syntax` constructors or builders. `Cek.run` accepts only
the pure variable/lambda/application subset. `Store_machine.run` also accepts
false, conditionals, assignment, and call/cc, and always uses fresh allocation.
Neither machine accepts captured-continuation literals as source programs.

For finite analysis, choose a finite policy with `Store_machine.analyze`. Its
result is the complete reachable set when the exploration returns successfully;
it has no resource cutoff. `Experiment_analysis.explore` is the separate bounded
experiment API and is not covered by this complete-result guarantee.

Fuel in concrete runs counts transitions, not reference beta reductions. Traces
include the initial and last observed states in execution order. Exhaustion does
not establish divergence. An abstract final state does not prove concrete
termination. The interfaces state defaults and invalid-input cases explicitly.

`Extended_reference.run` evaluates its own AST with functional continuations and
a separate concrete binding heap. Its expression/application fuel differs from
machine transition fuel. [Extended reference](details/EXTENDED_REFERENCE.md)
documents finite behavioral comparisons and the limits of value rendering.

## Experimental allocation parameters

`make_allocator ~alloc ~tick` separates address choice from per-transition time.
Use `successors_with` or `analyze_with` for those custom abstract parameters.
Time occupies `state.allocations`, starting at zero. Custom mutation always joins.
Callbacks receive the selected frame for value transitions and an allocation
location when appropriate. GC preserves time and invokes neither callback.

The [allocator contract](details/ALLOCATORS.md) specifies purity, finite-domain,
and simulation obligations. `analyze_with` has no cutoff or automatic finiteness
check. Existing abstraction helpers and mathematical claims remain specific to
the built-in policies; arbitrary callbacks require their own justification.

## Why the state representation remains visible

AST, closure, continuation, store, and state constructors are deliberately public.
Reviewers need to inspect complete transitions, the walkthrough renders them,
and invariant tests build synthetic stores and continuation cycles. Making these
types opaque would require a different inspection and fixture API without
improving the study's semantic explanation.

This choice means the compiler does not prevent malformed states. The interfaces
distinguish checked source entry points from advanced operations on supported
states. Low-level callers must preserve the invariants in [CORRECTNESS.md](CORRECTNESS.md):
free-variable and continuation support, cell roles, fresh singleton cells, and
the allocation phase appropriate to the policy. Collection permits unused
environment entries to refer to removed addresses.

`lookup` and `insert` support store inspection and invariant fixtures. `allocate`
is exposed for allocation checks, but only selects an address: it does not
advance a phase or construct the next state. Ordinary callers use `successors`.
`approximates` checks a relation; it does not validate its operands.

## What is internal

`Store_machine` transition helpers such as `push`, `bind_value`, `continue`,
`mutate`, and `raw_successors` are omitted from its interface. Clients use
`successors ~gc:false` for ordinary transitions and `successors ~gc:true` for
ordinary transitions followed by collection. Built-in policy construction,
primitive application dispatch, and storable comparison remain internal;
custom address/time choices use the documented callback interface.

The interfaces document the current machine semantics; they introduce no new
evaluation rules. `dune build @all` checks that implementations satisfy their
interfaces and that every library module, executable, and test uses the declared
surface. `dune runtest` then checks the existing semantic properties through
that surface. The independent reference, closure-reification, and guided-example
modules retain their existing interfaces.
