all: main.hex

main.hex: main.asm
	gpasm $< -o $@

flash: main.hex
	pk2cmd -PPIC12F629 -F$< -M

clean:
	rm -f main.hex main.lst main.cod
