%x ARG
%{
#include "bison_cash.tab.h"
%}

%%

cd[ \t]* { BEGIN ARG; return INTERNCD; }
exit[ \t]* { BEGIN ARG; return INTERNEX; }
"./"[A-Za-z0-9./]+ { BEGIN ARG; return REL_EXEC; }
"/"[A-Za-z0-9./]+ { BEGIN ARG; return ABS_EXEC; }
[A-Za-z0-9./]+ { BEGIN ARG; return PAT_EXEC; }
";;" { printf("invalid ;;\n"); }
[ \t] {} /* ignore whitespace */
<ARG>[^ \t\n]+ { yylval.str = strdup(yytext); return ARGUMENT; }
<ARG>";;" { BEGIN INITIAL; printf("invalid ;;\n"); return EOL; }
<ARG>";" { BEGIN INITIAL; return EOL; }
<ARG>\n { BEGIN INITIAL; return EOL; }
<ARG>[ \t] {} /* ignore whitespace */
<ARG>. { printf("error\n"); }
%%
