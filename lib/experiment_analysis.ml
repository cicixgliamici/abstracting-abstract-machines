module Machine = Store_machine

(* This explorer is deliberately separate from the complete library analysis.
   A stopped search supplies measurements of a prefix, never a fixed point. *)
let explore policy gc max_states cpu_limit program =
  let queue = Queue.create () in
  let start = Machine.initial program in
  let reached = ref (Machine.States.singleton start) in
  let status = ref "complete" in
  let started = Sys.time () in
  Queue.add start queue;
  while !status = "complete" && not (Queue.is_empty queue) do
    if Sys.time () -. started >= cpu_limit then status := "cpu_limit"
    else begin
      let state = Queue.take queue in
      List.iter (fun next ->
        if !status = "complete" && not (Machine.States.mem next !reached) then
          if Machine.States.cardinal !reached >= max_states then status := "state_limit"
          else begin
            reached := Machine.States.add next !reached;
            Queue.add next queue
          end) (Machine.successors ~gc policy state)
    end
  done;
  !status, !reached

