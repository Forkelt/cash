/*
 * Copyright (C) 2021 Thomas Folkert Mol
 * This work is free to be used, distributed, and modified under the terms of
 * EUPL-1.2-or-later. If you did not receive a copy of this licence with this
 * source code, you can find it at
 * https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
 * in your language of choice.
 */
#include <stdio.h>
#include <syscall.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <linux/limits.h>
#include <pwd.h>
#include <string.h>
#include "../lib/include/linenoise.h"
#include "../include/cash.h"

char prev_wd[PATH_MAX];
char curr_wd[PATH_MAX];

int argc;
char **argv;

void cash_init()
{
	getcwd(curr_wd, PATH_MAX);
	strcpy(prev_wd, curr_wd);
	argc = 0;
	argv = NULL;
}

int internal_cd(char *arg)
{
	if (!arg) {
		const char *home_dir = getenv("HOME");
		if (!home_dir)
			home_dir = getpwuid(getuid())->pw_dir;
		if (chdir(home_dir))
			return 1;

		strcpy(prev_wd, curr_wd);
		strcpy(curr_wd, home_dir);
	} else if (!strcmp(arg, "-")) {
		printf("%s\n", prev_wd);
		char *temp = prev_wd;
		strcpy(prev_wd, curr_wd);
		strcpy(curr_wd, temp);
	} else {
		if (chdir(arg))
			return 1;

		strcpy(prev_wd, curr_wd);
		getcwd(curr_wd, PATH_MAX);
	}
	return 0;
}

int pass_args(item_t *head)
{
	if (!head)
		return 0;

	/* Reverse linked list */
	int count = 1;
	while (head->prev) {
		++count;
		head->prev->next = head;
		head = head->prev;
	}

	if (argv) {
		for (int i = 0; i < argc; ++i)
			free(argv[i]);
		free(argv);
	}

	argc = count;
	argv = malloc(sizeof(char *) * (argc + 1));
	if (!argv) {
		argc = 0;
		return 0;
	}
	argv[argc] = NULL;

	/* Traverse */
	item_t *prev;
	for (int i = 0; i < argc; ++i) {
		argv[i] = strdup(head->str);
		prev = head;
		head = head->next;
		free(prev->str);
		free(prev);
	}

	return count;
}

void free_args(item_t *tail)
{
	item_t *prev;
	while (tail) {
		prev = tail;
		tail = tail->prev;
		free(prev);
	}
}

int execute()
{
	if (!argc)
		return 0;

	int pid = fork();
	if (!pid) { /* child */
		execvp(argv[0], argv);
	} else {
		int status;
		wait(&status);
	}
}
