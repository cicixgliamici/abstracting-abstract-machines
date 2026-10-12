open Aam
module Reference = Reference_semantics
module Reify = Closure_reification
module Machine = Store_machine
let check message condition = if not condition then failwith message
let equivalent = Reference.alpha_equivalent

let check_substitution () =
  let open Reference in
  let replacement = Variable "y" in
  let result = substitute "x" replacement (Lambda ("y", Variable "x")) in
  check "Substitution must preserve the free replacement variable"
    (equivalent result (Lambda ("fresh", Variable "y"))
     && Names.equal (free_variables result) (Names.singleton "y"));
  let nested = Lambda ("y", Apply (Variable "x", Lambda ("y_0", Variable "y"))) in
  check "Fresh renaming must avoid inner bound names"
    (equivalent (substitute "x" replacement nested)
      (Lambda ("outer", Apply (Variable "y", Lambda ("inner", Variable "outer")))));
  let shadowed = Lambda ("y", Apply (Variable "x", Lambda ("y", Variable "y"))) in
  check "Renaming must stop at a shadowing binder"
    (equivalent (substitute "x" replacement shadowed)
      (Lambda ("fresh", Apply (Variable "y", Lambda ("y", Variable "y")))));
  let blocked = Lambda ("x", Variable "x") in
  check "A binder must block substitution for its own name"
    (substitute "x" replacement blocked = blocked);
  let untouched = Lambda ("y", Variable "z") in
  check "An absent target must not cause unnecessary renaming"
    (substitute "x" replacement untouched = untouched)

let check_alpha_equivalence () =
  let open Reference in
  check "Alpha comparison must respect nearest-binder shadowing"
    (equivalent (Lambda ("x", Lambda ("x", Variable "x")))
      (Lambda ("a", Lambda ("b", Variable "b"))));
  check "Different binder references must remain different"
    (not (equivalent (Lambda ("x", Lambda ("x", Variable "x")))
      (Lambda ("a", Lambda ("b", Variable "a")))));
  check "Alpha comparison must preserve free names"
    (not (equivalent (Lambda ("x", Variable "y")) (Lambda ("z", Variable "z"))))

let check_free_variable_property () =
  let open Reference in
  let replacements = [Variable "y"; Lambda ("y", Variable "x");
    Apply (Variable "x", Variable "z")] in
  let inputs = List.init 5 (fun offset -> Generated_terms.terms (offset + 1) ["x"; "y"])
    |> List.concat |> List.map of_syntax in
  List.iter (fun term -> List.iter (fun name -> List.iter (fun replacement ->
    let free = free_variables term in
    let expected = Names.remove name free in
    let expected = if Names.mem name free then Names.union expected (free_variables replacement)
      else expected in
    check "Substitution must satisfy the free-variable law"
      (Names.equal expected (free_variables (substitute name replacement term)))) replacements)
    ["x"; "y"]) inputs;
  List.length inputs * 2 * List.length replacements

let check_evaluation_contexts () =
  let open Reference in
  let identity = Lambda ("i", Variable "i") in
  let constant = Lambda ("a", Lambda ("b", Variable "a")) in
  let program = Apply (Apply (identity, constant), Apply (identity, identity)) in
  check "Evaluation contexts must reduce the operator before the operand"
    (match step program with
     | Some next -> equivalent next (Apply (constant, Apply (identity, identity)))
     | None -> false);
  check "Evaluation contexts then reduce the operand"
    (match step (Apply (constant, Apply (identity, identity))) with
     | Some next -> equivalent next (Apply (constant, identity))
     | None -> false);
  check "Reduction must stop under a lambda"
    (step (Lambda ("unused", Apply (identity, identity))) = None)

let beta_transition (control, _, continuation) = match control.Syntax.term, continuation with
  | Syntax.Lambda _, Cek.Function _ -> true
  | _ -> false

(* Reconstruct the complete program, including pending contexts, at each state.
   Administrative machine steps preserve that term. A function-application step
   must match exactly one independent beta-value reduction, including Omega's
   self-loop. Machine transition counts are not compared with beta-step counts. *)
let check_projection gc expression =
  let rec visit remaining reference cek stored =
    check "CEK program projection differs from reduction semantics"
      (equivalent reference (Reify.cek_state cek));
    check "CESK program projection differs from reduction semantics"
      (equivalent reference (Reify.store_state stored));
    match Cek.step cek, Machine.successors ~gc Machine.Fresh stored with
    | None, [] ->
        check "Reference must also be a value at machine halting" (Reference.step reference = None);
        check "Reified CEK final value must equal the reference"
          (equivalent reference (Reify.cek_final cek));
        check "Reified CESK final value must equal the reference"
          (equivalent reference (Reify.store_final stored))
    | Some next, [stored_next] when remaining > 0 ->
        let reference_next = if beta_transition cek then
          match Reference.step reference with
          | Some next -> next | None -> failwith "Machine beta step has no reference reduction"
          else reference in
        visit (remaining - 1) reference_next next stored_next
    | Some _, [_] -> () (* A checked prefix is not a proof of divergence. *)
    | _ -> failwith "Pure machines disagree on progress"
  in visit 120 (Reference.of_syntax expression) (Cek.initial expression) (Machine.initial expression)

