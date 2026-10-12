# Deterministic abstract garbage collection

## Research question

Can the store traversal in Section 4 of the supplied paper improve the labelled
analyzer's precision and space use, and at what analysis cost?

This is a reproduction of a further construction in the paper, not a new GC
algorithm. The experiment holds syntax labels, allocation policies, per-state
stores, and the language fixed while switching collection on and off.

## Operational choices and paper correspondence

`Store_machine.expression_addresses` takes only environment addresses for free
variables of the associated expression. The state roots are these addresses for
the current control expression plus its continuation pointer. A closure has
edges to the free-variable addresses of its lambda. Argument and function frames
also have an edge to their continuation tail and the free-variable addresses of
their saved expression/value.

`live_addresses` follows these direct edges through every storable possibility
in each reachable cell. A visited-address set computes the least fixed point,
terminating on both live and unreachable cycles. `collect` filters store cells
to the reachable set and preserves all possibilities in each surviving cell.
It does not trim environments or remove individual values from live cells.

This decomposes the paper's recursive live-location equations into one-step
edges plus explicit traversal, implementing the grey/black traversal on page 6
and the restriction in Figure 7 on page 7.

With `gc=true`, `successors` performs an ordinary machine transition and then
collects each successor. There is no standalone nondeterministic GC branch:
following Section 4, collection happens after every step in both the concrete
and abstract machine. The ordinary uncollected execution remains available
with the default `gc=false`.

Fresh allocation uses a monotonically increasing counter and retains allocation
provenance. The collector preserves that counter, and the pooled allocator's
capped phase. Reclaimed cells therefore do not change the address projection
or cause accidental reuse of a concrete serial. Site allocation can reuse a
reclaimed address without joining its former contents.

## Validation

`test/gc_checks.ml` exercises 286 generated terms and eight named examples, for
294 programs, with pool sizes 1 and 2 and site-based allocation. It checks:

- Concrete CEK correspondence after restricting observed environments to free
  variables. Dead entries may refer to collected cells; dereferencing them would
  incorrectly treat permitted garbage removal as an evaluator failure.
- Each traced step of the uncollected concrete machine, after collecting its
  endpoints, matches one ordinary-plus-GC concrete step.
- Collection simulation: alpha(collect(concrete)) is covered by
  collect(alpha(concrete)), also for upper stores enlarged with trace cells.
  The maps are not assumed to commute or be equal.
- One-step simulation for the collected transition system, from exact and
  enlarged approximating stores.
- Complete GC fixed points on all generated terms under all three policies and
  all eight named examples under sites. They include injection, cover collected
  concrete trace prefixes, are closed under transitions, and contain already
  collected stores.
- A hand-built graph with saved-frame roots, transitive closure captures,
  multiple values per cell, a live cycle, an unreachable cycle, and unused
  environment references. Live cells and all their values survive; garbage
  disappears; collection is idempotent and only removes cells.
- Repeated calls to one closure: collection removes the old binder's argument
  before reuse and preserves exactly the expected final lambda term.

Traces contain at most 40 transitions. These are implementation checks over a
bounded suite, not a general soundness proof. In particular, GC trace coverage
compares against the deterministically collected concrete machine, not against
the entire stores of the uncollected trace: preserving garbage would defeat
the purpose of the collector. Live CEK correspondence checks the semantic link
back to ordinary evaluation.

## Reproduce the experiment

```sh
dune build
dune runtest
dune exec bin/gc_comparison.exe > results/gc-comparison.csv
```

The recorded CSV was produced on 12 October 2026 with OCaml 4.14.1 and Dune
3.23.1 in Ubuntu WSL. Each configuration runs three times; the CPU column is
the median of `Sys.time` durations for reachability exploration, including the
analyzer's collector and OCaml runtime GC during exploration. Summary calculation
and a preparatory OCaml full collection are outside the timed interval. These
measurements are CPU time, not wall time or process peak memory.

The original seven examples use pool-1 and sites, each with GC off/on. The added
repeated-call example uses sites only; its coarse pooled baseline is omitted
to keep the demonstration manageable. Each reported run computes a complete
fixed point without a cutoff.

## Results and interpretation

| Example / policy | States off / on | Final lambda terms off / on | Peak addresses off / on |
| --- | ---: | ---: | ---: |
| Lexical capture / pool-1 | 11891 / 10221 | 4 / 4 | 2 / 2 |
| Lexical capture / sites | 8 / 8 | 1 / 1 | 7 / 3 |
| Nested application / pool-1 | 767 / 661 | 3 / 3 | 2 / 2 |
| Omega / sites | 16 / 13 | 0 / 0 | 9 / 3 |
| Repeated calls / sites | 18 / 17 | 2 / 1 | 12 / 4 |

The repeated-call term binds one identity closure to `id`, invokes it with
identity, discards that result, and invokes the same closure with the constant
function. Without GC, the reused binder address contains both arguments and
the analyzer predicts two final lambda terms. GC removes the dead first binding
before the second call, leaving only the concrete constant-function result.
This demonstrates a precision gain beyond the original examples, which site
allocation already analyzed precisely.

The coarse pool often keeps unrelated values in a still-live shared cell. GC
cannot safely discard individual alternatives there. It reduces some history
and final-state counts without improving final-term precision in these cases.
For already precise site-based examples, it mainly reduces stored cells.

Timing is mixed: pooled lexical capture takes median CPU seconds 0.654629
without GC and 0.623244 with GC; pooled nested application takes 0.013485 and
0.015448. GC's traversal has a cost and fewer states do not guarantee a faster
analysis. Tiny site-based runs take only microseconds, so their timing should
not be interpreted as reliable speedup ratios.

Peak address/value counts range over reached states, so collected runs report
post-collection stores. They omit temporary pre-collection stores, retained
visited-state memory, and OCaml overhead. Final-term counts omit labels and
captured environments; they are not full closure-denotation counts. The exact
result assertion and simulation checks complement this limited precision metric.

[REPORT.md](REPORT.md) discusses allocation precision, reclaimable site reuse,
and GC overhead. [EXPERIMENTS.md](EXPERIMENTS.md) adds longer higher-order terms
and mutation/control workloads with explicit search limits. Larger application
workloads would still be needed before broader claims.
