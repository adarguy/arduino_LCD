; ***
; HD44780 LCD Driver for ATmega2560.
; (DFRobot LCD Keypad Shield v1.1, Arduino Mega2560)
;
; Title: 		LCDdefs.inc
; Description: 	Conditional Assembly, Constant Definitions
; Author: 		Keegan van der Laag (jkvander@uvic.ca)
; Updated:		23 February 2015

; ---
;
; Some code shamelessly adapted from the C implementation of an HD44780
; driver by Peter Dannegger, posted to the AVR Freaks forum. The original
; driver is available here:
;
; http://www.avrfreaks.net/forum/tutc-lcd-tutorial-1001?name=PNphpBB2&file=viewtopic&t=102296


; Throws a warning if LCD_LIBONLY is not set before the #include in the program
; using the driver. If LCD_LIBONLY is not set, the default program code for setup,
; initialization, and main program loop will be assembled.
#ifndef LCD_LIBONLY
#message "LCD Driver loaded, LCD_LIBONLY not set. Running default program code."
#endif

; Delay times for LCD commands. These are fairly conservative, but may need to be
; adjusted for cheap HD44780 compatible controllers, or if you're implementing
; this driver in antarctica. When in doubt, refer to the data sheet for your LCD
; module.
.equ LCD_DAT		=	50		; Execute time in microseconds for data commands
.equ LCD_ENA		=	1		; Execute time in microseconds for clock pulse
.equ LCD_CLEAR		=	2		; Execute time for longer commands in ms


; Set the bit-width of the stack pointer for your processor.
; This determines how many bytes some subroutines will pop off the stack
; to preserve return addresses.
; You know, I don't actually know if other MCUs have wider SP registers.
; This kind of just assumes that they don't. I guess we'll find out pretty
; quick.
.if 	RAMEND <	0x100
.equ	SP_OFFSET = 2
.else
.equ 	SP_OFFSET = 3
.endif


; ***
; Register definitions used in this module.

.def CREG	=	R18					; Command or data register used in routines
.def DREG	=	R19					; Delay values passed to dly_ms and dly_us
.def TEMP	=	R16					; Mnemonics for temporary values
.def TEMP2	=	R17
; ***
; End of Driver Register Definitions


; ***
; Exception Handling
;
; Handle cases where some things are defined, but not others.
#ifdef LCD_SIZE
	#ifndef LCD_ROW
		#error "LCD_SIZE defined, LCD_ROW not set."
	#elif (LCD_ROW > 4) | (LCD_ROW < 1) | (LCD_ROW == 3)
		#error "LCD_ROW out of range. (Should be 1, 2, or 4.)"
	#endif

	#ifndef LCD_COLUMN
		#error "LCD_SIZE defined, LCD_COLUMN not set."

	#elif LCD_ROW == 1
		#if !(LCD_COLUMN == 8 | LCD_COLUMN == 16 | LCD_COLUMN == 20 | LCD_COLUMN == 40)
			#error "LCD_COLUMN not valid for given LCD_ROW. (Must be 8, 16, 20, or 40 for LCD_ROW = 1)"
		#endif
	#elif LCD_ROW == 2
		#if !(LCD_COLUMN == 8 | LCD_COLUMN == 12 | LCD_COLUMN == 16 | LCD_COLUMN == 20 | LCD_COLUMN == 24 | LCD_COLUMN == 40)
			#error "LCD_COLUMN not valid for given LCD_ROW. (Must be 8, 12, 16, 20, 24, or 40 for LCD_ROW = 2)"
		#endif
	#elif LCD_ROW == 4
		#if !(LCD_COLUMN == 16 | LCD_COLUMN == 20)
			#error "LCD_COLUMN not valid for given LCD_ROW. (Must be 16, or 20 for LCD_ROW = 4)"
		#endif

	#endif
#endif

