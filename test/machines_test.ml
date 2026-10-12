open Aam
open Syntax
module Machine = Store_machine
let check message condition = if not condition then failwith message

let check_lockstep expression =
  let rec visit remaining cek stored =
    check "CEK/CESK whole-state projection mismatch"
      (Concrete_projection.matches cek stored);
    match Cek.step cek, Machine.successors Machine.Fresh stored with
    | None, [] -> check "CESK must halt" (Machine.is_final stored)
    | Some next, [stored_next] when remaining > 0 -> visit (remaining - 1) next stored_next
    | Some _, [_] -> () (* A bounded prefix is evidence, not a termination claim. *)
    | _ -> failwith "CEK/CESK transition mismatch"
  in visit 40 (Cek.initial expression) (Machine.initial expression)

let trace expression = match Machine.run ~fuel:40 expression with
  | Machine.Finished states | Machine.Fuel_exhausted states -> states
  | Machine.Stuck _ -> failwith "Pure lambda program unexpectedly stuck"

let join_stores left right =
  Machine.Addresses.union (fun _ first second -> Some (Machine.Values.union first second))
    left right

let check_step policy concrete next upper =
  let lower = Machine.abstract_state policy concrete in
  check "Simulation premise must hold" (Machine.approximates lower upper);
  let target = Machine.abstract_state policy next in
  check "One concrete step must have an approximating abstract successor"
    (List.exists (Machine.approximates target) (Machine.successors policy upper))

let check_simulation policy expression =
  let states = trace expression in
  (* Union future trace cells to test the simulation premise with strictly larger
     stores as well as exact alpha states. Allocation must be store-independent. *)
  let enlarged = List.fold_left (fun store state ->
    join_stores store (Machine.abstract_state policy state).store)
    Machine.Addresses.empty states in
  let rec pairs = function
    | concrete :: (next :: _ as rest) ->
        let abstract = Machine.abstract_state policy concrete in
        check_step policy concrete next abstract;
        check_step policy concrete next { abstract with store = enlarged };
        pairs rest
    | _ -> ()
  in pairs states

let check_reachability policy expression =
  let reachable = Machine.analyze ~policy expression in
  check "Injection belongs to reachability"
    (Machine.States.mem (Machine.abstract_state policy (Machine.initial expression)) reachable);
  List.iter (fun concrete ->
    let lower = Machine.abstract_state policy concrete in
    check "Reachability covers concrete trace"
      (Machine.States.exists (Machine.approximates lower) reachable)) (trace expression);
  Machine.States.iter (fun state ->
    List.iter (fun next -> check "Reachability is closed under successors"
      (Machine.States.mem next reachable)) (Machine.successors policy state)) reachable

let expect_final expression expected = match Cek.run expression with
  | Cek.Finished states ->
      let control, _, _ = List.hd (List.rev states) in
      check "Wrong lexical result" (to_string control = to_string expected)
  | _ -> failwith "Expected terminating example"

let check_returned_closure () = match Cek.run Examples.returned_closure with
  | Cek.Finished states ->
      let _, environment, _ = List.hd (List.rev states) in
      let Cek.Closure (captured, _) = List.assoc "x" environment in
      check "Returned closure must preserve captured binding"
        (to_string captured = to_string Examples.identity)
  | _ -> failwith "Expected returned closure"

let check_labels () =
  let rec sites expression = expression.label :: List.concat_map sites (children expression) in
  let program = label Examples.identity_application in
  let labels = sites program in
  check "Every syntax occurrence needs a unique label"
    (List.length labels = List.length (List.sort_uniq Int.compare labels));
  check "Labeling must be deterministic" (program = label Examples.identity_application);
  let store = Machine.Addresses.empty in
  let state = Machine.initial Examples.identity in
  let addresses = List.map (Machine.allocate Machine.Site_based state)
    [Machine.Binding_site 0; Machine.Argument_site 0; Machine.Function_site 0] in
  check "Address roles must be disjoint"
    (List.length (List.sort_uniq compare addresses) = 3);
  let joined = List.fold_left (fun store value -> Machine.insert (Machine.Pool 1) value store)
    store [Machine.Empty; Machine.Closure (program, Machine.Names.empty)] in
  check "Store reuse must join"
    (Machine.Values.cardinal (Machine.lookup (Machine.Pool 1) joined) = 2)

