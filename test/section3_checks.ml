open Aam
open Syntax
module Machine = Store_machine
let check message condition = if not condition then failwith message

let states = function
  | Machine.Finished trace | Machine.Fuel_exhausted trace | Machine.Stuck trace -> trace

let concrete_trace gc expression = Machine.run ~gc ~fuel:80 expression |> states

let check_results () =
  List.iter (fun gc ->
    List.iter (fun (name, expression, expected) ->
      match Machine.run ~gc ~fuel:500 expression with
      | Machine.Finished trace ->
          let final = List.hd (List.rev trace) in
          check ("Wrong concrete result: " ^ name)
            (to_string final.control = to_string expected)
      | _ -> failwith ("Expected concrete termination: " ^ name)) Extended_examples.terminating;
    List.iter (fun expression -> match Machine.run ~gc expression with
      | Machine.Finished trace ->
          let final = List.hd (List.rev trace) in
          check "Returned continuation must capture halt"
            (final.control.term = Captured_continuation Machine.Halt)
      | _ -> failwith "Expected a captured continuation result")
      [Extended_examples.returned_continuation; Extended_examples.callcc_continuation];
    List.iter (fun expression -> match Machine.run ~gc expression with
      | Machine.Stuck trace -> check "Stuck is distinct from halting"
          (not (Machine.is_final (List.hd (List.rev trace))))
      | _ -> failwith "Invalid application must be explicitly stuck")
      [Extended_examples.invalid_false_application; Extended_examples.invalid_callcc_argument])
    [false; true]

let join_stores left right =
  Machine.Addresses.union (fun _ first second -> Some (Machine.Values.union first second))
    left right

(* Mutation makes concrete stores nonmonotonic; taking the union of projected
   trace cells deliberately includes both old and new possibilities in an upper
   store. Runtime continuation addresses must be projected in control and values. *)
let check_simulation policy gc expression =
  let trace = concrete_trace gc expression in
  let enlarged = List.fold_left (fun store state ->
    join_stores store (Machine.abstract_state policy state).store)
    Machine.Addresses.empty trace in
  let rec visit = function
    | state :: (next :: _ as rest) ->
        let lower = Machine.abstract_state policy state in
        let target = Machine.abstract_state policy next in
        List.iter (fun upper ->
          let upper = if gc then Machine.collect upper else upper in
          check "Extended simulation premise must hold" (Machine.approximates lower upper);
          check "Extended concrete step needs an approximating successor"
            (List.exists (Machine.approximates target) (Machine.successors ~gc policy upper)))
          [lower; { lower with store = enlarged }];
        visit rest
    | _ -> ()
  in visit trace

let check_collection policy expression =
  List.iter (fun state ->
    let lower = Machine.abstract_state policy (Machine.collect state) in
    let upper = Machine.abstract_state policy state |> Machine.collect in
    check "Extended GC must cover concrete collection"
      (Machine.approximates lower upper)) (concrete_trace false expression)

let check_reachability gc expression =
  let policy = Machine.Site_based in
  let reached = Machine.analyze ~gc ~policy expression in
  List.iter (fun state ->
    let lower = Machine.abstract_state policy state in
    check "Extended fixed point must cover concrete trace"
      (Machine.States.exists (Machine.approximates lower) reached)) (concrete_trace gc expression);
  Machine.States.iter (fun state ->
    if gc then check "Extended reached stores must be collected"
      (Machine.compare_state state (Machine.collect state) = 0);
    List.iter (fun next -> check "Extended reachability must be closed"
      (Machine.States.mem next reached)) (Machine.successors ~gc policy state)) reached

