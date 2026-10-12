open Aam.Syntax

(* Exhaustive small source terms for Section 3, including ill-applied values.
   Runtime captured-continuation literals are excluded from the source grammar. *)
let rec terms size scope =
  let leaves = if size = 1 then false_value :: callcc :: List.map variable scope else [] in
  let unary = if size < 2 then [] else
    let lambdas = List.concat_map (fun name ->
      terms (size - 1) (List.sort_uniq String.compare (name :: scope))
      |> List.map (lambda name)) ["x"; "y"] in
    let assignments = List.concat_map (fun name ->
      List.map (assign name) (terms (size - 1) scope)) scope in
    lambdas @ assignments in
  let applications = List.init (max 0 (size - 2)) (fun offset ->
    let left = offset + 1 in
    List.concat_map (fun operator -> List.map (apply operator) (terms (size - 1 - left) scope))
      (terms left scope)) |> List.concat in
  leaves @ unary @ applications @ conditionals size scope
and conditionals size scope =
  List.init (max 0 (size - 3)) (fun offset ->
    let condition_size = offset + 1 in
    List.init (size - condition_size - 2) (fun branch_offset ->
      let yes_size = branch_offset + 1 in
      let no_size = size - 1 - condition_size - yes_size in
      List.concat_map (fun condition ->
        List.concat_map (fun yes -> List.map (conditional condition yes) (terms no_size scope))
          (terms yes_size scope)) (terms condition_size scope)) |> List.concat) |> List.concat

let closed_up_to maximum =
  List.init maximum (fun offset -> terms (offset + 1) []) |> List.concat
