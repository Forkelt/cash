/*
 * Copyright (C) 2021 Thomas Folkert Mol
 * This work is free to be used, distributed, and modified under the terms of
 * EUPL-1.2-or-later. If you did not receive a copy of this licence with this
 * source code, you can find it at
 * https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
 * in your language of choice.
 */
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include "../include/cash.h"

char prev_wd[PATH_MAX];
char curr_wd[PATH_MAX];

int argc;
char **argv;
int child;
int exit_code;

int pipe_input = STDIN_FILENO;
int redir_input = 0;
int redir_output = 0;

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

int internal_cd(int outputfd)
{
	if (argc > 2) {
		fprintf(stderr, "cd: too many arguments\n");
		seterr(1);
		return 1;
	}

	if (argc < 2) {
		const char *home_dir = getenv("HOME");
		if (!home_dir)
			home_dir = getpwuid(getuid())->pw_dir;
		if ((exit_code = chdir(home_dir)))
			return 1;

		strcpy(prev_wd, curr_wd);
		strcpy(curr_wd, home_dir);
	} else if (!strcmp(argv[1], "-")) {
		if ((exit_code = chdir(prev_wd)))
			return 1;

		dprintf(outputfd, "%s\n", prev_wd);
		char *temp = prev_wd;
		strcpy(prev_wd, curr_wd);
		strcpy(curr_wd, temp);
	} else {
		if ((exit_code = chdir(argv[1])))
			return 1;

		strcpy(prev_wd, curr_wd);
		getcwd(curr_wd, PATH_MAX);
	}

	exit_code = 0;
	return 0;
}

void internal_exit()
{
	if (argc > 2) {
		fprintf(stderr, "exit: too many arguments\n");
		seterr(1);
		return;
	}
	exit(argc > 1 ? atoi(argv[0]) : exit_code);
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

int set_redirect_input(char *path)
{
	if (redir_input)
		close(redir_input);
	redir_input = open(path, O_RDONLY);
	if (redir_input == -1) {
		fprintf(stderr, "error: failed to open file %s\n", path);
		redir_input = 0;
		return 0;
	}
	return 1;
}

int set_redirect_output(char *path, int append)
{
	if (redir_output)
		close(redir_output);
	if (append)
		redir_output = open(path, O_WRONLY | O_CREAT | O_APPEND, S_IRWXU);
	else
		redir_output = open(path, O_WRONLY | O_CREAT, S_IRWXU);
	if (redir_output == -1) {
		fprintf(stderr, "error: failed to open file %s\n", path);
		redir_output = 0;
		return 0;
	}
	return 1;
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

	int inputfd = pipe_input;
	int outputfd = STDOUT_FILENO;
	if (use_pipe) {
		int pipefd[2];
		pipe(pipefd);
		pipe_input = pipefd[0];
		outputfd = pipefd[1];
	}
	if (redir_input) {
		if (inputfd != STDIN_FILENO)
			close(inputfd);
		inputfd = redir_input;
		redir_input = 0;
	}
	if (redir_output) {
		if (outputfd != STDOUT_FILENO)
			close(outputfd);
		outputfd = redir_output;
		redir_output = 0;
	}


	if (!strcmp(argv[0], "cd"))
		return internal_cd(outputfd);
	if (!strcmp(argv[0], "exit")) {
		internal_exit();
		return 0; /* Reachable */
	}

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
		pipe_input = STDIN_FILENO; /* Next command uses stdin again */
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
