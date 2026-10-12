open Aam
module Machine = Store_machine

let explore = Experiment_analysis.explore

let csv value = "\"" ^ String.concat "\"\"" (String.split_on_char '"' value) ^ "\""

let concrete_result program =
  match Machine.run ~fuel:2000 program with
  | Machine.Finished trace -> "finished", Syntax.to_string (List.hd (List.rev trace)).control
  | Machine.Stuck _ -> "stuck", ""
  | Machine.Fuel_exhausted _ -> "fuel_exhausted", ""

let run benchmark policy_name gc max_states cpu_limit =
  let policy = match policy_name with
    | "sites" -> Machine.Site_based | "pool1" -> Machine.Bounded 1
    | _ -> invalid_arg "Expected sites or pool1" in
  let outcome, expected = concrete_result benchmark.Experiment_examples.program in
  (* The independent substitution semantics checks full pure values, including
     captured environments; the reported precision metric remains only syntax. *)
  if outcome = "finished" && Syntax.is_core benchmark.program then begin
    match Reference_semantics.run ~fuel:2000 (Reference_semantics.of_syntax benchmark.program),
          Machine.run ~fuel:2000 benchmark.program with
    | Reference_semantics.Finished reference_trace, Machine.Finished machine_trace ->
        let reference = List.hd (List.rev reference_trace) in
        let actual = Closure_reification.store_final (List.hd (List.rev machine_trace)) in
        if not (Reference_semantics.alpha_equivalent reference actual) then
          failwith "Independent reference disagreement"
    | _ -> failwith "Independent reference did not finish"
  end;
  Gc.full_major ();
  let cpu_start = Sys.time () and wall_start = Unix.gettimeofday () in
  let status, reached = explore policy gc max_states cpu_limit benchmark.program in
  let cpu = Sys.time () -. cpu_start and wall = Unix.gettimeofday () -. wall_start in
  let metrics = Analysis_metrics.summarize reached in
  let terms = Analysis_metrics.Terms.elements metrics.final_terms in
  let assessed = status = "complete" && outcome = "finished" in
  let extra = if assessed then string_of_int (List.length (List.filter ((<>) expected) terms)) else "" in
  let included = if assessed then string_of_bool (List.mem expected terms) else "" in
  if assessed && included = "false" then failwith "Concrete result syntax missing";
  let fields = [benchmark.name; policy_name; string_of_bool gc; status; outcome; expected;
    included; extra; string_of_int metrics.states; string_of_int metrics.final_states;
    string_of_int metrics.max_addresses; string_of_int metrics.max_values;
    Printf.sprintf "%.9f" cpu; Printf.sprintf "%.9f" wall; String.concat " | " terms] in
  print_endline (String.concat "," (List.map csv fields))

let () =
  if Array.length Sys.argv = 2 && Sys.argv.(1) = "--catalog" then
    List.iter (fun benchmark ->
      print_endline (String.concat "," (List.map csv [benchmark.Experiment_examples.name;
        benchmark.family; Syntax.to_string benchmark.program]))) Experiment_examples.all
  else if Array.length Sys.argv = 6 then begin
    let benchmark = List.find (fun benchmark -> benchmark.Experiment_examples.name = Sys.argv.(1))
      Experiment_examples.all in
    let max_states = int_of_string Sys.argv.(4) and cpu_limit = float_of_string Sys.argv.(5) in
    if max_states < 1 || cpu_limit <= 0. then invalid_arg "Limits must be positive";
    run benchmark Sys.argv.(2) (bool_of_string Sys.argv.(3)) max_states cpu_limit
  end else invalid_arg "Usage: experiments NAME sites|pool1 true|false MAX_STATES CPU_SECONDS"
