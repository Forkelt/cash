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
%x INIREDIN
%x INIREDAP
%x INIREDOU
%x ARGREDIN
%x ARGREDAP
%x ARGREDOU
%{
#include <signal.h>
#include <stdlib.h>
#include "bison_cash.tab.h"
#include "include/cash.h"
#include "lib/include/linenoise.h"

#define YY_INPUT(buff, result, size) result = get_input(buff, size);

item_t *prev_arg;

static int get_input(char *buff, int size)
{
	if (yyin != stdin) {
		int c = getc(yyin);
		if (c == EOF)
			return YY_NULL;
		buff[0] = c;
		int read_ahead = getc(yyin);
		if (read_ahead == EOF) {
			buff[1] = '\n'; /* Ensure end is detected by parser */
			return 2;
		}
		ungetc(read_ahead, yyin);
		return 1;
	}

	char *line;
	if (feof(yyin))
		return YY_NULL;
	if ((line = linenoise(PROMPT)) == NULL)
		return YY_NULL;
	
	if (line[0] && line[0] != ' ') {
		linenoiseHistoryAdd(line);
	}
	sprintf(buff, "%s\n", line);
	free(line);
	return strlen(buff);
}
%}

%%

"<"[ \t]* { BEGIN INIREDIN; }
">>"[ \t]* { BEGIN INIREDAP; }
">"[ \t]* { BEGIN INIREDOU; }
[A-Za-z0-9./]+ {
	BEGIN ARG;
	yylval.item = malloc(sizeof(item_t));
	yylval.item->str = strdup(yytext);
	yylval.item->prev = NULL;
	prev_arg = yylval.item;
	return COMMAND;
}
.*";"[ \t]*";".*\n? { yylval.num = yylineno; return SCERR; } /* match ;; */
.*"|"[ \t]*"|".*\n? { yylval.num = yylineno; return PPERR; } /* match || */
.*[><]{3,}.* { yylval.num == yylineno; return SNERR; } /* match invalid redirects */
("#".*)?\n { return EOL; }
[ \t] {} /* ignore whitespace */

<ARG>";" { BEGIN INITIAL; return EOC; }
<ARG>"|" { BEGIN INITIAL; return PIPE; }
<ARG>"<"[ \t]* { BEGIN ARGREDIN; }
<ARG>">>"[ \t]* { BEGIN ARGREDAP; }
<ARG>">"[ \t]* { BEGIN ARGREDOU; }
<ARG>[^ ><\t\n;]+ {
	/* Build a reversed linked list */
	yylval.item = malloc(sizeof(item_t)); 
	yylval.item->str = strdup(yytext);
	yylval.item->prev = prev_arg;
	prev_arg = yylval.item;
	return ARGUMENT; 
}
<ARG>("#".*)?\n { BEGIN INITIAL; return EOL; }
<ARG>[ \t] {} /* ignore whitespace */

<INIREDIN>[^ \t\n;]* { 
	BEGIN INITIAL;
	yylval.str = strdup(yytext); 
	return READFROM; 
}
<INIREDAP>[^ \t\n;]* {
	BEGIN INITIAL;
	yylval.str = strdup(yytext);
	return APPENDTO;
}
<INIREDOU>[^ \t\n;]* {
	BEGIN INITIAL;
	yylval.str = strdup(yytext);
	return WRITETO;
}

<ARGREDIN>[^ \t\n;]* { 
	BEGIN ARG; 
	yylval.str = strdup(yytext); 
	return READFROM; 
}
<ARGREDAP>[^ \t\n;]* {
	BEGIN ARG;
	yylval.str = strdup(yytext);
	return APPENDTO;
}
<ARGREDOU>[^ \t\n;]* {
	BEGIN ARG;
	yylval.str = strdup(yytext);
	return WRITETO;
}
%%
