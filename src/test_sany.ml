open Kaputt.Abbreviations
open Sany
open Sany_ds
open Sany_visitor

let exhandler f =
  try
    Printexc.record_backtrace true;
    let ret = f () in
    Printexc.record_backtrace false;
    ret
  with
    x ->
      Printf.printf "Exception: %s\n" (Printexc.to_string x);
      Printf.printf "Backtrace: %s\n\n" (Printexc.get_backtrace ());
      raise x

let name_visitor = object
  inherit [string list] visitor as super
  method name acc n = n::acc
end
    

let test_xml filename =
  Test.make_simple_test
    ~title: ("xml parsing " ^ filename)
    (fun () ->
      Assert.no_raise ~msg:"Unexpected exception raised." (fun () ->
	let channel = open_in filename in
	let tree = exhandler (fun () -> import_xml channel)
	in
	close_in channel;
	let acc = name_visitor#context [] tree in
	Printf.printf "%s\n" (Util.mkString (fun x->x) acc);
	tree
      )
    )

let addpath = (fun (str : string) -> "test/resources/" ^ str ^ ".xml")

let files = List.map addpath [
  "empty";
  "UserDefOp";
  "tuples";
  "Choose";
  "at" ; 
  "expr" ; 
  "Euclid" ; 
(*    "pharos" ; (* commented out, takes 10s to load *) *)
  "instanceA" ; 
  "exec" ; 
  "priming_stephan" ; 
  "withsubmodule" ; 
  "OneBit" ; 
]
  
let get_tests = List.map test_xml files

