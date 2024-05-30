CC=sdcc
FAMILY=pic14
PROC=12f629

all: main.hex

main.hex: main.c
	$(CC) --use-non-free -m$(FAMILY) -p$(PROC) $^

flash: main.hex
	pk2cmd -PPIC12F629 -F$< -M

clean:
	rm -f main.asm main.hex main.lst main.cod main.o