#ifdef LCD_DISPLAY_SET
	#ifndef LCD_SHOW_CURSOR
		#error "LCD_DISPLAY_SET defined, LCD_SHOW_CURSOR not set."
	#endif
	#ifndef LCD_BLINK_CURSOR
		#error "LCD_DISPLAY_SET defined, LCD_BLINK_CURSOR not set."
	#endif
	#ifndef LCD_DISPLAY_ON
		#error "LCD_DISPLAY_SET defined, LCD_DISPLAY_ON not set."
	#endif
#endif

#ifdef LCD_INTERFACE_SET
	#ifndef LCD_INTERFACE_WIDTH
		#error "LCD_INTERFACE_SET defined, LCD_INTERFACE_WIDTH not set."
	#endif
	#ifndef LCD_LINE_COUNT
		#error "LCD_INTERFACE_SET defined, LCD_LINE_COUNT not set."
	#endif
	#ifndef LCD_FONT_SIZE
		#error "LCD_INTERFACE_SET defined, LCD_FONT_SIZE not set."
	#endif
#endif

#ifdef LCD_CURSOR_SET
	#ifndef LCD_CURSOR_DIR
		#error "LCD_CURSOR_SET defined, LCD_CURSOR_DIR not set."
	#endif
	#ifndef LCD_DISPLAY_SHIFT
		#error "LCD_CURSOR_SET defined, LCD_DISPLAY_SHIFT not set."
	#endif
#endif

#ifdef LCD_SHIFT_SET
	#ifndef LCD_SHIFT_DIR
		#error "LCD_MOVE_SHIFT defined, LCD_SHIFT_DIR not set."
	#endif
	#ifndef LCD_MOVE_SHIFT
		#error "LCD_SHIFT_SET defined, LCD_MOVE_SHIFT not set."
	#endif
#endif

.ifdef LCD_INTERFACE_PORTS
	.ifndef LCD_PORT_D4
		.error "LCD_INTERFACE_PORTS defined, LCD_PORT_D4 not set."
	.elif LCD_PORT_D4 > IOEND
		.error "LCD_PORT_D4 out of range. (Must be inside I/O Space)" 
	.endif
	.ifndef LCD_PORT_D5
		.error "LCD_INTERFACE_PORTS defined, LCD_PORT_D5 not set."
	.elif LCD_PORT_D5 > IOEND
		.error "LCD_PORT_D5 out of range. (Must be inside I/O Space)"
	.endif
	.ifndef LCD_PORT_D6
		.error "LCD_INTERFACE_PORTS defined, LCD_PORT_D6 not set."
	.elif LCD_PORT_D6 > IOEND
		.error "LCD_PORT_D6 out of range. (Must be inside I/O Space)"
	.endif
	.ifndef LCD_PORT_D7
		.error "LCD_INTERFACE_PORTS defined, LCD_PORT_D7 not set."
	.elif LCD_PORT_D7 > IOEND
		.error "LCD_PORT_D7 out of range. (Must be inside I/O Space)"
	.endif
	.ifndef LCD_PORT_RS
		.error "LCD_INTERFACE_PORTS defined, LCD_PORT_RS not set."
	.elif LCD_PORT_RS > IOEND
		.error "LCD_PORT_RS out of range. (Must be inside I/O Space)"
	.endif
	.ifndef LCD_PORT_ENA
		.error "LCD_INTERFACE_PORTS defined, LCD_PORT_ENA not set."
	.elif LCD_PORT_ENA > IOEND
		.error "LCD_PORT_ENA out of range. (Must be inside I/O Space)"
	.endif

	.ifndef PIN_D4
		.error "LCD_INTERFACE_PORTS defined, PIN_D4 not set."
	.elif PIN_D4 > 7
		.error "PIN_D4 out of range. (Must be between 0 and 7.)
	.endif
	.ifndef PIN_D5
		.error "LCD_INTERFACE_PORTS defined, PIN_D5 not set."
	.elif PIN_D5 > 7
		.error "PIN_D5 out of range. (Must be between 0 and 7.)
	.endif
	.ifndef PIN_D6
		.error "LCD_INTERFACE_PORTS defined, PIN_D6 not set."
	.elif PIN_D6 > 7
		.error "PIN_D6 out of range. (Must be between 0 and 7.)
	.endif
	.ifndef PIN_D7
		.error "LCD_INTERFACE_PORTS defined, PIN_D7 not set."
	.elif PIN_D7 > 7
		.error "PIN_D7 out of range. (Must be between 0 and 7.)
	.endif
	.ifndef PIN_RS
		.error "LCD_INTERFACE_PORTS defined, PIN_RS not set."
	.elif PIN_RS > 7
		.error "PIN_RS out of range. (Must be between 0 and 7.)
	.endif
	.ifndef PIN_ENA
		.error "LCD_INTERFACE_PORTS defined, PIN_ENA not set."
	.elif PIN_ENA > 7
		.error "PIN_ENA out of range. (Must be between 0 and 7.)
	.endif

