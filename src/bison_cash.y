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
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <readline.h>
#include "include/cash.h"

extern FILE *yyin;

static char **gargv;

void handle_interrupt(int sig);
%}

%union {
	char *str;
	item_t *item;
}

%token INTERNCD INTERNEX
%token EXECUTAB
%token ARGUMENT
%token EOC EOL
%token SCERR

%type <item> ARGUMENT args
%%

prompt:
  /* nothing */
  | prompt EOL 
  | prompt command EOL 
  | prompt command EOC
  | prompt SCERR {
	fprintf(stderr, "error:%d: syntax error near unexpected token';'\n", 1);
	seterr(SYNTAX_ERROR); }
;

command:
    internal
  | executable
;

internal: 
    INTERNCD { internal_cd(NULL); }
  | INTERNCD ARGUMENT { internal_cd($2->str); free($2->str); free($2); }
  | INTERNEX { internal_exit(NULL); }
  | INTERNEX ARGUMENT { internal_exit($2->str); free($2->str); free($2); }
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

void handle_interrupt(int sig)
{
	if (kill_child())
		return;
	putchar('\n');
	execv(gargv[0], gargv);
	exit(127);
}

int main(int argc, char **argv)
{
	struct sigaction inthandler = { 
		.sa_handler = handle_interrupt,
		.sa_flags = SA_NODEFER
	};
	sigaction(SIGINT, &inthandler, 0);	

	cash_init();
	/*if (getopt(argc, argv) == 'c') {
		return 0;
	}*/
	
	if (argc > 1) {
		/* parse from file */
		yyin = fopen(argv[1], "r");
		yyparse();
		return 0;
	}	

	/* parse from readline */
	gargv = argv;
	gargv[0] = "/proc/self/exe";	
	
	read_history(HISTORY);
	yyparse();
}

int yyerror(char *s)
{
	fprintf(stderr, "error: %s\n", s);
}
