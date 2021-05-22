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

static int enable_error;
static char **gargv;

void handle_interrupt(int sig);
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
%token SCERR

%type <item> COMMAND command
%type <item> ARGUMENT args
%%

prompt:
  /* nothing */
  | prompt EOL
  | prompt redircommand EOL { execute(0); }
  | prompt redircommand EOC { execute(0); }
  | prompt redircommand PIPE { execute(1); }
  | prompt SCERR {
	fprintf(stderr, "error:%d: syntax error near unexpected token ';'\n",
		yylval.num);
	seterr(SYNTAX_ERROR); }
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
	enable_error = 1;

	struct sigaction inthandler = { 
		.sa_handler = handle_interrupt,
		.sa_flags = SA_NODEFER
	};
	sigaction(SIGINT, &inthandler, 0);	

	cash_init();
	if (getopt(argc, argv, OPTSTRING) == 'c') {
		enable_error = 0;
		yyin = fmemopen(argv[2], strlen(argv[2]), "r");
		yyparse();
		return geterr();
	}
	
	if (argc > 1) {
		/* parse from file */
		yyin = fopen(argv[1], "r");
		if (!yyin) {
			fprintf(stderr, "%s: file not found\n", argv[1]);
			return 1;
		}
		yyparse();
		return geterr();
	}	

	/* parse from readline */
	gargv = argv;
	gargv[0] = "/proc/self/exe";	
	
	read_history(HISTORY);
	yyparse();
}

int yyerror(char *s)
{
	if (enable_error)
		fprintf(stderr, "error: %s\n", s);
}
