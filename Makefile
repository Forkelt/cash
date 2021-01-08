SDIR = src
ODIR = obj

CC = gcc
CCFLAGS = -Wall -Wextra

TARGET = mysh

SRC = $(wildcard $(SDIR)/*.c)
OBJ = $(SRC:$(SDIR)/%.c=$(ODIR)/%.o)

.PHONY: all clean

all: $(TARGET)

clean:
	$(RM) $(OBJ) $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $^ -o $@

$(ODIR)/%.o: $(SDIR)/%.c
	$(CC) $(CCFLAGS) -c $< -o $@
