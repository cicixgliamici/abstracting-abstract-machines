module Machine = Store_machine
module Terms = Set.Make (String)
type t = { states : int; final_states : int; final_terms : Terms.t;
           max_addresses : int; max_values : int }

(* Syntax counts omit labels, captured environments, and continuation identity. Store peaks refer
   to reached states; temporary stores just before collection are not counted. *)
let summarize reached =
  let initial = { states = Machine.States.cardinal reached; final_states = 0;
    final_terms = Terms.empty; max_addresses = 0; max_values = 0 } in
  Machine.States.fold (fun state metrics ->
    let final = Machine.is_final state in
    let values = Machine.Addresses.fold (fun _ cell count ->
      count + Machine.Values.cardinal cell) state.Machine.store 0 in
    { metrics with
      final_states = metrics.final_states + (if final then 1 else 0);
      final_terms = (if final then Terms.add (Syntax.to_string state.control) metrics.final_terms
        else metrics.final_terms);
      max_addresses = max metrics.max_addresses (Machine.Addresses.cardinal state.store);
      max_values = max metrics.max_values values }) reached initial
