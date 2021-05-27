SDIR = src
IDIR = include
LDIR = lib

CC = gcc
CCFLAGS = -Wall -Wextra

YAC = bison
LEX = flex

TARGET = mysh

SRC = $(wildcard $(SDIR)/*.c)
DEPS = $(wildcard $(IDIR)/*.h)

LIBSRC = $(wildcard $(LDIR)/$(SDIR)/*.c)
LIBDEPS = $(wildcard $(LDIR)$(IDIR)/*.h)

YSRC = $(wildcard $(SDIR)/*.y)
LSRC = $(wildcard $(SDIR)/*.l)

.PHONY: all clean

all: $(TARGET)

clean:
	$(RM) $(TARGET) bison_cash.tab.* lex.yy.c

$(TARGET): $(YSRC) $(LSRC) $(LIBSRC) $(SRC) $(DEPS) $(LDEPS)
	$(YAC) -d $(YSRC)
	$(LEX) $(LSRC) 
	$(CC) -o $@ $(SRC) $(LIBSRC) bison_cash.tab.c lex.yy.c -lfl 
