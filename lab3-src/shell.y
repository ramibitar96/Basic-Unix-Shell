
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%token	<string_val> WORD

%token 	NOTOKEN GREAT NEWLINE PIPE LESS AMPERSAND GREATGREAT GREATAMPERSAND GREATGREATAMPERSAND

%union	{
		char   *string_val;
	}

%{

//#define yylex yylex
#include <stdio.h>
#include <stdlib.h>
#include "command.h"
#include <string.h>
#include <sys/types.h>
#include <regex.h>
#include <dirent.h>
#include <assert.h>
#include "command.h"
#include <pwd.h>
#include <unistd.h>

#define MAXLENGTH 1024

void yyerror(const char * s);
int comp(const void * str1, const void * str2);
void expandWildcard(char * prefix, char * suffix);
int yylex();

%}

%%

goal:	
	commands
	;

commands: 
	command
	| commands command 
	;

command: simple_command
        ;

simple_command:	
	pipe_list iomodifier_list background_opt NEWLINE {
		//printf("   Yacc: Execute command\n");
		Command::_currentCommand.execute();
	}
	| NEWLINE 
	| error NEWLINE { yyerrok; }
	;

command_and_args:
	command_word argument_list {
		Command::_currentCommand.
			insertSimpleCommand( Command::_currentSimpleCommand );
	}
	;


argument_list:
	argument_list argument
	| /* can be empty */
	;

argument:
	WORD {
              //printf("   Yacc: insert argument \"%s\"\n", $1);
              //Command::_currentSimpleCommand->insertArgument( $1 );
	      	expandWildcard(NULL ,$1);
  	}
	;

command_word:
	WORD {
              //printf("   Yacc: insert command \"%s\"\n", $1);
	       
	       Command::_currentSimpleCommand = new SimpleCommand();
	       Command::_currentSimpleCommand->insertArgument( $1 );
	}
	;


iomodifier_list: 
	iomodifier_list iomodifier_opt
	| iomodifier_opt
	|
	;

pipe_list: 
	pipe_list PIPE command_and_args
	| command_and_args
	|
	;

iomodifier_opt:
	GREAT WORD {
	//	printf("   Yacc: insert output \"%s\"\n", $2);

		if (Command::_currentCommand._inFile) { 
			printf("Ambiguous input redirect");
			exit(0);
		}

		if (Command::_currentCommand._outFile) { 
			printf("Ambiguous output redirect");
			exit(0);
		}
		Command::_currentCommand._outFile = $2;
	}
	|
	LESS WORD {
	//	printf("   Yacc: insert input \"%s\"\n", $2);
		if (Command::_currentCommand._inFile) { 
			printf("Ambiguous input redirect");
			exit(0);
		}

		if (Command::_currentCommand._outFile) { 
			printf("Ambiguous output redirect");
			exit(0);
		}
		Command::_currentCommand._inFile = $2;

	}
	| 
	GREATGREAT WORD {
	//	printf("   Yacc: append output \"%s\"\n", $2);
		if (Command::_currentCommand._inFile) { 
			printf("Ambiguous input redirect");
			exit(0);
		}

		if (Command::_currentCommand._outFile) { 
			printf("Ambiguous output redirect");
			exit(0);
		}
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._append = $2;
	}
	|
	GREATAMPERSAND WORD {
	//	printf("   Yacc: insert output from stdout and stderr \"%s\"\n", $2);
		if (Command::_currentCommand._inFile) { 
			printf("Ambiguous input redirect");
			exit(0);
		}

		if (Command::_currentCommand._outFile) { 
			printf("Ambiguous output redirect");
			exit(0);
		}
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._errFile = strdup($2);
	}
	|
	GREATGREATAMPERSAND WORD {
	//	printf("   Yacc: append output from stdout and stderr \"%s\"\n", $2);
		if (Command::_currentCommand._inFile) { 
			printf("Ambiguous input redirect");
			exit(0);
		}

		if (Command::_currentCommand._outFile) { 
			printf("Ambiguous output redirect");
			exit(0);
		}
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._errFile = strdup($2);
		Command::_currentCommand._append = $2;
	}
	;

