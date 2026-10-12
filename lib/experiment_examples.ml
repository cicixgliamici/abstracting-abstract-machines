open Syntax

type benchmark = { name : string; family : string; program : expression }

let repeat count transform initial =
  let rec build remaining value =
    if remaining = 0 then value else build (remaining - 1) (transform value) in
  build count initial

(* Each application reuses the same function binding, stressing allocation
   collisions rather than merely making the source tree larger. *)
let identity_pipeline count =
  apply (lambda "transform"
    (repeat count (fun value -> apply (variable "transform") value) Examples.constant))
    Examples.identity

let church_numeral count =
  lambda "f" (lambda "x"
    (repeat count (fun value -> apply (variable "f") value) (variable "x")))

let church_iteration count =
  apply (apply (church_numeral count) Examples.identity) Examples.constant

(* A reader closure observes several writes through one shared lexical cell. *)
let shared_writes =
  apply (lambda "cell"
    (apply (lambda "read"
      (Extended_examples.sequence (assign "cell" Examples.constant)
        (Extended_examples.sequence (assign "cell" Examples.identity)
          (Extended_examples.sequence (assign "cell" false_value)
            (apply (variable "read") Examples.identity)))))
      (lambda "unused" (variable "cell")))) Examples.identity

let all = [
  { name = "pipeline_2"; family = "closure reuse"; program = identity_pipeline 2 };
  { name = "pipeline_4"; family = "closure reuse"; program = identity_pipeline 4 };
  { name = "church_2"; family = "higher-order iteration"; program = church_iteration 2 };
  { name = "church_4"; family = "higher-order iteration"; program = church_iteration 4 };
  { name = "repeated_calls"; family = "closure reuse"; program = Examples.repeated_calls };
  { name = "shared_writes"; family = "mutation"; program = shared_writes };
  { name = "old_closure_environment"; family = "mutation";
    program = Extended_examples.assignment_closure };
  { name = "escape_skips_omega"; family = "nonlocal control";
    program = Extended_examples.escape_skips_omega };
  { name = "multi_shot"; family = "nonlocal control and mutation";
    program = Extended_examples.multi_shot };
  { name = "omega"; family = "nontermination"; program = Examples.omega };
]
