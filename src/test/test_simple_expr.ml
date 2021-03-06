open Kaputt.Abbreviations
open Expr_ds
open Simple_expr_ds
open Simple_expr
open Util
open Test_common
open Format
open Tla_simple_pb
open Backend_exceptions
open Obligation_formatter

let test_simple_expr record () =
  let rec obligations_to_string obligations sobligations n =
    match (obligations, sobligations) with
    | ([], []) -> ("","")
    | (obl::tl, sobl::stl) ->
      let (s1,s2) = obligations_to_string tl stl (n+1) in
      let fft = str_formatter in
      fprintf fft "Obligation %d:\n%a\n\n" n
        fmt_obligation obl;
      let s1' = flush_str_formatter () in
      fprintf fft "Obligation %d:\n%a\n\n" n
        fmt_tla_simple_pb sobl;
      let s2' = flush_str_formatter () in
      (s1'^s1,s2'^s2)
    | _ ->
      failwith "List of obligations and simple obligations are not of equal\
                length!"
  in
  try
    let simple_obs = List.map tla_pb_to_tla_simple_pb record.obligations in
    let (s1,s2) = obligations_to_string record.obligations simple_obs 0 in
    let msg = sprintf "Comparing expr %s and simple expr %s.@." s1 s2 in
    (* note: some language elements are removed, e.g. theorem references in a
       term are replaced by the definition. Therefore this assertion doesn't
       hold in general. *)
    Assert.equal ~msg s1 s2;
    simple_obs
  with
  | UnhandledLanguageElement (_, _)-> []

let create_test record =
  Test.make_assert_test
    ~title: ("Comparing simple_expression to expression in " ^ record.filename)
    (fun () -> ())
    (fun () ->
       (exhandler ( test_simple_expr record ))
    )
    (fun sobs ->
       ignore( record.simple_obligations <- sobs )
    )


let get_tests records = List.map create_test records
