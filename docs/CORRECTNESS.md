# Mathematical correctness argument

This chapter gives informal mathematical proofs for the implemented algorithms.
Its complete-worklist claims concern `Store_machine.analyze`. The separate
bounded experiment explorer can return a reached prefix and records its cutoff;
such outputs do not satisfy the complete fixed-point conclusion. See
[EXPERIMENTS.md](EXPERIMENTS.md) for that distinction and [REPORT.md](REPORT.md)
for the consolidated implementation study.
It is intended to be read with [PAPER_TO_CODE.md](PAPER_TO_CODE.md) and the source,
not as a certificate produced by Lean, Coq, or an OCaml verifier. The underlying
construction is from Van Horn and Might, *Abstracting Abstract Machines*, supplied
arXiv:1105.1743v1 PDF, Sections 2-4, Figures 1-7, and Lemmas 1-4 / Theorems 1-2.
The argument below specializes that construction to this repository's allocators,
runtime continuation values, mutation representation, and deterministic GC.

## 1. Claims and assumptions

We establish, in the mathematical model described below:

1. Capture-avoiding reference reduction implements weak, left-to-right CBV.
2. Pure CEK and fresh CESK* evaluation have the same reified results as reference
   reduction. Administrative steps cannot account for infinite stuttering.
3. Fresh concrete store transitions are simulated by each finite abstract policy,
   including every implemented condition, mutation, and control rule.
4. Concrete deterministic GC preserves execution modulo garbage; abstract GC
   preserves approximation of the collected concrete machine.
5. The worklist returns the complete finite reachable-state set of its selected
   abstract transition system, provided execution resources suffice.

**Assumptions.** A source program is a finite closed AST without runtime
continuation literals. Initial labels are unique per occurrence and deterministic.
We model counters as natural numbers and maps/sets as their mathematical finite
counterparts. OCaml integers must not overflow, and execution must not fail through
memory/stack exhaustion. Those resource/representation assumptions are not proved
by this chapter. Public helpers applied to malformed hand-built states are outside
the theorems. Abstract premises require the supported-state conditions in Section 3,
including well-formed extra alternatives; a store with arbitrary malformed values
can cause `Names.find` to fail during collection.

No independent reference semantics for Section 3 is claimed. Its concrete rules
are defined by the extended store machine and matched to Figure 6; the abstract
simulation theorem is relative to those concrete rules. No optimal precision,
universal speedup, complete error detection, or termination from abstract final-state
existence is claimed. Tests corroborate model/code correspondence; they do not
replace any of the quantified arguments below.

## 2. Notation and implementation dictionary

A concrete state is `s = <e, rho, sigma, k, n>`: control, environment, store,
continuation address, and allocation count. Environments are partial maps from
names to addresses. A concrete cell is a singleton. An abstract cell is a finite
set, and an abstract state is `<eh, rhoh, sigmah, kh, h>`.

Values are lambdas, false, call/cc, and `cap(a)` for a captured continuation.
`D(v,rho)` denotes the code's `Closure(v,rho)`, a generalized value/environment
pair. Frames are:

| Mathematical form | OCaml constructor | Stored information |
| --- | --- | --- |
| `mt` | `Empty` | Empty continuation |
| `ar(l,e,rho,k)` | `Argument` | Origin application label, operand, environment, tail |
| `fn(v,rho,k)` | `Function` | Evaluated operator, environment, tail |
| `ifk(et,ef,rho,k)` | `Conditional_frame` | Both branches, environment, tail |
| `setk(b,k)` | `Assignment_frame` | Update target and tail |

The initial address is `Halt`. A fresh address is `a(i,l)` = `Concrete(i,l)`,
where `i` is a positive serial and `l` is an allocation role/site. Roles are
binding, argument, function, conditional, and assignment. `FV(e)` is the set of
free source variables; `cap(a)` has no free variable but contains an address edge.
Label metadata is omitted in the displayed rules, but retained by abstraction.

`sigma[b := d]` is a strong singleton replacement. `sigmah join [b : {d}]`
is pointwise union, implemented by `insert`. Missing cells denote the empty set.
The raw transition `->c`/`->a` excludes GC; `G` is `collect`. Collected transition
`s =>c t` means `s ->c u` and `t = G(u)`, and similarly for `=>a`.

## 3. Supported-state invariants

The following conditions hold from `initial`, and are the admissibility conditions
used by the proofs. They concern free-variable support, not all environment entries.

