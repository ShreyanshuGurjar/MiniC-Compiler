%{
   #include "a3.tab.h"
   #include <bits/stdc++.h>
   using namespace std;
   extern void yyerror(const char* c);
   extern int l_count;
%}

%%

\#include[ ]*\<stdio.h\>         {return HEADER;}
int                              {return INT;}
char                             {return CHAR;}
"["                              {return *yytext;}
"]"                              {return *yytext;}
"("                              {return *yytext;}
")"                              {return *yytext;}
"{"                              {return *yytext;}
"}"                              {return *yytext;}
","                              {return *yytext;}
";"                              {return *yytext;}
"="                              {return *yytext;}
if                               {yylval.val=l_count++; return IF;}
else                             {return ELSE;}
while                            {yylval.val=l_count++; return WHILE;}
return                           {return RET;}

[a-zA-Z_][a-zA-Z0-9_]*           {yylval.str=strdup(yytext); return VAR;}
\'([^\']|\\\'|\\0|\\\\|\\n)\'    {yylval.str=strdup(yytext); return SOME_CHAR;}
\"([^\"]|\\\")*\"                {yylval.str=strdup(yytext); return TEXT;}
[0-9]+                           {yylval.val=stoi(yytext); return CONST;}
"=="|"!="|"<="|">="|"<"|">"      {yylval.str=strdup(yytext); return COMP;}
"**"                             {return PWR;}
"!"                              {return NOT;}
"||"                             {return OR;}
"&&"                             {return AND;}
"//"[^\n]*                       {}
"/*"([^*]|\*+[^*/])*\*+"/"  ;    {}
"-"                              {return *yytext;}
"+"                              {return *yytext;}
[*/]                             {yylval.c=*yytext; return MD;}
[\n]                             {yylineno++;}
[ \t\r]                            {}
.                                {yyerror(strdup("Unknown Character"));}
%%

int yywrap(void){
   return 1;
}