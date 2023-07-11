    list p=12f629
    #include <p12f629.inc>

    __CONFIG _CONFIG, _LP_OSC & _WDT_OFF & _MCLRE_OFF & _BOREN_ON & _CP_OFF & _CPD_OFF & _PWRTE_OFF

    #define cw_key_gpio GPIO,0
    #define cw_key_trisio TRISIO,0
    #define dit_paddle_bit 1
    #define dah_paddle_bit 2
    #define dit_paddle_gpio GPIO,dit_paddle_bit
    #define dah_paddle_gpio GPIO,dah_paddle_bit

    #define CAN_SLEEP_NO  0
    #define CAN_SLEEP_YES 1

    cblock 0x20
    w_save
    status_save
    pclath_save
    dit_dah_cycle
    sleep_ctrl
    dit_cnt_l
    dit_cnt_h
    endc

    org 0x0000
    goto main

    org 0x0004

    movwf   w_save              ; save off current W register contents
    movf    STATUS,w            ; move status register into W register
    movwf   status_save         ; save off contents of STATUS register
    movf    PCLATH,w            ; move pclath register into w register
    movwf   pclath_save         ; save off contents of PCLATH register

    btfss   INTCON, GPIF        ; If the interrupt was caused by GPIO change, disable it
    goto    add_tmr1_cnt
    bcf     INTCON, GPIE

    movf    dit_cnt_l, w        ; Reload Timer 1 counter (force)
    movwf   TMR1L
    movf    dit_cnt_h, w
    movwf   TMR1H
    goto    add_tmr1_cnt_end
add_tmr1_cnt:

    movf    dit_cnt_l, w        ; Reload Timer 1 counter (add)
    addwf   TMR1L, F
    incf    TMR1H, F
    movf    dit_cnt_h, w
    addwf   TMR1H, F
add_tmr1_cnt_end:

    banksel PIR1                ; Clear Timer 1 interrupt flag
    bcf     PIR1, TMR1IF

    movlw   0
    xorwf   dit_dah_cycle, W
    btfss   STATUS, Z
    goto    wait_dit_dah_finish
    bcf     cw_key_gpio

    movlw   0

    btfss   dit_paddle_gpio
    movlw   1

    btfss   dah_paddle_gpio
    movlw   3

    movwf   dit_dah_cycle

    xorlw   0
    btfss   STATUS, Z
    goto    start_dit_dah
    movlw   CAN_SLEEP_YES
    movwf   sleep_ctrl
    bcf     INTCON, GPIF        ; Clear GPIO interrupt flag and enable it
    bsf     INTCON, GPIE
    goto    end_dit_dah_fsm
start_dit_dah:
    movlw   CAN_SLEEP_NO
    movwf   sleep_ctrl
    bsf     cw_key_gpio
    goto    end_dit_dah_fsm
wait_dit_dah_finish:
    decfsz  dit_dah_cycle, F
    goto    end_dit_dah_fsm
    banksel GPIO
    bcf     cw_key_gpio
end_dit_dah_fsm:

    movf    pclath_save,w       ; retrieve copy of PCLATH register
    movwf   PCLATH              ; restore pre-isr PCLATH register contents
    movf    status_save,w       ; retrieve copy of STATUS register
    movwf   STATUS              ; restore pre-isr STATUS register contents
    swapf   w_save,f
    swapf   w_save,w            ; restore pre-isr W register contents
    retfie

main:
    banksel TRISIO
    bcf     cw_key_trisio       ; Define key control GPIO as an output
    movlw   (1 << TMR1IE)       ; Enable timer1 overflow interrupt
    movwf   PIE1
    movlw   (1 << dit_paddle_bit) | (1 << dah_paddle_bit)
    movwf   IOC                 ; Enable GPIO interrupt-on-change for the dit and dah switches
    movwf   WPU                 ; Enable Weak Pull-Ups for dit and dah switches
    bcf     OPTION_REG, NOT_GPPU

    banksel GPIO
    movlw   0x07                ; Disable analog comparator
    movwf   CMCON

    movlw   CAN_SLEEP_NO        ; Initialize sleep_ctrl flag
    movwf   sleep_ctrl
    movlw 0x00                  ; Initialize the dit dah cycle counter
    movwf dit_dah_cycle
    bcf cw_key_gpio

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
    movf    sleep_ctrl, W
    xorlw   CAN_SLEEP_YES
    btfsc   STATUS, Z
    nop                         ; Should be a sleep instruction here,
                                ; but it seems that the wake-up is
                                ; taking too long
    goto stop

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
