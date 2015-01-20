open Ast_mapper
open Ast_helper
open Asttypes
open Parsetree
open Longident


(* All sections enabled *)
let all_sects = ref false


(* Hash table for active sections *)
let active_sects : (string, unit) Hashtbl.t = Hashtbl.create 7 


(* Filter out @trace attributes from list of attributes and return an
   expression for each @trace attribute 

   Preserve the order of kept attributes and expressions generated
   from trace attributes *)
let rec split_trace_attrs (attrs, trace_attrs) = function

  (* Return attributes in original order *)
  | [] -> List.rev attrs, List.rev trace_attrs

  (* Attribute is @trace *)
  | ({ txt = "trace"; loc },
     
     (* Format of payload is [@trace sect fmt args ...] *)
     PStr
       [{pstr_desc =
           Pstr_eval
	     ({pexp_desc =
		 Pexp_apply
		   (({pexp_desc =
		       Pexp_ident {txt = Lident sect}}),
		    (("",
		      {pexp_desc =
			  Pexp_constant (Const_string _)} as fmt) ::
			args))}, _)}]) ::
      tl ->

    (* Section is enabled? *)
    if !all_sects || Hashtbl.mem active_sects sect then 
    
      (* Create expression [Trace.log "sect" fmt args ...] *)
      let trace_expr =
	Exp.apply
	  (Exp.ident { loc = Location.none; txt = Ldot (Lident "Trace", "log") })
	  (("", Exp.constant (Const_string (sect, None))) :: fmt :: args)
      in
      
      (* Continue with remaining attributes *)
      split_trace_attrs (attrs, trace_expr :: trace_attrs) tl

    (* Section is not enabled *)
    else

      (* Continue with remaining attributes *)
      split_trace_attrs (attrs, trace_attrs) tl
      
	
  (* Fail if payload is not as expected *)
  | ({ txt = "trace"; loc }, _) :: tl ->
    
    raise
      (Location.Error
	 (Location.error ~loc "Invalid syntax for @trace attribute"))
      
  (* Continue for other attribute *)
  | h :: tl -> split_trace_attrs (h :: attrs, trace_attrs) tl
	  

(* Mapper for expression *)
let expression mapper = function

  (* Delegate to default mapper for expression without attributes *)
  | ({ pexp_attributes = [] } as expr) -> default_mapper.expr mapper expr 

  (* Expression has attributes *)
  | ({ pexp_attributes = attrs } as expr) ->

    (* Filter out @trace attributes and create an expresssions for each *)
    let attrs', tracelogs = split_trace_attrs ([], []) attrs in

    (* Update attributes to expression *)
    let expr' = { expr with pexp_attributes = attrs' } in
    
    (* Were there @trace attributes? *)
    match tracelogs with

      (* Delegate to default mapper *)
      | [] -> default_mapper.expr mapper expr' 

      (* Split off expression for first attribute *)
      | h :: tl ->

	(* Replace 

	   expr
	     [@attr1]
	     [@trace sect1 fmt1 args1]
	     [@trace sect2 fmt2 args2] 
	     [@attr2]

	   with 

	   let __ppx_trace_log_res = expr [@attr1] [@attr2] in
	   Trace.log sect1 fmt1 args1; 
	   Trace.log sect2 fmt2 args2; 
	   __ppx_trace_log_res

	*)
	Exp.let_
	  Nonrecursive
	  [Vb.mk
	      (Pat.var { txt = "__ppx_trace_log_res"; loc = Location.none })
	      (default_mapper.expr mapper expr')]
	  (Exp.sequence
	     (List.fold_left Exp.sequence h tl)
	     (Exp.ident { txt = Lident "__ppx_trace_log_res"; loc = Location.none }))

	  
(* Rewrite expressions only *)
let trace_log_mapper argv = { default_mapper with expr = expression }
  
  
(* Register syntax extension *)
let () = register "trace_log" trace_log_mapper
  
