; ***
; HD44780 LCD Driver for ATmega2560.
; (DFRobot LCD Keypad Shield v1.1, Arduino Mega2560)
;
; Title: 		LCD.asm
; Description: 	LCD Configuration and Subroutines
; Author: 		Keegan van der Laag (jkvander@uvic.ca)
; Updated:		23 February 2015

; ---
;
; Some code shamelessly adapted from the C implementation of an HD44780
; driver by Peter Dannegger, posted to the AVR Freaks forum. The original
; driver is available here:
;
; http://www.avrfreaks.net/forum/tutc-lcd-tutorial-1001?name=PNphpBB2&file=viewtopic&t=102296
; 
; Delay loops hackishly paraphrased from Atmel's AVR C libraries.
;
; This module provides configuration, initialization, and control
; routines for a Hitachi HD44780-compatible LCD controller connected
; to an Atmel AVR microcontroller unit. It makes the following asusmptions:
; 	- The R/W pin on the HD44780 is permanently grounded, making it
;	  impossible to read the busy flag from the controller.
;	- Similarly, the DDRAM and CGRAM addresses cannot be read from the
;	  controller, meaning that the cursor position must be manually tracked
;	  and updated to match the LCD if cursor position is important to you.
;	- The HD44780 is being operated in 4-bit mode rather than 8-bit.
;	- Only one HD44780 is connected. (No ridiculously large matrices of 
;	  characters.)
;
; Also, the busy-wait delays used for the timing of LCD initialization and
; commands currently assume that the AVR MCU is running at 16 MHz. This is
; by laziness, not by design; it will be corrected in a future version.
;
; This module #includes a definition file for an unwieldy and sizable number
; of LCD-related symbols and values. This file is called LCDdefs.inc, and
; should be located in the project directory with this module, or in the
; main include directory of your AVR Toolchain installation.
;
; When including this module in your project, it is important to #define
; the symbol LCD_LIB_ONLY to keep this file from trying to run the default
; initialization and program loop written into the driver.
;
; LCD pin and port assignment, as well as setting things like LCD size in
; columns and rows, and the collection of HD44780 display modes and settings,
; can be done either here in the header #defines, or in the header of the
; program including the driver. In order for the program to assemble, the
; following symbols must be defined, as well as their listed children:
;
;	LCD_SIZE
;		LCD_ROW 				(n = 1, 2, 4)
;		LCD_COLUMN				(n = 8, 12, 16, 20, 24, 40)
;	LCD_DISPLAY_SET
;		LCD_SHOW_CURSOR			(n = 0, 1)
;		LCD_BLINK_CURSOR		(n = 0, 1)
;		LCD_DISPLAY_ON			(n = 0, 1)
;	LCD_INTERFACE_SET
;		LCD_INTERFACE_WIDTH		(n = 0, 1)
;		LCD_LINE_COUNT			(n = 0, 1)
;		LCD_FONT_SIZE			(n = 0, 1)
;	LCD_CURSOR SET
;		LCD_CURSOR_DIR			(n = 0, 1)
;		LCD_DISPLAY_SHIFT		(n = 0, 1)
;	LCD_SHIFT_SET
;		LCD_MOVE_SHIFT			(n = 0, 1)
;		LCD_SHIFT_DIR			(n = 0, 1)
;	LCD_INTERFACE_PORTS
;		LCD_PORT_D4				All LCD ports must be set using .equ
;		LCD_PORT_D5				rather than #define, and must be the
;		LCD_PORT_D6				memory address of an I/O port.
;		LCD_PORT_D7				This uses values from your Atmel partdef
;		LCD_PORT_RS				include, and so I/O space offset does not
;		LCD_PORT_ENA			need to be applied. Use of .equ is for
;								compatibility with Atmel's partdefs. Use 
;								the defaults provided here as an example.
;		LCD_PIN_D4
;		LCD_PIN_D5
;		LCD_PIN_D6				Pins are bit numbers within a port,
;		LCD_PIN_D7				(0 <= n <= 7)
;		LCD_PIN_RS
;		LCD_PIN_ENA
;
; Wherever possible, if something is defined in the including program, I've
; tried to have this driver defer to those definitions. Similarly, if there's
; anywhere something isn't defined and it should be, I've attempted to have the
; driver spit out a helpful assembler error. By and large, if an entire block of
; things is not defined, the driver will use default values. (Pin assignments,
; LCD size, display modes and settings, etc.) If individual values are not defined
; (for instance, a specific port or pin, LCD rows but not columns, Display mode
; but not whether to show/hide the cursor, etc) the assembler will error and tell
; you to define them. It should also do a pretty good job of letting you know if
; you've accidentally set an LCD size that isn't supported by the HD44780
;
; To this end, there is a LOT of conditional assembly here, which is why I've tried
; to do most of it in the included definitions file. If you want to make changes
; to the way the LCD behaves by default, it can be done using the settings in this
; module's header. You shouldn't need to modify anything in LCDdefs.inc, unless I've
; done something really, heinously wrong.

