open Aam
module Machine = Store_machine

let concrete_result gc expression = match Machine.run ~gc expression with
  | Machine.Finished trace -> "finished", Syntax.to_string (List.hd (List.rev trace)).control
  | Machine.Fuel_exhausted _ -> "fuel exhausted", ""
  | Machine.Stuck _ -> "stuck", ""

(* Printed syntax hides captured environments and continuation identities.
   The fixed-point tests inspect whole states, not only these summaries. *)
let report name expression gc =
  let outcome, result = concrete_result gc expression in
  let reached = Machine.analyze ~gc ~policy:Machine.Site_based expression in
  let metrics = Analysis_metrics.summarize reached in
  let stuck = Machine.States.filter (Machine.is_stuck Machine.Site_based) reached in
  let results = Analysis_metrics.Terms.elements metrics.final_terms |> String.concat " | " in
  Printf.printf "%s,%s,%s,%s,%d,%d,%d,%d,%s\n%!"
    name (if gc then "on" else "off") outcome result metrics.states metrics.final_states
    (Machine.States.cardinal stuck) metrics.max_addresses results

let () =
  print_endline "example,gc,concrete_outcome,concrete_value_syntax,reachable_states,final_states,stuck_states,max_store_addresses,possible_final_value_syntax";
  List.iter (fun (name, expression) ->
    List.iter (report name expression) [false; true]) Extended_examples.all
