/* -*-fundamental-*- */
/* $Id$ */

%{
#include "pub.h"
#include "pub_parse.h"
#include "parr.h"

%}

%token <str> T_NUM
%token <str> T_HNAM
%token <str> T_HVAL
%token <str> T_CODE
%token <str> T_STR
%token <str> T_VAR
%token <ch>  T_CH
%token <str> T_ETAG
%token <str> T_BJST
%token <str> T_EJS
%token <str> T_HTML
%token <str> T_GCODE
%token <str> T_BTAG
%token <str> T_BPRE
%token <str> T_EPRE

%token T_VARS
%token T_UVARS
%token T_PRINT
%token T_PTINCLUDE
%token T_PTSET
%token T_PTSETL
%token T_PTSWITCH
%token T_EPTAG
%token T_BVAR
%token T_ETAG
%token T_BCONF
%token T_BGCODE
%token T_BGCCE
%token T_INIT_PDL
%token T_EJS_SILENT
%token T_BJS_SILENT
%token T_2L_BRACE
%token T_2R_BRACE

%token T_INT_ARR
%token T_UINT_ARR
%token T_CHAR_ARR
%token T_INT16_ARR
%token T_UINT16_ARR
%token T_INT64_ARR
%token T_UINT64_ARR

%type <str> var str1 bname 
%type <num> number
%type <pvar> pvar evar
%type <pval> bvalue arr i_arr g_arr
%type <sec> htag htag_list javascript pre b_js_tag
%type <el> ptag
%type <func> ptag_func
%type <pstr> pstr pstr_sq
%type <arg> arg aarr nested_env
%type <parr> i_arr_open

%%
file: | hfile   {}
	| conffile {}
	;

conffile: T_BCONF aarr {}
	;

hfile: html 
	;

varlist: var 
	{
	  PGVARS->add ($1);
	}
	| varlist ',' var 
	{
	  PGVARS->add ($3);
	}
	;

html: /* empty */ {}
	| html html_part
	;

html_part: T_HTML 	{ PSECTION->hadd ($1); }
	| '\n'		{ PSECTION->hadd ('\n'); }	
	| evar		{ PSECTION->hadd (New pfile_var_t ($1, PLINENO)); }
	| T_CH		{ PSECTION->hadd ($1); }
	| htag		{ PSECTION->hadd ($1); PLASTHTAG = PHTAG; }
	| ' ' 		{ PSECTION->hadd_space (); }
	| javascript	{ PSECTION->hadd ($1); } 
	| ptag		{ PSECTION->hadd ($1); }
	| pre		{ PSECTION->hadd ($1); }
	;

nested_env: T_2L_BRACE
	{ 
 	  pfile_html_sec_t *s = New pfile_html_sec_t (PLINENO);
	  PFILE->push_section (s); 
	} 
        html T_2R_BRACE 
 	{
	  pfile_sec_t *s = PFILE->pop_section ();
	  $$ = New refcounted<nested_env_t> (s);
	}
	;

evar:     pvar
	;
	
ptag: ptag_func 
	{
 	  PUSH_PFUNC ($1);
	}
	ptag_list ptag_close
	{
	  if (!PFUNC->validate ()) 
	    PARSEFAIL;
	  $$ = POP_PFUNC();
	}
	;

ptag_close: ';' T_EPTAG
	| T_EPTAG
	;

ptag_func: T_PTINCLUDE  { $$ = New pfile_include2_t (PLINENO); }
	| T_PTSET	{ $$ = New pfile_set_func_t (PLINENO); }
	| T_PTSETL      { $$ = New pfile_set_local_func_t (PLINENO); }
	| T_PTSWITCH	{ $$ = New pfile_switch_t (PLINENO); }
	;

e_js_tag: T_EJS		{ PSECTION->add ($1); }
	| T_EJS_SILENT	{}
	;

javascript: b_js_tag js_code e_js_tag
	{
	  $$ = PSECTION;
	  PFILE->pop_section ();
	}
	;

pre: 	T_BPRE
	{
	  PFILE->push_section (New pfile_html_sec_t (PLINENO));
	  PSECTION->hadd ((PHTAG = New pfile_html_tag_t (PLINENO, $1)));
	}
	pre_body T_EPRE
	{
	  PSECTION->hadd ((PLASTHTAG = New pfile_html_tag_t (PLINENO, $4)));
	  $$ = PSECTION;
	  PFILE->pop_section ();
	}
	;

pre_body: /* empty */
	| pre_body pre_part
	;

pre_part: T_CH		{ PSECTION->add ($1); }
	| T_HTML	{ PSECTION->add ($1); }
	;
		
b_js_tag: T_BJST 
	{ 
 	  /* as a hack, we won't treat JavaScript section as explicit tags */
 	  PFILE->push_section (New pfile_html_sec_t (PLINENO));
	  PSECTION->add ($1);
  	  /* PSECTION->htag_space (); */
	} 
	htag_list T_ETAG
	{  
 	  PSECTION->add ($4);
	}
	| T_BJS_SILENT 
	{
	  /* we still need this here, even though it will most
	   * likely be empty
 	   */
	  PFILE->push_section (New pfile_html_sec_t (PLINENO));
        }
	;

js_code: /* empty */ 
	| js_code js_code_elem
	;

js_code_elem: T_CH  { PSECTION->add ($1); }
	| T_HTML    { PSECTION->add ($1); }
	| evar      { PSECTION->add (New pfile_var_t ($1, PLINENO)); }
	;

htag: T_BTAG
	{
	  PFILE->push_section ((PHTAG = New pfile_html_tag_t (PLINENO, $1)));
	}
  	htag_name htag_list T_ETAG
	{
	  if ($5[0] != '>') {
	    PSECTION->htag_space ();
 	  }
	  PSECTION->add ($5);
	  $$ = PSECTION;
	  PFILE->pop_section ();
	}
	;

