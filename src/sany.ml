(* Copyright (C) 2014 MSR-INRIA
 *
 * SANY expressions
 * This file should be broken into xml utilities, sany ds and sany export
 * Remark: the parser does not chek for additional data between nodes, e.g. 
 * adding newlines will result in parsing failures.
 *
 * Author: TL
 *)

open Commons
open Xmlm
open Sany_ds
open Xml_utils

let init_context_map ls = ContextMap.empty

let mkLevel i = match i with
  | 0 -> ConstantLevel
  | 1 -> VariableLevel
  | 2 -> ActionLevel
  | 3 -> TemporalLevel
  | _ -> Errors.bug ("XML Parser error: unknown level " ^
			(string_of_int i) ^ " (expected 0-3).")

let opdeclkind_from_int i = match i with
  | 2 -> ConstantDecl
  | 3 -> VariableDecl
  | 4 -> BoundSymbol
  | 24 -> NewConstant
  | 25 -> NewVariable
  | 26 -> NewState
  | 27 -> NewAction
  | 28 -> NewTemporal
  | n -> failwith ("Conversion from int to operator declaration type failed. The number " ^ (string_of_int n) ^ " does not represent a proepr declaration.")

    
(** Parses a location node, returning a record with line and column *)
let read_location i : location =
  open_tag i "location";
  open_tag i "column";
  let cb = get_data_in i "begin" read_int in
  let ce = get_data_in i "end" read_int in
  close_tag i "column";
  open_tag i "line";
  let lb = get_data_in i "begin" read_int in
  let le = get_data_in i "end" read_int in
  close_tag i "line";
  let fname = get_data_in i "filename" read_string in
  close_tag i "location";
  { column = {rbegin = cb; rend = ce};
    line = {rbegin = lb; rend = le};
    filename = fname
  }

(** Parses a location, if there is one *)
let read_optlocation i : location option =
  match get_optchild i "location" read_location with
  | [] -> None
  | [x] -> Some x
  | x -> failwith ("Implementation error in XML parsing: the reader for 0 or 1 elements returned multiple elements")

(** Parses an optional level node *)    
let get_optlevel i =
  match get_optchild i "level" (fun i -> get_data_in i "level" read_int) with
  | [] -> None
  | [x] -> Some (mkLevel x)
  | x -> failwith ("Implementation error in XML parsing: the reader for 0 or 1 elements returned multiple elements")
    
(** Parses the FormalParamNode within context/entry *)
let read_formal_param i : formal_param =
  open_tag i "FormalParamNode";
  let loc = read_optlocation i in
  let level = get_optlevel i in
  let un = get_data_in i "uniquename" read_string in
  let ar = get_data_in i "arity" read_int in
  close_tag i "FormalParamNode";
  FP {
    location = loc;
    level = level;
    arity = ar;
    name = un;
  }

(** Parses the OpArgNode *)
let read_oparg i : op_arg =
  open_tag i "OpArgNode";
  let loc = read_optlocation i in
  let level = get_optlevel i in
  let un = get_data_in i "uniquename" read_string in
  let ar = get_data_in i "arity" read_int in
  close_tag i "OpArgNode";
  {
    location = loc;
    level = level;
    arity = ar;
    name = un;
  }

    
(** gets the UID number of the reference node "name" *)    
let read_ref i name f =
  open_tag i name;
  open_tag i "UID";
  let str = read_int i in
  close_tag i "UID";
  close_tag i name;
  f str

