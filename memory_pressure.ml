(* Copyright (C) 2015, Thomas Leonard <thomas.leonard@unikernel.com>
   See the README file for details. *)

open Lwt

let src = Logs.Src.create "memory_pressure" ~doc:"Memory pressure monitor"
module Log = (val Logs.src_log src : Logs.LOG)

let wordsize_in_bytes = Sys.word_size / 8

let fraction_free stats =
  let { Xen_os.Memory.free_words; heap_words; _ } = stats in
  float free_words /. float heap_words

let meminfo stats =
  let { Xen_os.Memory.free_words; heap_words; _ } = stats in
  let mem_total = heap_words * wordsize_in_bytes in
  let mem_free = free_words * wordsize_in_bytes in
  Log.info (fun f -> f "Writing meminfo: free %a / %a (%.2f %%)"
    Fmt.bi_byte_size mem_free
    Fmt.bi_byte_size mem_total
    (fraction_free stats *. 100.0));
  Printf.sprintf "MemTotal: %d kB\n\
                  MemFree: %d kB\n\
                  Buffers: 0 kB\n\
                  Cached: 0 kB\n\
                  SwapTotal: 0 kB\n\
                  SwapFree: 0 kB\n" (mem_total / 1024) (mem_free / 1024)

let print_mem_usage =
  let rec aux () =
    let stats = Xen_os.Memory.quick_stat () in
    let top_heap = Xen_os.Memory.footprint () in
    let { Xen_os.Memory.free_words;  heap_words; live_words } = stats in
    let mem_total = heap_words * wordsize_in_bytes in
    let mem_live = live_words * wordsize_in_bytes in
    Log.info (fun f -> f "Memory usage: %a / %a / %a ( %.2f %.2f )"
      Fmt.bi_byte_size mem_live
      Fmt.bi_byte_size top_heap
      Fmt.bi_byte_size mem_total
      (float mem_live /. float mem_total *. 100.0)
      (float top_heap /. float mem_total *. 100.0));
    Xen_os.Time.sleep_ns (Duration.of_f 10.0) >>= fun () ->
    aux ()
  in
  aux ()

let report_mem_usage stats =
  Lwt.async (fun () ->
    let open Xen_os in
    Xs.make () >>= fun xs ->
    Xs.immediate xs (fun h ->
      Xs.write h "memory/meminfo" (meminfo stats)
    )
  )

let init () =
  (* This is a specially adapted GC configuration for this unikernel task.
     It uses a lot of bigarrays (Cstruct: packets given by mirage-net-xen).
   *)
  Gc.set {(Gc.get ()) with
    Gc.allocation_policy = 1 ; (* first-fit allocation, should avoid fragmentation *)
    Gc.space_overhead = 80 ; (* amount of "wasted" memory *)
    Gc.max_overhead = 10 ; (* do a compaction after a major collection when approx 10% of live words are "wasted" *)
    Gc.major_heap_increment = 65536 ; (* incr heap size (asked to Solo5) by 512kB (=64k words of 8B) *)
    Gc.custom_major_ratio = 20 ; (* trigger major when 20% of the memory is "bigarray-like" *)
    Gc.custom_minor_ratio = 5 ; (* trigger minor when 5% of the memory is "bigarray-like" *)
    (* Gc.custom_minor_max_size = 2048 ; *)
  } ;
  Gc.full_major ();
  let stats = Xen_os.Memory.quick_stat () in
  report_mem_usage stats

let status () =
  let stats = Xen_os.Memory.quick_stat () in
  let { Xen_os.Memory.free_words; _ } = stats in
  let min_free_words = 8*1024*1024 / wordsize_in_bytes in
  (* if more than min_free MB of free memory *)
  if free_words < min_free_words then Gc.full_major () ;
  `Ok
