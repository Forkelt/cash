/*
 * Copyright (C) 2021 Thomas Folkert Mol
 * This work is free to be used, distributed, and modified under the terms of
 * EUPL-1.2-or-later. If you did not receive a copy of this licence with this
 * source code, you can find it at
 * https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
 * in your language of choice.
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "../lib/include/linenoise.h"
#include "../include/cash.h"
#include "../bison_cash.tab.h"

extern FILE *yyin;
static char **gargv;

void handle_interrupt(int sig)
{
	if (kill_child())
		return;
	putchar('\n');
	execv(gargv[0], gargv);
	exit(127);
}

void save_history(void)
{
	linenoiseHistorySave(HISTORY);
}

int main(int argc, char **argv)
{
	struct sigaction inthandler = {
		.sa_handler = handle_interrupt,
		.sa_flags = SA_NODEFER
	};
	sigaction(SIGINT, &inthandler, 0);

	cash_init();
	if (getopt(argc, argv, OPTSTRING) == 'c') {
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

	linenoiseHistorySetMaxLen(HISTORY_LEN);
	linenoiseHistoryLoad(HISTORY);
	/* Ensure linenoise's atexit() executes last by setting it first */
	linenoiseSetAtExit();
	/* Save history even if exited through internal exit command */
	atexit(save_history);
	yyparse();
	return geterr();
}
