open Aam
open Syntax
module Machine = Store_machine
let check message condition = if not condition then failwith message

let trace gc expression = match Machine.run ~gc ~fuel:40 expression with
  | Machine.Finished states | Machine.Fuel_exhausted states -> states
  | Machine.Stuck _ -> failwith "Pure lambda program unexpectedly stuck"

let check_lockstep expression =
  let rec visit remaining cek stored =
    check "Concrete GC must preserve live CEK state"
      (Concrete_projection.matches_live cek stored);
    match Cek.step cek, Machine.successors ~gc:true Machine.Fresh stored with
    | None, [] -> check "Concrete GC must preserve halting" (Machine.is_final stored)
    | Some next, [stored_next] when remaining > 0 -> visit (remaining - 1) next stored_next
    | Some _, [_] -> ()
    | _ -> failwith "Concrete GC/CEK transition mismatch"
  in visit 40 (Cek.initial expression) (Machine.initial expression)

let join_stores left right =
  Machine.Addresses.union (fun _ first second -> Some (Machine.Values.union first second))
    left right

let check_collection policy state enlarged =
  let lower = Machine.abstract_state policy (Machine.collect state) in
  let upper = Machine.abstract_state policy state in
  check "Abstract GC must cover concrete GC"
    (Machine.approximates lower (Machine.collect upper));
  check "GC must preserve approximation under enlarged stores"
    (Machine.approximates lower (Machine.collect { upper with store = enlarged }))

let check_step policy concrete next upper =
  let lower = Machine.abstract_state policy concrete in
  let target = Machine.abstract_state policy next in
  check "Collected simulation premise must hold" (Machine.approximates lower upper);
  check "Ordinary transition plus GC must simulate the concrete GC step"
    (List.exists (Machine.approximates target)
      (Machine.successors ~gc:true policy upper))

let check_simulation policy expression =
  let raw = trace false expression in
  let enlarged = List.fold_left (fun store state ->
    join_stores store (Machine.abstract_state policy state).store)
    Machine.Addresses.empty raw in
  List.iter (fun state -> check_collection policy state enlarged) raw;
  let rec visit = function
    | state :: (next :: _ as rest) ->
        let concrete = Machine.collect state in
        let target = Machine.collect next in
        check "Deterministic GC scheduling must match collected concrete traces"
          (List.exists (fun successor -> Machine.compare_state target successor = 0)
            (Machine.successors ~gc:true Machine.Fresh concrete));
        let upper = Machine.abstract_state policy concrete in
        check_step policy concrete target (Machine.collect upper);
        check_step policy concrete target (Machine.collect { upper with store = enlarged });
        visit rest
    | _ -> ()
  in visit raw

let check_reachability policy expression =
  let reached = Machine.analyze ~policy ~gc:true expression in
  check "Collected reachability includes injection"
    (Machine.States.mem (Machine.initial expression) reached);
  List.iter (fun state ->
    let lower = Machine.abstract_state policy state in
    check "Collected reachability must cover the concrete GC trace"
      (Machine.States.exists (Machine.approximates lower) reached)) (trace true expression);
  Machine.States.iter (fun state ->
    check "Reached stores must already be collected"
      (Machine.compare_state state (Machine.collect state) = 0);
    List.iter (fun next -> check "Collected reachability is a fixed point"
      (Machine.States.mem next reached)) (Machine.successors ~gc:true policy state)) reached