let check_errors () =
  let rejected action = try action (); false with Invalid_argument _ -> true in
  check "Open terms rejected" (rejected (fun () -> ignore (Cek.initial (variable "free"))));
  check "Invalid pool rejected" (rejected (fun () ->
    ignore (Machine.analyze ~policy:(Machine.Bounded 0) Examples.identity)));
  check "Infinite allocator rejected for analysis" (rejected (fun () ->
    ignore (Machine.analyze ~policy:Machine.Fresh Examples.identity)))

let check_map_equality () =
  let bindings names = List.fold_left (fun result name ->
    Machine.Names.add name (Machine.Pool 1) result) Machine.Names.empty names in
  let first = bindings ["a"; "b"; "c"; "d"] in
  let second = bindings ["d"; "c"; "b"; "a"] in
  let state = Machine.initial Examples.identity in
  let values = Machine.Values.of_list
    [Machine.Closure (state.control, first); Machine.Closure (state.control, second)] in
  check "Equivalent environment maps must identify one closure"
    (Machine.Values.cardinal values = 1);
  let states = Machine.States.of_list
    [{ state with environment = first }; { state with environment = second }] in
  check "Equivalent environment maps must identify one state"
    (Machine.States.cardinal states = 1)

let check_evaluation_strategy () =
  let discarding = apply (lambda "unused" Examples.identity) Examples.omega in
  (match Cek.run ~fuel:40 discarding with
   | Cek.Fuel_exhausted _ -> ()
   | _ -> failwith "Call-by-value must evaluate even an unused argument");
  let initial = Cek.initial Examples.nested_application in
  let control, _, _ = initial in
  match control.term, Cek.step initial with
  | Apply (operator, _), Some (next, _, _) ->
      check "Application must evaluate its operator first" (operator = next)
  | _ -> failwith "Expected application transition"

let () =
  let generated = Generated_terms.closed_up_to 6 in
  check "Generated suite must be nonempty" (generated <> []);
  let programs = List.map snd Examples.all @ generated in
  let policies = [Machine.Bounded 1; Machine.Bounded 2; Machine.Site_based] in
  List.iter (fun expression ->
    check_lockstep expression;
    List.iter (fun policy -> check_simulation policy expression) policies) programs;
  (* Exhaustive tiny-term fixed points remain cheap. The large one-cell examples
     are measured by the comparison executable instead of repeated in this suite. *)
  List.iter (fun expression ->
    List.iter (fun policy -> check_reachability policy expression) policies) generated;
  List.iter (fun (_, expression) -> check_reachability Machine.Site_based expression) Examples.all;
  expect_final Examples.lexical_capture Examples.identity;
  expect_final Examples.shadowing Examples.constant;
  expect_final Examples.nested_application Examples.constant;
  check_returned_closure ();
  check_labels ();
  check_errors ();
  check_map_equality ();
  check_evaluation_strategy ();
  (match Cek.run ~fuel:40 Examples.omega with
   | Cek.Fuel_exhausted _ -> () | _ -> failwith "Omega must exhaust fuel");
  Printf.printf "Passed: %d generated closed terms (1-6 nodes), %d programs, 3 policies.\n"
    (List.length generated) (List.length programs);
  print_endline "Whole-state lockstep, local simulation with enlarged stores, reachability closure, lexical results, and allocation invariants passed.";
  Gc_checks.run generated;
  Section3_checks.run ();
  Reference_checks.run ();
  Invariant_checks.run ();
  Experiment_checks.run ()
