# Generated guided example: CEK execution and abstract branching

Source program:

```text
((lambda id. ((lambda ignored. (id (lambda z. (lambda w. z)))) (id (lambda x. x)))) (lambda x. x))
```

Aliases below abbreviate labelled source occurrences; their bodies are not evaluated on definition.

| Alias | Labelled function body |
| --- | --- |
| `L1` | `lambda id. (L3 (id L11))` |
| `L3` | `lambda ignored. (id L6)` |
| `L6` | `lambda z. L7` |
| `L7` | `lambda w. z` |
| `L11` | `lambda x. x` |
| `L13` | `lambda x. x` |

Abbreviated program: `(L1 L13)`. `Arg` saves an operand and its environment; `Fun` saves a function closure.
Environments in braces retain captured environments recursively. `B`, `A`, and `F` denote binding, argument-frame, and function-frame site addresses. GC is off unless stated. Phase is always zero for sites.


## Concrete CEK trace

Each row is a complete CEK state. The last column describes the next transition.

| Step | Control | Environment | Continuation | Next rule |
| --- | --- | --- | --- | --- |
| 0 | `(L1 L13)` | `{}` | `halt` | Evaluate operator; save operand |
| 1 | `L1` | `{}` | `Arg(L13,{}) :: halt` | Evaluate operand; save function |
| 2 | `L13` | `{}` | `Fun(L1,{}) :: halt` | Bind argument; enter function body |
| 3 | `(L3 (id L11))` | `{id=L13{}}` | `halt` | Evaluate operator; save operand |
| 4 | `L3` | `{id=L13{}}` | `Arg((id L11),{id=L13{}}) :: halt` | Evaluate operand; save function |
| 5 | `(id L11)` | `{id=L13{}}` | `Fun(L3,{id=L13{}}) :: halt` | Evaluate operator; save operand |
| 6 | `id` | `{id=L13{}}` | `Arg(L11,{id=L13{}}) :: Fun(L3,{id=L13{}}) :: halt` | Look up lexical closure |
| 7 | `L13` | `{}` | `Arg(L11,{id=L13{}}) :: Fun(L3,{id=L13{}}) :: halt` | Evaluate operand; save function |
| 8 | `L11` | `{id=L13{}}` | `Fun(L13,{}) :: Fun(L3,{id=L13{}}) :: halt` | Bind argument; enter function body |
| 9 | `x` | `{x=L11{id=L13{}}}` | `Fun(L3,{id=L13{}}) :: halt` | Look up lexical closure |
| 10 | `L11` | `{id=L13{}}` | `Fun(L3,{id=L13{}}) :: halt` | Bind argument; enter function body |
| 11 | `(id L6)` | `{ignored=L11{id=L13{}}; id=L13{}}` | `halt` | Evaluate operator; save operand |
| 12 | `id` | `{ignored=L11{id=L13{}}; id=L13{}}` | `Arg(L6,{ignored=L11{id=L13{}}; id=L13{}}) :: halt` | Look up lexical closure |
| 13 | `L13` | `{}` | `Arg(L6,{ignored=L11{id=L13{}}; id=L13{}}) :: halt` | Evaluate operand; save function |
| 14 | `L6` | `{ignored=L11{id=L13{}}; id=L13{}}` | `Fun(L13,{}) :: halt` | Bind argument; enter function body |
| 15 | `x` | `{x=L6{ignored=L11{id=L13{}}; id=L13{}}}` | `halt` | Look up lexical closure |
| 16 | `L6` | `{ignored=L11{id=L13{}}; id=L13{}}` | `halt` | Final value |

## Site-allocated prefix without GC

This table projects each state to control, environment, continuation address, and store size.

| Step | Control | Environment | Continuation | Store cells |
| --- | --- | --- | --- | --- |
| 0 | `(L1 L13)` | `{}` | `halt` | 1 |
| 1 | `L1` | `{}` | `A0` | 2 |
| 2 | `L13` | `{}` | `F0` | 3 |
| 3 | `(L3 (id L11))` | `{id=B1}` | `halt` | 4 |
| 4 | `L3` | `{id=B1}` | `A2` | 5 |
| 5 | `(id L11)` | `{id=B1}` | `F2` | 6 |
| 6 | `id` | `{id=B1}` | `A9` | 7 |
| 7 | `L13` | `{}` | `A9` | 7 |
| 8 | `L11` | `{id=B1}` | `F9` | 8 |
| 9 | `x` | `{x=B13}` | `F2` | 9 |
| 10 | `L11` | `{id=B1}` | `F2` | 9 |
| 11 | `(id L6)` | `{id=B1; ignored=B3}` | `halt` | 10 |
| 12 | `id` | `{id=B1; ignored=B3}` | `A4` | 11 |
| 13 | `L13` | `{}` | `A4` | 11 |
| 14 | `L6` | `{id=B1; ignored=B3}` | `F4` | 12 |
| 15 | `x` | `{x=B13}` | `halt` | 12 |

## The first abstract choice

Reading `x` consults `B13`, whose joined cell is:

```text
{L6{id=B1; ignored=B3}; L11{id=B1}}
```

Every row below is an actual successor, not a hypothetical branch.

| Successor | Control | Captured environment restored | Final? |
| --- | --- | --- | --- |
| 0 | `L6` | `{id=B1; ignored=B3}` | true |
| 1 | `L11` | `{id=B1}` | true |

The concrete run returns `L6`; the other final syntax is spurious.

## The same program with collection

Each row records the cell read when the shared identity body evaluates `x`.

| Step | Address | Live alternatives |
| --- | --- | --- |
| 9 | `B13` | `{L11{id=B1}}` |
| 15 | `B13` | `{L6{id=B1; ignored=B3}}` |

Complete reachable graphs, computed without experiment cutoffs:

| GC | Reached states | Final states | Distinct final syntaxes |
| --- | --- | --- | --- |
| off | 18 | 2 | 2 |
| on | 17 | 1 | 1 |

This is one deterministic program with an overapproximating abstract graph. Printed final syntaxes omit captured environments; the tests check the actual successor states and independent pure evaluation.
