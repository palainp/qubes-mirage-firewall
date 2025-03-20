(* Copyright (C) 2015, Thomas Leonard <thomas.leonard@unikernel.com>
   See the README file for details. *)

(** General utility functions. *)

(** An Ethernet interface. *)
class type interface = object
  method my_mac : Macaddr.t
  method writev : Ethernet.Packet.proto -> (Cstruct.t -> int) -> unit Lwt.t
  method my_ipv4 : Ipaddr.V4.t
  method other_ipv4 : Ipaddr.V4.t
  method my_ipv6 : Ipaddr.V6.t
  method other_ipv6 : Ipaddr.V6.t
end

(** An Ethernet interface connected to a clientVM. *)
class type client_link = object
  inherit interface
  method other_mac : Macaddr.t
  method log_header : string (* For log messages *)
  method get_rules : Pf_qubes.Parse_qubes.rule list
  method set_rules : string Qubes.DB.KeyMap.t -> unit
end

(** An Ethernet header from [src]'s MAC address to [dst]'s with an IPv4 payload.
*)
let eth_header ethertype ~src ~dst =
  Ethernet.Packet.make_cstruct
    { Ethernet.Packet.source = src; destination = dst; ethertype }

let error fmt =
  let err s = Failure s in
  Printf.ksprintf err fmt

let or_raise msg pp = function
  | Ok x -> x
  | Error e -> failwith (Fmt.str "%s: %a" msg pp e)

(* We now use both IPv4 and IPv6 configuration and the type is defined as (v4, v6) *)
let v4 tupl = fst tupl
let v6 tupl = snd tupl
