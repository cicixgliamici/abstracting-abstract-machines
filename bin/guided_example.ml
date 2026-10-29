open Aam
open Syntax
module Machine = Store_machine

(* Labels name syntax occurrences, not distinct denotations. Two identity
   lambdas can have different labels while printing the same source syntax. *)
let rec code expression = match expression.term with
  | Lambda _ -> "L" ^ string_of_int expression.label
  | Variable name -> name
  | Apply (operator, operand) -> "(" ^ code operator ^ " " ^ code operand ^ ")"
  | _ -> invalid_arg "The guided renderer expects the pure language"

let rec cek_environment environment =
  let binding (name, Cek.Closure (value, captured)) =
    name ^ "=" ^ code value ^ cek_environment captured in
  "{" ^ String.concat "; " (List.map binding environment) ^ "}"

let rec cek_continuation = function
  | Cek.Empty -> "halt"
  | Cek.Argument (operand, environment, rest) ->
      "Arg(" ^ code operand ^ "," ^ cek_environment environment ^ ") :: " ^ cek_continuation rest
  | Cek.Function (Cek.Closure (value, environment), rest) ->
      "Fun(" ^ code value ^ "," ^ cek_environment environment ^ ") :: " ^ cek_continuation rest

let cek_rule (expression, _, continuation) = match expression.term, continuation with
  | Apply _, _ -> "Evaluate operator; save operand"
  | Variable _, _ -> "Look up lexical closure"
  | Lambda _, Cek.Argument _ -> "Evaluate operand; save function"
  | Lambda _, Cek.Function _ -> "Bind argument; enter function body"
  | Lambda _, Cek.Empty -> "Final value"
  | _ -> invalid_arg "The guided renderer expects a pure CEK state"

let address = function
  | Halt -> "halt"
  | Site (Binding_site label) -> "B" ^ string_of_int label
  | Site (Argument_site label) -> "A" ^ string_of_int label
  | Site (Function_site label) -> "F" ^ string_of_int label
  | _ -> invalid_arg "The guided renderer expects pure site addresses"

let store_environment environment =
  let binding (name, location) = name ^ "=" ^ address location in
  "{" ^ String.concat "; " (List.map binding (Machine.Names.bindings environment)) ^ "}"

let stored_value = function
  | Machine.Closure (value, environment) -> code value ^ store_environment environment
  | _ -> invalid_arg "The displayed binding cell must contain closures"

let cell state location =
  Machine.lookup location state.Machine.store |> Machine.Values.elements
  |> List.map stored_value |> String.concat "; "

let print_aliases program =
  print_endline "| Alias | Labelled function body |";
  print_endline "| --- | --- |";
  let rec visit expression =
    (match expression.term with
     | Lambda (name, body) -> Printf.printf "| `%s` | `lambda %s. %s` |\n" (code expression) name (code body)
     | _ -> ());
    List.iter visit (children expression)
  in visit program

let print_cek trace =
  print_endline "\n## Concrete CEK trace\n";
  print_endline "Each row is a complete CEK state. The last column describes the next transition.\n";
  print_endline "| Step | Control | Environment | Continuation | Next rule |";
  print_endline "| --- | --- | --- | --- | --- |";
  List.iteri (fun index ((expression, environment, continuation) as state) ->
    Printf.printf "| %d | `%s` | `%s` | `%s` | %s |\n" index
      (code expression) (cek_environment environment) (cek_continuation continuation) (cek_rule state)) trace

let print_abstract trace =
  print_endline "\n## Site-allocated prefix without GC\n";
  print_endline "This table projects each state to control, environment, continuation address, and store size.\n";
  print_endline "| Step | Control | Environment | Continuation | Store cells |";
  print_endline "| --- | --- | --- | --- | --- |";
  List.iteri (fun index state ->
    Printf.printf "| %d | `%s` | `%s` | `%s` | %d |\n" index
      (code state.Machine.control) (store_environment state.environment)
      (address state.continuation) (Machine.Addresses.cardinal state.store)) trace

let print_choice observation =
  let state = List.hd (List.rev observation.Guided_example.abstract_prefix) in
  let name = match state.Machine.control.term with
    | Variable name -> name
    | _ -> failwith "Expected variable lookup at the first abstract choice" in
  let location = Machine.Names.find name state.environment in
  Printf.printf "\n## The first abstract choice\n\nReading `%s` consults `%s`, whose joined cell is:\n\n```text\n{%s}\n```\n"
    name (address location) (cell state location);
  print_endline "\nEvery row below is an actual successor, not a hypothetical branch.\n";
  print_endline "| Successor | Control | Captured environment restored | Final? |";
  print_endline "| --- | --- | --- | --- |";
  List.iteri (fun index successor -> Printf.printf "| %d | `%s` | `%s` | %b |\n"
    index (code successor.Machine.control) (store_environment successor.environment)
    (Machine.is_final successor)) observation.abstract_branches;
  Printf.printf "\nThe concrete run returns `%s`; the other final syntax is spurious.\n"
    (let expression, _, _ = List.hd (List.rev observation.concrete_trace) in code expression)

let print_collection observation =
  print_endline "\n## The same program with collection\n";
  print_endline "Each row records the cell read when the shared identity body evaluates `x`.\n";
  print_endline "| Step | Address | Live alternatives |";
  print_endline "| --- | --- | --- |";
  List.iteri (fun index state -> match state.Machine.control.term with
    | Variable "x" ->
        let location = Machine.Names.find "x" state.environment in
        Printf.printf "| %d | `%s` | `{%s}` |\n" index (address location) (cell state location)
    | _ -> ()) observation.Guided_example.collected_trace;
  print_endline "\nComplete reachable graphs, computed without experiment cutoffs:\n";
  print_endline "| GC | Reached states | Final states | Distinct final syntaxes |";
  print_endline "| --- | --- | --- | --- |";
  List.iter (fun (name, reached) ->
    let summary = Analysis_metrics.summarize reached in
    Printf.printf "| %s | %d | %d | %d |\n" name summary.states summary.final_states
      (Analysis_metrics.Terms.cardinal summary.final_terms))
    ["off", observation.uncollected_reached; "on", observation.collected_reached]

let () =
  let observation = Guided_example.observe () in
  let program = label Guided_example.program in
  print_endline "# Generated guided example: CEK execution and abstract branching\n";
  Printf.printf "Source program:\n\n```text\n%s\n```\n\n" (Syntax.to_string program);
  print_endline "Aliases below abbreviate labelled source occurrences; their bodies are not evaluated on definition.\n";
  print_aliases program;
  Printf.printf "\nAbbreviated program: `%s`. `Arg` saves an operand and its environment; `Fun` saves a function closure.\n" (code program);
  print_endline "Environments in braces retain captured environments recursively. `B`, `A`, and `F` denote binding, argument-frame, and function-frame site addresses. GC is off unless stated. Phase is always zero for sites.\n";
  print_cek observation.concrete_trace;
  print_abstract observation.abstract_prefix;
  print_choice observation;
  print_collection observation;
  print_endline "\nThis is one deterministic program with an overapproximating abstract graph. Printed final syntaxes omit captured environments; the tests check the actual successor states and independent pure evaluation."
