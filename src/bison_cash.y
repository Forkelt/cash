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
#include <sys/queue.h>
#include "include/cash.h"

static char **gargv;
%}

%union {
	char *str;
	item_t *item;
}

%token INTERNCD INTERNEX
%token EXECUTAB
%token ARGUMENT
%token EOC EOL
%token INT

%type <item> ARGUMENT args
%%

prompt:
  /* nothing */
  | prompt EOL { printf("%s", PROMPT); }
  | prompt command EOL { printf("%s", PROMPT); }
  | prompt command EOC
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
	printf("execl failed\n");
	exit(127);
}

int main(int argc, char **argv)
{
	gargv = argv;
	gargv[0] = "/proc/self/exe";	

	struct sigaction inthandler = { 
		.sa_handler = handle_interrupt,
		.sa_flags = SA_NODEFER
	};
	sigaction(SIGINT, &inthandler, 0);
	
	cash_init();
	printf(PROMPT);
	yyparse();
}

int yyerror(char *s)
{
	fprintf(stderr, "error: %s\n", s);
}
