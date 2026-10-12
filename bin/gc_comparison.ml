open Aam
module Machine = Store_machine

(* CPU timing excludes summary construction and the preparatory runtime GC.
   Three repetitions provide a median, not a portable performance guarantee. *)
let measure policy gc expression =
  let samples = List.init 3 (fun _ ->
    Gc.full_major ();
    let start = Sys.time () in
    let reached = Machine.analyze ~policy ~gc expression in
    let seconds = Sys.time () -. start in
    Analysis_metrics.summarize reached, seconds) in
  let metrics = fst (List.hd samples) in
  let times = List.map snd samples |> List.sort Float.compare in
  metrics, List.nth times 1

let report name expression policy_name policy gc =
  let metrics, seconds = measure policy gc expression in
  Printf.printf "%s,%s,%s,%d,%d,%d,%d,%d,%.6f\n%!"
    name policy_name (if gc then "on" else "off") metrics.states metrics.final_states
    (Analysis_metrics.Terms.cardinal metrics.final_terms)
    metrics.max_addresses metrics.max_values seconds

let compare name expression policy_name policy =
  List.iter (report name expression policy_name policy) [false; true]

let () =
  print_endline "example,allocation,gc,reachable_states,final_states,distinct_final_lambda_terms,max_store_addresses,max_store_values,cpu_seconds_median";
  List.iter (fun (name, expression) ->
    compare name expression "pool-1" (Machine.Bounded 1);
    compare name expression "sites" Machine.Site_based) Examples.all;
  (* The larger repeated-call example isolates site reuse. Its pooled analysis
     is omitted to keep this demonstration's coarse baseline cost bounded. *)
  compare "repeated calls" Examples.repeated_calls "sites" Machine.Site_based
