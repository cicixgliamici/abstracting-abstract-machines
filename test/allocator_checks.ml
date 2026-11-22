open Aam
module Machine = Store_machine

let check message condition = if not condition then failwith message

let legacy_allocator policy =
  let tick state _ event = match policy with
    | Machine.Bounded size -> min size (state.Machine.allocations +
        (if event = None then 0 else 1))
    | Machine.Site_based -> 0
    | Machine.Fresh -> invalid_arg "Finite policy required" in
  Machine.make_allocator ~alloc:(fun state _ location -> Machine.allocate policy state location) ~tick

let erase_time reached =
  Machine.States.fold (fun state result ->
    Machine.States.add { state with Machine.allocations = 0 } result) reached Machine.States.empty

let check_graphs () =
  let programs = List.map snd Extended_examples.all @
    List.map (fun benchmark -> benchmark.Experiment_examples.program) Experiment_examples.all in
  List.iter (fun program -> List.iter (fun gc ->
    let expected = Machine.analyze ~gc ~policy:Machine.Site_based program in
    let actual = Machine.analyze_with ~gc (legacy_allocator Machine.Site_based) program in
    check "Custom callbacks must reproduce the entire site graph" (Machine.States.equal actual expected);
    (* Alternating time advances even on lookup, branch selection, mutation,
       and jumps. Erasure recovers the original graph because alloc ignores it. *)
    let alternating = Machine.make_allocator
      ~alloc:(fun _ _ location -> Machine.Site location)
      ~tick:(fun state _ _ -> 1 - state.Machine.allocations) in
    let timed = Machine.analyze_with ~gc alternating program in
    check "Finite per-transition time preserves the graph after erasure"
      (Machine.States.equal (erase_time timed) expected);
    Machine.States.iter (fun state ->
      List.iter (fun successor ->
        check "Every ordinary successor advances time, including nonallocating rules"
          (successor.Machine.allocations = 1 - state.Machine.allocations))
        (Machine.successors_with ~gc alternating state)) timed) [false; true]) programs;
  List.iter (fun size -> List.iter (fun gc ->
    let policy = Machine.Bounded size in
    let expected = Machine.analyze ~gc ~policy Examples.identity_application in
    let actual = Machine.analyze_with ~gc (legacy_allocator policy) Examples.identity_application in
    check "Custom callbacks must reproduce the entire pool graph" (Machine.States.equal actual expected))
    [false; true]) [1; 2; 4; 16; 64]

let check_events () =
  let allocations = ref 0 and ticks = ref [] in
  (* Instrumentation observes callback scheduling only; it does not influence
     either callback's return value, which remains deterministic. *)
  let allocator = Machine.make_allocator
    ~alloc:(fun _ _ location -> incr allocations; Machine.Site location)
    ~tick:(fun _ frame event -> ticks := (frame, event) :: !ticks; 0) in
  let initial = Machine.initial Examples.identity_application in
  let next = Machine.successors_with ~gc:true allocator initial in
  check "One allocation and tick per ordinary allocating successor"
    (!allocations = 1 && List.length !ticks = 1);
  let state = List.hd next in
  allocations := 0; ticks := [];
  let operand = List.hd (Machine.successors_with allocator state) in
  check "Argument selection supplies its frame and allocation event"
    (!allocations = 1 && match !ticks with
      | [Some (Machine.Argument _), Some (Machine.Function_site _)] -> true | _ -> false);
  allocations := 0; ticks := [];
  let body = List.hd (Machine.successors_with allocator operand) in
  check "Binding allocates exactly once with the selected function frame"
    (!allocations = 1 && match !ticks with
      | [Some (Machine.Function _), Some (Machine.Binding_site _)] -> true | _ -> false);
  allocations := 0; ticks := [];
  ignore (Machine.successors_with allocator body);
  check "Variable lookup ticks without allocating or selecting a frame"
    (!allocations = 0 && !ticks = [None, None]);
  allocations := 0; ticks := [];
  ignore (Machine.successors_with allocator (Machine.initial Examples.identity));
  check "Final states do not allocate or tick" (!allocations = 0 && !ticks = [])

let check_selected_alternatives () =
  let initial = Machine.initial Examples.identity in
  let pointer = Machine.Pool 1 in
  let store = List.fold_left (fun store (site, operand) ->
    Machine.insert pointer (Machine.Argument (site, operand, Machine.Names.empty, Machine.Halt)) store)
    initial.store [10, Syntax.false_value; 11, Syntax.callcc] in
  let state = { initial with Machine.store; continuation = pointer } in
  let selected = function
    | Some (Machine.Argument (site, _, _, _)) -> site
    | _ -> failwith "Expected the selected argument alternative" in
  let allocator = Machine.make_allocator
    ~alloc:(fun _ frame _ -> Machine.Pool (selected frame))
    ~tick:(fun _ frame _ -> selected frame) in
  let next = Machine.successors_with allocator state in
  check "Allocation and tick must receive each selected alternative"
    (List.sort Int.compare (List.map (fun successor -> successor.Machine.allocations) next) = [10; 11]
    && List.for_all (fun successor ->
      successor.Machine.continuation = Machine.Pool successor.allocations &&
      List.mem successor.allocations [10; 11]) next)

let check_invalid_callbacks () =
  let initial = Machine.initial Examples.identity_application in
  let rejected allocator =
    try ignore (Machine.successors_with allocator initial); false with Invalid_argument _ -> true in
  check "Custom allocation cannot overwrite halt"
    (rejected (Machine.make_allocator ~alloc:(fun _ _ _ -> Machine.Halt) ~tick:(fun _ _ _ -> 0)));
  check "Custom time must be nonnegative"
    (rejected (Machine.make_allocator ~alloc:(fun _ _ location -> Machine.Site location)
      ~tick:(fun _ _ _ -> -1)))

let run () =
  check_graphs ();
  check_events ();
  check_selected_alternatives ();
  check_invalid_callbacks ();
  print_endline "Allocators passed: callback scheduling, selected frames, weak updates, complete graph compatibility, and finite per-transition time with GC off/on."
