#ifndef _CASH_H_
#define _CASH_H_
#include <stdio.h>

#define PROMPT "mysh$ "

typedef struct item {
	struct item *next;
	struct item *prev;
	char *str;
} item_t;

void cash_init();
int internal_cd(char *arg);
int pass_args(item_t *head);
void free_args(item_t *tail);
int execute();

#endif
