module Reference = Reference_semantics
module Machine = Store_machine

(* This adapter does NOT call the reference substitution routine. Bound names
   remain bound; free occurrences are resolved in the closure's own environment.
   Inserted closure denotations are closed, so they cannot be captured. *)
let rec expand bound resolve expression = match expression.Syntax.term with
  | Syntax.Variable name ->
      if List.mem name bound then Reference.Variable name else resolve name
  | Syntax.Lambda (name, body) -> Reference.Lambda (name, expand (name :: bound) resolve body)
  | Syntax.Apply (operator, operand) ->
      Reference.Apply (expand bound resolve operator, expand bound resolve operand)
  | _ -> invalid_arg "Closure reification covers the pure lambda calculus"

let rec cek_expression expression environment =
  expand [] (fun name ->
    match List.assoc_opt name environment with
    | Some (Cek.Closure (value, captured)) -> cek_expression value captured
    | None -> invalid_arg ("Missing closure binding: " ^ name)) expression

let singleton store address = match Machine.Values.elements (Machine.lookup address store) with
  | [value] -> value
  | _ -> invalid_arg "Reification requires an existing singleton concrete cell"

(* Only referenced free bindings are unfolded. Garbage-collected unused entries
   need not exist. Cyclic value graphs and joined abstract cells are rejected. *)
let rec store_expression store visited expression environment =
  expand [] (fun name ->
    let address = match Machine.Names.find_opt name environment with
      | Some address -> address | None -> invalid_arg ("Missing store binding: " ^ name) in
    if Machine.Address_set.mem address visited then invalid_arg "Cyclic closure cannot be unfolded";
    match singleton store address with
    | Machine.Closure (value, captured) ->
        store_expression store (Machine.Address_set.add address visited) value captured
    | _ -> invalid_arg "Variable binding must contain a closure") expression

let rec plug_cek current = function
  | Cek.Empty -> current
  | Cek.Argument (operand, environment, rest) ->
      plug_cek (Reference.Apply (current, cek_expression operand environment)) rest
  | Cek.Function (Cek.Closure (operator, environment), rest) ->
      plug_cek (Reference.Apply (cek_expression operator environment, current)) rest

let cek_state (control, environment, continuation) =
  plug_cek (cek_expression control environment) continuation

let rec plug_store store visited current address =
  if Machine.Address_set.mem address visited then invalid_arg "Cyclic continuation cannot be unfolded";
  let visited = Machine.Address_set.add address visited in
  let unfold expression environment = store_expression store Machine.Address_set.empty expression environment in
  match singleton store address with
  | Machine.Empty -> current
  | Machine.Argument (_, operand, environment, rest) ->
      plug_store store visited (Reference.Apply (current, unfold operand environment)) rest
  | Machine.Function (operator, environment, rest) ->
      plug_store store visited (Reference.Apply (unfold operator environment, current)) rest
  | _ -> invalid_arg "Continuation reification requires a pure-language frame"

let store_state state =
  let current = store_expression state.Machine.store Machine.Address_set.empty
    state.control state.environment in
  plug_store state.store Machine.Address_set.empty current state.continuation

let cek_final ((control, _, continuation) as state) =
  match control.Syntax.term, continuation with
  | Syntax.Lambda _, Cek.Empty -> cek_state state
  | _ -> invalid_arg "Expected a final pure CEK state"

let store_final state =
  if not (Machine.is_final state) then invalid_arg "Expected a final store-machine state";
  match state.Machine.control.Syntax.term with
  | Syntax.Lambda _ -> store_state state
  | _ -> invalid_arg "Final value reification covers the pure lambda calculus"