let check_terminating_results expression =
  match Reference.run ~fuel:200 (Reference.of_syntax expression), Cek.run expression,
    Machine.run expression, Machine.run ~gc:true expression with
  | Reference.Finished reference, Cek.Finished cek,
      Machine.Finished stored, Machine.Finished collected ->
      let expected = List.hd (List.rev reference) in
      check "Terminating evaluator results must be alpha equivalent"
        (equivalent expected (Reify.cek_final (List.hd (List.rev cek)))
         && equivalent expected (Reify.store_final (List.hd (List.rev stored)))
         && equivalent expected (Reify.store_final (List.hd (List.rev collected))))
  | _ -> failwith "Generated-term evaluation did not finish within verification budgets"

let check_reification () =
  let expected = Reference.Lambda ("y", Reference.Lambda ("x", Reference.Variable "x")) in
  (match Cek.run Examples.returned_closure with
   | Cek.Finished trace ->
       let state = List.hd (List.rev trace) in
       let control, _, _ = state in
       check "Raw final code must expose why closure reification matters"
         (not (equivalent expected (Reference.of_syntax control)));
       check "Closure denotation must insert the captured identity"
         (equivalent expected (Reify.cek_final state))
   | _ -> failwith "Captured closure must terminate");
  let state = Machine.initial Examples.identity in
  let missing = Machine.Concrete (99, Machine.Binding_site 99) in
  let unused = { state with environment = Machine.Names.singleton "x" missing } in
  check "Bound variables must not dereference unused GC environment entries"
    (equivalent (Reify.store_final unused) (Reference.of_syntax Examples.identity));
  let rejected action = try action (); false with Invalid_argument _ -> true in
  let invalid = { state with control = Syntax.label (Syntax.lambda "x" (Syntax.variable "free")) } in
  check "A live missing binding must be rejected" (rejected (fun () -> ignore (Reify.store_final invalid)));
  let address = Machine.Concrete (1, Machine.Binding_site 0) in
  let value = Syntax.label (Syntax.lambda "unused" (Syntax.variable "self")) in
  let environment = Machine.Names.singleton "self" address in
  let cyclic = { state with control = value; environment;
    store = Machine.insert address (Machine.Closure (value, environment)) state.store } in
  check "Reification must reject cyclic value graphs"
    (rejected (fun () -> ignore (Reify.store_final cyclic)));
  let joined = { cyclic with store = Machine.insert address
    (Machine.Closure (state.control, Machine.Names.empty)) cyclic.store } in
  check "Reification must not select an arbitrary value from a joined cell"
    (rejected (fun () -> ignore (Reify.store_final joined)))

let check_boundaries () =
  let rejected action = try action (); false with Invalid_argument _ -> true in
  check "Reference must reject open programs" (rejected (fun () ->
    ignore (Reference.run (Reference.Variable "free"))));
  check "Reference must reject Section 3 input" (rejected (fun () ->
    ignore (Reference.of_syntax Syntax.false_value)));
  check "Negative reference fuel must be rejected" (rejected (fun () ->
    ignore (Reference.run ~fuel:(-1) (Reference.of_syntax Examples.identity))));
  (match Reference.run ~fuel:0 (Reference.of_syntax Examples.identity) with
   | Reference.Finished [_] -> () | _ -> failwith "A value needs no reduction fuel");
  (match Reference.run ~fuel:0 (Reference.of_syntax Examples.identity_application) with
   | Reference.Fuel_exhausted [_] -> () | _ -> failwith "A redex needs reduction fuel");
  List.iter (fun expression -> match Reference.run ~fuel:30 (Reference.of_syntax expression) with
    | Reference.Fuel_exhausted _ -> () | _ -> failwith "CBV divergent operand must exhaust fuel")
    [Examples.omega; Reference_examples.divergent_operand]

let run () =
  check_substitution ();
  check_alpha_equivalence ();
  check_evaluation_contexts ();
  let property_cases = check_free_variable_property () in
  let generated = Generated_terms.closed_up_to 8 in
  List.iter (fun expression ->
    check_terminating_results expression;
    List.iter (fun gc -> check_projection gc expression) [false; true]) generated;
  List.iter (fun (_, expression) ->
    List.iter (fun gc -> check_projection gc expression) [false; true]) Reference_examples.all;
  check_reification ();
  check_boundaries ();
  Printf.printf "Reference passed: %d closed terms (1-8 nodes), %d named examples, %d substitution-law cases; beta-step projection and reified final values.\n"
    (List.length generated) (List.length Reference_examples.all) property_cases
