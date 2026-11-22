(** Independent concrete evaluator for the extended source language. Only the
    input adapter depends on Syntax. Evaluation uses its own AST, lexical name
    analysis, binding heap, and functional continuations; there is no abstract
    allocation, store-allocated continuation, or garbage collector. *)

type term =
  | Variable of string
  | Lambda of string * term
  | Apply of term * term
  | False
  | Callcc
  | Conditional of term * term * term
  | Assign of string * term

type value
type memory
type execution = Finished of value * memory | Stuck | Fuel_exhausted

(** Erase labels and reject runtime continuation literals. *)
val of_syntax : Syntax.expression -> term
val to_string : term -> string

(** Code/value tag only; captured environments and continuation behavior must
    be tested by evaluating enclosing source contexts, not this rendering. *)
val value_syntax : value -> string

(** Weak, operator-first CBV. Assignment returns the old value. Captured control
    is multi-shot and preserves the current binding heap on invocation.
    Fuel counts expression visits plus value applications; it is not comparable
    to Store_machine transition fuel. Exhaustion is inconclusive.
    As in Figure 6, call/cc receivers are closures or captured continuations;
    false and the call/cc primitive itself are invalid receivers.
    @raise Invalid_argument for open input or negative fuel. *)
val run : ?fuel:int -> term -> execution
