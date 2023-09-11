(* Copyright (C) 2015, Thomas Leonard <thomas.leonard@unikernel.com>
   See the README file for details. *)

open Lwt

let src = Logs.Src.create "memory_pressure" ~doc:"Memory pressure monitor"
module Log = (val Logs.src_log src : Logs.LOG)

let wordsize_in_bytes = Sys.word_size / 8

let fraction_free stats =
  let { Xen_os.Memory.free_words; heap_words; _ } = stats in
  float free_words /. float heap_words

let init () =
  Gc.full_major ();
  (* Report we are using all out memory available to be kept away from memory ballooning *)
  Lwt.async (fun () ->
    let open Xen_os in
    Xs.make () >>= fun xs ->
    Xs.immediate xs (fun h ->
      Xs.read h "memory/static-max" >>= fun mem ->
      (* Silently drop the EACCESS exception as the key is absent if we're out of ballooning *)
      Lwt.catch
        (fun () ->
          Xs.write h "memory/meminfo" mem
        )
        (function
          | Xs_protocol.Error _ -> Lwt.return_unit
          | ex -> fail ex
        )
    )
  )

let status () =
  let stats = Xen_os.Memory.quick_stat () in
  if fraction_free stats > 0.5 then `Ok
  else (
    Gc.full_major ();
    Xen_os.Memory.trim ();
    let stats = Xen_os.Memory.quick_stat () in
    if fraction_free stats < 0.6 then `Memory_critical
    else `Ok
  )
