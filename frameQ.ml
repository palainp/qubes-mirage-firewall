(* Copyright (C) 2016, Thomas Leonard <thomas.leonard@unikernel.com>
   See the README file for details. *)

let src = Logs.Src.create "frameQ" ~doc:"Interface output queue"
module Log = (val Logs.src_log src : Logs.LOG)

type t = {
  name : string;
  mutable items : int;
}

let create name = { name; items = 0 }

(* Note: the queue is only used if we already filled the transmit buffer. *)
let max_qlen = 10

let send q fn =
  if q.items = max_qlen then (
    Log.warn (fun f -> f "Maximum queue length exceeded for %s: dropping frame" q.name);
    Lwt.return_unit
  ) else (
    let sent = fn () in
    if Lwt.state sent = Lwt.Sleep then (
      q.items <- q.items + 1;
      Log.info (fun f -> f "Queue length for %s: incr to %d" q.name q.items);
      Lwt.on_termination sent (fun () ->
        q.items <- q.items - 1;
        Log.info (fun f -> f "Queue length for %s: decr to %d" q.name q.items);
      )
    );
    sent
  )
