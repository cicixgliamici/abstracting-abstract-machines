# Reading notes: Abstracting Abstract Machines

Source: David Van Horn and Matthew Might, *Abstracting Abstract Machines:
A Systematic Approach to Higher-Order Program Analysis*, supplied PDF,
arXiv:1105.1743v1, 9 May 2011. The PDF identifies ICFP 2010 as the original
publication. Page references below refer to the eight-page supplied version.

## Research question and construction

How can a higher-order evaluator become a computable conservative analysis
without replacing its semantics with an unrelated constraint language?

Section 2.1 (page 2) fixes closed, untyped, left-to-right call-by-value lambda
terms. Section 2.2 and Figure 1 (pages 2-3) replace substitution with lexical
closures and evaluation contexts with continuation frames. CEK is still a
concrete evaluator: "abstract machine" here does not mean abstract interpretation.

The obstacle is structural recursion in environments and continuations. Merely
abstracting their leaves leaves an infinite domain. Section 2.3 and Figure 2
(pages 3-4) redirect both bindings and continuation tails through a store.
Fresh addresses preserve concrete behavior; this transformation alone adds no
approximation.

Sections 2.4-2.5 and Figures 3-5 (pages 4-5) expose allocation/history and bound
addresses and time. Reuse requires joining cells, and lookup must explore every
compatible value. A finite worklist computes reachable states, including cycles
that stand for potentially infinite concrete executions.

## Interpretation adopted here

The implementation provides pooled and site-based allocation rather than call
strings. Each state retains its own store; there is no global store widening.
The pool fills N addresses then always reuses the first. A finite allocation
phase (0 through N) controls this policy; it must not depend on store size,
because an approximating store may already contain more possible cells. Site
allocation uses singleton time and keys addresses by binder/application label
and allocation role. A separate `Halt` constructor cannot collide with either
policy. Neither strategy is claimed to reproduce a named k-CFA analysis exactly.

Concrete addresses pair a fresh serial with allocation provenance. For a pool
of size N, alpha preserves serials 1 through N as pool addresses and maps later
serials to pool address 1; the allocation phase is capped at N. Site-based alpha
forgets the serial and retains the role/site; its phase is always zero. Both
maps preserve `Halt`, label-bearing syntax, and argument-frame origin labels.
Environments and frames map pointwise; cells with the same image are unioned.
`abstract_state` implements this map and `approximates` checks the state order:
identical control/environment/continuation/phase, with cell-wise store inclusion.

## Claims and verification obligations

The paper's Lemmas 1-4 establish evaluator correctness and machine correspondence;
Theorems 1-2 establish simulation soundness and decidability. Those results are
properties of the paper's formal systems, not automatic certificates for this code.
The core-machine checks provide evidence on seven examples and 286 generated
closed terms. Each observed concrete transition is tested from its exact alpha
state and from a store enlarged with cells from the entire trace prefix. Both
cases must have an abstract successor covering the concrete successor. These
checks do not quantify over every program or every approximating store. A
rule-by-rule informal argument is now given in `CORRECTNESS.md`, under explicit
supported-state and integer/resource assumptions. It does not provide a
machine-checked certificate for the compiled OCaml implementation.

Finiteness argument: a fixed program has finitely many subterms and variable
names. Environments map these names into a finite address set. Closures and
frames contain syntax, finite environments, and addresses, never recursive
stores. A cell contains a subset of finitely many storables, so stores and states
are finite. The pooled phase is finite and the site-based phase is a singleton.
Section 3's dynamically created continuation values also remain finite in the
abstract machine: they combine a finite address with a label drawn from the
fixed source program. They do not introduce unbounded runtime syntax.
This guarantees mathematical termination, not practical scalability.

One detail merits care: Section 2.4 prints a0=t0=0 and alloc(state)=t while
requiring fresh allocation. Taken literally, the first allocation can collide
with the initial halt cell. This implementation starts fresh allocation at 1
and increments an explicit allocation counter. Provenance metadata has no effect
on fresh execution behavior.

Section 3's conditions, mutation, and first-class continuations are implemented
in the concrete and abstract store machines. The pure CEK remains a reference
for its original language. Mutation returns the old denoted value, using its
lexical environment; concrete cells are overwritten and abstract cells joined.
Runtime captured-continuation addresses are projected by alpha even when they
appear in control or stored values. `SECTION3_NOTES.md` records the rule mapping,
872 generated terms, 22 named cases, and the limits of experimental validation.

Section 4's deterministic
garbage collection is implemented: one ordinary step followed by collection in
both machines. Direct edges from free-variable environments and continuation
tails are traversed over every storable in each reachable cell; Figure 7 is a
restriction of the store to the resulting least fixed point.
The new root cases include captured-continuation values, both saved conditional
branches, and pending mutation targets.

Collection can leave unused environment entries pointing to removed addresses.
Live CEK correspondence therefore restricts observed environments to free
variables. GC simulation tests compare alpha(collect(concrete)) below
collect(alpha(concrete)), not equality: abstract collisions can retain more
cells. Coverage tests for GC use deterministically collected concrete traces.

`GC_EXPERIMENT.md` documents the GC construction and measured effects. Reusing
a binder site across two calls demonstrates a precision gain: GC removes the
dead earlier argument rather than joining it with the new one. Shared live
pooled cells still retain all alternatives, so GC does not universally eliminate
imprecision or reduce analysis time. This reproduces a further part of the
paper rather than claiming a new algorithm.

The Section 2.1 reduction semantics is independently implemented in
`Reference_semantics`: its own AST, name analysis, capture-avoiding substitution,
and weak evaluation contexts. `Closure_reification` implements pure closure
denotation and whole-program reconstruction without calling that substitution
routine. The two machine representations are compared with the oracle at
administrative/beta steps and on reified final values, with GC off/on.
`REFERENCE_SEMANTICS.md` records 4034 closed terms, 12 named examples, 1212
substitution-law cases, and why this remains evidence rather than a proof.

`CORRECTNESS.md` adds the mathematical layer separately from these experiments.
Its raw simulation proof treats all successful implemented cases; GC soundness
uses `alpha(G(s)) <= G(alpha(s))` and GC monotonicity, not commutation of alpha
and collection. Concrete GC commutation is proved only for fresh allocation.
The pure correspondence argument includes a decreasing administrative-work
measure, avoiding an unjustified inference from finite stuttering alone. The
new invariant audit corroborates these code contracts on finite test inputs.

[REPORT.md](REPORT.md) consolidates the study and distinguishes these reproduced
constructions from repository-specific validation additions.
[EXPERIMENTS.md](EXPERIMENTS.md) documents the later ten-program corpus, separate
measurement dimensions, and explicitly incomplete resource-bounded searches.
