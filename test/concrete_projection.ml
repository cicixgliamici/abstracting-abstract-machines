open Aam
module Machine = Store_machine

(* Environments are mathematical maps. Canonical ordering lets list-based CEK
   environments be compared with the store machine's ordered maps. *)
let rec normalize_closure (Cek.Closure (value, environment)) =
  Cek.Closure (value, normalize_environment environment)
and normalize_environment environment =
  List.map (fun (name, value) -> name, normalize_closure value) environment
  |> List.sort (fun (first, _) (second, _) -> String.compare first second)

let rec normalize_continuation = function
  | Cek.Empty -> Cek.Empty
  | Cek.Argument (value, environment, rest) ->
      Cek.Argument (value, normalize_environment environment, normalize_continuation rest)
  | Cek.Function (value, rest) ->
      Cek.Function (normalize_closure value, normalize_continuation rest)

let singleton store address =
  match Machine.Values.elements (Machine.lookup address store) with
  | [value] -> value
  | _ -> failwith "Concrete cell must be a singleton"

let rec environment store bindings =
  Machine.Names.bindings bindings |> List.map (fun (name, address) ->
    match singleton store address with
    | Machine.Closure (value, captured) -> name, Cek.Closure (value, environment store captured)
    | _ -> failwith "Concrete binding must point to a closure")

let rec continuation store address = match singleton store address with
  | Machine.Empty -> Cek.Empty
  | Machine.Argument (_, value, captured, rest) ->
      Cek.Argument (value, environment store captured, continuation store rest)
  | Machine.Function (value, captured, rest) ->
      Cek.Function (Cek.Closure (value, environment store captured), continuation store rest)
  | Machine.Closure _ -> failwith "Concrete continuation must point to a frame"
  | Machine.Conditional_frame _ | Machine.Assignment_frame _ ->
      invalid_arg "CEK projection only covers the pure lambda subset"

let matches (control, captured, rest) stored =
  control = stored.Machine.control
  && normalize_environment captured = environment stored.store stored.environment
  && normalize_continuation rest = continuation stored.store stored.continuation

(* Collection may remove addresses referenced only by unused environment
   entries. Compare observable environments, restricted independently by FV,
   rather than trying to dereference those deliberately dead entries. *)
let restrict expression bindings =
  let free = Syntax.free_variables expression in
  List.filter (fun (name, _) -> List.mem name free) bindings

let rec normalize_live_environment expression bindings =
  restrict expression bindings |> List.map (fun (name, Cek.Closure (value, captured)) ->
    name, Cek.Closure (value, normalize_live_environment value captured))
  |> List.sort (fun (first, _) (second, _) -> String.compare first second)

let rec normalize_live_continuation = function
  | Cek.Empty -> Cek.Empty
  | Cek.Argument (value, captured, rest) ->
      Cek.Argument (value, normalize_live_environment value captured,
        normalize_live_continuation rest)
  | Cek.Function (Cek.Closure (value, captured), rest) ->
      Cek.Function (Cek.Closure (value, normalize_live_environment value captured),
        normalize_live_continuation rest)

let rec live_environment store expression bindings =
  restrict expression (Machine.Names.bindings bindings)
  |> List.map (fun (name, address) -> match singleton store address with
    | Machine.Closure (value, captured) ->
        name, Cek.Closure (value, live_environment store value captured)
    | _ -> failwith "Live concrete binding must point to a closure")

let rec live_continuation store address = match singleton store address with
  | Machine.Empty -> Cek.Empty
  | Machine.Argument (_, value, captured, rest) ->
      Cek.Argument (value, live_environment store value captured, live_continuation store rest)
  | Machine.Function (value, captured, rest) ->
      Cek.Function (Cek.Closure (value, live_environment store value captured),
        live_continuation store rest)
  | Machine.Closure _ -> failwith "Live concrete continuation must point to a frame"
  | Machine.Conditional_frame _ | Machine.Assignment_frame _ ->
      invalid_arg "Live CEK projection only covers the pure lambda subset"

let matches_live (control, captured, rest) stored =
  control = stored.Machine.control
  && normalize_live_environment control captured =
    live_environment stored.store stored.control stored.environment
  && normalize_live_continuation rest = live_continuation stored.store stored.continuation
