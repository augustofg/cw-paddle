// Copyright (C) 2024 Augusto Fraga Giachero

#define NO_BIT_DEFINES
#include <pic14regs.h>
#include <stdint.h>

#define cw_key_pin 2
#define dit_paddle_pin 1
#define dah_paddle_pin 0
#define cw_key_gpio GPIObits.GP2
#define dit_paddle_gpio GPIObits.GP1
#define dah_paddle_gpio GPIObits.GP0

__code uint16_t __at (_CONFIG) __configword = _INTRC_OSC_NOCLKOUT & _WDT_OFF & _MCLRE_OFF & _BOREN_ON & _CP_OFF & _CPD_OFF & _PWRTE_OFF;

const uint16_t wpm_dit_time_table[36] = {
	0x15A0,
	0x3CB0,
	0x5897,
	0x6D84,
	0x7DCB,
	0x8AD0,
	0x9577,
	0x9E58,
	0xA5DB,
	0xAC4B,
	0xB1E0,
	0xB6C2,
	0xBB11,
	0xBEE5,
	0xC253,
	0xC568,
	0xC832,
	0xCABC,
	0xCD0D,
	0xCF2C,
	0xD120,
	0xD2EE,
	0xD499,
	0xD626,
	0xD797,
	0xD8F0,
	0xDA33,
	0xDB61,
	0xDC7D,
	0xDD88,
	0xDE85,
	0xDF73,
	0xE054,
	0xE129,
	0xE1F4,
	0xE2B4,
};

enum element_t {
	Idle,
	ElementDit,
	ElementDah,
};

static void irq_handler(void) __interrupt(0) {
	static enum element_t curr_element = Idle, next_element = Idle;
	static uint8_t dit_dah_cnt = 0, wpm_reload_idx = 10;
	static uint8_t prev_gpio = 0;
	uint8_t button_pressed = 0;

	if (INTCONbits.GPIF == 1) { // GPIO change interrupt
		/*
		 * Detect if this is a paddle press event, we should ignore
		 * release events
		 */
		button_pressed = ~(~(GPIO ^ prev_gpio) | GPIO);
		prev_gpio = GPIO;
		if (button_pressed != 0) {
			/*
			 * Clear GPIO interrupt change flag, disable it now and only
			 * enable it later after a few ms for debouncing
			 */
			INTCONbits.GPIF = 0;
			INTCONbits.GPIE = 0;

			if (curr_element == Idle) {
				if ((button_pressed & (1 << dit_paddle_pin)) != 0) {
					dit_dah_cnt = 1;
					curr_element = ElementDit;
				} else if ((button_pressed & (1 << dah_paddle_pin)) != 0) {
					dit_dah_cnt = 3;
					curr_element = ElementDah;
				}

				/*
				 * Reload timer 1 counter and enable it with a 1/4
				 * pre-scaler
				 */
				uint16_t dit_cycs = wpm_dit_time_table[wpm_reload_idx];
				TMR1L = dit_cycs & 0xFF;
				TMR1H = (dit_cycs >> 8) & 0xFF;
				T1CONbits.T1CKPS1 = 1;
				T1CONbits.T1CKPS0 = 0;
				T1CONbits.TMR1ON = 1;

				/*
				 * Key down
				 */
				cw_key_gpio = 1;

				/*
				 * For consistency, if curr_element was Idle,
				 * next_element should be Idle also
				 */
				next_element = Idle;
			} else {
				if ((button_pressed & (1 << dit_paddle_pin)) != 0 &&
					curr_element != ElementDit) {
					next_element = ElementDit;
				} else if ((button_pressed & (1 << dah_paddle_pin)) != 0 &&
					curr_element != ElementDah) {
					next_element = ElementDah;
				}
			}
		}

	}
	if (PIR1bits.TMR1IF == 1) { // Timer 1 overflow interrupt
		uint16_t dit_cycs = wpm_dit_time_table[wpm_reload_idx];
		TMR1L = dit_cycs & 0xFF;
		TMR1H = (dit_cycs >> 8) & 0xFF;
		PIR1bits.TMR1IF = 0;
		INTCONbits.GPIE = 1;
		INTCONbits.GPIF = 0;

		if (dit_dah_cnt == 1) {
			/*
			 * Key up
			 */
			cw_key_gpio = 0;
			dit_dah_cnt -= 1;
		} else if (dit_dah_cnt == 0) {
			if (next_element == Idle) {
				if (dit_paddle_gpio == 0 && dah_paddle_gpio == 0) {
					cw_key_gpio = 1;
					if (curr_element == ElementDit) {
						curr_element = ElementDah;
						dit_dah_cnt = 3;
					} else {
						curr_element = ElementDit;
						dit_dah_cnt = 1;
					}
				} else if (dit_paddle_gpio == 0) {
					cw_key_gpio = 1;
					curr_element = ElementDit;
					dit_dah_cnt = 1;
				} else if (dah_paddle_gpio == 0) {
					cw_key_gpio = 1;
					curr_element = ElementDah;
					dit_dah_cnt = 3;
				} else {
					T1CONbits.TMR1ON = 0;
					curr_element = Idle;
				}
			} else {
				curr_element = next_element;
				next_element = Idle;
				if (curr_element == ElementDit) {
					curr_element = ElementDit;
					dit_dah_cnt = 1;
				} else {
					curr_element = ElementDah;
					dit_dah_cnt = 3;
				}
				cw_key_gpio = 1;
			}
		} else {
			dit_dah_cnt -= 1;
		}
	}
}

void main(void)
{
	/*
	 * Apply the internal oscillator calibration
	 */
	__asm__("call 0x3FF\n"
			"banksel OSCCAL\n"
			"movwf OSCCAL\n"
		);
	/*
	 * Configure input and outputs, enable weak internal pull-ups for
	 * the inputs, disable the analog comparator
	 */
	TRISIO = (1 << dit_paddle_pin) | (1 << dah_paddle_pin) | (0 << cw_key_pin);
	WPU = (1 << dit_paddle_pin) | (1 << dah_paddle_pin);
	CMCON = 0x07;
	GPIO &= ~(1 << cw_key_pin);
	OPTION_REGbits.NOT_GPPU = 0;

	/*
	 * Enable GPIO change interrupts
	 */
	IOC = (1 << dit_paddle_pin) | (1 << dah_paddle_pin);
	INTCONbits.GPIE = 1;

	/*
	 * Enable Timer 1 overflow interrupt
	 */
	PIE1bits.TMR1IE = 1;

	/*
	 * Enable global interrupts and peripheral interrupts
	 */
	INTCONbits.PEIE = 1;
	INTCONbits.GIE = 1;

	__asm__("sleep\n");
	for(;;) {
	}
}
