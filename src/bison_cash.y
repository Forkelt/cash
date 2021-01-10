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
#include <stdlib.h>
#include <string.h>
#include <sys/queue.h>
#include "include/cash.h"
%}

%union {
	char *str;
	item_t *item;
}

%token INTERNCD INTERNEX
%token EXECUTAB
%token ARGUMENT
%token EOL

%type <item> ARGUMENT args
%%

prompt:
  /* nothing */
  | prompt command EOL { printf("%s", PROMPT); }
;

command:
    internal
  | executable
;

internal: 
    INTERNCD args { internal_cd(yylval.str); }
  | INTERNEX args { printf("exit\n"); }
;

executable:
    EXECUTAB { pass_args(yylval.item); execute(); }
  | EXECUTAB args { pass_args($2); execute(); }
;

args:
    ARGUMENT args { $$ = $2; }
  | ARGUMENT { $$ = yylval.item; $$->next = NULL; }
;

%%

int main(int argc, char **argv)
{
	cash_init();
	printf(PROMPT);
	yyparse();
}

int yyerror(char *s)
{
	fprintf(stderr, "error: %s\n", s);
}
