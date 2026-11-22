# Independent extended evaluator

`Extended_reference` evaluates conditionals, mutation, and first-class control
using its own unlabelled AST, free-variable analysis, association-list binding
heap, and functional continuations. Only `of_syntax` imports source constructors.
It does not call CEK, `Store_machine`, allocation callbacks, GC, or reification.

## Operational choices

Evaluation is weak, operator-first call-by-value. Environments retain lexical
binding locations; closure application allocates a new binding. Assignment
evaluates its right-hand side, replaces the selected binding, and returns the
old value with its original environment. The binding heap is never collected.

A continuation is an OCaml function accepting a value, the current heap, and
remaining fuel. Capturing it saves control, not an earlier heap or fuel budget.
Invoking the same capture repeatedly therefore preserves intervening writes.
This representation handles cyclic mutable closures without unfolding them.

Following the receiver rules displayed in Figure 6, call/cc accepts a closure
or a captured continuation. Applying false, passing false to call/cc, and
`(call/cc call/cc)` are stuck in this study's language. The last case is explicit
because treating call/cc as an unrestricted host-language procedure would add
a receiver case beyond the displayed rules.

## Differential observations

`test/extended_reference_checks.ml` uses the 872 generated extended terms of
1-5 nodes, 22 named examples, and twelve experiment entries. Each is placed in
six source contexts: direct result, application to false, application to identity,
two applications, conditional test, and use as a call/cc receiver. Both fresh
store-machine modes, GC off/on, are compared with the independent evaluator.

Terminal results compare value tags/code or stuckness. Applying returned values
also exercises captured environments and control; direct fixtures distinguish
identical lambda code closing over different values and call a cyclic closure.
Named expected results separately check old-value assignment, shared writes,
saved closure environments, escape, reentry, and multi-shot control.

Each evaluation has fuel 4,000. Reference fuel counts expression visits and value
applications; machine fuel counts transitions. Their numeric budgets are not
equivalent. A terminal/exhausted mismatch fails with an insufficient-budget or
disagreement diagnostic. Joint exhaustion is reported as unassessed, never as
proof of divergence or behavioral equivalence.

The experiment executable additionally checks concrete outcome/value syntax
against this reference before timing exploration. Pure finished values still
receive the stronger existing substitution/reification check.

## Limits

Finite observations are not a decision procedure for contextual equivalence.
Value rendering omits environments and continuation identity, and no general
graph isomorphism, extended reification, or intermediate-state correspondence
is established. The two implementations share input programs and an intended
specification, so differential testing reduces correlated implementation errors
without certifying correctness of that specification. The informal extended
soundness argument remains relative to the concrete rules in
[CORRECTNESS.md](../CORRECTNESS.md).
