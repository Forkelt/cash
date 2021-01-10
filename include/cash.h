#ifndef _CASH_H_
#define _CASH_H_
#include <stdio.h>

#define SIGNAL_BASE 128
#define PROMPT "mysh$ "
#define SYNTAX_ERROR 254

typedef struct item {
	struct item *next;
	struct item *prev;
	char *str;
} item_t;

void cash_init();
int internal_cd(char *arg);
void internal_exit(char *arg);
int pass_args(item_t *head);
void free_args(item_t *tail);
int execute();
int kill_child();
void seterr(int code);

#endif
