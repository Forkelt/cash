/*
 * Copyright (C) 2021 Thomas Folkert Mol
 * This work is free to be used, distributed, and modified under the terms of
 * EUPL-1.2-or-later. If you did not receive a copy of this licence with this
 * source code, you can find it at
 * https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
 * in your language of choice.
 */
%option noyywrap
%x ARG
%{
#include <readline.h>
#include <stdlib.h>
#include <signal.h>
#include "include/cash.h"
#include "bison_cash.tab.h"

#define YY_INPUT(buff, result, size) result = get_input(buff, size);

static int get_input(char *buff, int size)
{
	if (yyin != stdin) {
		int c = getc(yyin);
		return (c == EOF) ? YY_NULL : (buff[0] = c, 1);
	}

	char *line;
	if (feof(yyin))
		return YY_NULL;
	if ((line = readline(PROMPT)) == NULL)
		return YY_NULL;
	
	
	if (line[0] && line[0] != ' ') {
		add_history(line);
		write_history(HISTORY);
	}
	sprintf(buff, "%s\n", line);
	free(line);
	return strlen(buff);
}
%}

%%

cd[ \t]* { BEGIN ARG; yylval.item = NULL; return INTERNCD; }
exit[ \t]* { BEGIN ARG; yylval.item = NULL; return INTERNEX; }
[A-Za-z0-9./]+ {
	BEGIN ARG;
	yylval.item = malloc(sizeof(item_t));
	yylval.item->str = strdup(yytext);
	yylval.item->prev = NULL;
	return EXECUTAB;
}
.*";"[ \t]*";".* { yylval.num = yylineno; return SCERR; }
("#".*)?\n { return EOL; }
[ \t] {} /* ignore whitespace */
<ARG>";" { BEGIN INITIAL; return EOC; }
<ARG>"|" { BEGIN INITIAL; return PIPE; }
<ARG>[^ \t\n;]+ {
	/* Build a reversed linked list */
	item_t *prv = yylval.item;
	yylval.item = malloc(sizeof(item_t)); 
	yylval.item->str = strdup(yytext);
	yylval.item->prev = prv;
	return ARGUMENT; 
}
<ARG>("#".*)?\n { BEGIN INITIAL; return EOL; }
<ARG>[ \t] {} /* ignore whitespace */
%%