**I1: finite code and value shape.** Non-runtime code is a labelled subterm of the
input. Stored denoted values and function operators are values. A runtime `cap(a)`
uses a source label already present in the computation. All maps and cells are
finite and retained cells are nonempty. Environment domains use only names in
the fixed input, and address fields use the selected policy's domain. Concrete
address fields, even unused dangling ones, refer only to previously minted serials
at most n, with role/sites originating in the input.

**I2: lexical support.** For control and each expression saved in a closure/frame,
`FV(e)` is in the environment's domain. Every corresponding address contains a
denoted-value alternative. Function/closure support is for the whole lambda,
so its formal parameter is excluded until application binds it.

**I3: continuation support.** The current continuation, every frame tail, and
every captured continuation value refer to a cell with a frame alternative.
Every assignment target refers to a cell with a denoted-value alternative.
These requirements cover all remaining store entries, including all alternatives
in a shared abstract cell. They do not require acyclic graphs.

**I4: reserved halt and allocation.** `Halt`, if retained, contains only `mt` and
is never used for bindings or allocated frames. Concrete serials are positive
and at most `n`; `n >= 0`. Every new concrete allocation uses serial `n+1`, and
collection never decreases `n`. Pooled phase is in `[0,N]`; site phase is zero.

**I5: cell roles.** Concrete cells are singletons, with a role matching their
data/frame constructor. Binding cells contain denoted values; frame cells contain
their corresponding frame kind. Site abstraction preserves these distinct roles.
Pool abstraction may mix roles, but I2/I3 require the appropriate alternative
where a binding or continuation is referenced. Argument origins match their sites.

**Unused entries may dangle after GC.** An environment can contain a name not in
`FV(e)` whose cell was removed. Claiming full environment-range inclusion in the
store would be false. No transition may resurrect such an entry: lambda application
creates a new parameter binding, and saved expressions retain their FV support.

### Invariant preservation

Injection has empty environment, closed code, and only `Halt : {mt}`, so I1-I5
hold. For each ordinary rule, the newly needed support is as follows:

| Rule family | Why support and roles are preserved |
| --- | --- |
| Variable lookup | The chosen denoted value already has a supporting saved environment. |
| Application / argument frame | Operator/operand FV sets are subsets of the application's FV set; the new frame retains the old tail. |
| Argument-to-function frame | The operator is an evaluated supported value; operand and tail were saved in the argument frame. |
| Lambda binding | Body FV is contained in lambda FV plus the parameter; the parameter gets a fresh/joined denoted-value binding, shadowing any old one. |
| Conditional push/pop | Both branch FV sets are saved; selecting either restores its supporting environment. |
| Assignment push | The target is in FV of the assignment; its frame retains that denoted address during RHS evaluation. |
| Assignment update | The target stays a denoted cell; old/new environments still have support, including references to the target itself. Abstract union also preserves existing frame alternatives. |
| call/cc with lambda | The receiver's free variables were supported; the new parameter stores a capture of the caller's supported tail. |
| call/cc with capture | Receiver target and caller tail are supported; the delivered capture has no free variables. |
| Applying a capture | Its target was supported in the function frame; the argument's supporting environment and the current store are retained. |

Every allocated role is chosen from the matching rule and increments the counter
or capped phase as defined in Section 6. Nonallocating rules preserve the phase.
Strong mutation only changes a concrete binding cell, so it cannot overwrite a
concrete continuation or `Halt`. Abstract mutation preserves all existing alternatives.
These observations establish ordinary-step preservation by case analysis.
Section 8 establishes GC preservation: it retains every edge of every retained
storable, while allowing irrelevant environment entries to disappear.

Singleton concrete cells give at most one applicable continuation/value choice.
The syntax cases and primitive application cases are disjoint. Thus fresh raw
execution is deterministic: it either has one successor, is a final value, or
is stuck (for example, applying false). Collection is deterministic as well.

## 4. Reference reduction and substitution

Erasing source labels preserves the three pure constructors and their FV sets
by structural induction. It therefore preserves source closedness and supplies
the same unlabelled input to the independent reference relation.

**Lemma 1: freshening is safe.** `fresh_name` terminates because a finite set of
forbidden names cannot contain every candidate. Its result is absent from all
bound/free names in the body and replacement and from the substitution target.
`rename_bound` changes precisely the occurrences owned by the selected binder,
stopping at a same-name inner binder. With a fresh name, the result changes only
that binder's spelling and is alpha equivalent to the original abstraction.
This follows by induction on the body; in the shadowing case recursion stops,
and in the other lambda case freshness excludes accidental capture.