(** reads one of reference arguments *)
let read_opref i =
    let name = match (peek i) with 
     | `El_start ((_, name),_ ) -> name
     | signal -> failwith "We expect a symbol opening tag of an operator reference but got " ^ (formatSignal signal)
   in 
    let opref = match name with
      | "FormalParamNodeRef"    -> read_ref i name (fun x -> FMOTA_formal_param (FP_ref x) )
      | "ModuleNodeRef"         -> read_ref i name (fun x -> FMOTA_module (MOD_ref x) )
      | "OpDeclNodeRef"         -> read_ref i name (fun x -> FMOTA_op_decl (OPD_ref x) )
      | "ModuleInstanceKindRef" -> read_ref i name (fun x -> FMOTA_op_def (OPDef_ref x) )
      | "UserDefinedOpKindRef"  -> read_ref i name (fun x -> FMOTA_op_def (OPDef_ref x) )
      | "BuiltInKindRef"        -> read_ref i name (fun x -> FMOTA_op_def (OPDef_ref x) )
      | "TheoremNodeRef"        -> read_ref i name (fun x -> FMOTA_theorem (THM_ref x) )
      | "AssumeNodeRef"         -> read_ref i name (fun x -> FMOTA_assume (ASSUME_ref x) )
      | _ -> failwith ("Found tag " ^ name ^ " but we need an operator reference ("^
			  "FormalParamNodeRef, ModuleNodeRef, OpDeclNodeRef, " ^
			  "ModuleInstanceKindRef, UserDefinedOpKindRef, " ^
			  "BuiltInKindRef, TheoremNodeRef, AssumeNodeRef)")
    in
    opref



(** handles the leibnizparam tag *)
let read_param i =
  open_tag i "leibnizparam";
  let wrap_fp x = FP_ref x in
  let fpref = read_ref i "FormalParamNodeRef" wrap_fp in
  let is_leibniz = read_flag i "leibniz"  in
  let ret = (fpref, is_leibniz) in
  close_tag i "leibnizparam";
  ret
    
let read_params i =
  get_children_in i "params" "leibnizparam" read_param
  
 
(** Parses the BuiltinKind within context/entry *)
let read_builtin_kind i =
  open_tag i "BuiltInKind";
  let loc = read_optlocation i in
  let level = get_optlevel i in
  let un = get_data_in i "uniquename" read_string in
  let ar = get_data_in i "arity" read_int in
  let params = get_children i "params" read_params in
  close_tag i "BuiltInKind";
  BOP {
    location = loc;
    arity = ar;
    name = un;
    params = List.flatten params;
    level = level;
  }

(* untested *)    
let read_module_instance i : module_instance =
  open_tag i "ModuleInstanceKind";
  let loc = read_optlocation i in
  let level = get_optlevel i in
  let un = get_data_in i "uniquename" read_string in
  close_tag i "ModuleInstanceKind";
  MI {
    location = loc;
    level    = level;
    name     = un;
  }

    
(* --- expressions parsing is mutually recursive (e.g. OpApplNode Expr) ) --- *)
let rec read_expr i =
  let name = match (peek i) with 
     | `El_start ((_, name),_ ) -> name
     | _ -> failwith "We expect symbol opening tag in an entry."
   in 
   let expr = match name with 
     | "AtNode"      -> E_at (read_at i)
     | "DecimalNode" -> E_decimal (read_decimal i)
     | "LabelNode"   -> E_label (read_label i)
     | "LetInNode"   -> E_let_in (read_let i)
     | "NumeralNode" -> E_numeral (read_numeral i)
     | "OpApplNode"  -> E_op_appl (read_opappl i)
     | "StringNode"  -> E_string (read_stringnode i)
     | "SubstInNode" -> E_subst_in (read_substinnode i)
     | _ -> failwith ("Unexpected node start tag for expression " ^ name ^
		      ", expected one of AtNode, DecimalNode, LabelNode, "^
		      " LetInNode, NumeralNode, OpApplNode, StringNode or SubstInNode." )
   in
   expr

(* this is different from the xsd file which allows expression and oparg nodes. the java at node code has only opapp (which are expressions) children though. *) 
and read_at i           = 
  open_tag i "AtNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let except = read_opappl i  in
  let except_component = read_opappl i in
  close_tag i "AtNode";
  {
    location          = location;
    level             = level;
    except            = except;
    except_component  = except_component;
  }
  
and read_decimal i 	=
  open_tag i "DecimalNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let mantissa = get_data_in i "mantissa" read_int in
  let exponent = get_data_in i "exponent" read_int in
  close_tag i "DecimalNode";
  {
    location  = location;
    level     = level;
    mantissa  = mantissa;
    exponent  = exponent;
  }
