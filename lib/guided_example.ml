module Machine = Store_machine

type observation = {
  concrete_trace : Cek.state list;
  abstract_prefix : Machine.state list;
  abstract_branches : Machine.state list;
  collected_trace : Machine.state list;
  uncollected_reached : Machine.States.t;
  collected_reached : Machine.States.t;
}

let program = Examples.repeated_calls

let concrete_trace () = match Cek.run ~fuel:100 program with
  | Cek.Finished trace -> trace
  | Cek.Fuel_exhausted _ -> failwith "Guided example must finish within its concrete budget"

(* Follow actual successors only until the first choice. Selecting an arbitrary
   branch would hide where deterministic execution becomes an abstract graph. *)
let prefix_until_choice ~gc =
  let rec visit fuel reversed state =
    let next = Machine.successors ~gc Machine.Site_based state
      |> Machine.States.of_list |> Machine.States.elements in
    match next with
    | [successor] when fuel > 0 -> visit (fuel - 1) (state :: reversed) successor
    | [_] -> failwith "Guided prefix exceeded its display budget"
    | _ -> List.rev (state :: reversed), next
  in
  visit 100 [] (Machine.initial program)

let observe () =
  let abstract_prefix, abstract_branches = prefix_until_choice ~gc:false in
  let collected_trace, remaining = prefix_until_choice ~gc:true in
  if remaining <> [] then failwith "Collected guided example must remain deterministic";
  { concrete_trace = concrete_trace (); abstract_prefix; abstract_branches;
    collected_trace;
    uncollected_reached = Machine.analyze ~policy:Machine.Site_based program;
    collected_reached = Machine.analyze ~policy:Machine.Site_based ~gc:true program }