**Lemma 2: substitution correctness.** `substitute x r t` computes capture-avoiding
`[r/x]t`. Induct on term size. Variables select r exactly when their name is x;
applications recurse on both children. A lambda binding x blocks substitution.
If x is absent from the body, no replacement is needed. For another binder y,
when `y` is not free in r, recurse under that binder. Otherwise Lemma 1 permits
freshening y, then recurse in the renamed body. Its size is still smaller than
the original abstraction, so the induction remains well-founded. Consequently:

```text
FV([r/x]t) = (FV(t) \ {x}) union (FV(r) if x is in FV(t), else empty).
```

**Lemma 3: reference-step correctness and progress.** Evaluation contexts are
`E ::= [] | (E e) | (v E)` with lambdas as values. A closed non-value cannot be a
variable; it is an application. If its operator is not a value, recurse there;
otherwise recurse into a non-value operand; otherwise contract the lambda/value
redex. The cases are disjoint and determine one context/redex decomposition.
`Reference_semantics.step` implements exactly those cases. Closedness is preserved
by Lemma 2: a closed lambda has body FV contained in its parameter and the argument
value is closed. Values have no transition, including redexes inside lambda bodies.

Nearest-binder canonical forms used by `alpha_equivalent` preserve free names
and distinguish binder depth. Induction on term shape shows equality of canonical
forms is precisely alpha equivalence for these finite named terms.

## 5. Pure-machine correspondence

For this section only, the language is the pure lambda subset. A closure's
denotation `R(v,rho)` resolves its free variables through rho, preserving variables
bound inside v. Resolving an environment value starts in that value's own captured
environment, not the caller's. Every inserted denotation is closed.

Unfolding is well-founded. Without mutation/control, a newly stored value refers
only to older binding addresses, and new frames point to older tails. Fresh serials
strictly decrease along these edges. Removing garbage does not create edges.
CEK's corresponding immutable closure/continuation structures are finite.

Let `U_rho^B(e)` unfold e while leaving names bound by enclosing lambdas B intact.
This is `Closure_reification.expand`; store lookups unfold singleton cells on
live paths. Missing irrelevant entries are never consulted. The binding identity is:

```text
U_(rho[x := nu])^empty(body) = [R(nu)/x] U_rho^{x}(body), modulo alpha.
```

The `{x}` on the right is essential: an older rho binding for x must not replace
the formal parameter before substitution. The identity follows by induction on
body, with nested x binders blocking replacement. Other free names insert closed
denotations; therefore no capture occurs. The adapters implement this directly
through scope tracking and lookup, without calling reference substitution.

Reconstruct a CEK program `P(s)` by unfolding its control and plugging it into
the continuation: an argument frame plugs `(hole unfolded_operand)`; a function
frame plugs `(unfolded_operator hole)`; the empty frame returns the hole.
Each context is an evaluation context because saved operators are lambda values.

**Lemma 4: projected CEK steps.** Variable lookup preserves P by the definition
of unfolding. Application preserves P by moving the operand into an argument
frame. An argument-to-function step preserves P by moving the same unfolded
operator into a function frame. Lambda application yields exactly one reference
beta-value reduction by the binding identity. Final CEK states project to their
closed lambda denotation.

**Lemma 5: no infinite administrative stuttering.** Define weak work:

```text
w(x) = 1; w(lambda x.e) = 0; w(e0 e1) = 2 + w(e0) + w(e1).
q(mt) = 0; q(ar(e,rho,k)) = w(e) + 1 + q(k); q(fn(v,rho,k)) = q(k).
M(<e,rho,k>) = w(e) + q(k).
```

For lookup, application push, and argument-to-function transitions, direct
calculation decreases M by exactly one. M is a natural number, so an infinite
pure run must contain infinitely many beta transitions. Beta steps may increase M.

**Theorem 1: pure evaluator correctness.** Injection projects to the source term.
Lemma 4 projects every CEK run to reference reduction with administrative stuttering;
Lemma 5 prevents an infinite run from projecting to finitely many reductions.
Closed pure CEK states have progress except at final values. Therefore finite
termination and reified results coincide with deterministic reference evaluation.
If reference terminates but CEK did not, Lemma 5 would give an impossible infinite
reference reduction after its final value; the reverse direction is Lemma 4.

Fresh pure CESK* is a pointer representation of CEK: unfold its singleton binding
cells and continuation tails. Each of the four pure rules performs the corresponding
CEK rule, allocating only fresh cells or restoring the corresponding saved data.
Thus the correspondence holds by induction on traces without GC. Sections 8-9
extend the result to concrete GC, comparing live denotations rather than demanding
that unused, collected environment entries can still be dereferenced.

