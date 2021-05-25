/*
 * Copyright (C) 2021 Thomas Folkert Mol
 * This work is free to be used, distributed, and modified under the terms of
 * EUPL-1.2-or-later. If you did not receive a copy of this licence with this
 * source code, you can find it at
 * https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
 * in your language of choice.
 */
%{
#include <stdio.h>
#include <unistd.h>
#include "include/cash.h"
%}

%union {
	int num;
	char *str;
	item_t *item;
}

%token INTERNCD INTERNEX
%token COMMAND
%token ARGUMENT
%token EOC EOL
%token READFROM WRITETO APPENDTO
%token PIPE
%token SCERR PPERR SNERR

%type <item> COMMAND command
%type <item> ARGUMENT args
%%

prompt:
  /* nothing */
  | prompt EOL
  | prompt redircommand EOL { execute(0); }
  | prompt redircommand EOC { execute(0); }
  | prompt redircommand PIPE { execute(1); }
  | prompt syntax_error { seterr(SYNTAX_ERROR); }
;

redircommand:
    command
  | redirects command
;

command:
    COMMAND { pass_args(yylval.item); }
  | COMMAND args { pass_args($2); }
  | COMMAND redirects { pass_args($1); }
  | COMMAND redirects args { pass_args($3); }
;

args:
    ARGUMENT args { $$ = $2; }
  | ARGUMENT { $$ = yylval.item; $$->next = NULL; }
  | ARGUMENT redirects { $$ = $1; $$->next = NULL; }
  | ARGUMENT redirects args { $$ = $3; }
;

redirects:
    redirect
  | redirects redirect
;

redirect:
    READFROM { set_redirect_input(yylval.str); free(yylval.str); }
  | WRITETO { set_redirect_output(yylval.str, 0); free(yylval.str); }
  | APPENDTO { set_redirect_output(yylval.str, 1); free(yylval.str); }
;

syntax_error:
    SCERR{ fprintf(stderr, "error:%i: syntax error near unexpected token ';'\n", yylval.num); }
  | PPERR { fprintf(stderr, "error:%i: syntax error near unexpected token '|'\n", yylval.num); }
  | SNERR { fprintf(stderr, "error:%i: syntax error\n", yylval.num); }
%%

int yyerror(char *s)
{
	fprintf(stderr, "error: %s\n", s);
}
