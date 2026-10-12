open Aam
module Reference = Reference_semantics
module Reify = Closure_reification
module Machine = Store_machine
type observation = { outcome : string; steps : int; value : Reference.term option }

let last trace = List.hd (List.rev trace)
let observe_reference expression = match Reference.run ~fuel:100 (Reference.of_syntax expression) with
  | Reference.Finished trace ->
      { outcome = "finished"; steps = List.length trace - 1; value = Some (last trace) }
  | Reference.Fuel_exhausted trace ->
      { outcome = "fuel exhausted"; steps = List.length trace - 1; value = None }

let observe_cek expression = match Cek.run ~fuel:400 expression with
  | Cek.Finished trace ->
      { outcome = "finished"; steps = List.length trace - 1; value = Some (Reify.cek_final (last trace)) }
  | Cek.Fuel_exhausted trace ->
      { outcome = "fuel exhausted"; steps = List.length trace - 1; value = None }

let observe_store gc expression = match Machine.run ~gc ~fuel:400 expression with
  | Machine.Finished trace ->
      { outcome = "finished"; steps = List.length trace - 1; value = Some (Reify.store_final (last trace)) }
  | Machine.Fuel_exhausted trace ->
      { outcome = "fuel exhausted"; steps = List.length trace - 1; value = None }
  | Machine.Stuck trace -> { outcome = "stuck"; steps = List.length trace - 1; value = None }

let agreement observations = match List.map (fun observation -> observation.value) observations with
  | Some expected :: rest when List.for_all Option.is_some rest ->
      if List.for_all (fun value -> Reference.alpha_equivalent expected (Option.get value)) rest
      then "yes" else "no"
  | _ -> "not checked: incomplete execution"

let print_csv cells =
  cells |> List.map (fun cell -> "\"" ^ String.concat "\"\"" (String.split_on_char '"' cell) ^ "\"")
    |> String.concat "," |> print_endline

(* Beta reductions and machine transitions have different units. Budgets are
   stated separately; incomplete runs have no final-value agreement claim. *)
let report name expression =
  let observations = [observe_reference expression; observe_cek expression;
    observe_store false expression; observe_store true expression] in
  let outcomes = List.concat_map (fun observation -> [observation.outcome; string_of_int observation.steps])
    observations in
  let values = List.map (fun observation -> match observation.value with
    | None -> "" | Some value -> Reference.to_string value) observations in
  print_csv ([name] @ outcomes @ [agreement observations] @ values)

let () =
  print_csv ["example"; "reference_outcome"; "reference_beta_steps"; "cek_outcome";
    "cek_transitions"; "cesk_outcome"; "cesk_transitions"; "gc_outcome"; "gc_transitions";
    "final_values_alpha_equal"; "reference_value"; "cek_reified_value";
    "cesk_reified_value"; "gc_reified_value"];
  List.iter (fun (name, expression) -> report name expression) Reference_examples.all