let graph_fixture () =
  let environment name address = Machine.Names.add "unused" (Machine.Pool 9)
    (Machine.Names.singleton name address) in
  let identity = label Examples.identity in
  let captured name address =
    Machine.Closure (label (lambda "bound" (variable name)), environment name address) in
  let argument = Machine.Site (Machine.Argument_site 90) in
  let function_address = Machine.Site (Machine.Function_site 90) in
  let entries = [
    Machine.Halt, Machine.Empty;
    Machine.Pool 1, captured "first" (Machine.Pool 2);
    Machine.Pool 1, captured "second" (Machine.Pool 4);
    Machine.Pool 1, Machine.Argument (91, identity, Machine.Names.empty, Machine.Pool 1);
    Machine.Pool 2, Machine.Closure (identity, Machine.Names.empty);
    Machine.Pool 4, Machine.Closure (identity, Machine.Names.empty);
    argument, Machine.Argument (90, label (variable "saved"),
      environment "saved" (Machine.Pool 6), function_address);
    function_address, Machine.Function (label (lambda "bound" (variable "saved")),
      environment "saved" (Machine.Pool 7), Machine.Halt);
    Machine.Pool 6, Machine.Closure (identity, Machine.Names.empty);
    Machine.Pool 7, Machine.Closure (identity, Machine.Names.empty);
    Machine.Pool 8, Machine.Argument (92, identity, Machine.Names.empty, Machine.Pool 9);
    Machine.Pool 9, Machine.Argument (93, identity, Machine.Names.empty, Machine.Pool 8)] in
  let store = List.fold_left (fun store (address, value) -> Machine.insert address value store)
    Machine.Addresses.empty entries in
  { (Machine.initial Examples.identity) with control = label (variable "root");
    environment = Machine.Names.add "unused" (Machine.Pool 9)
      (environment "root" (Machine.Pool 1)); store; continuation = argument }

let check_graph () =
  let state = graph_fixture () in
  let collected = Machine.collect state in
  List.iter (fun address -> check "Live transitive location must survive"
    (Machine.Addresses.mem address collected.store))
    [Machine.Halt; Machine.Pool 1; Machine.Pool 2; Machine.Pool 4;
     Machine.Pool 6; Machine.Pool 7;
     Machine.Site (Machine.Argument_site 90); Machine.Site (Machine.Function_site 90)];
  List.iter (fun address -> check "Unreachable cycle must be removed"
    (not (Machine.Addresses.mem address collected.store))) [Machine.Pool 8; Machine.Pool 9];
  check "GC must preserve every possibility in a live cell"
    (Machine.Values.equal (Machine.lookup (Machine.Pool 1) state.store)
      (Machine.lookup (Machine.Pool 1) collected.store));
  check "GC must be idempotent" (Machine.compare_state collected (Machine.collect collected) = 0);
  check "GC must only remove cells" (Machine.approximates collected state)

let check_reuse () =
  let plain = Machine.analyze ~policy:Machine.Site_based Examples.repeated_calls
    |> Analysis_metrics.summarize in
  let collected = Machine.analyze ~policy:Machine.Site_based ~gc:true Examples.repeated_calls
    |> Analysis_metrics.summarize in
  let expected = to_string Examples.constant in
  check "Without GC, repeated binder reuse must expose the old argument"
    (Analysis_metrics.Terms.mem (to_string Examples.identity) plain.final_terms);
  check "GC must leave exactly the concrete repeated-call result"
    (Analysis_metrics.Terms.equal collected.final_terms (Analysis_metrics.Terms.singleton expected));
  check "GC must reclaim store addresses in the reuse example"
    (collected.max_addresses < plain.max_addresses)

let run generated =
  let policies = [Machine.Bounded 1; Machine.Bounded 2; Machine.Site_based] in
  let programs = generated @ List.map snd Examples.gc_cases in
  List.iter (fun expression ->
    check_lockstep expression;
    List.iter (fun policy -> check_simulation policy expression) policies) programs;
  List.iter (fun expression ->
    List.iter (fun policy -> check_reachability policy expression) policies) generated;
  List.iter (fun (_, expression) -> check_reachability Machine.Site_based expression) Examples.gc_cases;
  check_graph ();
  check_reuse ();
  Printf.printf "GC passed: %d programs, 3 policies; live CEK correspondence, collection simulation, fixed points, cycles, and address reuse.\n"
    (List.length programs)
