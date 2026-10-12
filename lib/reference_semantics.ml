(* The evaluator uses its own unlabelled syntax and name analysis. Syntax is
   consulted only by the input adapter, never for reduction or substitution. *)
type term = Variable of string | Lambda of string * term | Apply of term * term
module Names = Set.Make (String)
type execution = Finished of term list | Fuel_exhausted of term list

let rec of_syntax expression = match expression.Syntax.term with
  | Syntax.Variable name -> Variable name
  | Syntax.Lambda (name, body) -> Lambda (name, of_syntax body)
  | Syntax.Apply (operator, operand) -> Apply (of_syntax operator, of_syntax operand)
  | _ -> invalid_arg "Reference semantics covers the pure lambda calculus"

let rec to_string = function
  | Variable name -> name
  | Lambda (name, body) -> "(lambda " ^ name ^ ". " ^ to_string body ^ ")"
  | Apply (operator, operand) -> "(" ^ to_string operator ^ " " ^ to_string operand ^ ")"

let rec free_variables = function
  | Variable name -> Names.singleton name
  | Lambda (name, body) -> Names.remove name (free_variables body)
  | Apply (operator, operand) -> Names.union (free_variables operator) (free_variables operand)

let rec all_names = function
  | Variable name -> Names.singleton name
  | Lambda (name, body) -> Names.add name (all_names body)
  | Apply (operator, operand) -> Names.union (all_names operator) (all_names operand)

let fresh_name base forbidden =
  let rec choose index =
    let candidate = base ^ "_" ^ string_of_int index in
    if Names.mem candidate forbidden then choose (index + 1) else candidate
  in choose 0

(* Rename occurrences belonging to one binder, stopping at a shadowing lambda.
   The caller chooses a name absent from ALL names, not only the free ones. *)
let rec rename_bound old_name new_name = function
  | Variable name -> Variable (if name = old_name then new_name else name)
  | Lambda (name, _) as term when name = old_name -> term
  | Lambda (name, body) -> Lambda (name, rename_bound old_name new_name body)
  | Apply (operator, operand) ->
      Apply (rename_bound old_name new_name operator, rename_bound old_name new_name operand)

let substitute name replacement expression =
  let replacement_free = free_variables replacement in
  let replacement_names = all_names replacement in
  let rec visit = function
    | Variable variable -> if variable = name then replacement else Variable variable
    | Apply (operator, operand) -> Apply (visit operator, visit operand)
    | Lambda (binder, _) as term when binder = name -> term
    | Lambda (binder, body) as term ->
        if not (Names.mem name (free_variables body)) then term else
        if Names.mem binder replacement_free then
          (* Avoid inner bound names as well as free names: renaming the outer
             binder must not make its occurrences refer to an inner lambda. *)
          let forbidden = Names.add name (Names.union replacement_names (all_names body)) in
          let fresh = fresh_name binder forbidden in
          Lambda (fresh, visit (rename_bound binder fresh body))
        else Lambda (binder, visit body)
  in visit expression

let is_value = function Lambda _ -> true | _ -> false

(* Section 2.1: E ::= [] | (E e) | (v E). One call finds and contracts a
   single beta-value redex. Lambda bodies are values, not evaluation contexts. *)
let rec step = function
  | Apply (operator, operand) when not (is_value operator) ->
      Option.map (fun next -> Apply (next, operand)) (step operator)
  | Apply (operator, operand) when not (is_value operand) ->
      Option.map (fun next -> Apply (operator, next)) (step operand)
  | Apply (Lambda (name, body), value) -> Some (substitute name value body)
  | Variable _ | Lambda _ | Apply _ -> None

let run ?(fuel = 1000) expression =
  if fuel < 0 then invalid_arg "Fuel must be nonnegative";
  if not (Names.is_empty (free_variables expression)) then
    invalid_arg "Reference evaluation requires a closed term";
  let rec visit remaining reversed current =
    if is_value current then Finished (List.rev (current :: reversed)) else
    match step current with
    | Some _ when remaining = 0 -> Fuel_exhausted (List.rev (current :: reversed))
    | Some next -> visit (remaining - 1) (current :: reversed) next
    | None -> failwith "Invariant: a closed non-value must have a beta-value redex"
  in visit fuel [] expression

type canonical = Free of string | Bound of int | Abstraction of canonical
  | Application of canonical * canonical

let bound_index name scope =
  let rec find index = function
    | [] -> None
    | binder :: _ when binder = name -> Some index
    | _ :: rest -> find (index + 1) rest
  in find 0 scope

(* Nearest-binder indices preserve shadowing and leave free names untouched.
   Equality of these forms compares alpha equivalence without printed names. *)
let rec canonical scope = function
  | Variable name ->
      (match bound_index name scope with Some index -> Bound index | None -> Free name)
  | Lambda (name, body) -> Abstraction (canonical (name :: scope) body)
  | Apply (operator, operand) -> Application (canonical scope operator, canonical scope operand)

let alpha_equivalent left right = canonical [] left = canonical [] right