(* untested *)    
and read_label i	=
  open_tag i "LabelNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let name = get_data_in i "uniquename" read_string in
  let arity = get_data_in i "arity" read_int in
  let body = read_expr_or_assumeprove i in
  let params = get_children i "params" (fun i -> read_ref i "FormalParamNodeRef" (fun x -> FP_ref x)) in
  close_tag i "LabelNode";
  {
    location  = location;
    level     = level;
    name      = name;
    arity     = arity;
    body      = body;
    params    = params;
  }

(* untested *)  
and read_let i :let_in	=
  open_tag i "LetInNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let body = get_data_in i "body" read_expr in
  let mkOPDref x = OTA_op_def (OPDef_ref x) in
  let mkAref x = OTA_assume (ASSUME_ref x) in
  let mkTref x = OTA_theorem (THM_ref x) in
  let mkRef name f inp = read_ref inp name f in
  let op_defs = get_children_choice_in i "opDefs" [
    ((=) "ModuleInstanceKindRef", mkRef "ModuleInstanceKindRef" mkOPDref);
    ((=) "UserDefinedOpKindRef",  mkRef "UserDefinedOpKindRef" mkOPDref);
    ((=) "BuiltInKindRef",        mkRef "BuiltInKindRef" mkOPDref);
    ((=) "AssumeNodeRef",         mkRef "AssumeNodeRef" mkAref);
    ((=) "TheoremNodeRef",        mkRef "TheoremNodeRef" mkTref);
    ((=) "AssumeNode",            (fun i -> OTA_assume (read_assume i)));
    ((=) "TheoremNode",           (fun i -> OTA_theorem (read_theorem i)));
  ] in
  close_tag i "LetInNode";
  {
    location = location;
    level    = level;
    body     = body;
    op_defs  = op_defs;
  }

and read_numeral i : numeral =
  open_tag i "NumeralNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let value = get_data_in i "IntValue" read_int in
  close_tag i "NumeralNode";
  {
    location = location;
    level = level;
    value = value;
  }
    
and read_opappl i	=
  open_tag i "OpApplNode";
  let loc = read_optlocation i in
  let level = get_optlevel i in
  let opref = get_data_in i "operator" read_opref in
  let operands = get_data_in i "operands" (fun i ->
    get_children_choice i [
      ((=) "OpArgNode", (fun i -> EO_op_arg (read_oparg i)));
      ((fun x -> true), (fun i -> EO_expr (read_expr i)) )
    ])
  in
  let bound_symbols = match (peek i) with
    | `El_start ((_,name), _) ->
      open_tag i "boundSymbols";
      let bs = get_children_choice i [
	((=) "unbound", (fun i -> B_unbounded_bound_symbol (read_unbounded_param i)) );
	((=) "bound",   (fun i -> B_bounded_bound_symbol (read_bounded_param i)) )
      ] in
      close_tag i "boundSymbols";
      bs
    | _ -> []
  in
  let ret =  {
    location = loc;
    level = level;
    operator = opref;
    operands = operands;
    bound_symbols = bound_symbols;
  }
  in
  close_tag i "OpApplNode";
  ret
  
and read_stringnode i : strng	=
  open_tag i "StringNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  open_tag i "StringValue";
  let value = match (peek i) with
    | `El_end -> ""  (* we accept empty strings as string values *)
    | _       -> read_string i in
  close_tag i "StringValue";
  close_tag i "StringNode";
  {
    location = location;
    level = level;
    value = value;
  }

  
and read_subst i =
  open_tag i "Subst";
  let op = read_ref i "OpDeclNodeRef" (fun x -> OPD_ref x) in
  let expr = get_child_choice i [
    (is_expr_node, (fun i -> EO_expr (read_expr i)));
    ((=)"OpArgNode", (fun i -> EO_op_arg (read_oparg i)));
  ] in
  close_tag i "Subst";
  {
    op = op;
    expr = expr;
  }

(* untested *)    
and read_substinnode i : subst_in =
  open_tag i "SubstInNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let substs = get_children_in i "substs" "Subst" read_subst in
  let body = read_expr i in 
  close_tag i "SubstInNode";
  {
    location = location;
    level    = level;
    substs   = substs;
    body     = body;
  }

