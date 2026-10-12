# Independent reduction semantics

This milestone implements Section 2.1 of the supplied Van Horn/Might paper,
and makes its relationship to the concrete machines executable. It also unfolds
pure closure values, corresponding to the paper's `real` operation. It does not
add a machine-checked proof of Lemma 1 or Lemma 3. The subsequent
[CORRECTNESS.md](CORRECTNESS.md) supplies an informal argument including the
required no-infinite-administrative-stuttering condition.

## Independence boundary

`Reference_semantics` owns an unlabelled AST of variables, lambdas, and applications.
It implements its own free-variable analysis, name collection, capture-avoiding
substitution, evaluation-context traversal, and alpha-equivalence comparison.
Its evaluator does not import CEK, store-machine transitions, environments,
continuation frames, allocation, or garbage collection.

`of_syntax` is the input adapter. It discards source labels and rejects Section 3
constructs. Evaluation checks closedness with its own name analysis, not
`Syntax.require_closed`. Sharing inputs and a conversion permits comparison;
the operational algorithms are separate.

## Capture-avoiding substitution

`substitute x replacement term` replaces only free occurrences of x. A lambda
binding x blocks substitution. If another binder would capture a free variable
of the replacement, that binder is alpha-renamed first.

Replacing x with the free variable y in `lambda y. x` gives a term alpha
equivalent to `lambda fresh. y`, not `lambda y. y`. Fresh names avoid every
bound and free name in the body and replacement. Renaming stops at an inner
shadowing binder. An absent target leaves the lambda unchanged.

The substitution utility accepts open terms. Closed call-by-value evaluations
alone would not expose all capture cases: evaluated argument values are closed.
Direct open-term tests therefore exercise freshening and shadowing separately.

## Reduction and budgets

The reference follows `E ::= [] | (E e) | (v E)`: evaluate the operator, then
the operand, then substitute the parameter with the operand value. Only lambdas
are values. Evaluation stops under a lambda; this is weak call-by-value, not
normalization of function bodies.

`step` contracts at most one beta-value redex and returns `None` if none is
available. Open terms can be stuck, so the runner accepts only closed terms.
Fuel counts beta reductions; CEK/CESK fuel counts transitions including
bookkeeping. These units and budgets must not be treated as interchangeable.

Alpha equivalence uses nearest-binder indices with free names preserved. Bound
renaming does not cause a false mismatch, while distinct lexical references do.

## Closure values and projected states

`Closure_reification` preserves bound occurrences and resolves free ones in the
closure's lexical environment. It does NOT call reference substitution. Inserted
closure denotations are closed and therefore cannot be captured.

The raw final control of `Examples.returned_closure` is `lambda y. x`, with x
bound to identity. Its full value is `lambda y. (lambda x. x)`. Comparing only
printed control syntax misses this difference.

The store adapter follows only free bindings actually used by the expression.
Unused entries can point to collected cells. Missing live bindings, encountered
joined cells, cyclic value graphs, and cyclic continuation chains are rejected.
These adapters target acyclic pure concrete executions, not general mutable
graphs or abstract-result denotations.

Intermediate-state adapters also plug control into pending argument/function
frames. This reconstructs the complete program and permits step correspondence,
rather than relying on final-value agreement alone.

## Executed verification

The suite checks 4034 closed terms of 1-8 nodes over binder names x/y and 12
named examples, using the deterministic source generator. Reference reduction
and closedness remain independent of that generator.

- Generated programs finish within 200 reference reductions and 1000 machine
  transitions. Reified final values agree modulo alpha equivalence for reference,
  CEK, CESK*, and CESK* with GC.
- Up to 120 machine transitions are replayed for generated/named programs, GC
  off/on. Administrative steps preserve the projected term; a pure application
  transition matches exactly one independent beta reduction. Omega's beta
  self-loop is checked even when before/after terms are alpha equivalent.
- 1212 substitution-law cases cover 202 potentially open terms of 1-5 nodes,
  two target names, and three replacements. They assert:

  `FV([r/x]t) = (FV(t) - {x}) union (if x in FV(t) then FV(r) else empty)`.

- Direct cases check capture, fresh names against inner binders, shadowing,
  blocked/absent targets, and bound/free distinctions in alpha comparison.
- Hand-specified steps require operator-first then operand evaluation and no
  reduction under a lambda.
- Reification inserts captured identity, ignores unused collected entries even
  when they match a binder name, and rejects missing live bindings, cycles, and
  encountered joined cells.
- Boundaries reject extended/open programs and negative fuel. Values need no
  fuel, redexes do, and Omega plus an unused Omega operand exhaust their budgets.

The earlier suites still run. These checks reduce correlated-error risk but
are not a general correctness proof. The oracle, adapters, and alpha comparator
are tested implementations rather than trusted mathematical certificates.

## Reproduce and inspect

```sh
dune build
dune runtest
dune exec bin/reference_comparison.exe > results/reference-comparison.csv
```

The CSV was recorded on 12 October 2026 using OCaml 4.14.1 and Dune 3.23.1 in
Ubuntu WSL. Named runs use 100 reference reductions and 400 transitions per
machine. Incomplete runs have no final-value agreement claim.

| Example | Reference reductions | CEK transitions | Reified value agreement |
| --- | ---: | ---: | --- |
| Identity application | 1 | 4 | Yes |
| Returned closure | 1 | 3 | Yes, including captured identity |
| Lexical capture | 2 | 7 | Yes |
| Repeated calls | 4 | 16 | Yes |
| Weak lambda body | 0 | 0 | Yes, body stays unevaluated |
| Omega | 100, exhausted | 400, exhausted | Not checked: incomplete |

All ten terminating named examples agree across the four evaluators. The other
two exhaust their budgets. Matching exhausted runs is not a divergence proof.

## Remaining boundaries

This oracle/reification covers the pure Section 2.1 language, not independent
Section 3 semantics or unfolding cyclic mutable values into finite lambda terms.
The earlier abstract-analysis CSVs still count printed syntax; their metrics are
not silently redefined. Proof mechanization, refinement to bounded execution,
broader workloads, and the final implementation paper remain open. The informal
model-level simulation and evaluator arguments are in `CORRECTNESS.md`.