htag_list: /* empty */ {}
	| htag_list htag_elem
	;

htag_elem: htag_name '=' { PSECTION->add ('='); } htag_val
	| htag_name
	;

htag_name: T_HNAM  
	{ 
	   PSECTION->htag_space ();
           PSECTION->add ($1); 
        }
	| evar     
	{ 
	   PSECTION->htag_space ();
	   PSECTION->add (New pfile_var_t ($1, PLINENO));  
	}
	;

htag_val: T_HNAM   { PSECTION->add ($1); }
	| T_HVAL   { PSECTION->add ($1); }
	| evar     { PSECTION->add (New pfile_var_t ($1, PLINENO)); }
	| pstr_sq
	{
 	   PSECTION->add ('\'');
	   PSECTION->add (New pfile_pstr_t ($1)); 
 	   PSECTION->add ('\'');
	}
	| pstr     
	{ 
 	   PSECTION->add ('"');
	   PSECTION->add (New pfile_pstr_t ($1)); 
 	   PSECTION->add ('"');
	}
	| T_STR
	{
	   PSECTION->add ('\'');
	   PSECTION->add ($1); 
	   PSECTION->add ('\'');
	}
	;

parg:   '('
	{
	  ARGLIST = New refcounted<arglist_t> ();
	} 
	arglist ')'
	{
	  if (!PFUNC->add (ARGLIST))
	    PARSEFAIL;	    
	  ARGLIST = NULL;
	}
	;

ptag_list: parg
	| ptag_list ',' parg
	;

arglist: arg 		    { ARGLIST->push_back ($1); }
	| arglist ',' arg   { ARGLIST->push_back ($3); }
	;

arg: /* empty */  { $$ = New refcounted<pval_null_t> (); }
	| var     { $$ = New refcounted<pstr_t> ($1); }
	| pstr    { $$ = $1; }
	| number  { $$ = New refcounted<pint_t> ($1); }
	| aarr    { $$ = $1; }
	| pvar    { $$ = New refcounted<pstr_t> ($1); }
	| nested_env { $$ = $1; }
	;

aarr: '{' 
	{
	  PAARR = New refcounted<aarr_arg_t> ();
	} 
	bind_list '}'
	{
	  $$ = PAARR;
	  PAARR = NULL;
	}
	; 

bind_list: binding
	| bind_list ',' binding
	;

binding: bname '=' bvalue	
	{
	  PAARR->add (New nvpair_t ($1, $3));
	}
	;

bname: var
	| str1
	;

bvalue:   number   { $$ = New refcounted<pint_t> ($1); }
	| var      { $$ = New refcounted<pstr_t> ($1); }
	| pstr     { $$ = $1; }
	| evar     { $$ = New refcounted<pstr_t> ($1); }
	| arr 	   { $$ = $1; }
	;

arr: i_arr | g_arr;

g_arr: '('
	{
	  parser->push_parr (New refcounted<parr_mixed_t> ());
	}
	g_arr_list ')'
	{
	  $$ = parser->pop_parr ();
	}
	;

i_arr: i_arr_open 
	{
	  parser->push_parr ($1);
	}
	i_arr_list ')'
	{
	  $$ = parser->pop_parr ();
	}
	;

i_arr_open: T_INT_ARR 	{ $$ = New refcounted<parr_int_t> (); }
	| T_CHAR_ARR 	{ $$ = New refcounted<parr_char_t> (); }
	| T_INT64_ARR 	{ $$ = New refcounted<parr_int64_t> (); }
	| T_INT16_ARR	{ $$ = New refcounted<parr_int16_t> (); }
	| T_UINT_ARR	{ $$ = New refcounted<parr_uint_t> (); }
	| T_UINT16_ARR 	{ $$ = New refcounted<parr_uint16_t> (); }
	;

i_arr_list: number		{ if (!PARR->add ($1)) PARSEFAIL; }
	| i_arr_list ',' number	{ if (!PARR->add ($3)) PARSEFAIL; }
	;

g_arr_list: bvalue		{ PARR->add ($1); }
	| g_arr_list ',' bvalue	{ PARR->add ($3); }
	;

pstr: '"' 
	{
	  PPSTR = New refcounted<pstr_t> ();
	}
	pstr_list '"'
	{
   	  $$ = PPSTR;
	  PPSTR = NULL;
	}
	;

pstr_sq: '\'' 
	{
	  PPSTR = New refcounted<pstr_t> ();
	}
	pstr_list '\''
	{
   	  $$ = PPSTR;
	  PPSTR = NULL;
	}
	;

pstr_list: /* empty */ {}
	| pstr_list pstr_el
	;

pstr_el:  T_STR { PPSTR->add ($1); }
	| T_CH  { PPSTR->add ($1); }
	| pvar  { PPSTR->add ($1); }
	;

pvar: T_BVAR T_VAR '}'
	{
	  $$ = New refcounted<pvar_t> ($2, PLINENO);
	}
	;

str1: '"'
	{
	  PSTR1 = New concatable_str_t ();
	} 
	str1_list '"'
	{
	  $$ = PSTR1->to_str ();
	  delete PSTR1; /* XXX -  probably can't do this */
	  PSTR1 = NULL;
	}
	;

str1_list: /* empty */ {}
	| str1_list str1_el
	;

str1_el: T_STR     { PSTR1->concat ($1); }
	| T_CH     { PSTR1->concat ($1); }
	;

number: T_NUM 
	{ 
	  u_int64_t tmp = strtoull ($1, NULL, 0); 
	  $$ = ($1[0] == '-' ? 0 - tmp : tmp);
	} 
	;

var: T_VAR
	;