(* untested *)    
and read_instance i  = 
  open_tag i "InstanceNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let name  = get_data_in i "uniquename" read_string in
  let substs = get_children_in i "substs" "Subst" read_subst in
  let params = get_children_in i "params" "FormalParamNodeRef"
    (fun i-> read_ref i "FormalParamNodeRef" (fun x -> FP_ref x))
  in 
  close_tag i "InstanceNode";
  {
    location = location;
    level    = level;
    name     = name;
    substs   = substs;
    params   = params;
  }

and is_node name = is_expr_node name || is_proof_node name || (List.mem name
  ["APSubstInNode"; "AssumeProveNode"; "DefStepNode";
   "OpArgNode"; "InstanceNode"; "NewSymbNode"; 
   "FormalParamNodeRef"; "ModuleNodeRef"; "OpDeclNodeRef";
   "ModuleInstanceKindRef"; "UserDefinedOpKindRef"; "BuiltInKindRef";
   "AssumeNodeRef"; "TheoremNodeRef"; "UseOrHideNode"; ])
   
and read_node i = get_child_choice i [
  ((=) "APSubstInNode",         fun i -> N_ap_subst_in (read_apsubstinnode i));
  ((=) "AssumeProveNode",       fun i -> N_assume_prove (read_assume_prove i));
  ((=) "DefStepNode",           fun i -> N_def_step (read_defstep i));
  (is_expr_node,                fun i -> N_expr (read_expr i));
  ((=) "InstanceNode",          fun i -> N_instance (read_instance i));
  ((=) "NewSymbNode",           fun i -> N_new_symb (read_newsymb i));
  (is_proof_node,               fun i -> N_proof (read_proof i));
  ((=) "FormalParamNodeRef",    fun i -> N_formal_param (read_ref i "FormalParamNodeRef" (fun x -> FP_ref x)));
  ((=) "ModuleNodeRef",         fun i -> N_module (read_ref i "ModuleNodeRef" (fun x -> MOD_ref x)));
  ((=) "OpDeclNodeRef",         fun i -> N_op_decl (read_ref i "OpDeclNodeRef" (fun x -> OPD_ref x)));
  ((=) "ModuleInstanceKindRef", fun i -> N_op_def (read_ref i "ModuleInstanceKindRef" (fun x -> OPDef_ref x)));
  ((=) "UserDefinedOpKindRef",  fun i -> N_op_def (read_ref i "UserDefinedOpKindRef" (fun x -> OPDef_ref x)));
  ((=) "BuiltInKindRef",        fun i -> N_op_def (read_ref i "BuiltInKindRef" (fun x -> OPDef_ref x)));
  ((=) "AssumeNodeRef",         fun i -> N_assume (read_ref i "AssumeNodeRef" (fun x -> ASSUME_ref x)));
  ((=) "TheoremNodeRef",        fun i -> N_theorem (read_ref i "TheoremNodeRef" (fun x -> THM_ref x)));
  ((=) "UseOrHideNode",         fun i -> N_use_or_hide (read_useorhide i));    
]


  
(* untested *)    
and read_apsubstinnode i : ap_subst_in = 
  open_tag i "APSubstInNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let substs = get_children_in i "substs" "Subst" read_subst in
  open_tag i "body";
  let body = get_child_choice i [(is_node, read_node)] in
  close_tag i "body";
  close_tag i "APSubstInNode";
  {
    location = location;
    level    = level;
    substs   = substs;
    body = body;
  }
    

