#define LCD_LIBONLY
.include "lcd.asm"

.cseg
	call main

lp:	jmp lp

main:
	call lcd_init
	call lcd_clr
	
	call init_strings
	call set_ptrs1
	call set_ptrs2
	ldi r18, 0x00
	ldi r19, 0x00
	loop:
		call lcd_clr	
		call display_strings
		call increment_ptrs1
		call increment_ptrs2
		call copy_strings1
		call copy_strings2
		call delay
		jmp loop

increment_ptrs1:
	push XH
	push XL
	push ZH
	push ZL
	push r16
	push r17

	inc r18
	ldi XH, high(l1ptr)
	ldi XL, low(l1ptr)
	
	ldi ZH, high(line1)
	ldi ZL, low(line1)
	
	ldi r16, high(msg1)
	ldi r17, low(msg1)
	
	add r17, r18
	
	st X+, r16
	st X, r17

	pop r17
	pop r16
	pop ZL
	pop ZH
	pop XL
	pop XH
	ret

increment_ptrs2:
	push XH
	push XL
	push ZH
	push ZL
	push r16
	push r17

	inc r19
	ldi XH, high(l2ptr)
	ldi XL, low(l2ptr)
	
	ldi ZH, high(line2)
	ldi ZL, low(line2)
	
	ldi r16, high(msg2)
	ldi r17, low(msg2)
	
	add r17, r19
	
	st X+, r16
	st X, r17

	pop r17
	pop r16
	pop ZL
	pop ZH
	pop XL
	pop XH
	ret
	
copy_strings1:
	push XH
	push XL
	push ZH
	push ZL
	push r16
	push YH
	push YL

	ldi XH, high(l1ptr)
	ldi XL, low(l1ptr)

	ldi ZH, high(line1)
	ldi ZL, low(line1)

	ld r16, X+
	mov YH, r16

	ld r16, X
	mov YL, r16
	
	ldi r17, 0x00
	copy_loop1:
		ld r16, Y+
		cpi r16, 0
		breq wrap_around1
		
		st Z+, r16
		cpi r17, 17
		breq done
		
		inc r17
		jmp copy_loop1
		wrap_around1:
			cpi r17, 0x00
			brne skipped1
			clr r18
		skipped1:
			ldi YH, high(msg1)
			ldi YL, low(msg1)
			jmp copy_loop1				
		done:
			pop YL
			pop YH
			pop r16
			pop ZL
			pop ZH
			pop XL
			pop XH
			ret

copy_strings2:
	push XH
	push XL
	push ZH
	push ZL
	push r16
	push YH
	push YL

	ldi XH, high(l2ptr)
	ldi XL, low(l2ptr)

	ldi ZH, high(line2)
	ldi ZL, low(line2)

	ld r16, X+
	mov YH, r16

	ld r16, X
	mov YL, r16
	
	ldi r17, 0x00
	copy_loop2:
		ld r16, Y+
		cpi r16, 0
		breq wrap_around2
		
		st Z+, r16
		cpi r17, 17
		breq done2
		
		inc r17
		jmp copy_loop2
		wrap_around2:
			cpi r17, 0x00
			brne skipped2
			clr r19
		skipped2:
			ldi YH, high(msg2)
			ldi YL, low(msg2)
			jmp copy_loop2				
		done2:
			pop YL
			pop YH
			pop r16
			pop ZL
			pop ZH
			pop XL
			pop XH
			ret

set_ptrs1:
	push XH
	push XL
	push r16
	push r17
	push YH
	push YL

	ldi XH, high(l1ptr)
	ldi XL, low(l1ptr)
	
	ldi r16, high(msg1)
	ldi r17, low(msg1)

	st X+, r17
	st X, r16
	sbiw XH:XL, 1

	ld YH, X+
	ld YL, X
	sbiw XH:XL, 1

	pop YL
	pop YH
	pop r17
	pop r16
	pop XL
	pop XH
	ret

set_ptrs2:
	push XH
	push XL
	push r16
	push r17
	push YH
	push YL

	ldi XH, high(l2ptr)
	ldi XL, low(l2ptr)
	
	ldi r16, high(msg2)
	ldi r17, low(msg2)

	st X+, r17
	st X, r16
	sbiw XH:XL, 1

	ld YH, X+
	ld YL, X
	sbiw XH:XL, 1

	pop YL
	pop YH
	pop r17
	pop r16
	pop XL
	pop XH
	ret


init_strings:

	push r16				; copy strings from program memory to data memory
	ldi r16, high(msg1)		; this the destination
	push r16
	ldi r16, low(msg1)
	push r16
	ldi r16, high(msg1_p << 1) ; this is the source
	push r16
	ldi r16, low(msg1_p << 1)
	push r16
	call str_init			; copy from program to data

	pop r16					; remove the parameters from the stack
	pop r16
	pop r16
	pop r16
	

	ldi r16, high(msg2)
	push r16
	ldi r16, low(msg2)
	push r16
	ldi r16, high(msg2_p << 1)
	push r16
	ldi r16, low(msg2_p << 1)
	push r16
	call str_init
	
	pop r16
	pop r16
	pop r16
	pop r16
	pop r16
	ret

display_strings:

	; This subroutine sets the position the next
	; character will be output on the lcd
	;
	; The first parameter pushed on the stack is the Y position
	; 
	; The second parameter pushed on the stack is the X position
	; 
	; This call moves the cursor to the top left (ie. 0,0)

	push r16

	call lcd_clr

	ldi r16, 0x00
	push r16
	ldi r16, 0x00
	push r16
	call lcd_gotoxy
	pop r16
	pop r16
	

	; Now display msg1 on the first line
	ldi r16, high(line1)
	push r16
	ldi r16, low(line1)
	push r16
	call lcd_puts
	pop r16
	pop r16

	; Now move the cursor to the second line (ie. 0,1)
	ldi r16, 0x01
	push r16
	ldi r16, 0x00
	push r16
	call lcd_gotoxy
	pop r16
	pop r16

	; Now display msg1 on the second line
	ldi r16, high(line2)
	push r16
	ldi r16, low(line2)
	push r16
	call lcd_puts
	pop r16
	pop r16

	pop r16
	ret

delay:	
del1:		nop
		ldi r21,0x10
del2:		nop
		ldi r22, 0xFF
del3:		nop
		dec r22
		brne del3
		dec r21
		brne del2
		dec r20
		brne del1	
		ret
; sample strings
; These are in program memory
msg1_p:.db"This is the first message displayed on the first line of the LCD.",0
msg2_p: .db "On the second line of the LCD", 0
.dseg
;
; The program copies the strings from program memory
; into data memory.  These are the strings
; that are actually displayed on the lcd
;
msg1:	.byte 200
msg2:	.byte 200

line1: .byte 17
line2: .byte 17

l1ptr: .byte 2
l2ptr: .byte 2
