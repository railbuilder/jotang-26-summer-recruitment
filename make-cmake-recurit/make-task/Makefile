CC = gcc
CFLAGS = -Wall -Wextra -Iinclude

calculator: main.o calculator.o logger.o
	# TODO: link object files into the calculator executable
	$(CC) main.o calculator.o logger.o -o calculator
main.o: src/main.c include/calculator.h include/logger.h
	# TODO: compile src/main.c
	$(CC) $(CFLAGS) -c src/main.c -o main.o
calculator.o: src/calculator.c include/calculator.h
	# TODO: compile src/calculator.c
	$(CC) $(CFLAGS) -c src/calculator.c -o calculator.o
logger.o: src/logger.c include/logger.h
	# TODO: compile src/logger.c
	$(CC) $(CFLAGS) -c src/logger.c -o logger.o
.PHONY: clean
clean:
	# TODO: remove calculator and all .o files
	rm -f calculator main.o calculator.o logger.o