## 6. Abstraction, ordering, and allocation

Fix one policy P. The address map g and phase map psi are:

```text
g(Halt) = Halt.
Sites:  g(a(i,l)) = Site(l);                 psi(n) = 0.
Pool N: g(a(i,l)) = Pool(i) if i <= N,
                       Pool(1) otherwise;   psi(n) = min(n,N), with N >= 1.
```

Let alpha map control/value syntax with `Syntax.map_addresses`, all environment
addresses, all frame targets/tails, store keys, and phase. Ordinary source code
and labels are unchanged; `cap(a)` becomes `cap(g(a))`. Store abstraction is:

```text
alpha(sigma)(b) = union { {alpha(d)} | a in dom(sigma), g(a)=b, d in sigma(a) }.
```

This equation also applies to singleton concrete cells that have been strongly
updated. `abstract_state` implements it by folding cells and unioning images.
Multiple concrete addresses may therefore contribute to one abstract cell.

State ordering, implemented by `approximates`, is flat in control, environment,
continuation, and phase, with pointwise store inclusion:

```text
t <= u iff their four non-store components agree,
          and for every b, t.store(b) is a subset of u.store(b).
s is covered by u iff alpha(s) <= u.
gamma(u) = { admissible concrete s | alpha(s) <= u }.
```

Map/tree insertion order has no mathematical meaning. The code uses extensional
environment/store comparison and canonical environment bindings in storable
ordering, so duplicate representations do not define different semantic cells.

### Allocation compatibility

**Lemma 6.** If `alpha(s) <= u`, an allocation with role/site l in s and its
corresponding abstract rule in u chooses addresses b/bh such that `g(b)=bh`, and
their new phases correspond.

Concrete allocation chooses `a(n+1,l)`. Sites choose `Site(l)`, immediately its
image, and keep phase zero. For Pool N, if `min(n,N)<N`, then n<N: both choose
pool n+1. Otherwise n>=N: concrete n+1 projects to pool 1 and abstract chooses
pool 1. Phase correspondence follows from:

```text
min(N, min(n,N)+1) = min(N,n+1).
```

The corresponding role/site l is the same because labels and frame origins are
preserved. In particular, the function frame uses the saved application origin,
and a binding uses the applied lambda's label, including call/cc's receiver.
Nonallocating rules leave n/h unchanged. Collection changes neither.

The use of an explicit phase is essential. For example, with a two-address pool,
an upper store may already contain an extra pool cell while the covered state
has phase zero. Deriving allocation from store cardinality could select pool 2
instead of the required pool 1, breaking a flat continuation-address comparison.
The implemented allocator depends on phase, not store cardinality.

### Update and lookup facts

**Lemma 7: joined update.** For covered stores and corresponding b/bh and d/dh:

```text
alpha(sigma[b := d]) <= sigmah join [g(b) : {alpha(d)}].
```

For any concrete address other than b, its old contents were included in sigmah
and remain there after union. The new b content is included by the added image.
These are all contents of the strongly updated concrete store. Aliases in g can
only add alternatives to the right. Fresh insertion is the special case in
which b did not previously exist. Retaining the old b image is conservative,
although it may be imprecise for a mutation of a unique concrete binding.

**Lemma 8: lookup witness.** If concrete lookup at b selects d, and stores are
covered, then `alpha(d)` belongs to the upper cell at g(b). A value lookup can
select that denoted alternative; a continuation lookup can select that frame.
Other mixed-role pooled alternatives do not remove the witness. The implementation
enumerates every compatible alternative using `Values.elements`.

## 7. Rule-by-rule forward simulation

**Theorem 2 (raw one-step simulation).** For admissible concrete s and admissible
abstract u, if `s ->c s'` and `alpha(s) <= u`, there exists `u ->a u'` with
`alpha(s') <= u'`. The upper state need not equal alpha(s), or be reachable;
its extra alternatives must satisfy the supported-state assumptions.

The complete case analysis follows. In each case headers correspond by structural
mapping; unchanged stores retain inclusion. Allocations use Lemma 6, updates use
Lemma 7, and needed old values/frames are supplied by Lemma 8.

### 7.1 Variable lookup

Control is x and `sigma(rho(x)) = {D(v,rhov)}`. Abstract environments agree
pointwise, so the lookup address is `g(rho(x))`. Lemma 8 supplies
`D(alpha(v),alpha(rhov))` among its alternatives. Selecting it gives corresponding
control/environment; continuation, phase, and store are unchanged.

