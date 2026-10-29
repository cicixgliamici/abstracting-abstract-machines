(** Shared source syntax and runtime address vocabulary.

    Constructors remain public so examples, transition rules, and invariant
    checks can inspect the AST directly. Source builders leave labels unset;
    machine injection assigns them before execution. *)

type location =
  | Binding_site of int
  | Argument_site of int
  | Function_site of int
  | Conditional_site of int
  | Assignment_site of int

type address =
  | Halt
  | Concrete of int * location
  | Pool of int
  | Site of location

type expression = { label : int; term : term }
and term =
  | Variable of string
  | Lambda of string * expression
  | Apply of expression * expression
  | False
  | Callcc
  | Captured_continuation of address
  | Conditional of expression * expression * expression
  | Assign of string * expression
(** [Captured_continuation] represents a runtime value. It is not accepted as
    source input, even when embedded inside a lambda or another constructor. *)

(** {1 Source construction} *)

val variable : string -> expression
val lambda : string -> expression -> expression
val apply : expression -> expression -> expression
val false_value : expression
val callcc : expression
val conditional : expression -> expression -> expression -> expression
val assign : string -> expression -> expression

(** {1 Inspection and injection} *)

(** Immediate children in source order. *)
val children : expression -> expression list

(** Recognize lambda, false, call/cc, and captured-continuation value forms.
    This is a syntax check; it does not establish closedness or well-formedness. *)
val is_value : expression -> bool

(** Whether the entire expression belongs to the pure variable/lambda/apply subset. *)
val is_core : expression -> bool

(** Replace labels with unique, deterministic preorder occurrence numbers,
    starting at zero. Shared OCaml subtrees get separate occurrence labels.
    @raise Invalid_argument if a captured-continuation literal occurs. *)
val label : expression -> expression

(** Print syntax without labels. Captured continuation addresses are omitted;
    this string is not a complete runtime-value identity. *)
val to_string : expression -> string

(** Sorted, duplicate-free free variable names. Assignment includes its target. *)
val free_variables : expression -> string list

(** @raise Invalid_argument if the expression has free variables.
    This check alone does not reject runtime literals or extended syntax. *)
val require_closed : expression -> unit

(** {1 Runtime abstraction support} *)

(** Map addresses in runtime continuation values, including nested occurrences.
    Names and labels are preserved; source syntax has no runtime addresses. *)
val map_addresses : (address -> address) -> expression -> expression