; The lcd_putchar/lcd_puts routines should include functionality for
; automatically updating the cursor row/column values stored in memory,
; as well as automatically overflowing to the next line if necessary. For
; application reasons, this version of the driver has this functionality
; removed.

; End Notes
; ***

; If no partdef file has been included yet, include the partdef for
; the ATmega2560.
.ifndef SIGNATURE_000
.include "m2560def.inc"
.endif


; Define the LCD size in rows x columns. Constants are conditionally
; determined based on this, and should be compatible with any HD44780
; controlled display.
#ifndef LCD_SIZE
#define LCD_SIZE
#message "LCD_SIZE not set, using default values."

	#define LCD_ROW			2
	#define LCD_COLUMN		16

#endif


#ifndef LCD_DISPLAY_SET
#define LCD_DISPLAY_SET
#message "LCD_DISPLAY_SET not set, using default values."

	#define LCD_SHOW_CURSOR		0	; Show cursor = 1, Hide cursor = 0
	#define LCD_BLINK_CURSOR	0	; Blink on = 1, off = 0
	#define LCD_DISPLAY_ON		1	; Entire Display On = 1, Off = 0

#endif


#ifndef LCD_CURSOR_SET
#define LCD_CURSOR_SET
#message "LCD_CURSOR_SET not set, using default values."

	#define LCD_CURSOR_DIR		1	; Increment = 1, Decrement = 0
	#define LCD_DISPLAY_SHIFT	0	; Display shift on = 1, off = 0

#endif


#ifndef LCD_INTERFACE_SET
#define LCD_INTERFACE_SET
#message "LCD_INTERFACE_SET not set, using default values."

	#define LCD_INTERFACE_WIDTH	0	; 4-bit = 0, 8-bit = 1
	#define LCD_LINE_COUNT		1	; 1 line = 0, 2 lines = 1
	#define LCD_FONT_SIZE		0	; 5x8 dot = 0, 5x10 dot = 1

#endif


#ifndef LCD_SHIFT_SET
#define LCD_SHIFT_SET
#message "LCD_SHIFT_SET not set, using default values."

	#define LCD_MOVE_SHIFT		0	; Move cursor = 0, Shift display = 1
	#define LCD_SHIFT_DIR		0	; Shift left = 0, Shift right = 1

#endif


; ***
; LCD Pin Definitions.
; Changing these should affect lcd_init, lcd_nbl, lcd_byte, and lcd_putchar
; These default assignments are for the Arduino Mega2560 with DFRobot LCD
; Keypad Shield. Symbols used must be defined in the Atmel AVR partdef file
; used, or you're going to have a bad time.

.ifndef LCD_INTERFACE_PORTS
.set LCD_INTERFACE_PORTS = 1
.message "LCD_INTERFACE_PORTS not set, using default values."

