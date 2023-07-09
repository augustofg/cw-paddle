	list p=12f629
	#include <p12f629.inc>

	__CONFIG _CONFIG, _LP_OSC & _WDT_OFF & _MCLRE_OFF & _BOREN_ON & _CP_OFF & _CPD_OFF & _PWRTE_OFF

tmp1 equ 0x20
tmp2 equ 0x21

	org 0x0000
	goto main

	org 0x0004
	retfie

main:
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	banksel TRISIO
	movlw 0xFE
	movwf TRISIO
	banksel GPIO
stop:
	banksel GPIO
	bsf GPIO, 0
	call delay_250ms
	banksel GPIO
	bcf GPIO, 0
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	call delay_250ms
	goto stop

delay_250ms:
	movlw 0x51
	movwf tmp1
	movlw 0x02
	movwf tmp2
loop:
	decfsz tmp1, 1
	goto loop
	decfsz tmp2, 1
	goto loop
	nop
	nop
	return

	end
