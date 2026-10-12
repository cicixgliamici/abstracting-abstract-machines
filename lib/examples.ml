open Syntax
let identity = lambda "x" (variable "x")
let identity_application = apply identity identity
let constant = lambda "z" (lambda "w" (variable "z"))
let lexical_capture =
  apply (apply (lambda "x" (lambda "y" (variable "x"))) identity) constant
let shadowing =
  apply (apply (lambda "x" (lambda "x" (variable "x"))) identity) constant
let returned_closure = apply (lambda "x" (lambda "y" (variable "x"))) identity
let nested_application = apply identity (apply identity constant)
let self_application = lambda "x" (apply (variable "x") (variable "x"))
let omega = apply self_application self_application
(* Both calls invoke the same identity closure, so its binder address is reused.
   The first argument becomes dead before the second call; GC can reclaim it. *)
let repeated_calls =
  apply (lambda "id"
    (apply (lambda "ignored" (apply (variable "id") constant))
      (apply (variable "id") identity))) identity
let all = ["identity", identity; "application", identity_application;
           "lexical capture", lexical_capture; "shadowing", shadowing;
           "returned closure", returned_closure;
           "nested application", nested_application; "omega", omega]
let gc_cases = all @ ["repeated calls", repeated_calls]