.equ	LCD_PORT_D4  =  PORTG
.equ	LCD_PORT_D5  =	PORTE
.equ	LCD_PORT_D6  =	PORTH
.equ	LCD_PORT_D7  =	PORTH

.equ	PIN_D4	  =		5
.equ	PIN_D5	  =		3
.equ	PIN_D6	  =		3
.equ	PIN_D7	  =		4

.equ	LCD_PORT_ENA =	PORTH
.equ 	LCD_PORT_RS  =	PORTH

.equ	PIN_ENA	  =		6
.equ	PIN_RS	  =		5
.endif

; ***
; End of LCD Pin Definitions


; ***
; Include LCD Driver Constants and Conditionals.
.include "LCDdefs.inc"
; ***



; ***
; Code Segment.
.cseg


; **
; Default Program Initialization/Setup
; (Not included if LCD_LIBONLY is defined.)
#ifndef LCD_LIBONLY
	call lcd_init		; call lcd_init to Initialize the LCD

	ldi TEMP, high(str)	; Push the data memory address
	push TEMP			; of str to the stack
	ldi TEMP, low(str)
	push TEMP
	ldi TEMP, high(init<<1)	; Push the address of init, shifted for
	push TEMP				; program memory access, to the stack
	ldi TEMP, low(init<<1)
	push TEMP
	call str_init		; Call str_init to initialize data memory address
	pop TEMP			; str with the contents of program memory segment
	pop TEMP			; init
	pop TEMP
	pop TEMP

	ldi TEMP, high(str)
	push TEMP
	ldi TEMP, low(str)
	push TEMP 
	call lcd_puts		; Call lcd_puts to output the initialized string
						; to the LCD. For demonstration purposes only.
						; May be commented without impacting LCD functionality.
	pop TEMP
	pop TEMP

#endif
; **
; End of Default Program Initialization/Setup


; **
; Default Main Program Loop
; (Not included if LCD_LIBONLY is defined.)
#ifndef LCD_LIBONLY
mainloop:


	jmp mainloop
#endif
; **
; End of Main Program Loop



#ifndef LCD_LIBONLY
subroutinedefinitions: jmp subroutinedefinitions 	; Just in case.
#else
jmp lcd_after
#endif

; *** ***
; LCD Controller Subroutine Definitions
;
; * LCD Subroutines    *
; lcd_nbl     - 	Take byte from stack. Send high nibble to LCD. Return byte.
; lcd_byte    - 	Take byte from stack. Push to lcd_nbl. Swap nibbles of byte, push to stack.
;					call lcd_nbl
; lcd_cmd     - 	Take byte from stack. Set RS pin to 0 (command). Push byte to LCD
;					through lcd_byte.
; lcd_putchar - 	Take byte from stack. Set RS to 1 (write). Push byte to lcd_byte.
;					Increment cursor_xy.
; lcd_puts    - 	Take two-byte address of string from stack. Set X pointer to address.
;					Push (X) to stack. Call lcd_putchar.
; lcd_gotoxy  -		Take byte from stack. Byte takes form YYYYXXXX. Update cursor_xy to byte.
;					High nibble is row value, low nibble is column. Use LCD definitions to calculate
;					memory address for location on display. Push address to stack. Call lcd_cmd.
;					Update cursor_xy to byte.
; lcd_clr     -		Push LCD_CMD_CLR to the stack, call lcd_cmd. Clears display, returns cursor to 0,0
;
;
; * Delay Subroutines  *
; dly_us      -		Busy-wait delay loop for ~(DREG) microseconds. (0 <= (DREG) <= 255)
; dly_ms      -		Busy-wait delay loop for ~(DREG) milliseconds (0 <= (DREG) <= 15)
;
;	Both delay subroutines currently assume a CPU frequency of 16 MHz.
;
;
; * String Subroutines *
; str_init	  -		Take two-byte pointer for string constant location in program memory, take
;					two-byte pointer for target location in data memory. Copy each byte from
;					program memory to data memory until a null character is found.

