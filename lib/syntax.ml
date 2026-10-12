(* Runtime continuation values share the address domain with the store machine.
   They are produced by evaluation, never accepted as source-program literals. *)
type location = Binding_site of int | Argument_site of int | Function_site of int
  | Conditional_site of int | Assignment_site of int
type address = Halt | Concrete of int * location | Pool of int | Site of location

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

(* Builders leave labels unset; injection assigns occurrence labels so a shared
   OCaml subtree does not accidentally identify distinct allocation sites. *)
let variable name = { label = -1; term = Variable name }
let lambda name body = { label = -1; term = Lambda (name, body) }
let apply operator operand = { label = -1; term = Apply (operator, operand) }
let false_value = { label = -1; term = False }
let callcc = { label = -1; term = Callcc }
let conditional condition consequent alternative =
  { label = -1; term = Conditional (condition, consequent, alternative) }
let assign name value = { label = -1; term = Assign (name, value) }

let children expression = match expression.term with
  | Lambda (_, body) | Assign (_, body) -> [body]
  | Apply (operator, operand) -> [operator; operand]
  | Conditional (condition, consequent, alternative) -> [condition; consequent; alternative]
  | Variable _ | False | Callcc | Captured_continuation _ -> []

let is_value expression = match expression.term with
  | Lambda _ | False | Callcc | Captured_continuation _ -> true
  | _ -> false

let rec is_core expression = match expression.term with
  | Variable _ | Lambda _ | Apply _ -> List.for_all is_core (children expression)
  | _ -> false

(* Visit children explicitly in source order: OCaml argument evaluation order
   must not affect labels used by allocation and the executable alpha map. *)
let label expression =
  let next = ref 0 in
  let rec visit expression =
    let site = !next in
    incr next;
    let term = match expression.term with
      | Variable name -> Variable name
      | Lambda (name, body) -> Lambda (name, visit body)
      | Apply (operator, operand) ->
          let operator = visit operator in
          let operand = visit operand in
          Apply (operator, operand)
      | False -> False
      | Callcc -> Callcc
      | Captured_continuation _ -> invalid_arg "Captured continuations are runtime values"
      | Conditional (condition, consequent, alternative) ->
          let condition = visit condition in
          let consequent = visit consequent in
          let alternative = visit alternative in
          Conditional (condition, consequent, alternative)
      | Assign (name, value) -> Assign (name, visit value)
    in { label = site; term }
  in visit expression

let rec to_string expression = match expression.term with
  | Variable name -> name
  | Lambda (name, body) -> "(lambda " ^ name ^ ". " ^ to_string body ^ ")"
  | Apply (operator, operand) ->
      "(" ^ to_string operator ^ " " ^ to_string operand ^ ")"
  | False -> "#f"
  | Callcc -> "call/cc"
  | Captured_continuation _ -> "#<continuation>"
  | Conditional (condition, consequent, alternative) ->
      "(if " ^ to_string condition ^ " " ^ to_string consequent ^ " " ^ to_string alternative ^ ")"
  | Assign (name, value) -> "(set! " ^ name ^ " " ^ to_string value ^ ")"

let rec free_variables expression = match expression.term with
  | Variable name -> [name]
  | Lambda (name, body) -> List.filter ((<>) name) (free_variables body)
  | Apply (operator, operand) ->
      List.sort_uniq String.compare
        (free_variables operator @ free_variables operand)
  | False | Callcc | Captured_continuation _ -> []
  | Conditional (condition, consequent, alternative) ->
      List.sort_uniq String.compare
        (free_variables condition @ free_variables consequent @ free_variables alternative)
  | Assign (name, value) -> List.sort_uniq String.compare (name :: free_variables value)

(* Only continuation values contain runtime addresses; source syntax is stable
   under alpha. This traversal also handles values embedded in synthetic tests. *)
let rec map_addresses map_address expression =
  let visit = map_addresses map_address in
  let term = match expression.term with
    | Captured_continuation address -> Captured_continuation (map_address address)
    | Lambda (name, body) -> Lambda (name, visit body)
    | Apply (operator, operand) -> Apply (visit operator, visit operand)
    | Conditional (condition, consequent, alternative) ->
        Conditional (visit condition, visit consequent, visit alternative)
    | Assign (name, value) -> Assign (name, visit value)
    | Variable _ | False | Callcc -> expression.term
  in { expression with term }

let require_closed expression =
  if free_variables expression <> [] then
    invalid_arg "Expected a closed lambda-calculus program"