let check_updates () =
  let before = concrete_trace false Extended_examples.assignment_old
    |> List.find (fun state -> is_value state.Machine.control &&
      Machine.Values.exists (function Machine.Assignment_frame _ -> true | _ -> false)
        (Machine.lookup state.continuation state.store)) in
  let target = Machine.Values.elements (Machine.lookup before.continuation before.store)
    |> List.find_map (function Machine.Assignment_frame (target, _) -> Some target | _ -> None)
    |> Option.get in
  let after = List.hd (Machine.successors Machine.Fresh before) in
  check "Concrete set! must overwrite its unique binding"
    (Machine.Values.cardinal (Machine.lookup target after.store) = 1);
  let lower = Machine.abstract_state Machine.Site_based before in
  let abstract_target = Machine.abstract_address Machine.Site_based target in
  let abstract_after = List.hd (Machine.successors Machine.Site_based lower) in
  check "Abstract set! must retain both old and new values"
    (Machine.Values.cardinal (Machine.lookup abstract_target abstract_after.store) = 2)

let check_gc_roots () =
  let start = Machine.initial Examples.identity in
  let target = Machine.Site (Machine.Argument_site 90) in
  let store = Machine.insert target
    (Machine.Argument (90, start.control, Machine.Names.empty, Machine.Halt)) start.store in
  let captured = { label = 0; term = Captured_continuation target } in
  let saved = { start with control = captured; store } |> Machine.collect in
  check "A continuation value in control is a GC root"
    (Machine.Addresses.mem target saved.store);
  let binding = Machine.Site (Machine.Binding_site 91) in
  let stored = Machine.insert binding (Machine.Closure (captured, Machine.Names.empty)) store in
  let saved = { start with control = label (variable "saved"); store = stored;
    environment = Machine.Names.singleton "saved" binding } |> Machine.collect in
  check "A continuation value stored in a binding keeps its frames alive"
    (Machine.Addresses.mem target saved.store);
  let frame = Machine.Site (Machine.Assignment_site 92) in
  let stored = Machine.insert frame (Machine.Assignment_frame (binding, Machine.Halt)) stored in
  let pending = { start with store = stored; continuation = frame } |> Machine.collect in
  check "Assignment must retain its target while evaluating the RHS"
    (Machine.Addresses.mem binding pending.store && Machine.Addresses.mem target pending.store)

let check_boundaries () =
  let rejected action = try action (); false with Invalid_argument _ -> true in
  check "Assignment target must be bound" (rejected (fun () ->
    ignore (Machine.initial (assign "free" false_value))));
  check "Runtime continuation literals cannot be source programs" (rejected (fun () ->
    ignore (Machine.initial { label = -1; term = Captured_continuation Machine.Halt })));
  check "Core CEK must identify its language boundary" (rejected (fun () ->
    ignore (Cek.initial Extended_examples.if_false)))

let check_sequence_hygiene () =
  let expression = apply (lambda "discarded"
    (Extended_examples.sequence false_value (variable "discarded"))) Examples.identity in
  List.iter (fun gc -> match Machine.run ~gc expression with
    | Machine.Finished trace ->
        check "Sequencing must not capture the outer discarded binding"
          (to_string (List.hd (List.rev trace)).control = to_string Examples.identity)
    | _ -> failwith "Hygienic sequence must terminate") [false; true]

let run () =
  check_results ();
  let generated = Extended_generated_terms.closed_up_to 5 in
  let programs = generated @ List.map snd Extended_examples.all in
  let policies = [Machine.Bounded 1; Machine.Bounded 2; Machine.Site_based] in
  List.iter (fun expression ->
    List.iter (fun policy ->
      List.iter (fun gc -> check_simulation policy gc expression) [false; true];
      check_collection policy expression) policies;
    List.iter (fun gc -> check_reachability gc expression) [false; true]) programs;
  check_updates ();
  check_gc_roots ();
  check_boundaries ();
  check_sequence_hygiene ();
  Printf.printf "Section 3 passed: %d generated terms (1-5 nodes), %d named examples; 3 policies, GC off/on, simulation and site fixed points.\n"
    (List.length generated) (List.length Extended_examples.all)