; *            		  *




; **
; lcd_nbl : 		Send high nibble of CREG to LCD. Pulses clock.
;
; Registers:	CREG	-	Data byte of which to send high nibble to LCD.
;				TEMP	-	Temporary working register
;				DREG    -	Passed to dly_us.
; Memory:		None.
; Stack:		None.
; Returns:		Nothing.
;
lcd_nbl:
	push TEMP
	push CREG
	push DREG

	lds TEMP, PINS_D4
	cbr TEMP, (1<<PIN_D4)
	sbrc CREG, 4
	sbr TEMP, (1<<PIN_D4)
	sts PORT_D4, TEMP

	lds TEMP, PINS_D5
	cbr TEMP, (1<<PIN_D5)
	sbrc CREG, 5
	sbr TEMP, (1<<PIN_D5)
	sts PORT_D5, TEMP

	lds TEMP, PINS_D6
	cbr TEMP, (1<<PIN_D6)
	sbrc CREG, 6
	sbr TEMP, (1<<PIN_D6)
	sts PORT_D6, TEMP

	lds TEMP, PINS_D7
	cbr TEMP, (1<<PIN_D7)
	sbrc CREG, 7
	sbr TEMP, (1<<PIN_D7)
	sts PORT_D7, TEMP

	; Pulse clock high
	lds TEMP, PINS_ENA
	sbr TEMP, (1<<PIN_ENA)
	sts PORT_ENA, TEMP

	; Wait for LCD_ENA microseconds
	ldi DREG, LCD_ENA
	call dly_us

	; Pulse clock low.
	lds TEMP, PINS_ENA
	cbr TEMP,  (1<<PIN_ENA)
	sts PORT_ENA, TEMP

	; Return
	pop DREG
	pop CREG
	pop TEMP
	ret
; **
; End of lcd_nbl


; **
; lcd_byte :   	 	Send eight bits of (dat) to LCD. Calls lcd_nbl.
;
; Registers:	CREG	-	Working register. Command data.
;				DREG	-	Passed to dly_us.
;				TEMP	-	Temporary working register.
; Stack:		Input	-	1 byte
;					1	-	Data byte to send to LCD.
; Returns:		CREG	-	1 byte returned to stack, data byte sent.
;							Used for checking command at end of things
;							like lcd_cmd.
lcd_byte:
	.set PARAM_OFFSET = 5
	; Get stack data into CREG
	push CREG
	push DREG
	push TEMP
	push YH
	push YL

	in YH, SPH
	in YL, SPL

	ldd CREG, Y+1+(SP_OFFSET+PARAM_OFFSET)

	; Send high nibble
	call lcd_nbl
	; Wait LCD_DAT microseconds for command to finish.

	ldi DREG, LCD_DAT
	call dly_us
	; Send low nibble of CREG
	swap CREG
	call lcd_nbl
	; Wait LCD_DAT microseconds for command to finish,
	ldi DREG, LCD_DAT
	call dly_us
	
	pop YL
	pop YH
	pop TEMP
	pop DREG
	pop CREG
	ret
; **
; End of lcd_byte


; **
; lcd_cmd :			Set RS pin on LCD to 0 (Command.) Pop command data byte from
;					stack. Send to LCD using lcd_byte.
;
; Registers:	TEMP	-	Temporary working register.
;				DREG	-	Passed to dly_ms.
;				CREG	-	Working register. Returned from lcd_byte.
; Stack:		Input	-	1 byte
;					1:		Command data byte.
; Returns:		Nothing.
lcd_cmd:
	.set PARAM_OFFSET = 5
	push TEMP
	push DREG
	push CREG
	push YH
	push YL
	in YH, SPH
	in YL, SPL

	ldd CREG, Y+1+(SP_OFFSET+PARAM_OFFSET)


	; Set RS = 0
	lds TEMP, PINS_RS
	cbr TEMP, (1<<PIN_RS)
	sts PORT_RS, TEMP
	; Send commnand byte (dat)
	push CREG
	call lcd_byte
	pop CREG

	; On CREG = 0x01, 0x02, or 0x03, command takes longer to execute.
	; Wait LCD_CLEAR milliseconds before continuing.

	cpi CREG, 0x04
	brsh cmd_fin
	ldi DREG, LCD_CLEAR
	call dly_ms

