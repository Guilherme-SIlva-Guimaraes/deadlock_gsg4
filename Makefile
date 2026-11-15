CC = gcc
CFLAGS = -Wall -Wextra -std=c11
TARGET = banker
SRC = banker.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

test: all
	bash tests/run_all.sh

clean:
	rm -f $(TARGET)

.PHONY: all clean test
