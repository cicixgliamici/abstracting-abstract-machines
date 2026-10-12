open Aam
module Machine = Store_machine

let report name expression policy_name policy =
  let metrics = Machine.analyze ~policy expression |> Analysis_metrics.summarize in
  Printf.printf "%s,%s,%d,%d,%d\n%!" name policy_name
    metrics.states metrics.final_states (Analysis_metrics.Terms.cardinal metrics.final_terms)

let () =
  print_endline "example,allocation,reachable_states,final_states,distinct_final_lambda_terms";
  List.iter (fun (name, expression) ->
    report name expression "pool-1" (Machine.Bounded 1);
    report name expression "sites" Machine.Site_based) Examples.all