cmd_fin:
	pop YL
	pop YH
	pop CREG
	pop DREG
	pop TEMP

	ret
; **
; End of lcd_cmd


; **
; lcd_putchar : 	Set RS pin on LCD to 1 (write data). Send character in
;					byte from stack.
;					...just saying, this command auto-increments the DDRAM
;					address of the LCD. You'll probably want to update your
;					cursor position accordingly.
;
; Registers:	TEMP		-	Temporary value. MODIFIED.
;				CREG		-	Stack input, character to write
; Memory:		Nothing.		
; Stack:		Input		-	1 byte. Character data.
;					SP+1	-	Character to write
; Returns:		Nothing.							
lcd_putchar:
	.set PARAM_OFFSET = 4
	push TEMP
	push CREG
	push YH
	push YL

	in YH, SPH
	in YL, SPL

	ldd CREG, Y+1+(SP_OFFSET+PARAM_OFFSET)

	; Set RS = 1 (Write data to current DDRAM address)
	lds TEMP, PINS_RS
	sbr TEMP, (1<<PIN_RS)
	sts PORT_RS, TEMP
	; Send character data in byte (dat) using lcd_byte
	push CREG
	call lcd_byte
	pop CREG

	; Increment cursor column. Note that this does not
	; perform any sort of checking for whether or not
	; the column number exceeds the number of columns
	; that the LCD can display, nor does it automatically
	; adjust the cursor_row position accordingly.
	lds TEMP, cursor_col
	inc TEMP
	sts cursor_col, TEMP

	pop YL
	pop YH
	pop CREG
	pop TEMP
	ret
; 
; **
; End of lcd_putchar


; **
; lcd_puts:			Takes a two-byte address pointer to the start of a
;					string, outputs it serially to the LCD using
;					lcd_putchar. Stops when a null character is found
;					in memory.
;					Conceivably, you could add code to the end of parse
;					to check cursor position validity for the given LCD
;					size. This could also be done in lcd_putchar.
; Registers:		ZH:ZL	-	Address pointer to beginning of string.
;					TEMP	-	Temporary working register
;					TEMP2	-	Temporary working register
; Stack:			Input	-	Two-byte address pointer to string.
;						SP+1	-	Low Byte of Address
;						SP+2	-	High Byte of Address
; Returns:			Nothing
lcd_puts:		
	.set PARAM_OFFSET = 6
	push TEMP
	push TEMP2
	push YH
	push YL
	push ZH
	push ZL
	
	in YH, SPH
	in YL, SPL	
		
		ldd ZH, Y+1+(SP_OFFSET+PARAM_OFFSET)+1
		ldd ZL, Y+1+(SP_OFFSET+PARAM_OFFSET)
	parse:
		ld TEMP2, Z+
		cpi TEMP2, 0x00
		breq donestr
		push TEMP2
		call lcd_putchar
		pop TEMP2
		rjmp parse
	donestr:
		pop ZL
		pop ZH
		pop YL
		pop YH
		pop TEMP2
		pop TEMP

		ret
; **
; End of lcd_puts


