/* File: arduinoLCDinC.c

 Author: Adar Guy
 Contact: adarguy10@gmail.com

 This program implements scrolling on the AVR AtMega 2560 Microcontroller.
 The function of each button is as follows:
 		Up - Stop scrolling
 		Down - Start scrolling
 		Left - Decrease scrolling speed
 		Right - Increase scrolling speed
 		Select - Scroll through 6 different messages. Displays two at a time
 */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "main.h"
#include "lcd_drv.h"

void displayValue (int val)
{
	unsigned char toL = 0x00;
	unsigned char toB = 0x00;

	val = val & 0x3F;

	if (val & 0x01)
		toL |= 0x80;
	if (val & 0x02)
		toL |= 0x20;
	if (val & 0x04)
		toL |= 0x08;
	if (val & 0x08)
		toL |= 0x02;
	if (val & 0x10)
		toB |= 0x08;
	if (val & 0x20)
		toB |= 0x02;
	
	PORTB = toB;
	PORTL = toL;	
}



int check_buttons(int last_button)
{
	unsigned int count = 0;

	DDRL = 0xFF;
	DDRB = 0xFF;

	ADCSRA = 0x87;
	ADMUX = 0x40;
	
	for (;;)
	{
		ADCSRA |= 0x40;

		while (ADCSRA & 0x40)
			;
		unsigned int val = ADCL;
		unsigned int val2 = ADCH;

		val += (val2 << 8);
		count = count + 1;

		if (val > 1000)         // no button pressed
		{
			if (last_button == 2)
				return 2; // if up button was pressed last time keep holding
			else
				return 0;
		}

	    if (val < 50)
		{
			if (last_button == 2)
				return 2; 			// right button pressed
			return 1;  
	    }
		if (val < 195)		// up button pressed
		{
			return 2;
		}
		if (val < 380)		// down button pressed
			return 3;
		if (val < 555)  	// left button pressed
		{
			if (last_button == 2)
				return 2;
			return 4;
	    }
		else
		{ 			// select button pressed
			if (last_button == 2)
				return 2;
			return 5;	
		}
	}
}

void copy_line(char* line, int ptr, char*  display)
{
	
	int i = 0;
	while (i<16)
	{		
		if (display[ptr] == 0)
		{
			ptr = 0;
		}		
		else
		{
			line[i++] = display[ptr++];
		}
	}
	line[16] = '\0';
}

void display_line(char* line_1, char* line_2)
{
	lcd_xy(0,0);
	lcd_puts(line_1);

	lcd_xy(0,1);
	lcd_puts(line_2);
}

int check(char* display, int ptr)
{
	if (display[ptr] == 0)
		ptr = 0;
	return ptr;
}

char* choose_msg(int count, int line)
{
	char* msg1 = "LINE 1 LINE 1 LINE 1 LINE 1 LINE 1 LINE 1 LINE 1";
	char* msg2 = "LINE 2 LINE 2 LINE 2 LINE 2 LINE 2 LINE 2 LINE 2";
	char* msg3 = "LINE 3 LINE 3 LINE 3 LINE 3 LINE 3 LINE 3 LINE 3";
	char* msg4 = "LINE 4 LINE 4 LINE 4 LINE 4 LINE 4 LINE 4 LINE 4";
	char* msg5 = "LINE 5 LINE 5 LINE 5 LINE 5 LINE 5 LINE 5 LINE 5";
	char* msg6 = "LINE 6 LINE 6 LINE 6 LINE 6 LINE 6 LINE 6 LINE 6";
	
	if (count == 0)
	{
		displayValue(3);
		if (line == 1)
			return msg1;
		else
			return msg2;

	}
	else if (count == 1)
	{
		displayValue(6);
		if (line == 1)
			return msg2;
		else
			return msg3;
	}
	else if (count == 2)
	{
		displayValue(12);
		if (line == 1)
			return msg3;
		else
			return msg4;;
	}
	else if (count == 3)
	{
		displayValue(24);
		if (line == 1)
			return msg4;
		else
			return msg5;
	}
	else if (count == 4)
	{
		displayValue(48);
		if (line == 1)
			return msg5;
		else
			return msg6;
	}
	else 
	{
		displayValue(33);
		if (line == 1)
			return msg6;
		else
			return msg1;
	}
}

int main(void)
{
	int button = 0;
	int ms = 4;
	int x = 32;
	int count = 0;

	lcd_init();
	lcd_blank(x);

	char* display1;
	char* display2;	

	char line_1[17];
	char line_2[17];
	
	int l1ptr = 0;
	int l2ptr = 0;

	display1 = choose_msg(count, 1);
	display2 = choose_msg(count++, 2);

	copy_line(line_1, l1ptr, display1);
	copy_line(line_2, l2ptr, display2);
	
	for (;;)
	{	
		lcd_blank(x);	
		display_line(line_1, line_2);
	start:
		button = check_buttons(button);
		if (button == 2)
			goto start;
		if (button == 4)
			ms += 1;
		if (button == 1)
			if (ms > 0)
				ms -= 1;
		if (button == 5)
		{
			_delay_ms(200);
			if (count == 6)
				count = 0;
			display1 = choose_msg(count, 1);
			display2 = choose_msg(count++, 2);
		}
		 	
		l1ptr++;
		l1ptr = check(display1, l1ptr);

		l2ptr++;
		l2ptr = check(display2, l2ptr);
	
		copy_line(line_1, l1ptr, display1);
		copy_line(line_2, l2ptr, display2);
		
		int i = 0;
		while (i <= ms)
		{	
		start2:
			button = check_buttons(button);
			if (button == 2)
				goto start2;
			if (button == 4)
				ms += 1;
			if (button == 1)
				if (ms > 0)
					ms -= 1;
			if (button == 5)
			{
				_delay_ms(200);
				if (count == 6)
					count = 0;
				display1 = choose_msg(count, 1);
				display2 = choose_msg(count++, 2);
			}
			_delay_ms(50);		 //regularly is 200 because ms is 4
			i++;
		}
		
	}
}

