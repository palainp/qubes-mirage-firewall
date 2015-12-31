(* Copyright (C) 2015, Thomas Leonard <thomas.leonard@unikernel.com>
   See the README file for details. *)

(** Commands we provide via qvm-run. *)

open Lwt

module Flow = Qubes.RExec.Flow

let src = Logs.Src.create "command" ~doc:"qrexec command handler"
module Log = (val Logs.src_log src : Logs.LOG)

let handler ~user:_ cmd flow =
  (* Write a message to the client and return an exit status of 1. *)
  let error fmt =
    fmt |> Printf.ksprintf @@ fun s ->
    Log.warn "<< %s" (fun f -> f s);
    Flow.ewritef flow "%s [while processing %S]" s cmd >|= fun () -> 1 in
  match cmd with
  | cmd -> error "Unknown command %S" cmd