SDIR = src
IDIR = include
ODIR = obj
LDIR = lib

CC = gcc
CCFLAGS = -Wall -Wextra

TARGET = mysh

SRC = $(wildcard $(SDIR)/*.c)
OBJ = $(SRC:$(SDIR)/%.c=$(ODIR)/%.o)
DEPS = $(wildcard $(IDIR)/*.h)

LSRC = $(wildcard $(LDIR)/$(SDIR)/*.c)
LIB = $(LSRC:$(LDIR)/$(SDIR)/%.c=$(ODIR)/%.a)
LDEPS = $(wildcard $(LDIR)$(IDIR)/*.h)

.PHONY: all clean lib

all: $(TARGET)

clean:
	$(RM) $(OBJ) $(LIB) $(TARGET)

lib: $(LIB)

$(TARGET): $(OBJ) $(LIB)
	$(CC) $^ -o $@

$(ODIR)/%.o: $(SDIR)/%.c $(DEPS)
	$(CC) $(CCFLAGS) -c $< -o $@

$(ODIR)/%.a: $(LDIR)/$(SDIR)/%.c $(LDEPS)
	$(CC) $(CCFLAGS) -c $< -o $@
