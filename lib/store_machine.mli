(** Store-allocated concrete execution and finite-address abstract analysis.

    Use [run] and [analyze] for source programs. Representation types remain
    visible because inspecting entire states and constructing invariant fixtures
    are explicit goals of this implementation study. They do not enforce valid
    states by construction.

    Low-level operations require supported states: every free-variable binding,
    continuation edge, and mutation target has the appropriate store support;
    source labels and address roles agree; counters match the selected policy.
    Fresh cells are singleton. Unused environment entries may dangle after GC.
    See CORRECTNESS.md, invariants I1-I5. Inputs from [initial] followed by the
    corresponding [successors] satisfy these requirements, subject to the
    documented integer and resource assumptions. *)

type location = Syntax.location =
  | Binding_site of int
  | Argument_site of int
  | Function_site of int
  | Conditional_site of int
  | Assignment_site of int

type address = Syntax.address =
  | Halt
  | Concrete of int * location
  | Pool of int
  | Site of location

module Names : Map.S with type key = string
module Addresses : Map.S with type key = address
module Address_set : Set.S with type elt = address

type environment = address Names.t

type storable =
  | Closure of Syntax.expression * environment
  | Empty
  | Argument of int * Syntax.expression * environment * address
  | Function of Syntax.expression * environment * address
  | Conditional_frame of Syntax.expression * Syntax.expression * environment * address
  | Assignment_frame of address * address
(** [Closure] also represents false, call/cc, and captured-continuation values.
    [Empty] is the halt frame. The integer in [Argument] retains its application
    origin so a later function frame allocates at the same application site. *)

module Values : Set.S with type elt = storable
type store = Values.t Addresses.t

type state = {
  control : Syntax.expression;
  environment : environment;
  store : store;
  continuation : address;
  allocations : int;
}
(** [allocations] is a fresh serial count, a capped pooled phase, or zero for
    sites. Collection preserves it; it is not the store's cardinality. *)

module States : Set.S with type elt = state

type allocation = Fresh | Bounded of int | Site_based
(** [Bounded n] fills slots 1 through [n], then always reuses slot 1. It is not
    round-robin. [Site_based] separates binder and continuation-frame roles. *)

type execution =
  | Finished of state list
  | Fuel_exhausted of state list
  | Stuck of state list
(** Nonempty traces include the initial and last observed states, in execution
    order. [Stuck] is separate from a final value and from fuel exhaustion. *)

(** {1 Source-level execution and analysis} *)

(** Inject a closed source program with deterministic labels and a halt cell.
    @raise Invalid_argument for open input or runtime continuation literals. *)
val initial : Syntax.expression -> state

(** Deterministic fresh-address execution. Defaults: 1000 transitions, GC off.
    Assignment returns the old value; invoking a continuation keeps the current
    store. GC, if enabled, follows each ordinary transition.
    @raise Invalid_argument for negative fuel or a source rejected by [initial]. *)
val run : ?fuel:int -> ?gc:bool -> Syntax.expression -> execution

(** Complete reachable-state exploration, including the initial state. Each
    reached state has its own store; there is no global store widening or cutoff.
    Completion assumes sufficient time, memory, stack, and nonoverflowing integers.

    Without [policy], use [Bounded addresses] with [addresses = 1] by default.
    An explicit [policy] overrides [addresses]. GC defaults to false.
    @raise Invalid_argument for [Fresh], a nonpositive selected pool size, or
    a source rejected by [initial]. *)
val analyze :
  ?addresses:int -> ?policy:allocation -> ?gc:bool -> Syntax.expression -> States.t

(** {1 Supported-state transitions and inspection} *)

(** All compatible next states. Joined cells can induce multiple successors.
    GC defaults to false; enabling it collects every successor deterministically.
    The policy and state's address domain/phase must agree.
    @raise Invalid_argument for a nonpositive pool size. *)
val successors : ?gc:bool -> allocation -> state -> state list

(** A value whose current continuation cell includes the halt frame. In an
    abstract graph, a final state need not prove concrete termination. *)
val is_final : state -> bool

(** Nonfinal state with no uncollected successor under the given policy.
    Abstract extra alternatives can conceal concrete stuckness; this predicate
    is not a complete concrete-error detector. *)
val is_stuck : allocation -> state -> bool

(** Extensional state ordering, consistent with [States] membership. Map insertion
    history does not distinguish semantically equal environments or stores. *)
val compare_state : state -> state -> int

(** Missing addresses denote the empty set. *)
val lookup : address -> store -> Values.t

(** Add one alternative by union, retaining every existing value at the address.
    This low-level helper alone does not establish supported-state invariants. *)
val insert : address -> storable -> store -> store

(** Reachable store addresses from control free variables and continuation.
    Traverses every alternative, terminates on cycles, and requires supported
    free-variable environments in every reached value/frame. *)
val live_addresses : state -> Address_set.t

(** Restrict the store to [live_addresses]; retain the other state fields.
    Unused environment entries may then refer to removed cells. *)
val collect : state -> state

(** {1 Allocation and abstraction checks} *)

(** @raise Invalid_argument for [Bounded n] when [n < 1]. *)
val validate_policy : allocation -> unit

(** Select an address without updating the state or advancing its phase.
    Exposed for allocator/invariant checks; ordinary clients use [successors].
    The state must have the selected policy's supported phase.
    @raise Invalid_argument for a nonpositive pool size. *)
val allocate : allocation -> state -> location -> address

(** Project halt or a fresh concrete address into a finite policy's domain.
    Requires a finite policy and a positive, provenance-bearing concrete serial.
    @raise Invalid_argument for invalid pools, nonconcrete/nonhalt input, or
    a fresh-address projection requested with [Fresh]. *)
val abstract_address : allocation -> address -> address

(** Project a supported fresh state, including runtime addresses and phase,
    merging concrete cells whose images collide. Use a finite policy.
    @raise Invalid_argument for [Fresh], a nonpositive pool size, or an address
    that is already abstract. *)
val abstract_state : allocation -> state -> state

(** [approximates lower upper] requires equal control, environment, continuation,
    and phase, and checks pointwise inclusion of [lower]'s store in [upper]'s.
    For concrete coverage, first obtain [lower] with [abstract_state]. This
    predicate does not validate either state's invariants. *)
val approximates : state -> state -> bool
