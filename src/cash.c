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
#include <errno.h>
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
int child;
int exit_code;

void cash_init()
{
	getcwd(curr_wd, PATH_MAX);
	strcpy(prev_wd, curr_wd);
	argc = 0;
	argv = NULL;
	child = 0;
	exit_code = 0;
}

int internal_cd(char *arg)
{
	if (!arg) {
		const char *home_dir = getenv("HOME");
		if (!home_dir)
			home_dir = getpwuid(getuid())->pw_dir;
		if (exit_code = chdir(home_dir))
			return 1;

		strcpy(prev_wd, curr_wd);
		strcpy(curr_wd, home_dir);
	} else if (!strcmp(arg, "-")) {
		if (exit_code = chdir(prev_wd))
			return 1;

		printf("%s\n", prev_wd);
		char *temp = prev_wd;
		strcpy(prev_wd, curr_wd);
		strcpy(curr_wd, temp);
	} else {
		if (exit_code = chdir(arg))
			return 1;

		strcpy(prev_wd, curr_wd);
		getcwd(curr_wd, PATH_MAX);
	}

	exit_code = 0;
	return 0;
}

void internal_exit(char *arg)
{
	exit(arg ? atoi(arg) : exit_code);
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
		argv[i] = head->str;
		prev = head;
		head = head->next;
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
	if (pid == 0) { /* child */
		execvp(argv[0], argv);
		fprintf(stderr, "%s: No such file or directory\n", argv[0]);
		exit(127);
	} else {
		int status;
		child = pid;
		if (waitpid(child, &status, 0) < 0) {
			if (errno == EINTR) {
				child = 0;
				return 1;
			}
		}

		if (!WIFSIGNALED(status))
			exit_code = WEXITSTATUS(status);
		child = 0;
	}
	return 1;
}

int kill_child()
{
	if (child) {
		kill(child, SIGKILL);
		child = 0;
		fprintf(stderr, "Killed by signal %d.\n", SIGINT);
		exit_code = SIGNAL_BASE + SIGINT;
		return 1;
	} else {
		return 0;
	}
}

void seterr(int code)
{
	exit_code = code;
}
