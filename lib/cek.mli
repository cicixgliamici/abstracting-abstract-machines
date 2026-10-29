(** Concrete, weak, left-to-right call-by-value evaluation of the pure subset.

    Closure and continuation constructors remain visible for trace rendering,
    reification, and whole-state correspondence tests. A hand-built state is
    not automatically valid: stepping requires the lexical support and pure
    closure/frame invariants established by [initial] and preserved by [step]. *)

type closure = Closure of Syntax.expression * environment
and environment = (string * closure) list

type continuation =
  | Empty
  | Argument of Syntax.expression * environment * continuation
  | Function of closure * continuation

type state = Syntax.expression * environment * continuation

type execution =
  | Finished of state list
  | Fuel_exhausted of state list
(** Traces are nonempty and ordered from the initial state to the last observed
    state, with both endpoints included. Exhaustion does not prove divergence. *)

(** Check the source, label its occurrences, and start with an empty environment
    and continuation.
    @raise Invalid_argument for open programs or any extended-language syntax. *)
val initial : Syntax.expression -> state

(** One transition on a supported pure state. [None] means a final lambda with
    an empty continuation. Lambda bodies are evaluated only on application.
    Malformed hand-built states are outside this function's contract. *)
val step : state -> state option

(** Evaluate a closed pure source program; [fuel] defaults to 1000 and counts
    transitions, not beta reductions. A final state needs no further fuel.
    @raise Invalid_argument for negative fuel or a source rejected by [initial]. *)
val run : ?fuel:int -> Syntax.expression -> execution