; **
; lcd_gotoxy :		Take Row/Column values from stack. Check that input isn't
;					bogus for the LCD size defined in the header. If row or column
;					are out of bound, they are set arbitrarily to the highest possible
;					value for the LCD. Calculates DDRAM address in HD44780 corresponding
;					to the given (Row,Column) pair for the LCD size defined in the header.
;					Sends memory address command to LCD using lcd_cmd.
; Register:		TEMP	-	Temporary working register. Pops Column from stack.
;				TEMP2	-	Temporary working register. Pops Row from stack.
; Memory:		cursor_row	-	Current cursor row position. Updated.
;				cursor_col	-	Current cursor column position. Updated.
;								Unmodified.
; Stack:		Input:			2 bytes
;					SP+1:			Row to jump to. Range: 0 to (LCD_ROW - 1)
;					SP+2:			Column to jump to. Range: 0 to (LCD_COLUMN - 1)
; Returns:		Nothing
lcd_gotoxy:
	.set PARAM_OFFSET = 4
	push TEMP
	push TEMP2
	push YH
	push YL

	in YH, SPH
	in YL, SPL

	ldd TEMP, Y+1+(SP_OFFSET+PARAM_OFFSET)		; Column
	ldd TEMP2, Y+1+(SP_OFFSET+PARAM_OFFSET)+1	; Row

	cpi TEMP2, (LCD_ROW - 1)
	brlt check_col
	ldi TEMP2, (LCD_ROW - 1)
	jmp gotoxy_assign
check_col:
	cpi	TEMP, (LCD_COLUMN - 1)
	brlt gotoxy_assign
	ldi TEMP, (LCD_COLUMN - 1)
gotoxy_assign:
	sts cursor_row, TEMP2
	sts cursor_col, TEMP

	#ifdef LCD_LINE4
	cpi TEMP2, 3
	brne ln3
	ldi TEMP2, LCD_LINE4
	jmp addcol
	#endif
	#ifdef LCD_LINE3
ln3:
	cpi TEMP2, 2
	brne ln2
	ldi TEMP2, LCD_LINE3
	jmp addcol
	#endif
	#ifdef LCD_LINE2
ln2:
	cpi TEMP2, 1
	brne ln1
	ldi TEMP2, LCD_LINE2
	jmp addcol
	#endif
ln1:
	ldi TEMP2, LCD_LINE1

addcol:
	add TEMP, TEMP2

	; Memory address is command data. Send using lcd_cmd
	push TEMP
	call lcd_cmd
	pop TEMP

	pop YL
	pop YH
	pop TEMP2
	pop TEMP
	ret
; **
; End of lcd_gotoxy


; **
; lcd_clr : 		Clear the LCD, return cursor to (0,0)
; Registers :	TEMP	-	Temporary working register.
; Memory :		cursor_row	-	Current cursor row. Updated.
;				cursor_col 	-	Current cursor column. Updated.
; Stack:		None.
; Returns:		None.
lcd_clr:
	push TEMP

	ldi TEMP, LCD_CMD_CLR
	push TEMP
	call lcd_cmd
	pop TEMP

	; Update cursor position,
	clr TEMP
	sts cursor_row, TEMP
	sts cursor_col, TEMP

	pop TEMP
	ret
; **
; End lcd_clr


