
/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>
#include <fcntl.h>
#include <pwd.h>
#include "command.h"

SimpleCommand::SimpleCommand()
{
	// Create available space for 5 arguments
	_numOfAvailableArguments = 5;
	_numOfArguments = 0;
	_arguments = (char **) malloc( _numOfAvailableArguments * sizeof( char * ) );
}

void
SimpleCommand::insertArgument( char * argument )
{
	if ( _numOfAvailableArguments == _numOfArguments  + 1 ) {
		// Double the available space
		_numOfAvailableArguments *= 2;
		_arguments = (char **) realloc( _arguments,
				  _numOfAvailableArguments * sizeof( char * ) );
	}
	char * newArgument = (char *) malloc (1024 * sizeof(char));
	char * newArgument2 = (char *) malloc (1024 * sizeof(char));
	char * finalArgument = (char *) malloc (1024 * sizeof(char));
	int i = 0;
	int j = 0;
	//variable expansion
	if (strchr(argument, '$')) {
		while (argument[i] != '\0') {
			if (argument[i] == '$' && argument[i + 1] == '{') { 
				i += 2;
				while (argument[i] != '}') {
					newArgument[j] = argument[i];
					j++;
					i++;
				}
				newArgument[j] = '\0';
				strcat(finalArgument, getenv(newArgument));
				j = 0;
			} else {
				while(argument[i] != '\0' && argument[i] != '$') {
					newArgument2[j] = argument[i];
					j++;
					i++;
				}
				j = 0;
				strcat(finalArgument, newArgument2);
				i--;
			}
			i++;
		}
		argument = strdup(finalArgument);
	}
	//tilde expansion
	if (argument[0] == '~') {
		struct passwd *pw = getpwuid(getuid());
		const char *homedir = pw->pw_dir;
		if (argument[1] == '\0') 
			argument = strdup(getenv("HOME"));
		else 
			argument = strdup(getpwnam(argument + 1)->pw_dir);
	}
	
	_arguments[ _numOfArguments ] = argument;
	_arguments[ _numOfArguments + 1] = NULL;
	_numOfArguments++;
}

Command::Command()
{
	// Create available space for one simple command
	_numOfAvailableSimpleCommands = 10;
	_simpleCommands = (SimpleCommand **)
		malloc( _numOfSimpleCommands * sizeof( SimpleCommand * ) );

	_numOfSimpleCommands = 0;
	_outFile = 0;
	_inFile = 0;
	_errFile = 0;
	_background = 0;
	_append = 0;
}

void
Command::insertSimpleCommand( SimpleCommand * simpleCommand )
{
	if ( _numOfAvailableSimpleCommands == _numOfSimpleCommands ) {
		_numOfAvailableSimpleCommands *= 2;
		_simpleCommands = (SimpleCommand **) realloc( _simpleCommands,
			 _numOfAvailableSimpleCommands * sizeof( SimpleCommand * ) );
	}
	
	_simpleCommands[ _numOfSimpleCommands ] = simpleCommand;
	_numOfSimpleCommands++;
}

void
Command:: clear()
{
	for ( int i = 0; i < _numOfSimpleCommands; i++ ) {
		for ( int j = 0; j < _simpleCommands[ i ]->_numOfArguments; j ++ ) {
			free ( _simpleCommands[ i ]->_arguments[ j ] );
		}
		
		free ( _simpleCommands[ i ]->_arguments );
		free ( _simpleCommands[ i ] );
	}

	if ( _outFile ) {
		free( _outFile );
	}

	if ( _inFile ) {
		free( _inFile );
	}

	if ( _errFile ) {
		free( _errFile );
	}

	_numOfSimpleCommands = 0;
	_outFile = 0;
	_inFile = 0;
	_errFile = 0;
	_background = 0;
	_append = 0;
}

