open Aam
open Syntax
module Machine = Store_machine

let require condition message = if not condition then failwith message
let last values = List.hd (List.rev values)

let final_syntax state = Syntax.to_string state.Machine.control

let check_concrete observation =
  let final = last observation.Guided_example.concrete_trace in
  let reified = Closure_reification.cek_final final in
  let expected = Reference_semantics.of_syntax Examples.constant in
  require (Reference_semantics.alpha_equivalent reified expected)
    "The walkthrough must return the constant function concretely";
  match Reference_semantics.run (Reference_semantics.of_syntax Guided_example.program) with
  | Reference_semantics.Finished trace ->
      require (Reference_semantics.alpha_equivalent reified (last trace))
        "The walkthrough must agree with independent substitution evaluation"
  | _ -> failwith "The walkthrough reference evaluation must finish"

let shared_binding () =
  match (Syntax.label Guided_example.program).term with
  | Apply (_, identity) -> Machine.Site (Machine.Binding_site identity.label)
  | _ -> failwith "Expected a shared identity argument"

let check_choice observation =
  let state = last observation.Guided_example.abstract_prefix in
  require (state.Machine.control.term = Variable "x")
    "The first abstract choice must be the second lookup of x";
  let location = Machine.Names.find "x" state.environment in
  require (location = shared_binding ()) "Both calls must reuse the shared identity binder";
  let values = Machine.lookup location state.store in
  require (Machine.Values.cardinal values = 2) "The binder must retain both actual arguments";
  let branches = observation.abstract_branches in
  require (List.length branches = 2 && List.for_all Machine.is_final branches)
    "The joined lookup must have two final successors";
  require (List.for_all (fun branch -> Machine.States.mem branch observation.uncollected_reached) branches)
    "Displayed branches must belong to the complete reachable graph";
  let terms = List.map final_syntax branches |> List.sort_uniq String.compare in
  let expected = List.map Syntax.to_string [Examples.identity; Examples.constant]
    |> List.sort_uniq String.compare in
  require (terms = expected) "The uncollected analysis must include the spurious identity";
  Machine.Values.iter (function
    | Machine.Closure (value, captured) ->
        require (List.exists (fun branch -> branch.Machine.control = value
          && Machine.Names.equal (=) branch.environment captured) branches)
          "Each branch must restore its own closure environment"
    | _ -> failwith "A site binding must contain only closures") values

let check_collection observation =
  let reads = List.filter (fun state -> state.Machine.control.term = Variable "x")
    observation.Guided_example.collected_trace in
  require (List.length reads = 2) "The collected trace must show both calls to the shared identity";
  List.iter2 (fun state expected ->
    let location = Machine.Names.find "x" state.Machine.environment in
    require (location = shared_binding ()) "GC must not change the binder address";
    match Machine.Values.elements (Machine.lookup location state.store) with
    | [Machine.Closure (value, _)] ->
        require (Syntax.to_string value = Syntax.to_string expected)
          "GC must retain only the current call's argument"
    | _ -> failwith "Each collected binder lookup must be singleton") reads
    [Examples.identity; Examples.constant];
  let metrics = Analysis_metrics.summarize observation.collected_reached in
  require (Analysis_metrics.Terms.elements metrics.final_terms = [Syntax.to_string Examples.constant])
    "The complete collected graph must exclude the spurious identity result";
  require (Machine.is_final (last observation.collected_trace)) "The collected trace must finish"

let run () =
  let observation = Guided_example.observe () in
  check_concrete observation;
  check_choice observation;
  check_collection observation;
  print_endline "Guided example passed: independent concrete result, joined binder branches, captured environments, and GC precision."
