open Syntax

type closure = Closure of expression * environment
and environment = (string * closure) list

type continuation =
  | Empty
  | Argument of expression * environment * continuation
  | Function of closure * continuation

type state = expression * environment * continuation
type execution = Finished of state list | Fuel_exhausted of state list

let initial expression =
  require_closed expression;
  if not (is_core expression) then
    invalid_arg "CEK models the pure lambda subset; use Store_machine for Section 3";
  (label expression, [], Empty)

(* These four cases follow Figure 1; closures retain the lexical environment. *)
let step (expression, environment, continuation) =
  match expression.term, continuation with
  | Variable name, _ ->
      let Closure (value, saved_environment) = List.assoc name environment in
      Some (value, saved_environment, continuation)
  | Apply (operator, operand), _ ->
      Some (operator, environment, Argument (operand, environment, continuation))
  | Lambda _, Argument (operand, saved_environment, rest) ->
      Some (operand, saved_environment, Function (Closure (expression, environment), rest))
  | Lambda _, Function (Closure ({ term = Lambda (name, body); _ }, saved_environment), rest) ->
      (* Extend the operator's lexical environment, not the caller's. Removing
         its previous binding keeps shadowing compatible with the store map. *)
      Some (body, (name, Closure (expression, environment)) ::
        List.remove_assoc name saved_environment, rest)
  | Lambda _, Empty -> None
  | Lambda _, Function _ -> failwith "Invariant: function closure must be a lambda"
  | _ -> invalid_arg "CEK models the pure lambda subset"

let run ?(fuel = 1000) expression =
  if fuel < 0 then invalid_arg "Fuel must be nonnegative";
  let rec visit remaining reversed state =
    match step state with
    | None -> Finished (List.rev (state :: reversed))
    | Some _ when remaining = 0 -> Fuel_exhausted (List.rev (state :: reversed))
    | Some next -> visit (remaining - 1) (state :: reversed) next
  in
  visit fuel [] (initial expression)
