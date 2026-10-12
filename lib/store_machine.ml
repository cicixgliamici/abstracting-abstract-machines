open Syntax
module Names = Map.Make (String)

(* Disjoint site roles separate bindings from all continuation-frame kinds.
   Concrete addresses retain their origin solely to make alpha executable. *)
type location = Syntax.location = Binding_site of int | Argument_site of int | Function_site of int
  | Conditional_site of int | Assignment_site of int
type address = Syntax.address = Halt | Concrete of int * location | Pool of int | Site of location
module Addresses = Map.Make (struct type t = address let compare = compare end)
module Address_set = Set.Make (struct type t = address let compare = compare end)
type environment = address Names.t
(* A denoted value is paired with its lexical environment. Closure also carries
   false, call/cc, and captured-continuation values; these have no free variables. *)
type storable =
  | Closure of expression * environment
  | Empty
  | Argument of int * expression * environment * address
  | Function of expression * environment * address
  | Conditional_frame of expression * expression * environment * address
  | Assignment_frame of address * address
(* Map insertion order must not distinguish equal closures or machine states.
   Canonical bindings keep storable comparison independent of tree shape. *)
let compare_storable left right = match left, right with
  | Closure (value, environment), Closure (other, captured) ->
      compare (value, Names.bindings environment) (other, Names.bindings captured)
  | Argument (site, value, environment, rest), Argument (other_site, other, captured, tail) ->
      compare (site, value, Names.bindings environment, rest)
        (other_site, other, Names.bindings captured, tail)
  | Function (value, environment, rest), Function (other, captured, tail) ->
      compare (value, Names.bindings environment, rest)
        (other, Names.bindings captured, tail)
  | Conditional_frame (yes, no, environment, rest),
      Conditional_frame (other_yes, other_no, captured, tail) ->
      compare (yes, no, Names.bindings environment, rest)
        (other_yes, other_no, Names.bindings captured, tail)
  | _ -> compare left right
module Values = Set.Make (struct type t = storable let compare = compare_storable end)
type store = Values.t Addresses.t
type state = { control : expression; environment : environment;
               store : store; continuation : address; allocations : int }
let compare_state left right =
  let control = compare (left.control, left.continuation, left.allocations)
    (right.control, right.continuation, right.allocations) in
  if control <> 0 then control else
    let environment = Names.compare compare left.environment right.environment in
    if environment <> 0 then environment else
      Addresses.compare Values.compare left.store right.store
module States = Set.Make (struct type t = state let compare = compare_state end)
type allocation = Fresh | Bounded of int | Site_based
type execution = Finished of state list | Fuel_exhausted of state list | Stuck of state list

let validate_policy = function
  | Bounded size when size < 1 -> invalid_arg "Address pool must be positive"
  | _ -> ()

let lookup address store =
  match Addresses.find_opt address store with
  | None -> Values.empty
  | Some values -> values

(* Joining rather than overwriting is essential when abstract addresses collide. *)
let insert address value store =
  Addresses.add address (Values.add value (lookup address store)) store

let initial expression =
  require_closed expression;
  { control = label expression; environment = Names.empty;
    store = insert Halt Empty Addresses.empty; continuation = Halt; allocations = 0 }

