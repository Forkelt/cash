# cash

Copyright (C) 2021 Thomas Folkert Mol

Licensed under EUPL-1.2-or-later (see Licence.txt).

linenoise.h and linenoise.c are licensed under BSD. See https://github.com/antirez/linenoise. This version of linenoise.c uses a patch by S. Bennet (msteveb), adapted by A.F. Mayer (afmayer), as well as some adjustments by me.

## Features
* Shell command execution.
* Pipes.
* Stdin/stdout redirection.
* Internal cd/exit.
* Executing argument with -c.
* Sequential execution of commands from a script.
* Line editing and history through the linenoise library.

## Dependencies

### Make
* A C compiler (tested with gcc).
* Bison (tested with GNU Bison).
* Lex (tested with flex).

You can adjust the relevant variables in the Makefile to work for your setup.

### Run
* A POSIX-compliant operating system.

