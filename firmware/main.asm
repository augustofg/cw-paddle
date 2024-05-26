;;; Electronic Iambic Paddle for CW firmware
;;; Copyright (C) 2023 Augusto Fraga Giachero <afg@augustofg.net>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

    list p=12f629
    #include <p12f629.inc>

    __CONFIG _CONFIG, _INTRC_OSC_NOCLKOUT & _WDT_OFF & _MCLRE_OFF & _BOREN_ON & _CP_OFF & _CPD_OFF & _PWRTE_OFF

    #define cw_key_gpio GPIO,2
    #define cw_key_trisio TRISIO,2
    #define dit_paddle_bit 1
    #define dah_paddle_bit 0
    #define dit_paddle_gpio GPIO,dit_paddle_bit
    #define dah_paddle_gpio GPIO,dah_paddle_bit

    #define CAN_SLEEP_NO  0
    #define CAN_SLEEP_YES 1

    #define DEFAULT_WPM D'15'
    #define DEFAULT_WPM_IDX (DEFAULT_WPM - D'5') * D'2'

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

    banksel INTCON

    btfss   INTCON, GPIF        ; If the interrupt was caused by GPIO change, disable it
    goto    add_tmr1_cnt
    bcf     INTCON, GPIE

    movf    dit_cnt_l, w        ; Reload Timer 1 counter (force)
    movwf   TMR1L
    movf    dit_cnt_h, w
    movwf   TMR1H
    goto    add_tmr1_cnt_end
add_tmr1_cnt:

    banksel TMR1L
    movf    dit_cnt_l, w        ; Reload Timer 1 counter (add)
    addwf   TMR1L, F
    incf    TMR1H, F
    movf    dit_cnt_h, w
    addwf   TMR1H, F
add_tmr1_cnt_end:

    bcf     PIR1, TMR1IF        ; Clear Timer 1 interrupt flag

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
    banksel sleep_ctrl
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
    call    0x3FF               ; Load and apply internal OSC callibration
    banksel TRISIO
    movwf   OSCCAL
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

    movlw   0x00                ; Initialize the dit dah cycle counter
    movwf   dit_dah_cycle

    bcf     cw_key_gpio         ; CW key should start in OFF

    movlw   DEFAULT_WPM_IDX
    call    wpm_to_dit_cycles_table
    banksel TMR1L
    movwf   dit_cnt_l
    movwf   TMR1L

    movlw   (DEFAULT_WPM_IDX + 1)
    call    wpm_to_dit_cycles_table
    banksel TMR1H
    movwf   dit_cnt_h
    movwf   TMR1H

    bcf     PIR1, TMR1IF
    movlw   (1 << PEIE) | (1 << GIE)
    movwf   INTCON
    ;; Configure Timer1 with a 1/4 pre-escaler
    movlw   (1 << TMR1ON) | (1 << T1CKPS1) | (0 << T1CKPS1)
    movwf   T1CON

stop:
    movf    sleep_ctrl, W
    xorlw   CAN_SLEEP_YES
    btfsc   STATUS, Z
    nop                         ; Should be a sleep instruction here,
                                ; but it seems that the wake-up is
                                ; taking too long
    goto    stop

wpm_to_dit_cycles_table:        ; 0x10000 - cycles, little endian, Fosc = 4 MHz
    addwf PCL, F
    dt 0xA0, 0x15 ; 60000 cycles, 5 wpm
    dt 0xB0, 0x3C ; 50000 cycles, 6 wpm
    dt 0x97, 0x58 ; 42857 cycles, 7 wpm
    dt 0x84, 0x6D ; 37500 cycles, 8 wpm
    dt 0xCB, 0x7D ; 33333 cycles, 9 wpm
    dt 0xD0, 0x8A ; 30000 cycles, 10 wpm
    dt 0x77, 0x95 ; 27273 cycles, 11 wpm
    dt 0x58, 0x9E ; 25000 cycles, 12 wpm
    dt 0xDB, 0xA5 ; 23077 cycles, 13 wpm
    dt 0x4B, 0xAC ; 21429 cycles, 14 wpm
    dt 0xE0, 0xB1 ; 20000 cycles, 15 wpm
    dt 0xC2, 0xB6 ; 18750 cycles, 16 wpm
    dt 0x11, 0xBB ; 17647 cycles, 17 wpm
    dt 0xE5, 0xBE ; 16667 cycles, 18 wpm
    dt 0x53, 0xC2 ; 15789 cycles, 19 wpm
    dt 0x68, 0xC5 ; 15000 cycles, 20 wpm
    dt 0x32, 0xC8 ; 14286 cycles, 21 wpm
    dt 0xBC, 0xCA ; 13636 cycles, 22 wpm
    dt 0x0D, 0xCD ; 13043 cycles, 23 wpm
    dt 0x2C, 0xCF ; 12500 cycles, 24 wpm
    dt 0x20, 0xD1 ; 12000 cycles, 25 wpm
    dt 0xEE, 0xD2 ; 11538 cycles, 26 wpm
    dt 0x99, 0xD4 ; 11111 cycles, 27 wpm
    dt 0x26, 0xD6 ; 10714 cycles, 28 wpm
    dt 0x97, 0xD7 ; 10345 cycles, 29 wpm
    dt 0xF0, 0xD8 ; 10000 cycles, 30 wpm
    dt 0x33, 0xDA ; 9677 cycles, 31 wpm
    dt 0x61, 0xDB ; 9375 cycles, 32 wpm
    dt 0x7D, 0xDC ; 9091 cycles, 33 wpm
    dt 0x88, 0xDD ; 8824 cycles, 34 wpm
    dt 0x85, 0xDE ; 8571 cycles, 35 wpm
    dt 0x73, 0xDF ; 8333 cycles, 36 wpm
    dt 0x54, 0xE0 ; 8108 cycles, 37 wpm
    dt 0x29, 0xE1 ; 7895 cycles, 38 wpm
    dt 0xF4, 0xE1 ; 7692 cycles, 39 wpm
    dt 0xB4, 0xE2 ; 7500 cycles, 40 wpm

    end
