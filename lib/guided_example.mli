(** Observations are computed from the production transition functions. The
    example uses pure repeated calls, site allocation, and a 100-step prefix cap. *)
type observation = {
  concrete_trace : Cek.state list;
  abstract_prefix : Store_machine.state list;
  abstract_branches : Store_machine.state list;
  collected_trace : Store_machine.state list;
  uncollected_reached : Store_machine.States.t;
  collected_reached : Store_machine.States.t;
}

val program : Syntax.expression
val observe : unit -> observation
