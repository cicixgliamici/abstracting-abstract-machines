open Aam
open Syntax
module Reference = Extended_reference
module Machine = Store_machine

type observation = Value of string | Stuck | Exhausted

let check message condition = if not condition then failwith message

let reference_outcome program =
  match Reference.run ~fuel:4000 (Reference.of_syntax program) with
  | Reference.Finished (value, _) -> Value (Reference.value_syntax value)
  | Reference.Stuck -> Stuck
  | Reference.Fuel_exhausted -> Exhausted

let machine_outcome gc program =
  match Machine.run ~gc ~fuel:4000 program with
  | Machine.Finished trace -> Value (to_string (List.hd (List.rev trace)).control)
  | Machine.Stuck _ -> Stuck
  | Machine.Fuel_exhausted _ -> Exhausted

(* These finite source contexts exercise returned environments and control
   without trying to unfold cyclic heaps or compare OCaml functions. *)
let contexts = [
  "result", (fun program -> program);
  "apply false", (fun program -> apply program false_value);
  "apply identity", (fun program -> apply program Examples.identity);
  "apply twice", (fun program -> apply (apply program false_value) Examples.identity);
  "conditional", (fun program -> conditional program false_value Examples.identity);
  "call/cc receiver", (fun program -> apply callcc program)]

let compare_program name program =
  let expected = reference_outcome program in
  List.iter (fun gc ->
    let actual = machine_outcome gc program in
    check ("Extended oracle disagreement or insufficient budget: " ^ name ^
      ", GC=" ^ string_of_bool gc ^ ", program=" ^ to_string program)
      (actual = expected)) [false; true];
  expected <> Exhausted

let check_named_results () =
  List.iter (fun (name, program, expected) ->
    check ("Independent expected value: " ^ name)
      (reference_outcome program = Value (to_string expected))) Extended_examples.terminating;
  List.iter (fun program ->
    check "Independent control result must be a continuation"
      (reference_outcome program = Value "#<continuation>"))
    [Extended_examples.returned_continuation; Extended_examples.callcc_continuation];
  List.iter (fun program ->
    check "Independent invalid application must be stuck" (reference_outcome program = Stuck))
    [Extended_examples.invalid_false_application; Extended_examples.invalid_callcc_argument;
     apply callcc callcc]

let check_observations () =
  (* The same returned lambda code can close over different cells. Applications
     must distinguish them; rendering the returned lambda alone cannot. *)
  let captured value = apply (lambda "cell" (lambda "unused" (variable "cell"))) value in
  List.iter (fun (value, expected) ->
    let program = apply (captured value) Examples.identity in
    check "Closure application must expose its captured value"
      (reference_outcome program = Value expected);
    ignore (compare_program "captured value observation" program))
    [false_value, "#f"; Examples.constant, to_string Examples.constant];
  let cyclic_read = apply Extended_examples.assignment_cycle Examples.identity in
  check "Cyclic mutable closure remains callable"
    (reference_outcome cyclic_read = Value "(lambda unused. x)");
  ignore (compare_program "cyclic closure observation" cyclic_read)

let check_boundaries () =
  let rejected action = try action (); false with Invalid_argument _ -> true in
  check "Reference independently rejects open terms"
    (rejected (fun () -> ignore (Reference.run (Reference.Assign ("free", Reference.False)))));
  check "Reference rejects negative fuel"
    (rejected (fun () -> ignore (Reference.run ~fuel:(-1) Reference.False)));
  check "Adapter rejects runtime literals even under lambdas"
    (rejected (fun () -> ignore (Reference.of_syntax
      (lambda "x" { label = -1; term = Captured_continuation Machine.Halt }))));
  check "A source visit consumes reference fuel"
    (match Reference.run ~fuel:0 Reference.False with Reference.Fuel_exhausted -> true | _ -> false);
  check "A false value completes after one visit"
    (match Reference.run ~fuel:1 Reference.False with Reference.Finished _ -> true | _ -> false);
  check "Divergent sample exhausts its budget without a divergence claim"
    (reference_outcome Examples.omega = Exhausted)

let run () =
  check_named_results ();
  check_observations ();
  check_boundaries ();
  let generated = Extended_generated_terms.closed_up_to 5 in
  let programs = List.mapi (fun index program -> "generated " ^ string_of_int index, program) generated
    @ Extended_examples.all
    @ List.map (fun benchmark -> benchmark.Experiment_examples.name, benchmark.program)
        Experiment_examples.all in
  let assessed = ref 0 and exhausted = ref 0 in
  List.iter (fun (name, program) -> List.iter (fun (context_name, context) ->
    if compare_program (name ^ ": " ^ context_name) (context program) then incr assessed
    else incr exhausted) contexts) programs;
  Printf.printf "Extended reference passed: %d generated terms, %d named/corpus entries, %d contexts, GC off/on; %d terminal observations, %d jointly exhausted observations (unassessed).\n"
    (List.length generated) (List.length programs - List.length generated)
    (List.length contexts) !assessed !exhausted