and read_tuple i : bool = match (peek i) with
  | `El_start ((_,"tuple"), _) ->
  (* if tag is present, consume tag and return true*)
  open_tag i "tuple";
  close_tag i "tuple";
  true
  | _ ->  (* otherwise return false *)
  false
  
and read_bounded_param i : bounded_bound_symbol =
  open_tag i "bound";
  let params = get_children i "FormalParamNodeRef"
    (fun i -> read_ref i "FormalParamNodeRef" (fun x -> FP_ref x)) in
  let tuple = read_tuple i in
  let domain = read_expr i in
  let ret =  {
    params = params;
    tuple = tuple;
    domain = domain;
  } in
  close_tag i "bound";
  ret
   
and read_unbounded_param i : unbounded_bound_symbol =
  open_tag i "unbound";
  let params = read_ref i "FormalParamNodeRef" (fun x -> FP_ref x) in
  let tuple = read_tuple i in
  let ret =  {
    param = params;
    tuple = tuple;
  } in
  close_tag i "unbound";
  ret
and read_assume i =
  open_tag i "AssumeNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let expr = read_expr i in 
  close_tag i "AssumeNode";
  ASSUME {
    location = location;
    level    = level;
    expr     = expr;
  }
    

and expr_nodes =
  ["AtNode"      ;   "DecimalNode" ;   "LabelNode"   ;
   "LetInNode"   ;   "NumeralNode" ;   "OpApplNode"  ;
   "StringNode"  ;   "SubstInNode" ]

and is_expr_node name = List.mem name expr_nodes
    
(* --- end of mutual recursive expression parsing --- *)

  
(** reads the definition of a user defined operator within context/entry *)
and read_userdefinedop_kind i  =
  open_tag i "UserDefinedOpKind";
  let loc = read_optlocation i in
  let level = get_optlevel i in
  let un = get_data_in i "uniquename" read_string in
  let ar = get_data_in i "arity" read_int in
  let body = get_data_in i "body" read_expr in
  let params = List.flatten
    (get_optchild i "params" read_params) in
  let recursive = read_flag i "recursive" in
  let ret = UOP {
    location = loc;
    arity = ar;
    name = un;
    level = level;
    body = body;
    params = params;
    recursive = recursive;
  } in
  close_tag i "UserDefinedOpKind";
  ret
 
and read_op_decl i =
  open_tag i "OpDeclNode";
  let loc = read_optlocation i in
  let level = get_optlevel i in
  let un = get_data_in i "uniquename" read_string in
  let ar = get_data_in i "arity" read_int in
  let kind = opdeclkind_from_int (get_data_in i "kind" read_int) in
  close_tag i "OpDeclNode";
  OPD {
    location = loc;
    level = level;
    name = un;
    arity = ar;
    kind = kind;
  }
    
 

and read_newsymb i =
  open_tag i "NewSymbNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let op_decl = OPD_ref (read_ref i "OpDeclNodeRef" (fun x->x)) in
  let exprl = get_optchild_choice i [
    (is_expr_node, read_expr);
  ] in
  let set = match exprl with
    | [e] -> Some e
    | [] -> None
    | _ -> failwith "An option expression returned more than 1 result."
  in
  close_tag i "NewSymbNode";
  {
  location = location;
  level    = level;
  op_decl  = op_decl;
  set      = set;
  }

and read_assume_prove i =
  open_tag i "AssumeProveNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let assumes = get_children_choice_in i "assumes"  [
    ((=) "AssumeProveNode", (fun i -> NEA_assume_prove (read_assume_prove i)));
    ((=) "NewSymbNode", (fun i -> NEA_new_symb (read_newsymb i)));
    (is_expr_node , (fun i -> NEA_expr (read_expr i)));
  ] in
  open_tag i "prove"; 
  let prove = get_child_choice i [(is_expr_node, read_expr)] in
  close_tag i "prove";
  let suffices = read_flag i "suffices" in
  let boxed = read_flag i "boxed" in
  close_tag i "AssumeProveNode";
  {
    location = location;
    level    = level;
    assumes  = assumes;
    prove    = prove;   
    suffices = suffices;
    boxed    = boxed;
  }

and read_omitted i : omitted =
  open_tag i "omitted";
  let location = read_optlocation i in
  let level = get_optlevel i in
  close_tag i "omitted";
  {
    location = location;
    level = level;
  }

and read_obvious i : obvious =
  open_tag i "obvious";
  let location = read_optlocation i in
  let level = get_optlevel i in
  close_tag i "obvious";
  {
    location = location;
    level = level;
  }

and read_facts i =
  let id = (fun x -> x) in
  get_children_choice_in i "facts" [
    ((=) "ModuleNodeRef", (fun i -> EMM_module (MOD_ref (read_ref i "ModuleNodeRef" id))));
    ((=) "ModuleInstanceKind", (fun i -> EMM_module_instance (read_module_instance i)));
    (is_expr_node, (fun i -> EMM_expr (read_expr i)));
  ]

and read_defs i =
  let id = (fun x -> x) in
  get_children_choice_in i "defs" [
    ((=) "UserDefinedOpKindRef", (fun i -> UMTA_user_defined_op (UOP_ref (read_ref i "UserDefinedOpKindRef" id) )));
    ((=) "ModuleInstanceKindRef", (fun i -> UMTA_module_instance (MI_ref (read_ref i "ModuleInstanceKindRef" id) ) ));
    ((=) "TheoremNodeRef", (fun i -> UMTA_theorem (THM_ref (read_ref i "TheoremNodeRef" id) )));
    ((=) "AssumeNodeRef", (fun i -> UMTA_assume (ASSUME_ref (read_ref i "AssumeNodeRef" id) )));
  ]
 
and read_by i =
  open_tag i "by";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let facts = read_facts i in
  let defs = read_defs i in
  let only = read_flag i "only"  in
  close_tag i "by";
  {
    location = location;
    level = level;
    facts = facts;
    defs = defs;
    only = only;
  }

   
and read_useorhide i : use_or_hide =
  open_tag i "UseOrHideNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let facts = read_facts i in
  let defs = read_defs i in
  let only = read_flag i "only" in
  let hide = read_flag i "hide" in
  close_tag i "UseOrHideNode";
  {
    location = location;
    level    = level;
    facts    = facts;
    defs     = defs;
    only     = only;
    hide     = hide;
  }
  
  
and read_steps i =
  open_tag i "steps";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let id = fun x -> x in
  let steps = get_children_choice i [
    ((=) "DefStepNode",    (fun i -> S_def_step (read_defstep i)));
    ((=) "UseOrHideNode",  (fun i -> S_use_or_hide (read_useorhide i)));
    ((=) "InstanceNode",   (fun i -> S_instance (read_instance i)));
    ((=) "TheoremNodeRef", (fun i -> S_theorem (THM_ref (read_ref i "TheoremNodeRef" id))));
    ((=) "TheoremNode",    (fun i -> S_theorem (read_theorem i)));
  ] in 
  close_tag i "steps";
  {
    location = location;
    level = level;
    steps = steps;
  }

and read_defstep i   =
  open_tag i "DefStepNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let mkRef name inp = read_ref inp name (fun x->OPDef_ref x) in
  let defs = get_children_choice i [
    ((=) "ModuleInstanceKindRef", mkRef "ModuleInstanceKindRef");
    ((=) "UserDefinedOpKindRef", mkRef "UserDefinedOpKindRef");
    ((=) "BuiltInKindRef", mkRef "BuiltInKindRef");
  ] in
  close_tag i "DefStepNode";
  {
    location = location;
    level    = level;
    defs     = defs;
  }
   
and read_proof i =
  let ret = get_child_choice i [
    ((=) "omitted", (fun i -> P_omitted (read_omitted i)));
    ((=) "obvious", (fun i -> P_obvious (read_obvious i)));
    ((=) "by",      (fun i -> P_by (read_by i)));
    ((=) "steps",   (fun i -> P_steps (read_steps i)));
  ] in
  ret

and is_proof_node name = List.mem name ["omitted"; "obvious"; "by"; "steps"]

and read_expr_or_assumeprove i =
  get_child_choice i [
    ((=) "AssumeProveNode", (fun i -> EA_assume_prove (read_assume_prove i)));
    (is_expr_node , (fun i -> EA_expr (read_expr i)));
  ]  
  
and read_theorem i : theorem =
  open_tag i "TheoremNode";
  let location = read_optlocation i in
  let level = get_optlevel i in
  let expr = read_expr_or_assumeprove i in
  let proofl = get_optchild_choice i [(is_proof_node, read_proof)]  in
  let proof = match proofl with
    | [p] -> p
    | _   -> P_noproof
  in
  let suffices = read_flag i "suffices" in
  close_tag i "TheoremNode";
  THM {
    location = location;
    level    = level;
    expr     = expr;
    proof    = proof;
    suffices = suffices;
  }


and read_module i =
  open_tag i "ModuleNode";
  let loc = get_child i "location" read_optlocation in
  (* we need to read the context first and pass it for the symbols (thm, const, etc.*)
  (*  let con = Some (init_context_map (get_children_in i "context" "entry" read_entry)) in *)
  let name = get_data_in i "uniquename" read_string in
  let read_varconst_ref i = read_ref i "OpDeclNodeRef" (fun x -> OPD_ref x ) in
  let mkOpdefrefHandler name i = read_ref i name (fun x -> OPDef_ref x) in
  let mkAssumerefHandler name i = read_ref i name (fun x -> ASSUME_ref x) in
  (* print_string name; *)
  let constants = get_children_in  i "constants" "OpDeclNodeRef" read_varconst_ref in
  let variables = get_children_in  i "variables" "OpDeclNodeRef" read_varconst_ref in
  let definitions = get_children_choice_in i "definitions" [
    ((=) "ModuleNodeRef",        mkOpdefrefHandler "ModuleNodeRef") ;
    ((=) "UserDefinedOpKindRef", mkOpdefrefHandler "UserDefinedOpKindRef")  ;
    ((=) "BuiltInKindRef",       mkOpdefrefHandler "BuiltInKindRef")  ;
  ]
  in
  let assumptions = get_children_choice_in i "assumptions" [
    ((=) "AssumeNode", read_assume);
    ((=) "AssumeNodeRef", mkAssumerefHandler "AssumeNodeRef");
  ]
  in
  let theorems = get_children_choice_in i "theorems" [
    ((=) "TheoremNode", read_theorem);
    ((=) "TheoremNodeRef", fun i -> read_ref i "TheoremNodeRef" (fun x -> THM_ref x) );
  ]
  in
  let ret = MOD {
    location     = loc;
    name         = name;
    constants    = constants;
    variables    = variables;
    definitions  = definitions;
    assumptions  = assumptions;
    theorems     = theorems;
  } in
  close_tag i "ModuleNode";
  ret

(* Operator definition nodes: ModuleInstanceKind, UserDefinedOpKind, BuiltinKind *)
and read_op_def i =
  get_child_choice i [
     ((=) "UserDefinedOpKind" , (fun i -> OPDef (O_user_defined_op (read_userdefinedop_kind i))));
     ((=) "ModuleInstanceKind", (fun i -> OPDef (O_module_instance (read_module_instance i))));
     ((=) "BuiltInKind"       , (fun i -> OPDef (O_builtin_op (read_builtin_kind i))));
  ]
and is_op_def name = List.mem name ["UserDefinedOpKind"; "ModuleInstanceKind"; "BuiltInKind"]
    
and read_entry i = 
   open_tag i "entry";
   let uid = get_data_in i "UID" read_int in
   let symbol = get_child_choice i [
     ((=)  "FormalParamNode", (fun i ->  FMOTA_formal_param (read_formal_param i)));
     (is_op_def             , (fun i ->  FMOTA_op_def (read_op_def i)));
     ((=)  "ModuleNode"     , (fun i ->  FMOTA_module  (read_module i)));
     ((=)  "OpDeclNode"     , (fun i ->  FMOTA_op_decl (read_op_decl i)));
     ((=)  "TheoremNode"    , (fun i ->  FMOTA_theorem (read_theorem i)));
     ((=)  "AssumeNode"     , (fun i ->  FMOTA_assume  (read_assume i)));
     ((=)  "APSubstInNode"  , (fun i ->  FMOTA_ap_subst_in  (read_apsubstinnode i)));
   ] in
   close_tag i "entry";
   {
     uid = uid;
     reference = symbol;
   }

let read_modules i =
  open_tag i "modules";
  let entries = get_children_in i "context" "entry" read_entry in
  let ret = get_children i "ModuleNode" read_module in
  close_tag i "modules";
  {
    entries = entries;
    modules = ret;
  }

let read_header i =
  input i (* first symbol is dtd *)

  (*while true do match (input i) with
  | `Data d -> print_string ("data: " ^ d ^ "\n")
  | `Dtd d -> print_string "dtd\n"
  | `El_start d -> print_string ("start: " ^ (snd(fst d)) ^ "\n")
  | `El_end -> print_string "end\n"
  done*)

let import_xml ic =
  let i = Xmlm.make_input (`Channel ic) in
  let _ = read_header i in
  read_modules i
  (*while not (Xmlm.eoi i) do match (Xmlm.input i) with
  done;
  assert false*)