### 7.2 Application push

Control is `(e0 e1)`. Concrete allocates b at `Argument_site(label(e))`, inserts
`ar(label(e),e1,rho,k)`, and continues with e0/rho and continuation b. Abstract
allocates g(b) and joins the exact frame image. The new control is alpha(e0),
environment alpha(rho), continuation g(b), and phase psi(n+1).

### 7.3 Argument-to-function frame

Control is a value v and the selected concrete frame is `ar(l,e,rho',c)`.
Its image exists at g(k). Select it, allocate a function cell using origin l,
insert/join `fn(v,rho,c)`, and continue with e/rho' at the new pointer.
The saved environment belongs to the operand, while the new frame retains the
operator's environment; the pointwise images agree in both positions.

### 7.4 Lambda application

The selected frame is `fn(lambda x.body,rho',c)` and the argument is v/rho.
Both runs bind x at corresponding new binder addresses, inserting/joining
`D(v,rho)`. New control is body, environment `rho'[x := b]`, and continuation c.
Pointwise abstraction commutes with environment extension, including shadowing:
`alpha(rho'[x := b]) = alpha(rho')[x := g(b)]`. Lemmas 6-7 finish the case.
Here v can be any extended-language value, not only a lambda.

### 7.5 Conditional push

Control is `if e0 et ef`. Allocate the conditional role, store/join
`ifk(et,ef,rho,k)`, and evaluate e0. Both branches and the environment are mapped
structurally. Allocation and insertion are the same argument as application push.

### 7.6 False conditional result

