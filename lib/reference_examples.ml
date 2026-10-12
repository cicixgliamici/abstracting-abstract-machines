open Syntax
let shadowed_capture =
  apply (lambda "x" (lambda "x" (variable "x"))) Examples.constant
let weak_body = lambda "unused" (apply Examples.identity Examples.identity)
let divergent_operand = apply (lambda "unused" Examples.identity) Examples.omega
let nested_arguments =
  apply (apply (lambda "x" (lambda "y" (variable "x")))
    (apply Examples.identity Examples.constant))
    (apply Examples.identity Examples.identity)
let all = Examples.gc_cases @ [
  "shadowed captured name", shadowed_capture;
  "weak lambda body", weak_body;
  "unused divergent operand", divergent_operand;
  "nested evaluated arguments", nested_arguments]
