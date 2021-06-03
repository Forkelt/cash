#ifndef _CASH_H_
#define _CASH_H_
#include <stdio.h>

#define OPTSTRING "c:"
#define HISTORY_LEN 1000
#define HISTORY "cashhistory.txt"
#define SIGNAL_BASE 128
#define PROMPT "cash$ "
#define SYNTAX_ERROR 254

typedef struct item {
	struct item *next;
	struct item *prev;
	char *str;
} item_t;

typedef struct child_process {
	struct child_process *next;
	pid_t pid;
} child_process_t;

void cash_init();
int pass_args(item_t *head);
void free_args(item_t *tail);
int set_redirect_input(char *path);
int set_redirect_output(char *path, int append);
int execute(int use_pipe);
int kill_child();
void seterr(int code);
int geterr();

#endif
