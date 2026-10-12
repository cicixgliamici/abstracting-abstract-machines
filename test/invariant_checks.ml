open Aam
module Machine = Store_machine
let check message condition = if not condition then failwith message

let is_frame = function Machine.Closure _ -> false | _ -> true
let is_denoted = function Machine.Closure _ -> true | _ -> false
let has_kind state address predicate =
  Machine.Values.exists predicate (Machine.lookup address state.Machine.store)

let check_continuation state address =
  check "A live continuation needs a frame alternative" (has_kind state address is_frame)

let check_expression state expression environment =
  List.iter (fun name ->
    let address = match Machine.Names.find_opt name environment with
      | Some address -> address | None -> failwith "A free variable needs a binding" in
    check "A live variable needs a denoted-value alternative" (has_kind state address is_denoted))
    (Syntax.free_variables expression);
  match expression.Syntax.term with
  | Syntax.Captured_continuation address -> check_continuation state address
  | _ -> ()

let check_storable state = function
  | Machine.Empty -> ()
  | Machine.Closure (value, environment) ->
      check "A binding must hold a value" (Syntax.is_value value);
      check_expression state value environment
  | Machine.Argument (_, operand, environment, rest) ->
      check_expression state operand environment; check_continuation state rest
  | Machine.Function (value, environment, rest) ->
      check "A function frame must hold an evaluated value" (Syntax.is_value value);
      check_expression state value environment; check_continuation state rest
  | Machine.Conditional_frame (yes, no, environment, rest) ->
      check_expression state yes environment; check_expression state no environment;
      check_continuation state rest
  | Machine.Assignment_frame (target, rest) ->
      check "A pending update needs its denoted target" (has_kind state target is_denoted);
      check_continuation state rest

let role_matches location value = match location, value with
  | Machine.Binding_site _, Machine.Closure _ -> true
  | Machine.Argument_site site, Machine.Argument (origin, _, _, _) -> site = origin
  | Machine.Function_site _, Machine.Function _ -> true
  | Machine.Conditional_site _, Machine.Conditional_frame _ -> true
  | Machine.Assignment_site _, Machine.Assignment_frame _ -> true
  | _ -> false

let check_address policy state address values =
  check "Store cells must be nonempty" (not (Machine.Values.is_empty values));
  match address, policy with
  | Machine.Halt, _ ->
      check "Halt is reserved exclusively for Empty"
        (Machine.Values.equal values (Machine.Values.singleton Machine.Empty))
  | Machine.Concrete (serial, location), Machine.Fresh ->
      check "Concrete serials stay within the allocation counter"
        (serial > 0 && serial <= state.Machine.allocations);
      check "Concrete cells are singletons" (Machine.Values.cardinal values = 1);
      check "Concrete role and cell tag must agree" (Machine.Values.for_all (role_matches location) values)
  | Machine.Pool index, Machine.Bounded size ->
      check "Pooled addresses stay within the configured domain" (index > 0 && index <= size)
  | Machine.Site location, Machine.Site_based ->
      check "Site addresses keep allocation roles separate"
        (Machine.Values.for_all (role_matches location) values)
  | _ -> failwith "Store address family must agree with allocation policy"

(* The invariant deliberately checks FV support, not every environment entry:
   collection may leave unused entries dangling while all observable edges live. *)
let check_state policy state =
  (match policy with
   | Machine.Fresh -> check "Concrete allocation counter must be nonnegative" (state.Machine.allocations >= 0)
   | Machine.Bounded size -> check "Pooled phase must be capped"
       (state.allocations >= 0 && state.allocations <= size)
   | Machine.Site_based -> check "Site phase is a singleton" (state.allocations = 0));
  check_expression state state.control state.environment;
  check_continuation state state.continuation;
  Machine.Addresses.iter (fun address values ->
    check_address policy state address values;
    Machine.Values.iter (check_storable state) values) state.store

let trace gc expression = match Machine.run ~gc ~fuel:80 expression with
  | Machine.Finished states | Machine.Fuel_exhausted states | Machine.Stuck states -> states

let check_concrete gc expression =
  let rec visit = function
    | [] -> ()
    | state :: rest ->
        check_state Machine.Fresh state;
        let collected = Machine.collect state in
        check "GC restriction is idempotent" (Machine.compare_state collected (Machine.collect collected) = 0);
        check "GC retains its allocation phase" (collected.allocations = state.allocations);
        List.iter (fun next ->
          let expected = Machine.collect next in
          let actual = Machine.successors ~gc:true Machine.Fresh collected in
          check "Concrete collection must commute with an ordinary step plus collection"
            (List.exists (fun next -> Machine.compare_state expected next = 0) actual))
          (Machine.successors Machine.Fresh state);
        visit rest
  in visit (trace gc expression)

let check_abstract gc expression =
  let policy = Machine.Site_based in
  Machine.analyze ~gc ~policy expression |> Machine.States.iter (check_state policy)

(* Each pure administrative CEK step decreases this natural-number measure by
   one. Lambda bodies contribute zero because weak evaluation does not enter them. *)
let rec weak_size expression = match expression.Syntax.term with
  | Syntax.Variable _ -> 1
  | Syntax.Lambda _ -> 0
  | Syntax.Apply (operator, operand) -> 2 + weak_size operator + weak_size operand
  | _ -> failwith "Weak-work measure covers the pure subset"

let rec pending_work = function
  | Cek.Empty -> 0
  | Cek.Argument (operand, _, rest) -> weak_size operand + 1 + pending_work rest
  | Cek.Function (_, rest) -> pending_work rest

let check_work_measure expression =
  let rec visit remaining ((control, _, continuation) as state) =
    match Cek.step state with
    | Some ((next_control, _, next_continuation) as next) when remaining > 0 ->
        (match control.Syntax.term, continuation with
         | Syntax.Lambda _, Cek.Function _ -> ()
         | _ -> check "Administrative work must strictly decrease by one"
             (weak_size next_control + pending_work next_continuation =
                weak_size control + pending_work continuation - 1));
        visit (remaining - 1) next
    | _ -> ()
  in visit 120 (Cek.initial expression)

let run () =
  List.iter (fun (_, expression) ->
    check_work_measure expression;
    List.iter (fun gc -> check_concrete gc expression) [false; true]) Reference_examples.all;
  List.iter (fun (_, expression) -> List.iter (fun gc ->
    check_concrete gc expression; check_abstract gc expression) [false; true]) Extended_examples.all;
  let tiny = Extended_generated_terms.closed_up_to 4 in
  List.iter (fun expression -> List.iter (fun gc ->
    List.iter (fun policy ->
      Machine.analyze ~gc ~policy expression |> Machine.States.iter (check_state policy))
      [Machine.Bounded 1; Machine.Bounded 2; Machine.Site_based]) [false; true]) tiny;
  Printf.printf "Invariant audit passed: %d named inputs and %d tiny terms; supported edges, roles, singleton cells, allocation phases, GC commutation, administrative descent.\n"
    (List.length Reference_examples.all + List.length Extended_examples.all) (List.length tiny)