; **
; lcd_init: 	Initialize the LCD based on the specifications for
;				initialization by command in the Hitachi HD44780
;				data sheet.
; Registers:	Most of TEMP, TEMP2, DREG, CREG, RET1-RET3, at
;				some point.
; Memory:		Lots of I/O space read/write.
; Stack:		None
; Returns:		Nothing.
lcd_init:
	push TEMP
	push CREG
	push DREG

	; Set Data Direction Register bits to output for LCD data 4-7,
	; E, and RS.
	lds TEMP, DDR_D4
	sbr TEMP, (1<<PIN_D4)
	sts DDR_D4, TEMP
	lds TEMP, PINS_D4
	cbr TEMP, (1<<PIN_D4)
	sts PORT_D4, TEMP

	lds TEMP, DDR_D5
	sbr TEMP, (1<<PIN_D5)
	sts DDR_D5, TEMP
	lds TEMP, PINS_D5
	cbr TEMP, (1<<PIN_D5)
	sts PORT_D5, TEMP

	lds TEMP, DDR_D6
	sbr TEMP, (1<<PIN_D6)
	sts DDR_D6, TEMP
	lds TEMP, PINS_D6
	cbr TEMP, (1<<PIN_D6)
	sts PORT_D6, TEMP

	lds TEMP, DDR_D7
	sbr TEMP, (1<<PIN_D7)
	sts DDR_D7, TEMP
	lds TEMP, PINS_D7
	cbr TEMP, (1<<PIN_D7)
	sts PORT_D7, TEMP

	lds TEMP, DDR_RS
	sbr TEMP, (1<<PIN_RS)
	sts DDR_RS, TEMP
	lds TEMP, PINS_RS
	cbr TEMP, (1<<PIN_RS)
	sts PORT_RS, TEMP

	lds TEMP, DDR_ENA
	sbr TEMP, (1<<PIN_ENA)
	sts DDR_ENA, TEMP
	lds TEMP, PINS_ENA
	cbr TEMP, (1<<PIN_ENA)
	sts PORT_ENA, TEMP

	; Initialize display to specs listed in HD44780 data sheet.
	; Generally very conservative with timing; speed may be improved
	; with some experimentation.

	ldi DREG, 0xF	; wait >= 15ms to power up. (Conservatively.)
	call dly_ms
	ldi DREG, 0x5
	call dly_ms

	ldi CREG, LCD_CMD_INI ; send the first half of 0x30 (8-bit mode) three times
	call lcd_nbl
	ldi DREG, 0x5	; wait 5ms before sending the second set command
	call dly_ms
	ldi CREG, LCD_CMD_INI
	call lcd_nbl
	ldi R21, 0x7	; wait 15ms (max for dly_ms) 7 times is ~100ms
dly_init:
	ldi DREG, 0xF	; wait 100ms before sending the last one
	call dly_ms
	dec R21  		; dec temp counter (not used in dly_ms)
	brne dly_init	; if 0, send the nibble again
    ldi CREG, LCD_CMD_INI
	call lcd_nbl
	ldi DREG, LCD_DAT	; wait LCD_DATus before sending more commands
	call dly_us
	ldi CREG, LCD_CMD_FNC	; load 4-bit mode command into CREG
	call lcd_nbl
	ldi DREG, LCD_DAT
	call dly_us
	ldi TEMP, LCD_CMD_FUNCTION_SET		; 4-bit, 2-line, 5x8 dot

	push TEMP
	call lcd_cmd
	pop TEMP

	ldi TEMP, LCD_CMD_DSP		; Display Off, Cursor Off, Blink Off

	push TEMP
	call lcd_cmd
	pop TEMP

	ldi TEMP, LCD_CMD_CLR	; Display Clear

	push TEMP
	call lcd_cmd
	pop TEMP

	ldi DREG, LCD_CMD_HOM
	call dly_ms
	ldi TEMP, LCD_CMD_ENTRY_MODE		; Increment cursor, no Display Shift

	push TEMP
	call lcd_cmd
	pop TEMP

	ldi TEMP, LCD_CMD_DISPLAY_MODE		; Display On, Cursor On, Blink On

	push TEMP
	call lcd_cmd
	pop TEMP

	clr TEMP
	sts cursor_row, TEMP ; Update cursor position to (0,0)
	sts cursor_col, TEMP

	pop DREG
	pop CREG
	pop TEMP

	ret
; **


; **
; dly_us : 			Busy-Wait loop for about DREG microseconds.
;					(0 < DREG <= 255)
;					Regrettably assumes a CPU speed of 16 MHz.
;					This should be abstracted to use the symbol
;					FCPU to calculate a 1us loop for the CPU
;					speed of the given processor.
;
; Registers:	DREG	-	Input. Used as counter. MODIFIED.
;				TEMP	-	Counter. MODIFIED.
; Memory:		Nope.
; Stack:		Nah.
; Returns:		Nothing.
dly_us:
	push TEMP
	push DREG