background_opt: 
	AMPERSAND {
		//printf("   Yacc: run in background");
		if (Command::_currentCommand._inFile) { 
			printf("Ambiguous input redirect");
			exit(0);
		}

		if (Command::_currentCommand._outFile) { 
			printf("Ambiguous output redirect");
			exit(0);
		}
		Command::_currentCommand._background = 1;
	}
	|
	;



%%

void
yyerror(const char * s)
{
	fprintf(stderr,"%s", s);
}

void expandWildcard(char * prefix, char * suffix) {
	//create array
	int nEntries = 0;
	int maxEntries = 20;
	char** array = (char**) malloc(maxEntries * sizeof(char *));

	//if suffix is null insert prefix and return
	if (suffix[0] == 0) {
		Command::_currentSimpleCommand->insertArgument(strdup(prefix));
		return;
	}

	//obtain and advance suffix
	char * s = strchr(suffix, '/');
	char component[MAXLENGTH] = "";
	if (s != NULL) {
		strncpy(component, suffix, s - suffix);
		suffix = s + 1;
	} else {
		strcpy(component, suffix);
		suffix = suffix + strlen(suffix);
	}

	//if component doesn't contain a wildcard
	char newPrefix[MAXLENGTH];
	if (strchr(component, '*') == NULL && strchr(component, '?') == NULL) {
		if (prefix == NULL)
			sprintf(newPrefix, "%s", component);
		else
			sprintf(newPrefix, "%s/%s", prefix, component);
		expandWildcard(newPrefix, suffix);
		return;
	}

	//convert and compile regex
  	char * reg = (char *) malloc(2*strlen(component)+10);
	char * a   = component;
	char * r   = reg;

	*r = '^'; r++; // match beginning of line
	while (*a) {
		if (*a == '*') { 
			*r = '.'; 
			r++; 
			*r = '*'; 
			r++; 
		} else if (*a == '?') { 
			*r = '.'; 
			r++; 
		} else if (*a == '.') { 
			*r = '\\'; 
			r++; 
			*r = '.'; 
			r++; 
		} else { 
			*r = *a; 
			r++; 
		}
		a++;
	}
	*r='$'; r++; *r='\0';
	
	regex_t re;
	int expbuf = regcomp(&re, reg, REG_EXTENDED|REG_NOSUB);
	if (expbuf != 0) {
		perror("bad regular expression");
		exit(1);
	}

	//if prefix is empty then list current dir
	char * dir;
	if (prefix == NULL) {
		dir = (char *) ".";
	} else if(!strcmp("", prefix)) {
		dir = strdup("/");
	} else {
		dir = prefix;
	}

	DIR * d = opendir(dir);
	if (d == NULL) 
		return;
	
	//Now we need to check what entries match
	struct dirent * ent;
    regmatch_t match;
	while((ent = readdir(d)) != NULL) {
		if (regexec(&re, ent->d_name, 1, &match, 0) == 0) {
			
			if (nEntries == maxEntries) {
				maxEntries*=2;
				array = (char **) realloc(array, maxEntries*sizeof(char *));
			}

			if (ent->d_name[0] == '.') {
				if (component[0] == '.') {
					if (prefix == NULL) {
						sprintf(newPrefix, "%s", ent->d_name);
						array[nEntries++] = strdup(newPrefix);
					} else {
						sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
						array[nEntries++] = strdup(newPrefix);
					}
				}
			} else {
				if (prefix == NULL) {
					sprintf(newPrefix, "%s", ent->d_name);
					array[nEntries++] = strdup(newPrefix);
				} else {
					sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
					array[nEntries++] = strdup(newPrefix);
				}
			}
		}
	}

	closedir(d);
	char newPrefix2[MAXLENGTH] = "";
	qsort(array, nEntries, sizeof(char *), comp);
	//recursively call sorted entries
	for (int i = 0; i < nEntries; i++)  { 
			sprintf(newPrefix2, "%s", array[i]);
    	expandWildcard(newPrefix2, suffix);
  	}
  
 	if(array != NULL)
    free(array);
    array = NULL;
	return;
}

int comp(const void *str1, const void *str2)
{
  return strcmp(*(char *const*)str1, *(char *const*)str2);
}

#if 0
main()
{
	yyparse();
}
#endif
