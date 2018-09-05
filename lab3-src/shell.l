
/*
 *
 * CS-252 Fall 2013
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>
#include "y.tab.h"
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/prctl.h>

int BUFFSIZE = 1024;

static void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
    unput(c);
}

%}

%%

[^ \t\n<>&\|]*(\\.[^ \t\n<>&\|]*)* {
		yylval.string_val = strdup(yytext);

		int length = strlen(yylval.string_val);
		char temp[length + 1];

		int i = 0;
		for (int j = 0; j < length; j++) {
			if(yylval.string_val[j] == '\\') {
				temp[i++] = yylval.string_val[++j];
			} else {
				temp[i++] = yylval.string_val[j];
			}
		}
		temp[i] = '\0';
		strcpy(yylval.string_val, temp);
		return WORD;
}

\n 	{
		return NEWLINE;
	}

[ \t] 	{
		/* Discard spaces and tabs */
     	}	

">" {
		return GREAT;
	}

"|" {
		return PIPE;
	}

"<" {
   		return LESS;
    }

"&" {
   		return AMPERSAND;	
    }

">>" {
   		return GREATGREAT;	
     }

">&" {
		return GREATAMPERSAND;
	 }

">>&" {
   	      return GREATGREATAMPERSAND; 	
   	  }



\"[^\n\"]*\" {
		yytext = (char *) (yytext + 1); //moves to first character after quote
		yytext[strlen(yytext) - 1] = '\0'; //removes second quote
		yylval.string_val = strdup(yytext);
		return WORD;
}