Control is false and the selected frame is `ifk(et,ef,rho',c)`. False remains
false under alpha, so selecting the frame image restores ef/alpha(rho') and g(c).
Store and phase are unchanged. Label metadata does not affect truth selection.

### 7.7 Non-false conditional result

For lambda, call/cc, or a captured address value, alpha preserves its non-false
constructor. The same selected frame therefore restores et/rho' in both machines.
Even when the abstract cell also contains other possible values, this witness
uses the particular control value supplied by state coverage.

### 7.8 Assignment push

Control is `set! x e`. The target b is rho(x); its abstract target is g(b).
Both rules allocate an assignment frame storing that target and old tail, then
evaluate e in rho. Lemmas 6-7 cover the new frame and phase. Saving the target
address does not read or freeze its value before RHS evaluation.

### 7.9 Assignment completion

Control is new value v/rho and the selected frame is `setk(b,c)`. Read the OLD
denoted value `D(vo,rhoo)` from the current concrete cell at b, after RHS effects.
Lemma 8 supplies its image in the abstract OLD cell at g(b). Concrete replaces
b with `D(v,rho)`; abstract joins its image. Lemma 7 covers the new store.
Select the old-value image as the result and restore its old environment rhoo,
not the new RHS environment. The new continuation is c and phase is unchanged.
This covers aliases, nested assignment, and self-reference: all stored environments
contain addresses, so the proof does not unfold a potentially cyclic mutable graph.

### 7.10 call/cc applied to a lambda

The selected frame is `fn(call/cc,rhop,c)` and control is receiver `lambda x.body`
in rho. The captured value is `cap(c)` with the receiver's label and empty
environment. It is bound at the receiver's new binder address; execution continues
in body under extended rho with continuation c. Alpha maps the embedded c and
preserves the receiver label, so the abstract new value is exactly `cap(g(c))`.
Binding/phase compatibility and store coverage are Lemmas 6-7. No separate frame
is allocated merely to capture c; c excludes the primitive's own function frame.

### 7.11 call/cc applied to a captured continuation

The selected frame is again `fn(call/cc,rhop,c)`, but control is `cap(d)`.
Concrete delivers `cap(c)` with empty environment to continuation d. Abstract
delivers `cap(g(c))` to g(d), with the same copied origin label. The current store
and phase are retained. The frame/value witnesses and all address images agree.

### 7.12 Applying a captured continuation

The selected frame operator is `cap(d)` and the argument is v/rho. Concrete keeps
v/rho, sigma, and n, replacing the continuation with d. Abstract selects the frame
image and replaces its pointer with g(d), preserving the covered argument/store.
Thus jumps preserve current mutations; captures are addresses, not store snapshots.
No removal or linear consumption of the captured value occurs, so repeated
invocation is included in the same rule.

These are all successful cases of `raw_successors` and `continue`. Empty frames,
applying false, and call/cc receiving false have no successful concrete transition
and impose no extra case on a forward-step theorem. Admissibility preservation
from Section 3 ensures all enumerated abstract successors have supported graphs;
therefore subsequent collection is defined on the entire successor list, not only
on the selected simulation witness.

## 8. Garbage-collection graph and its basic properties

Define direct addresses `A(e,rho)` as environment addresses for FV(e), plus a
captured address when e is a standalone runtime `cap(a)`. Runtime tokens are not
embedded in source syntax in reachable states. Roots and storable edges are:

```text
Roots(s) = A(e,rho) union {k}.
Edges(mt) = empty.
Edges(D(v,rho)) = A(v,rho).
Edges(ar(l,e,rho,c)) = A(e,rho) union {c}.
Edges(fn(v,rho,c)) = A(v,rho) union {c}.
Edges(ifk(et,ef,rho,c)) = A(et,rho) union A(ef,rho) union {c}.
Edges(setk(b,c)) = {b,c}.
Edges_sigma(a) = union { Edges(d) | d in sigma(a) }.
```

These are exactly `expression_addresses` and `storable_addresses`. The live set
`L(s)` is the least set containing Roots(s) and closed under Edges_sigma. `G(s)`
restricts sigma to L(s) and changes no other state field.

**Lemma 9: marking correctness.** In `live_addresses`, visited addresses have
been scanned and pending addresses are discovered but not necessarily scanned.
Every discovered address has a path from a root. Every child of a scanned address
is either visited or pending. Initially these facts hold for roots. Scanning one
new address adds precisely its children and preserves both properties. A repeated
address is skipped without losing its previously scanned children. A finite graph
has finitely many addresses and finite fanout, so every new address is scanned
at most once and the finite worklist eventually empties, even with cycles.
At exhaustion visited contains every root and its closure; its path property
excludes any address outside that least closure. Thus visited equals L(s).

Under support invariants, every live address has a nonempty cell. Restriction
therefore loses no cell on any edge reachable from a root. All alternatives in a
retained cell survive unchanged. This proves support and role preservation,
including captured continuations, both conditional branches, and mutation targets.
An unreachable cycle has no root path and is deleted; a reachable cycle survives.

**Lemma 10: contraction and idempotence.** `G(s) <= s` for the same-domain state
order. Surviving contents are unchanged. Every old root path is still present
after restriction, and no new edge is added; therefore `L(G(s)) = L(s)` and
`G(G(s)) = G(s)`. Allocation phase, labels, environment, and continuation are
preserved, so this equality is for complete state records, not only stores.

## 9. Concrete GC preserves behavior

**Lemma 11: no resurrection of garbage by a concrete step.** Suppose `s ->c t`
is a fresh ordinary transition. Its reads access cells in L(s), and every old
address live in t was already in L(s). New live addresses can only be the freshly
allocated cell of that step. The rule-by-rule justification is:

| Rule family | Retained reads and future roots |
| --- | --- |
| Lookup | The variable address is a root; the chosen value's free/captured references are its outgoing edges. |
| Application push | Operand/operator FV roots and the old tail were live; the new frame introduces only its fresh pointer. |
| Argument-to-function | Saved operand/tail and the current operator's references were live. |
| Lambda binding | Body free names other than the parameter were live in the function closure; the parameter gets a fresh binding to the supported argument. |
| Conditional push/pop | Condition roots and both saved branch supports were live; selecting a branch only drops requirements. |
| Assignment push | Target and RHS FV roots were live; the new frame retains the target. |
| Assignment completion | Target, old value edges, new argument edges, and tail were live before replacement. Even an old closure referring to its own target now reaches the new, supported cell contents. |
| call/cc with lambda | Receiver free references and caller tail were live; only its parameter cell is new. |
| call/cc with capture | Receiver target and delivered caller tail were already live. |
| Invoking a capture | The function frame kept the captured target live, and the current argument's references were live. |

This table also explains why unused entries do not become observable accidentally.
Every restored expression has its FV support in a saved frame/value; exposing a
lambda body introduces only the formal parameter, which is newly bound. Restoring
a continuation restores control/environments whose live edges were retained,
not a previous store snapshot.

**Lemma 12: concrete collection commutes with a step followed by collection.**
If `s ->c t`, then `G(s) ->c t0` and `G(t0) = G(t)`. Enabled rule and selected
singleton contents are unchanged because their reads are live. Fresh allocation
chooses the same serial and role because n was retained, even if store cardinality
changed. The non-store headers and any inserted/replaced contents therefore agree.
By Lemma 11, post-step live paths use only old live cells and the matching new
cell. Those cells have identical contents in t/t0, so their marked sets and
restricted stores agree. Stuck/final classification is unchanged as well: every
candidate read enabling a concrete rule survives, and control/value tags are unchanged.

**Theorem 3: concrete GC trace correspondence.** Starting from the same injection,
the deterministically collected fresh run is `G(s0), G(s1), ...` when the ordinary
fresh run is `s0, s1, ...`. Injection is already collected. Induction on steps
uses Lemma 12; terminal/stuck behavior is preserved. Their final live rooted graphs
agree, although the uncollected stores can retain garbage. For the pure subset,
reification consults only live paths, so Theorem 1's evaluator equality also holds
with concrete GC. For Section 3 this is a heap/continuation correspondence, not
an assertion that cyclic mutable values can be unfolded into finite lambda terms.

The concrete commutation equality depends on fresh, phase-preserving allocation.
It is NOT asserted for finite abstract allocation: collecting a reusable address
before an update can intentionally prevent joins and change precision.

## 10. Abstract GC and collected-step simulation

**Lemma 13: GC monotonicity for flat headers.** If t<=u, Roots(t)=Roots(u).
At every address, t's storable set is included in u's, so its union of outgoing
edges is included as well. Induction on path length gives L(t) subset L(u).
Restriction therefore preserves cell-wise inclusion: `G(t) <= G(u)`. This lemma
requires supported extra alternatives so every environment access is defined.

**Lemma 14: GC abstraction compatibility.** Every direct concrete edge maps to
the corresponding direct edge of its storable image, and mapped roots are roots
of alpha(s). Induction on root-path length gives:

```text
g(L(s)) is a subset of L(alpha(s)).
alpha(G(s)) <= G(alpha(s)).
```

For the second claim, each concrete live cell's contents are mapped into a cell
at an abstract live address, so abstract restriction retains them. A dead concrete
cell can have the same image as a live one; its alternatives can survive abstract
GC, possibly keeping further abstract paths alive. Therefore equality or
commutation of alpha and G is not generally valid.

**Theorem 4 (collected one-step simulation).** Suppose `s =>c t` and
`alpha(s) <= u`, with admissible states. Write `s ->c s'`, `t=G(s')`. Theorem 2
provides `u ->a u'` with alpha(s')<=u'. Then Lemmas 13-14 yield:

```text
alpha(t) = alpha(G(s')) <= G(alpha(s')) <= G(u').
```

Since the code maps G over every raw successor, `u =>a G(u')` is an actual
collected successor. This proves the witness property for `successors ~gc:true`.
It neither assumes alpha/G commute nor adds an optional GC branch.

## 11. Reachability, outcomes, and finiteness

**Theorem 5: reachable-state coverage.** Injection commutes with alpha for both
policies: labels, empty environment, Halt cell, and initial phase zero agree.
Induct on the length of a finite concrete path, using Theorem 2 without GC or
Theorem 4 with GC. Every state on that path is covered by an abstract reachable
state. An infinite concrete path is covered prefix by prefix; no finite concrete
fuel cutoff is part of this semantic theorem.

GC analysis covers the deterministically collected concrete trace. It need not
cover every garbage cell of the ordinary concrete trace. Theorem 3 connects that
collected trace back to the same concrete live behavior.

If the concrete run finishes normally, its final value tag and `Halt : mt` survive
alpha and coverage, so at least one abstract final state is reachable. Consequently,
a COMPLETE analysis with no final states excludes normal concrete termination
under these model assumptions. In the extended language that does not imply
divergence: the program could be stuck. Conversely, abstract final-state existence
does not establish concrete termination or rule out spurious results.

Forward simulation does not preserve absence of transitions. A concrete stuck
state may be covered by an abstract state with extra applicable frame/value
alternatives. Thus `is_stuck` counts dead ends in the abstract graph; it is not
a complete detector of concrete errors. Matching fuel exhaustion is likewise
not a divergence proof. Printed value syntax omits closure environments and
continuation identities, so the CSV syntax counts are not full value denotations.

### Finite-state argument

Fix a source p, its finite labelled subterms S, names X, and labels L. Pool N has
N+1 addresses including Halt. Sites have at most:

```text
1 + lambda_sites + 2*application_sites + conditional_sites + assignment_sites.
```

Partial environments number at most `(|A|+1)^|X|`. Runtime captured values are
pairs of a label from L and an address from A, so they add at most `|L|*|A|`
controls; they do not introduce unbounded runtime code. Closures and frames
contain only finite choices of syntax/value, environment, origin label, and
address, never a nested store. The storable universe D is therefore finite.
Stores have at most `(2^|D|)^|A|` possibilities. Phase has N+1 possibilities for
pools and one for sites. State fields range over a finite product.

GC can remove cells and introduce cycles in the exploration history, but cannot
enlarge those domains. Concrete fresh addresses/counters are unbounded in the
ideal model and are deliberately excluded from `analyze`.

**Theorem 6: worklist correctness and termination.** Initially reached and queue
contain injection. Maintain: every reached state has a path from injection;
every reached but unprocessed state is queued; every processed state's successors
are reached. Processing a state adds only its actual successors and queues unseen
ones, preserving these facts. Each state is enqueued once, so the finite universe
guarantees queue exhaustion. At exhaustion reached contains injection and is closed
under successors. Induction on path length puts every reachable state in reached;
the first invariant excludes unreachable states. Hence the returned set is exactly
the reflexive transitive closure of the selected abstract transition system.

This is a computability result, not a practical memory/time bound: the finite
universe can be very large, and implementation resource failures remain outside
the successful-execution claim.

## 12. Why the implementation choices matter

| Tempting simplification | Obligation it would break |
| --- | --- |
| Infer next address from store size | Allocation compatibility under enlarged stores or concrete GC. |
| Strongly overwrite an abstract cell | Another concrete address with the same image may still require its old contents. |
| Consider just one value in a cell | Lose the lookup witness required by forward simulation. |
| Ignore addresses inside captured values | Wrong alpha headers and lost GC roots on continuation jumps. |
| Root every environment entry | Preserve unnecessary cells and defeat the intended precision gain; not required by lexical support. |
| Forget the pending mutation target | Remove the old value before RHS completion, losing mutation semantics. |
| Restore a capture's old store | Roll back current mutations; contradict the implemented control rule. |
| Assume alpha/G equality | Ignore alias-induced live abstract alternatives. |
| Compare raw final lambda code | Ignore lexical bindings represented by closure environments. |

For strong abstract overwrite, a concrete store can have distinct a1/a2 with
`g(a1)=g(a2)=b`. Updating only a2 must preserve a1's value in alpha of the new
store. Replacing abstract b rather than joining can drop that required value,
directly violating Lemma 7. GC permits a clean insertion only when that abstract
cell was proven wholly unreachable and removed; it never arbitrarily removes
an individual alternative from a live cell.

## 13. Code and verification audit

| Mathematical obligation | Implementation | Supporting checks |
| --- | --- | --- |
| Substitution / weak CBV | `reference_semantics.ml` | `reference_checks.ml`: capture cases, FV law, contexts, boundaries |
| Closure denotation / projection | `closure_reification.ml` | Reified final values and administrative/beta replay for 4034 generated terms |
| No infinite administrative stuttering | `weak_size`, `pending_work` in the audit | Natural measure decreases on checked pure transitions |
| I1-I5 and determinism | `store_machine.ml` rule cases | `invariant_checks.ml`: support, roles, singleton concrete cells, phases |
| Allocation / join / lookup | `allocate`, `next_phase`, `insert`, `lookup` | Exact/enlarged-store step simulation for pools 1/2 and sites |
| Section 3 cases | `raw_successors`, `continue`, `mutate`, `apply_callcc`, `apply_function` | 872 small extended terms, 22 named examples, GC off/on |
| Marking and concrete GC commutation | `live_addresses`, `collect` | Cyclic root graphs plus ordinary/collected concrete successors |
| Collected simulation / reachability | `successors ~gc:true`, `analyze` | GC coverage and fixed-point closure checks |

The invariant audit exercises 34 named input entries and 154 extended source
terms of 1-4 nodes. It checks supporting value/frame edges, role separation,
singleton concrete cells, allocation ranges, collection commutation, and the
pure administrative-work measure. The existing suites continue to check the
larger generated corpora and local simulation. These finite audits check that
the code behaves like the mathematical clauses; they do not validate universal
quantifiers or make this an automatically checked proof.

Remaining proof work is mechanization and refinement to bounded OCaml execution
(including arithmetic/resource assumptions), not replacing the case analysis
with more examples. An independent extended-language oracle, graph-aware value
representations, broader benchmarks, and the final implementation paper are
separate project milestones. The concrete Section 3 semantics is still taken
from the implemented/modelled rules rather than independently derived here.
