%{
#include <stdio.h>
%}

%union {
	char *str;
}

%token INTERNCD INTERNEX
%token REL_EXEC ABS_EXEC PAT_EXEC
%token ARGUMENT
%token EOL

%%

prompt:
  /* nothing */
  | prompt command EOL { printf("end prompt\n"); }
;

command:
    internal
  | executable
;

internal: 
    INTERNCD args { printf("cd %s\n", yylval.str); }
  | INTERNEX args { printf("exit\n"); }
;

executable:
    REL_EXEC args { printf("relative\n"); }
  | ABS_EXEC args { printf("absolute\n"); }
  | PAT_EXEC args { printf("path\n"); }
;

args:
  /* nothing */
  | args1
;

args1:
    ARGUMENT { printf("%s\n", yylval.str); }
  | args1 ARGUMENT { printf("%s\n", yylval.str); }
;

%%

int main(int argc, char **argv)
{
	yyparse();
}

int yyerror(char *s)
{
	fprintf(stderr, "error: %s\n", s);
}