.endif



; Definitions of constants for different LCD sizes.
#if (LCD_ROW == 1 & LCD_COLUMN == 8)
#define LCD_LINE1       0x80
#endif

#if (LCD_ROW == 1 & LCD_COLUMN == 16 )
#define LCD_LINE1       0x80
#endif

#if (LCD_ROW == 1 & LCD_COLUMN == 20 )
#define LCD_LINE1       0x80
#endif

#if (LCD_ROW == 1 & LCD_COLUMN == 40 )
#define LCD_LINE1       0x80
#endif

#if (LCD_ROW == 2 & LCD_COLUMN == 8 )
#define LCD_LINE1       0x80
#define LCD_LINE2       (0x80 + 0x40)
#endif

#if (LCD_ROW == 2 & LCD_COLUMN == 12 )
#define LCD_LINE1       0x80
#define LCD_LINE2       (0x80 + 0x40)
#endif

#if (LCD_ROW == 2 & LCD_COLUMN == 16 )
#define LCD_LINE1       0x80
#define LCD_LINE2       (0x80 + 0x40)
#endif

#if (LCD_ROW == 2 & LCD_COLUMN == 20 )
#define LCD_LINE1       0x80
#define LCD_LINE2       (0x80 + 0x40)
#endif

#if (LCD_ROW == 2 & LCD_COLUMN == 24 )
#define LCD_LINE1       0x80
#define LCD_LINE2       (0x80 + 0x40)
#endif

#if (LCD_ROW == 2 & LCD_COLUMN == 40 )
#define LCD_LINE1       0x80
#define LCD_LINE2       (0x80 + 0x40)
#endif

#if (LCD_ROW == 4 & LCD_COLUMN == 16 )
#define LCD_LINE1       0x80
#define LCD_LINE2       (0x80 + 0x40)
#define LCD_LINE3       (0x80 + 0x10)
#define LCD_LINE4       (0x80 + 0x50)
#endif

#if (LCD_ROW == 4 & LCD_COLUMN == 20 )
#define LCD_LINE1       0x80
#define LCD_LINE2       (0x80 + 0x40)
#define LCD_LINE3       (0x80 + 0x14)
#define LCD_LINE4       (0x80 + 0x54)
#endif

; Maximum length of a null-terminated string that fills the LCD completely.
; (Good for reserving memory for the LCD contents.)
#define lcd_length      (LCD_ROW * LCD_COLUMN) + 1

; Some constant definitions for Hitachi HD44780 Command instructions.
; Can be used with lcd_cmd by pushing them onto the stack before calling.
; For more details about the HD44780 instruction set and instruction format,
; see the data sheet for the HD44780 from Hitachi.
#define LCD_CMD_CLR			0x01
#define LCD_CMD_HOM			0x02
#define LCD_CMD_EMS     	0x04
#define LCD_CMD_DSP     	0x08
#define LCD_CMD_SHF     	0x10
#define LCD_CMD_FNC     	0x20
#define LCD_CMD_CGR     	0x40
#define LCD_CMD_DDR     	0x80
#define LCD_CMD_INI     	LCD_CMD_FNC + 0x10

