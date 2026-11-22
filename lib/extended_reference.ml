(* This direct CPS evaluator owns its syntax and binding heap. Continuations
   are OCaml functions, never addresses or frames from Store_machine. *)
type term =
  | Variable of string
  | Lambda of string * term
  | Apply of term * term
  | False
  | Callcc
  | Conditional of term * term * term
  | Assign of string * term

type environment = (string * int) list
type value =
  | Closure of string * term * environment
  | False_value
  | Callcc_value
  | Continuation of (int -> memory -> value -> execution)
and memory = { next_binding : int; bindings : (int * value) list }
and execution = Finished of value * memory | Stuck | Fuel_exhausted

module Names = Set.Make (String)

let rec of_syntax expression = match expression.Syntax.term with
  | Syntax.Variable name -> Variable name
  | Syntax.Lambda (name, body) -> Lambda (name, of_syntax body)
  | Syntax.Apply (operator, operand) -> Apply (of_syntax operator, of_syntax operand)
  | Syntax.False -> False
  | Syntax.Callcc -> Callcc
  | Syntax.Conditional (condition, yes, no) ->
      Conditional (of_syntax condition, of_syntax yes, of_syntax no)
  | Syntax.Assign (name, body) -> Assign (name, of_syntax body)
  | Syntax.Captured_continuation _ -> invalid_arg "Runtime values are not source terms"

let rec free_variables = function
  | Variable name -> Names.singleton name
  | Lambda (name, body) -> Names.remove name (free_variables body)
  | Apply (operator, operand) -> Names.union (free_variables operator) (free_variables operand)
  | False | Callcc -> Names.empty
  | Conditional (condition, yes, no) ->
      Names.union (free_variables condition) (Names.union (free_variables yes) (free_variables no))
  | Assign (name, body) -> Names.add name (free_variables body)

let rec to_string = function
  | Variable name -> name
  | Lambda (name, body) -> "(lambda " ^ name ^ ". " ^ to_string body ^ ")"
  | Apply (operator, operand) -> "(" ^ to_string operator ^ " " ^ to_string operand ^ ")"
  | False -> "#f"
  | Callcc -> "call/cc"
  | Conditional (condition, yes, no) ->
      "(if " ^ to_string condition ^ " " ^ to_string yes ^ " " ^ to_string no ^ ")"
  | Assign (name, body) -> "(set! " ^ name ^ " " ^ to_string body ^ ")"

let value_syntax = function
  | Closure (name, body, _) -> to_string (Lambda (name, body))
  | False_value -> "#f"
  | Callcc_value -> "call/cc"
  | Continuation _ -> "#<continuation>"

let bind name value environment memory =
  let address = memory.next_binding in
  (name, address) :: List.remove_assoc name environment,
  { next_binding = address + 1; bindings = (address, value) :: memory.bindings }

let read name environment memory =
  List.assoc (List.assoc name environment) memory.bindings

(* Fuel counts expression visits and value applications, unlike machine
   transitions. Both recursive paths consume it, including repeated jumps. *)
let rec evaluate fuel expression environment memory continuation =
  if fuel = 0 then Fuel_exhausted else
  let fuel = fuel - 1 in
  match expression with
  | Variable name -> continuation fuel memory (read name environment memory)
  | Lambda (name, body) -> continuation fuel memory (Closure (name, body, environment))
  | False -> continuation fuel memory False_value
  | Callcc -> continuation fuel memory Callcc_value
  | Apply (operator, operand) ->
      evaluate fuel operator environment memory (fun fuel memory function_value ->
        evaluate fuel operand environment memory (fun fuel memory argument ->
          apply_value fuel function_value argument memory continuation))
  | Conditional (condition, yes, no) ->
      evaluate fuel condition environment memory (fun fuel memory value ->
        let branch = match value with False_value -> no | _ -> yes in
        evaluate fuel branch environment memory continuation)
  | Assign (name, body) ->
      evaluate fuel body environment memory (fun fuel memory value ->
        let address = List.assoc name environment in
        let previous = List.assoc address memory.bindings in
        let memory = { memory with bindings =
          (address, value) :: List.remove_assoc address memory.bindings } in
        continuation fuel memory previous)
and apply_value fuel function_value argument memory continuation =
  if fuel = 0 then Fuel_exhausted else
  let fuel = fuel - 1 in
  match function_value with
  | Closure (name, body, environment) ->
      let environment, memory = bind name argument environment memory in
      evaluate fuel body environment memory continuation
  | False_value -> Stuck
  | Callcc_value ->
      (* Figure 6 defines receivers only for closures and captured control.
         The primitive itself is not a receiver in this paper's language. *)
      (match argument with
       | Closure _ | Continuation _ ->
           apply_value fuel argument (Continuation continuation) memory continuation
       | False_value | Callcc_value -> Stuck)
  | Continuation target ->
      (* A capture saves control only. The invoking computation supplies the
         current heap and remaining budget, so mutation survives every jump. *)
      target fuel memory argument

let run ?(fuel = 1000) expression =
  if fuel < 0 then invalid_arg "Fuel must be nonnegative";
  if not (Names.is_empty (free_variables expression)) then
    invalid_arg "Extended reference evaluation requires a closed term";
  evaluate fuel expression [] { next_binding = 0; bindings = [] }
    (fun _ memory value -> Finished (value, memory))