dlyus_dreg:	ldi TEMP, 0x05
dlyus_in:	dec TEMP
			brne dlyus_in
			dec DREG
			brne dlyus_dreg

	pop DREG
	pop TEMP

	ret
; **
; End of dly_us


; **
; dly_ms:			Busy-wait loop for about DREG milliseconds.
;					Hackily adapted from the delay_ms function
;					in the AVR C libraries. Regrettably assumes a
;					CPU speed of 16 MHz.
;
; Registers : 	DREG	-	Input. Number of ms to wait. MODIFIED.
;				YH:YL	-	16-bit counter. MODIFIED.
;				TEMP	-	Temporary value. MODIFIED.
; Memory:		None.
; Stack:		None.
; Returns:		Nothing.
dly_ms:
	push TEMP
	push TEMP2
	push DREG
	push YH
	push YL

		; 1ms = FCPU / 1000 instructions
		; This loop is 4 instructions per iteration.
		;
		ldi TEMP, 0xFD
		mul DREG, TEMP
		mov TEMP, R1
		swap TEMP
		andi TEMP, 0xF0
		mov YH, TEMP
		mov TEMP, R0
		swap TEMP
		mov TEMP2, TEMP
		andi TEMP, 0xF0
		andi TEMP2, 0x0F
		mov YL, TEMP
		or YH, TEMP2


dlyms:	sbiw YH:YL, 1
		brne dlyms

	pop YL
	pop YH
	pop DREG
	pop TEMP2
	pop TEMP
	ret
; **
; End dlyms


; **
; str_init:		Takes a pointer to an initialized constant in program memory,
;				and a pointer to a location in data memory. Iterates over the
;				segment of program memory and loads each byte into the corresponding
;				byte of data memory until a null character is found. You should probably
;				make sure of two things:
;					1) That the string in program memory is explicitly null terminated,
;					   otherwise you can have fun with data memory full of instructions.
;					2) That you've reserved enough memory in data space to fit the string
;					   you initialized in program memory, otherwise you're going to have a
;					   super-great time trying to figure out why your string keeps getting
;					   mangled.
;				This subroutine does automatically toss a null character on the end of the
;				string being initialized.
str_init:
	.set PARAM_OFFSET = 7
	push TEMP
	push ZH
	push ZL
	push XH
	push XL
	push YH
	push YL
	in YH, SPH
	in YL, SPL

	ldd ZL, Y+1+(SP_OFFSET+7)
	ldd ZH, Y+1+(SP_OFFSET+7)+1

	ldd XL, Y+1+(SP_OFFSET+7)+2
	ldd XH, Y+1+(SP_OFFSET+7)+3

initloop:
	lpm TEMP, Z+
	cpi TEMP, 0x00
	st X+, TEMP
	brne initloop

	pop YL
	pop YH
	pop XL
	pop XH
	pop ZL
	pop ZH
	pop TEMP

	ret
; **
; End of str_init



; *** ***
; End of Subroutine Definitions


; ***
; Program Memory Allocation

; Initialization value for default string. (Not included if LCD_LIBONLY defined.)
#ifndef LCD_LIBONLY
init:	.db		"Hello, World!", '\0'
#endif

; ***
; End of Program Memory Allocation

#ifdef LCD_LIBONLY
lcd_after:
#endif

; ***
; Data Memory Allocation

.dseg

	; Data memory reserved for default string. (Not allocated if LCD_LIBONLY defined.)
	#ifndef LCD_LIBONLY
	str: .byte lcd_length ;
	#endif

	; Data memory allocated for current LCD cursor position.
	cursor_row:	.byte 1 
	cursor_col:	.byte 1	

; ***
; End of Data Memory Allocation