(* Section 4 restricts environment roots to the expression's free variables.
   Keeping every captured binding would retain garbage and hide GC's benefit. *)
let expression_addresses expression environment =
  let bindings = List.fold_left (fun addresses name ->
    Address_set.add (Names.find name environment) addresses)
    Address_set.empty (free_variables expression) in
  match expression.term with
  | Captured_continuation address -> Address_set.add address bindings
  | _ -> bindings

let storable_addresses = function
  | Empty -> Address_set.empty
  | Closure (value, environment) -> expression_addresses value environment
  | Argument (_, operand, environment, rest) ->
      Address_set.add rest (expression_addresses operand environment)
  | Function (value, environment, rest) ->
      Address_set.add rest (expression_addresses value environment)
  | Conditional_frame (yes, no, environment, rest) ->
      Address_set.add rest (Address_set.union (expression_addresses yes environment)
        (expression_addresses no environment))
  | Assignment_frame (target, rest) -> Address_set.of_list [target; rest]

(* Traverse every value in every reachable cell, including continuation cycles.
   Visited addresses give the least fixed point without recursively unfolding
   the store. The same graph traversal serves concrete and abstract stores. *)
let live_addresses state =
  let roots = Address_set.add state.continuation
    (expression_addresses state.control state.environment) in
  let rec visit pending visited = match pending with
    | [] -> visited
    | address :: rest when Address_set.mem address visited -> visit rest visited
    | address :: rest ->
        let children = Values.fold (fun value children ->
          Address_set.union (storable_addresses value) children)
          (lookup address state.store) Address_set.empty in
        visit (Address_set.elements children @ rest) (Address_set.add address visited)
  in visit (Address_set.elements roots) Address_set.empty

(* Figure 7 changes only the store. Unused environment entries may now point
   to removed cells; their free-variable restriction is what makes this safe.
   Allocation phase is preserved so fresh addresses remain fresh after GC. *)
let collect state =
  let live = live_addresses state in
  { state with store = Addresses.filter (fun address _ -> Address_set.mem address live) state.store }

(* Allocation phase is explicit, not inferred from store size: adding possible
   cells to an approximating store must not change which pool address is chosen. *)
let allocate policy state location =
  match policy with
  | Fresh -> Concrete (state.allocations + 1, location)
  | Site_based -> Site location
  | Bounded size ->
      validate_policy policy;
      let used = state.allocations in
      (* This deliberately coarse policy fills the pool, then reuses slot one.
         Its capped phase is part of the state and is preserved by collection. *)
      Pool (if used < size then used + 1 else 1)

let next_phase policy state = match policy with
  | Fresh -> state.allocations + 1
  | Bounded size -> min size (state.allocations + 1)
  | Site_based -> 0

let push policy state location control environment continuation value =
  let address = allocate policy state location in
  { control; environment;
    allocations = next_phase policy state;
    continuation = (match continuation with Some rest -> rest | None -> address);
    store = insert address value state.store }

let bind_value policy state function_value environment rest value captured =
  match function_value.term with
  | Lambda (name, body) ->
      let location = Binding_site function_value.label in
      let address = allocate policy state location in
      [push policy state location body (Names.add name address environment)
         (Some rest) (Closure (value, captured))]
  | _ -> []

let capture state rest = { label = state.control.label; term = Captured_continuation rest }

(* call/cc receives either a lambda or an already captured continuation. Capture
   the caller's remaining continuation, excluding the primitive's call frame. *)
let apply_callcc policy state rest = match state.control.term with
  | Lambda _ -> bind_value policy state state.control state.environment rest
      (capture state rest) Names.empty
  | Captured_continuation target ->
      [{ state with control = capture state rest; environment = Names.empty; continuation = target }]
  | _ -> []

let apply_function policy state value environment rest = match value.term with
  | Lambda _ -> bind_value policy state value environment rest state.control state.environment
  | Callcc -> apply_callcc policy state rest
  | Captured_continuation target ->
      (* The current control is the evaluated argument. A jump retains that
         value and the current store, so earlier mutations survive reentry. *)
      [{ state with continuation = target }]
  | _ -> [] (* Applying false, or call/cc to false, is a stuck computation. *)

(* Figure 6 returns the OLD value of the binding. Concrete mutation overwrites
   its unique cell; abstract mutation joins, since aliases may share an address.
   Preserve the old value's lexical environment when returning a closure. *)
let mutate policy state target rest =
  let value = Closure (state.control, state.environment) in
  let store = match policy with
    | Fresh -> Addresses.add target (Values.singleton value) state.store
    | Bounded _ | Site_based -> insert target value state.store in
  lookup target state.store |> Values.elements |> List.filter_map (function
    | Closure (control, environment) -> Some { state with control; environment; store; continuation = rest }
    | _ -> None)

let continue policy state = function
  | Argument (site, operand, environment, rest) ->
      [push policy state (Function_site site) operand environment None
         (Function (state.control, state.environment, rest))]
  | Function (value, environment, rest) -> apply_function policy state value environment rest
  | Conditional_frame (yes, no, environment, rest) ->
      let control = if state.control.term = False then no else yes in
      [{ state with control; environment; continuation = rest }]
  | Assignment_frame (target, rest) -> mutate policy state target rest
  | Empty | Closure _ -> []

(* Figures 2, 4, and 6 share their control rules. Frame allocation uses the
   application site; binding allocation uses the applied lambda's binder site. *)
let raw_successors policy state =
  validate_policy policy;
  match state.control.term with
  | Variable name ->
      lookup (Names.find name state.environment) state.store
      |> Values.elements |> List.filter_map (function
          | Closure (control, environment) -> Some { state with control; environment }
          | _ -> None)
  | Apply (operator, operand) ->
      [push policy state (Argument_site state.control.label) operator
         state.environment None
         (Argument (state.control.label, operand, state.environment, state.continuation))]
  | Conditional (condition, yes, no) ->
      [push policy state (Conditional_site state.control.label) condition state.environment None
         (Conditional_frame (yes, no, state.environment, state.continuation))]
  | Assign (name, value) ->
      [push policy state (Assignment_site state.control.label) value state.environment None
         (Assignment_frame (Names.find name state.environment, state.continuation))]
  | Lambda _ | False | Callcc | Captured_continuation _ ->
      lookup state.continuation state.store |> Values.elements
      |> List.concat_map (continue policy state)

(* Deterministic scheduling follows Section 4: one ordinary transition followed
   by collection. Optional standalone GC transitions would also explore paths
   with no collection and would lose the precision improvement. *)
let successors ?(gc = false) policy state =
  let next = raw_successors policy state in
  if gc then List.map collect next else next

let is_final state =
  is_value state.control && Values.mem Empty (lookup state.continuation state.store)

let is_stuck policy state = not (is_final state) && successors policy state = []

let run ?(fuel = 1000) ?(gc = false) expression =
  if fuel < 0 then invalid_arg "Fuel must be nonnegative";
  let rec visit remaining reversed state =
    match successors ~gc Fresh state with
    | [] when is_final state -> Finished (List.rev (state :: reversed))
    | [] -> Stuck (List.rev (state :: reversed))
    | [_] when remaining = 0 -> Fuel_exhausted (List.rev (state :: reversed))
    | [next] -> visit (remaining - 1) (state :: reversed) next
    | _ -> failwith "Invariant: concrete execution must be deterministic"
  in visit fuel [] (initial expression)

(* No global store widening: visited states include their own stores. Exhausting
   the queue establishes successor closure. Resource cutoffs belong to the
   separate Experiment_analysis explorer, not this complete analysis API. *)
let analyze ?(addresses = 1) ?policy ?(gc = false) expression =
  let policy = match policy with None -> Bounded addresses | Some policy -> policy in
  validate_policy policy;
  if policy = Fresh then invalid_arg "Analysis requires finite allocation";
  let queue = Queue.create () in
  let start = initial expression in
  let reached = ref (States.singleton start) in
  Queue.add start queue;
  while not (Queue.is_empty queue) do
    let state = Queue.take queue in
    List.iter (fun next ->
      if not (States.mem next !reached) then begin
        reached := States.add next !reached;
        Queue.add next queue
      end) (successors ~gc policy state)
  done;
  !reached

let abstract_address policy = function
  | Halt -> Halt
  | Concrete (serial, location) ->
      (match policy with
       | Site_based -> Site location
       | Bounded size -> Pool (if serial <= size then serial else 1)
       | Fresh -> invalid_arg "Alpha requires abstract allocation")
  | _ -> invalid_arg "Alpha expects concrete addresses"

let abstract_value map_address = function
  | Closure (value, environment) ->
      Closure (map_addresses map_address value, Names.map map_address environment)
  | Empty -> Empty
  | Argument (site, value, environment, rest) ->
      Argument (site, map_addresses map_address value, Names.map map_address environment, map_address rest)
  | Function (value, environment, rest) ->
      Function (map_addresses map_address value, Names.map map_address environment, map_address rest)
  | Conditional_frame (yes, no, environment, rest) ->
      Conditional_frame (map_addresses map_address yes, map_addresses map_address no,
        Names.map map_address environment, map_address rest)
  | Assignment_frame (target, rest) -> Assignment_frame (map_address target, map_address rest)

(* Alpha merges all concrete cells with the same abstract image. Allocation
   provenance makes this definition independent of a test's execution history. *)
let abstract_state policy state =
  validate_policy policy;
  let map_address = abstract_address policy in
  let store = Addresses.fold (fun address values result ->
    Values.fold (fun value result ->
      insert (map_address address) (abstract_value map_address value) result)
      values result) state.store Addresses.empty in
  { store; control = map_addresses map_address state.control;
    environment = Names.map map_address state.environment;
    continuation = map_address state.continuation;
    allocations = (match policy with Bounded size -> min size state.allocations
      | Site_based -> 0 | Fresh -> invalid_arg "Alpha requires abstract allocation") }

let approximates lower upper =
  lower.control = upper.control && Names.equal (=) lower.environment upper.environment
  && lower.continuation = upper.continuation
  && lower.allocations = upper.allocations
  && Addresses.for_all (fun address values ->
       Values.subset values (lookup address upper.store)) lower.store
