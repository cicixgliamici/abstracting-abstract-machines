(** Pure-language closure and evaluation-context unfolding, without substitution.
    Store adapters require singleton, acyclic concrete cells on every live path. *)
val cek_state : Cek.state -> Reference_semantics.term
val store_state : Store_machine.state -> Reference_semantics.term
val cek_final : Cek.state -> Reference_semantics.term
val store_final : Store_machine.state -> Reference_semantics.term
