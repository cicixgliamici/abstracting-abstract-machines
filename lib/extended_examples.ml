open Syntax

(* Sequencing is expressed in the existing call-by-value language; no extra
   source construct is needed to discard the first expression's result. *)
let sequence first second =
  let free = free_variables second in
  let rec unused_name candidate =
    if List.mem candidate free then unused_name (candidate ^ "_") else candidate in
  (* Discarding a result must not capture a free variable in the second expression. *)
  apply (lambda (unused_name "discarded") second) first
let identity = Examples.identity
let constant = Examples.constant
let if_false = conditional false_value identity constant
let if_function = conditional identity constant Examples.omega
let if_primitive = conditional callcc identity Examples.omega
let conditional_capture =
  apply (lambda "x" (conditional false_value Examples.omega (variable "x"))) constant
let assignment_old = apply (lambda "x" (assign "x" false_value)) identity
let assignment_read =
  apply (lambda "x" (sequence (assign "x" false_value) (variable "x"))) identity
let assignment_nested =
  apply (lambda "x" (assign "x" (assign "x" false_value))) identity
let assignment_cycle =
  apply (lambda "x"
    (sequence (assign "x" (lambda "unused" (variable "x"))) (variable "x"))) false_value
let assignment_alias =
  apply (lambda "x"
    (apply (lambda "reader"
      (sequence (assign "x" false_value) (apply (variable "reader") identity)))
      (lambda "unused" (variable "x")))) identity
let assignment_shadow =
  apply (lambda "x"
    (sequence (apply (lambda "x" (assign "x" false_value)) constant) (variable "x"))) identity

(* Evaluating the RHS calls an outside closure, whose environment does not
   contain 'captured'. The old closure must restore its own environment. *)
let assignment_closure =
  apply (lambda "outside"
    (apply (lambda "captured"
      (apply (lambda "x"
        (apply (assign "x" (apply (variable "outside") false_value)) identity))
        (lambda "unused" (variable "captured")))) constant)) identity

let escape = apply callcc (lambda "k" (apply (variable "k") identity))
let escape_skips_omega =
  apply callcc (lambda "k"
    (apply (lambda "unused" Examples.omega) (apply (variable "k") constant)))
let escape_pending_argument = apply escape constant
let returned_continuation = apply callcc identity
let if_continuation = conditional returned_continuation identity Examples.omega
let invoke_returned = apply returned_continuation identity
let callcc_continuation = apply callcc returned_continuation

(* Store a captured continuation in a mutable binding and enter it twice.
   Mutation must persist across jumps: a continuation restores control, not a
   previous version of the store. The second entry returns the constant. *)
let reentry =
  apply (lambda "saved"
    (apply (lambda "first"
      (apply (lambda "result"
        (conditional (variable "first")
          (sequence (assign "first" false_value) (apply (variable "saved") constant))
          (variable "result")))
        (apply callcc (lambda "k" (sequence (assign "saved" (variable "k")) identity)))))
      identity)) false_value

(* Invoke the SAME saved continuation two times. Each flag update survives the
   jump, so the third entry returns false instead of restoring an old store. *)
let multi_shot =
  let after_capture = lambda "result"
    (conditional (variable "first")
      (sequence (assign "first" false_value) (apply (variable "saved") constant))
      (conditional (variable "second")
        (sequence (assign "second" false_value) (apply (variable "saved") false_value))
        (variable "result"))) in
  let save = apply callcc (lambda "k" (sequence (assign "saved" (variable "k")) identity)) in
  apply (lambda "saved"
    (apply (lambda "first"
      (apply (lambda "second" (apply after_capture save)) identity)) identity)) false_value

let invalid_false_application = apply false_value identity
let invalid_callcc_argument = apply callcc false_value

let terminating = [
  "if false", if_false, constant;
  "if function", if_function, constant;
  "if primitive", if_primitive, identity;
  "conditional saved binding", conditional_capture, constant;
  "if continuation", if_continuation, identity;
  "set returns old value", assignment_old, identity;
  "set updates binding", assignment_read, false_value;
  "nested assignment", assignment_nested, false_value;
  "self-referential binding", assignment_cycle, lambda "unused" (variable "x");
  "shared mutable binding", assignment_alias, false_value;
  "shadowed mutation", assignment_shadow, identity;
  "old closure environment", assignment_closure, constant;
  "continuation escape", escape, identity;
  "escape skips omega", escape_skips_omega, constant;
  "escape pending argument", escape_pending_argument, constant;
  "invoke returned continuation", invoke_returned, identity;
  "continuation reentry", reentry, constant;
  "multi-shot continuation", multi_shot, false_value]

let all = List.map (fun (name, expression, _) -> name, expression) terminating @ [
  "returned continuation", returned_continuation;
  "callcc receives continuation", callcc_continuation;
  "false application", invalid_false_application;
  "callcc receives false", invalid_callcc_argument]
