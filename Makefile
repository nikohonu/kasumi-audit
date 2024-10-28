CC = gcc
CFLAGS = -pedantic
SRC = main.c
OBJ = ${SRC:.c=.o}
NAME = kasumi-audit

all: ${NAME}

%.o: %.c
	${CC} -c ${CFLAGS} -o $@ $<

${NAME}: ${OBJ}
	${CC} -o $@ ${OBJ}

clean:
	rm ${NAME} ${OBJ}

.PHONY: all clean
