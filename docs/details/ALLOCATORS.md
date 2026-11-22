# Parameterized time and allocation

The original `Fresh`, `Bounded n`, and `Site_based` entry points remain available
with their original address/phase behavior. `make_allocator`, `successors_with`,
and `analyze_with` additionally expose the time/allocation choices independently
of transition rules. Custom analyses always use joined updates.

## Callback contract

`alloc state frame location` is called once per allocation event, before the
successor is built. `tick state frame event` sets the successor's integer time
once per ordinary transition, including lookup, branch selection, mutation, and
continuation jumps. Its event is `Some location` for allocation and `None`
otherwise. Both see the state before the transition.

For value transitions, `frame` identifies the continuation alternative selected
from the current cell. For syntactic decomposition and variable lookup it is
`None`: those rules do not branch on continuation alternatives in this machine.
GC does not call the callbacks or change time. Final/stuck states have no
ordinary successor and do not tick.

The state field `allocations` remains the time representation for compatibility.
It starts at zero. Built-in policies advance it only on allocation events;
custom policies may advance it on every ordinary step. For example, a finite
two-phase clock independent of allocation is:

```ocaml
let alternating_sites = Store_machine.make_allocator
  ~alloc:(fun _state _frame location -> Store_machine.Site location)
  ~tick:(fun state _frame _event -> 1 - state.Store_machine.allocations)
```

This is a scheduling/parameterization example, not a new precision heuristic.
The tests erase its time component and compare its entire reachable graph with
the original site graph, including mutation and control, GC off/on.

## Obligations for an analysis

Callbacks must be pure and deterministic. They must preserve supported-state
invariants, choose addresses other than reserved halt, and return nonnegative
time. Halt allocation and negative time are rejected at the transition boundary.
Other obligations remain the policy author's responsibility.

Finite address/time ranges for each fixed source ensure a finite state domain.
An unbounded clock can make `analyze_with` fail to terminate even for a finite
address policy. Soundness needs a concrete-to-abstract map and compatibility
arguments for both callbacks, including invariance under enlarged upper stores.
`abstract_address` and `abstract_state` still implement only built-in policies.
The existing correctness theorems cover those policies; arbitrary callbacks are
not certified simply by constructing an allocator.

## Current scope

Time remains a nonnegative OCaml integer and addresses use the existing variant
type. There is no arbitrary OCaml time type, built-in call-history allocator,
automatic finiteness proof, or proof of callback simulation. In addition, rules
without continuation selection pass `None` rather than selecting an arbitrary
frame just to call `alloc`/`tick`. This is an explicit specialization of the
paper's most general parameter signatures.

`test/allocator_checks.ml` checks full graph compatibility for sites and small
pools, independent per-transition time, selected alternatives, callback counts,
reserved halt, and negative times. Context-sensitive policies and their precision
experiments remain the next research step.