; Definitions of commands specific to display settings from driver.
; These are used primarily in lcd_init
#define LCD_CMD_FUNCTION_SET	LCD_CMD_FNC + (LCD_INTERFACE_WIDTH<<4) + (LCD_LINE_COUNT<<3) + (LCD_FONT_SIZE<<2)
#define LCD_CMD_DISPLAY_MODE  LCD_CMD_DSP + (LCD_DISPLAY_ON<<2) + (LCD_SHOW_CURSOR<<1) + LCD_BLINK_CURSOR
#define LCD_CMD_ENTRY_MODE    LCD_CMD_EMS + (LCD_CURSOR_DIR<<1) + (LCD_DISPLAY_SHIFT)
#define LCD_CMD_SHIFT_DISPLAY LCD_CMD_SHF + (LCD_MOVE_SHIFT<<3) + (LCD_SHIFT_DIR)


; ***
; Port and Pin symbols for LCD_INTERFACE_PORTS. Uses symbols defined in
; the Atmel partdef file for your MCU.

; Port/Pin Labels for D4
.if (LCD_PORT_D4 < 0x100)
	.equ PORT_D4 = (LCD_PORT_D4) + 0x20
	.equ PINS_D4 = (LCD_PORT_D4 - 2) + 0x20
	.equ DDR_D4  = (LCD_PORT_D4 - 1) + 0x20
.else
	.equ PORT_D4 = LCD_PORT_D4
	.equ PINS_D4 = LCD_PORT_D4 - 2
	.equ DDR_D4  = LCD_PORT_D4 - 1
.endif

; Port/Pin Labels for D5
.if (LCD_PORT_D5 < 0x100)
	.equ PORT_D5 = (LCD_PORT_D5) + 0x20
	.equ PINS_D5 = (LCD_PORT_D5 - 2) + 0x20
	.equ DDR_D5  = (LCD_PORT_D5 - 1) + 0x20
.else
	.equ PORT_D5 = LCD_PORT_D5
	.equ PINS_D5 = LCD_PORT_D5 - 2
	.equ DDR_D5  = LCD_PORT_D5 - 1
.endif

; Port/Pin Labels for D6
.if (LCD_PORT_D6 < 0x100)
	.equ PORT_D6 = (LCD_PORT_D6) + 0x20
	.equ PINS_D6 = (LCD_PORT_D6 - 2) + 0x20
	.equ DDR_D6  = (LCD_PORT_D6 - 1) + 0x20
.else
	.equ PORT_D6 = LCD_PORT_D6
	.equ PINS_D6 = LCD_PORT_D6 - 2
	.equ DDR_D6  = LCD_PORT_D6 - 1
.endif

; Port/Pin Labels for D7
.if (LCD_PORT_D7 < 0x100)
	.equ PORT_D7 = (LCD_PORT_D7) + 0x20
	.equ PINS_D7 = (LCD_PORT_D7 - 2) + 0x20
	.equ DDR_D7  = (LCD_PORT_D7 - 1) + 0x20
.else
	.equ PORT_D7 = LCD_PORT_D7
	.equ PINS_D7 = LCD_PORT_D7 - 2
	.equ DDR_D7  = LCD_PORT_D7 - 1
.endif

; Port/Pin Labels for RS
.if (LCD_PORT_RS < 0x100)
	.equ PORT_RS = (LCD_PORT_RS) + 0x20
	.equ PINS_RS = (LCD_PORT_RS - 2) + 0x20
	.equ DDR_RS  = (LCD_PORT_RS - 1) + 0x20
.else
	.equ PORT_RS = LCD_PORT_RS
	.equ PINS_RS = LCD_PORT_RS - 2
	.equ DDR_RS  = LCD_PORT_RS - 1
.endif

; Port/Pin Labels for ENA
.if (LCD_PORT_ENA < 0x100)
	.equ PORT_ENA = (LCD_PORT_ENA) + 0x20
	.equ PINS_ENA = (LCD_PORT_ENA - 2) + 0x20
	.equ DDR_ENA  = (LCD_PORT_ENA - 1) + 0x20
.else
	.equ PORT_ENA = LCD_PORT_ENA
	.equ PINS_ENA = LCD_PORT_ENA - 2
	.equ DDR_ENA  = LCD_PORT_ENA - 1
.endif
