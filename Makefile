SDIR = src
IDIR = include
ODIR = obj
LDIR = lib

CC = gcc
CCFLAGS = -Wall -Wextra

YAC = bison
LEX = flex

TARGET = mysh

SRC = $(wildcard $(SDIR)/*.c)
OBJ = $(SRC:$(SDIR)/%.c=$(ODIR)/%.o)
DEPS = $(wildcard $(IDIR)/*.h)

LIBSRC = $(wildcard $(LDIR)/$(SDIR)/*.c)
LIB = $(LSRC:$(LDIR)/$(SDIR)/%.c=$(ODIR)/%.a)
LIBDEPS = $(wildcard $(LDIR)$(IDIR)/*.h)

YSRC = $(wildcard $(SDIR)/*.y)
LSRC = $(wildcard $(SDIR)/*.l)

.PHONY: all clean lib yacc

all: $(TARGET)

clean:
	$(RM) $(OBJ) $(LIB) $(TARGET)

lib: $(LIB)

yacc: flex_cash

flex_cash: $(YSRC) $(LSRC) $(LIBSRC) $(SRC) $(DEPS) $(LDEPS)
	$(YAC) -d $(YSRC)
	$(LEX) $(LSRC) 
	$(CC) -o $@ $(SRC) $(LIBSRC) bison_cash.tab.c lex.yy.c -lfl

$(TARGET): $(OBJ) $(LIB)
	$(CC) $^ -o $@

$(ODIR)/%.o: $(SDIR)/%.c $(DEPS)
	$(CC) $(CCFLAGS) -c $< -o $@

$(ODIR)/%.a: $(LDIR)/$(SDIR)/%.c $(LDEPS)
	$(CC) $(CCFLAGS) -c $< -o $@
