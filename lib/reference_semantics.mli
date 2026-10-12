(** Independent weak, left-to-right call-by-value semantics for the pure subset. *)
type term = Variable of string | Lambda of string * term | Apply of term * term
module Names : Set.S with type elt = string
type execution = Finished of term list | Fuel_exhausted of term list
val of_syntax : Syntax.expression -> term
val to_string : term -> string
val free_variables : term -> Names.t

(** Substitution accepts open terms and avoids capture through alpha renaming. *)
val substitute : string -> term -> term -> term

(** None means no beta-value redex; open terms may be stuck. *)
val step : term -> term option

(** Evaluation accepts closed terms only. Fuel counts beta reductions. *)
val run : ?fuel:int -> term -> execution
val alpha_equivalent : term -> term -> bool
