open Aam
module Machine = Store_machine

let require condition message = if not condition then failwith message

let run () =
  List.iter (fun benchmark -> List.iter (fun gc ->
    let status, reached = Experiment_analysis.explore Machine.Site_based gc 5000 30.
      benchmark.Experiment_examples.program in
    require (status = "complete") "Site benchmark unexpectedly incomplete";
    let expected = Machine.analyze ~policy:Machine.Site_based ~gc benchmark.program in
    require (Machine.States.equal reached expected) "Bounded explorer changed a complete graph")
    [false; true]) Experiment_examples.all;
  let status, prefix = Experiment_analysis.explore Machine.Site_based false 1 30.
    Examples.identity_application in
  require (status = "state_limit" && Machine.States.cardinal prefix = 1)
    "State cutoff must preserve the cap and report incompleteness";
  let status, _ = Experiment_analysis.explore Machine.Site_based false 1 30. Examples.identity in
  require (status = "complete") "A graph exactly at its cap can still be complete";
  let status, _ = Experiment_analysis.explore Machine.Site_based false 5000 Float.min_float
    Examples.identity_application in
  require (status = "cpu_limit") "CPU cutoff must report incompleteness";
  print_endline "Experiments passed: complete graphs match library analysis; state and CPU cutoffs are explicit."