void
Command::print()
{
	printf("\n\n");
	printf("              COMMAND TABLE                \n");
	printf("\n");
	printf("  #   Simple Commands\n");
	printf("  --- ----------------------------------------------------------\n");
	
	for ( int i = 0; i < _numOfSimpleCommands; i++ ) {
		printf("  %-3d ", i );
		for ( int j = 0; j < _simpleCommands[i]->_numOfArguments; j++ ) {
			printf("\"%s\" \t", _simpleCommands[i]->_arguments[ j ] );
		} printf("\n");
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background\n" );
	printf( "  ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s\n", _outFile?_outFile:"default",
		_inFile?_inFile:"default", _errFile?_errFile:"default",
		_background?"YES":"NO");
	printf( "\n\n" );
	
}

void
Command::execute()
{
	// Don't do anything if there are no simple commands
	if ( _numOfSimpleCommands == 0 ) {
		prompt();
		return;
	}

	if(_numOfSimpleCommands == 1 && !strcmp( _simpleCommands[0]->_arguments[0], "exit" ))  {
	    exit(0);
	}

	//change directory
	if (!strcmp( _simpleCommands[0]->_arguments[0], "cd" )) {
		int cd;
		if (_simpleCommands[0]->_numOfArguments == 1) {
			cd = chdir(getenv("HOME"));
		} else {
			cd = chdir(_simpleCommands[0]->_arguments[1]);
		}
		if (cd != 0) {
			perror("cd");
		}
		clear();
		prompt();
		return;
	}

	//setenv
	if (!strcmp( _simpleCommands[0]->_arguments[0], "setenv" )) {
		int set;
		set = setenv(_simpleCommands[0]->_arguments[1], _simpleCommands[0]->_arguments[2], 1);
		clear();
		prompt();
		return;
	}

	//unsetenv
	if (!strcmp( _simpleCommands[0]->_arguments[0], "unsetenv" )) {
		int unset;
		unset = unsetenv(_simpleCommands[0]->_arguments[1]);
		clear();
		prompt();
		return;
	}

	// Print contents of Command data structure
	//print();

	// Add execution here
	// For every simple command fork a new process
	// Setup i/o redirection
	// and call exec

	//save defaults
	int tempin = dup(0);
	int tempout = dup(1);
	int temperr = dup(2);

	//get input
	int fdin;
	if (_inFile) 
		fdin = open(Command::_inFile, O_RDONLY);
	else 
		fdin = dup(tempin);

	int ret;
	int fdout;
	int fderr;
	//loop through commands
	for (int i = 0; i < _numOfSimpleCommands; i++) {
		dup2(fdin,0);
		close(fdin);

		//if last command
		if (i == (_numOfSimpleCommands - 1)) {
		//if outfule is defined
			if (_outFile) {
				if (_append) {
					fdout = open(_outFile, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR | S_IXUSR);
				} else {
					fdout = open(_outFile, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IXUSR);
				}
			} else {
				fdout = dup(tempout);
			}
		//if errfile is defined
		if (_errFile) {
				if (_append) {
					fderr = open(_errFile, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR | S_IXUSR);
				} else {
					fderr = open(_errFile, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IXUSR);
				}
			} else {
				fderr = dup(temperr);
			}
			dup2(fderr,2);
			close(fderr);
		} else {
			//create pipes
			int fdpipe[2];
			pipe(fdpipe);
			fdout = fdpipe[1];
			fdin = fdpipe[0];
		}

		dup2(fdout,1);
		close(fdout);

		//create child process
		ret = fork();
		if (ret == 0) {
			execvp(_simpleCommands[i]->_arguments[0], _simpleCommands[i]->_arguments);
			perror("fork");
			_exit(1);
		}
	}

	//reset defaults
	dup2(tempin, 0);
	dup2(tempout, 1);
	dup2(temperr, 2);
	close(tempin);
	close(tempout);
	close(temperr);

	if (!_background) {
		waitpid(ret, NULL, 0);
	}
	// Clear to prepare for next command
	clear();
	
	// Print new prompt
	prompt();
}

// Shell implementation

void
Command::prompt()
{
	if ( isatty(0) ) {
		printf("myshell>");
		fflush(stdout);
	}
}

Command Command::_currentCommand;
SimpleCommand * Command::_currentSimpleCommand;

int yyparse(void);

void sigint_handler(int sig) {
	printf("\n");
	Command::_currentCommand.clear();
	Command::_currentCommand.prompt();
}

void sigchild_handler(int sig) {
	while( waitpid(-1, NULL, WNOHANG) > 0); 
}

main()
{
	
	struct sigaction signalChild;
	signalChild.sa_handler = sigchild_handler;
	sigemptyset(&signalChild.sa_mask); 
	signalChild.sa_flags = SA_RESTART; 
	int error = sigaction(SIGCHLD, &signalChild, NULL ); 
	if ( error )  {  
		perror( "sigchild" );  
		exit( -1 ); 
	} 

	struct sigaction signalInt;
	signalInt.sa_handler = sigint_handler;
	sigemptyset(&signalInt.sa_mask); 
	signalInt.sa_flags = SA_RESTART; 
	int error2 = sigaction(SIGINT, &signalInt, NULL ); 
	if ( error2 )  {  
		perror( "sigint" );  
		exit( -1 ); 
	} 

	Command::_currentCommand.prompt();
	yyparse();
}

