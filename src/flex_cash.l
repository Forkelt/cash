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
#include "include/cash.h"
#include "bison_cash.tab.h"
%}

%%

cd[ \t]* { BEGIN ARG; return INTERNCD; }
exit[ \t]* { BEGIN ARG; return INTERNEX; }
[A-Za-z0-9./]+ {
	BEGIN ARG;
	yylval.item = malloc(sizeof(item_t));
	yylval.item->str = strdup(yytext);
	yylval.item->prev = NULL;
	return EXECUTAB;
}
.*";"[ \t]*";".* { return SCERR; }
("#".*)?\n { return EOL; }
[ \t] {} /* ignore whitespace */
<ARG>";" { BEGIN INITIAL; return EOC; }
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
<ARG>. { printf("error\n"); }
%%
