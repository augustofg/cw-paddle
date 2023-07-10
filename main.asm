    list p=12f629
    #include <p12f629.inc>

    __CONFIG _CONFIG, _LP_OSC & _WDT_OFF & _MCLRE_OFF & _BOREN_ON & _CP_OFF & _CPD_OFF & _PWRTE_OFF

    #define PAUSE_STATE 0x00
    #define DIT_STATE   0x01
    #define DAH_STATE1  0x02
    #define DAH_STATE2  0x03
    #define DAH_STATE3  0x04

    #define cw_key_gpio GPIO,0
    #define dit_paddle_gpio GPIO,3
    #define dah_paddle_gpio GPIO,2

    cblock 0x20
    w_save
    status_save
    pclath_save
    tmp1
    tmp2
    dit_dah_fsm
    dit_cnt_l
    dit_cnt_h
    endc

    org 0x0000
    goto main

    org 0x0004

    movwf   w_save            ; save off current W register contents
    movf    STATUS,w          ; move status register into W register
    movwf   status_save       ; save off contents of STATUS register
    movf    PCLATH,w      ; move pclath register into w register
    movwf   pclath_save      ; save off contents of PCLATH register

    movwf   w_save
    movf    STATUS, W
    movwf   status_save

    banksel PIR1
    bcf     PIR1, TMR1IF

    movf    dit_cnt_l, w
    addwf   TMR1L,f
    btfsc   STATUS, C
    incf    TMR1H, f
    movf    dit_cnt_h, w
    addwf   TMR1H, f

    movlw   PAUSE_STATE
    xorwf   dit_dah_fsm, W
    btfss   STATUS, Z
    goto    end_pause_state
    bcf     cw_key_gpio

    movlw   PAUSE_STATE

    btfss   dit_paddle_gpio
    movlw   DIT_STATE

    btfss   dah_paddle_gpio
    movlw   DAH_STATE1

    movwf   dit_dah_fsm

    xorlw   PAUSE_STATE
    btfss   STATUS, Z
    bsf     cw_key_gpio

    goto    end_dit_dah_fsm
end_pause_state:

    movlw   DIT_STATE
    xorwf   dit_dah_fsm, W
    btfss   STATUS, Z
    goto    end_dit_state
    banksel GPIO
    bcf     cw_key_gpio
    movlw   PAUSE_STATE
    movwf   dit_dah_fsm
    goto    end_dit_dah_fsm
end_dit_state:

    movlw   DAH_STATE1
    xorwf   dit_dah_fsm, W
    btfss   STATUS, Z
    goto    end_dah_state1
    movlw   DAH_STATE2
    movwf   dit_dah_fsm
    goto    end_dit_dah_fsm
end_dah_state1:

    movlw   DAH_STATE2
    xorwf   dit_dah_fsm, W
    btfss   STATUS, Z
    goto    end_dah_state2
    movlw   DAH_STATE3
    movwf   dit_dah_fsm
    goto    end_dit_dah_fsm
end_dah_state2:

    movlw   DAH_STATE3
    xorwf   dit_dah_fsm, W
    btfss   STATUS, Z
    goto    end_dah_state3
    bcf     cw_key_gpio
    movlw   PAUSE_STATE
    movwf   dit_dah_fsm
    goto    end_dit_dah_fsm
end_dah_state3:

end_dit_dah_fsm:

    movf    pclath_save,w     ; retrieve copy of PCLATH register
    movwf   PCLATH        ; restore pre-isr PCLATH register contents
    movf    status_save,w     ; retrieve copy of STATUS register
    movwf   STATUS            ; restore pre-isr STATUS register contents
    swapf   w_save,f
    swapf   w_save,w          ; restore pre-isr W register contents
    retfie

main:
    banksel TRISIO
    movlw 0xFE
    movwf TRISIO
    movlw (1 << TMR1IE)
    movwf PIE1
    banksel GPIO

    movlw 0x00
    movwf dit_dah_fsm
    bcf GPIO, 0

    call delay_250ms

    movlw 0x12
    call wpm_to_dit_cycles_table
    banksel TMR1L
    movwf dit_cnt_l
    movwf TMR1L

    movlw 0x13
    call wpm_to_dit_cycles_table
    banksel TMR1H
    movwf dit_cnt_h
    movwf TMR1H

    bcf     PIR1, TMR1IF
    movlw (1 << PEIE) | (1 << GIE)
    movwf INTCON
    movlw (1 << TMR1ON)
    movwf T1CON

stop:
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

wpm_to_dit_cycles_table:        ; 0x10000 - cycles, little endian, Fosc = 32.768 kHz
    addwf PCL, F
    dt 0x52, 0xf8 ; 5 wpm
    dt 0x9a, 0xf9 ; 6 wpm
    dt 0x84, 0xfa ; 7 wpm
    dt 0x33, 0xfb ; 8 wpm
    dt 0xbc, 0xfb ; 9 wpm
    dt 0x29, 0xfc ; 10 wpm
    dt 0x82, 0xfc ; 11 wpm
    dt 0xcd, 0xfc ; 12 wpm
    dt 0x0c, 0xfd ; 13 wpm
    dt 0x42, 0xfd ; 14 wpm
    dt 0x71, 0xfd ; 15 wpm
    dt 0x9a, 0xfd ; 16 wpm
    dt 0xbe, 0xfd ; 17 wpm
    dt 0xde, 0xfd ; 18 wpm
    dt 0xfb, 0xfd ; 19 wpm
    dt 0x14, 0xfe ; 20 wpm
    dt 0x2c, 0xfe ; 21 wpm
    dt 0x41, 0xfe ; 22 wpm
    dt 0x55, 0xfe ; 23 wpm
    dt 0x66, 0xfe ; 24 wpm
    dt 0x77, 0xfe ; 25 wpm
    dt 0x86, 0xfe ; 26 wpm
    dt 0x94, 0xfe ; 27 wpm
    dt 0xa1, 0xfe ; 28 wpm
    dt 0xad, 0xfe ; 29 wpm
    dt 0xb8, 0xfe ; 30 wpm
    dt 0xc3, 0xfe ; 31 wpm
    dt 0xcd, 0xfe ; 32 wpm
    dt 0xd6, 0xfe ; 33 wpm
    dt 0xdf, 0xfe ; 34 wpm
    dt 0xe7, 0xfe ; 35 wpm
    dt 0xef, 0xfe ; 36 wpm
    dt 0xf6, 0xfe ; 37 wpm
    dt 0xfd, 0xfe ; 38 wpm
    dt 0x04, 0xff ; 39 wpm
    dt 0x0a, 0xff ; 40 wpm

    end
