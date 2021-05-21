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
#include <limits.h>
#include <pwd.h>
#include <string.h>
#include "../include/cash.h"

char prev_wd[PATH_MAX];
char curr_wd[PATH_MAX];

int argc;
char **argv;
int child;
int exit_code;

fdqitem_t *fdqhead = NULL;
fdqitem_t *fdqtail = NULL;

child_process_t *cpqhead = NULL;
child_process_t *cpqtail = NULL;

void cash_init()
{
	getcwd(curr_wd, PATH_MAX);
	strcpy(prev_wd, curr_wd);
	argc = 0;
	argv = NULL;
	child = 0;
	exit_code = 0;
}

void set_file_descriptors(int *input, int *output)
{
	if (fdqhead) {
		*input = fdqhead->infd;
		*output = fdqhead->outfd;
		fdqitem_t *tmp = fdqhead;
		fdqhead = fdqhead->next;
		free(tmp);
	} else {
		*input = STDIN_FILENO;
		*output = STDOUT_FILENO;
	}
}

int internal_cd()
{
	int inputfd;
	int outputfd;
	set_file_descriptors(&inputfd, &outputfd);

	if (argc > 2) {
		fprintf(stderr, "cd: too many arguments\n");
		seterr(1);
		return 1;
	}

	if (argc < 2) {
		const char *home_dir = getenv("HOME");
		if (!home_dir)
			home_dir = getpwuid(getuid())->pw_dir;
		if (exit_code = chdir(home_dir))
			return 1;

		strcpy(prev_wd, curr_wd);
		strcpy(curr_wd, home_dir);
	} else if (!strcmp(argv[1], "-")) {
		if (exit_code = chdir(prev_wd))
			return 1;

		dprintf(outputfd, "%s\n", prev_wd);
		char *temp = prev_wd;
		strcpy(prev_wd, curr_wd);
		strcpy(curr_wd, temp);
	} else {
		if (exit_code = chdir(argv[1]))
			return 1;

		strcpy(prev_wd, curr_wd);
		getcwd(curr_wd, PATH_MAX);
	}

	exit_code = 0;
	return 0;
}

void internal_exit()
{
	/*
	 * While it might make sense to dequeue the pipe file descriptors here,
	 * there's no real need since the program will exit now and we can let
	 * the kernel clean up the memory for us.
	 */
	if (argc > 2) {
		fprintf(stderr, "exit: too many arguments\n");
		seterr(1);
		return;
	}
	exit(argc > 1 ? atoi(argv[0]) : exit_code);
}

/*
 * TODO: Error checking on pipe() and malloc()
 * Note that the linked list might not actually be necessary, depending on the
 * rest of the implementation of pipes. Revisit.
 */
void pass_pipe()
{
	int pipefd[2];

	pipe(pipefd);

	/*
	 * Every process gets two FDs, one for input and one for output.
	 * The first command (generally) gets stdin as input, and the last
	 * stdout as output. The fdq represents a queue with both input and
	 * output for each command in the prompt.
	 */
	fdqitem_t *newin = malloc(sizeof(fdqitem_t));
	newin->infd = pipefd[0];
	newin->outfd = STDOUT_FILENO;
	newin->next = NULL;

	if (!fdqhead) {
		fdqhead = malloc(sizeof(fdqitem_t));
		fdqhead->infd = STDIN_FILENO;
		fdqhead->outfd = pipefd[1];
		fdqtail = fdqhead;
	} else {
		fdqtail->outfd = pipefd[1];
	}
	fdqtail->next = newin;
	fdqtail = fdqtail->next;
}

void wait_pipe()
{
	while (cpqhead) {
		int status;
		int wait = waitpid(cpqhead->pid, &status, 0);
		child_process_t *tmp = cpqhead;
		cpqhead = cpqhead->next;
		free(tmp);
	}
	cpqtail = NULL;
}

void kill_pipe()
{
	/*
	 * We can't directly manipulate cpqhead or free the list because
	 * wait_pipe() might be running. At the same time, we can depend on
	 * wait_pipe() to clean up for us once the killing ends so it's fine.
	 */
	child_process_t *i = cpqhead;
	while (i) {
		kill(i->pid, SIGKILL);
		child_process_t *tmp = i;
		i = i->next;
	}
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

int execute(int use_pipe)
{
	if (!argc)
		return 0;

	if (!strcmp(argv[0], "cd"))
		return internal_cd();
	if (!strcmp(argv[0], "exit")) {
		internal_exit();
		return 0; /* Reachable */
	}

	int inputfd;
	int outputfd;
	set_file_descriptors(&inputfd, &outputfd);

	int pid = fork();
	if (pid == 0) { /* child */
		dup2(inputfd, STDIN_FILENO);
		dup2(outputfd, STDOUT_FILENO);
		if (inputfd != STDIN_FILENO)
			close(inputfd);
		if (outputfd != STDOUT_FILENO)
			close(outputfd);

		execvp(argv[0], argv);
		fprintf(stderr, "%s: No such file or directory\n", argv[0]);
		exit(127);
	} else if (use_pipe) { /* parent of piped process */
		if (inputfd != STDIN_FILENO)
			close(inputfd);
		if (outputfd != STDOUT_FILENO)
			close(outputfd);

		/* Add child to waiting queue */
		child_process_t *new_child = malloc(sizeof(child_process_t));
		new_child->next = NULL;
		new_child->pid = pid;

		if (cpqtail)
			cpqtail->next = new_child;
		else
			cpqhead = new_child;
		cpqtail = new_child;
	} else { /* parent of single process or last process in pipe */
		if (inputfd != STDIN_FILENO)
			close(inputfd);
		if (outputfd != STDOUT_FILENO)
			close(outputfd);

		int status;
		child = pid;
		wait_pipe(); /* Order is essential, close pipe before tail. */
		int wait = waitpid(child, &status, 0);
		if (wait < 0) {
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
	kill_pipe();
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

int geterr()
{
	return exit_code;
}
