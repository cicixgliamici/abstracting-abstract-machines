open Aam.Syntax

(* Exhaustive enumeration by node count over two binder names. Reusing names
   deliberately exercises shadowing; free variables only come from the scope. *)
let rec terms size scope =
  let variables = if size = 1 then List.map variable scope else [] in
  let lambdas = if size < 2 then [] else
    List.concat_map (fun name ->
      List.map (lambda name)
        (terms (size - 1) (List.sort_uniq String.compare (name :: scope)))) ["x"; "y"] in
  let applications = List.init (max 0 (size - 2)) (fun offset ->
    let operator_size = offset + 1 in
    let operand_size = size - 1 - operator_size in
    List.concat_map (fun operator ->
      List.map (apply operator) (terms operand_size scope))
      (terms operator_size scope)) |> List.concat in
  variables @ lambdas @ applications

let closed_up_to maximum =
  List.init maximum (fun index -> terms (index + 1) []) |> List.concat
