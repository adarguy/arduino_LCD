/*
 * button.c
 *
 * An example of using the buttons on the LCD shield
 *
 * The buttons are all wired to Analog Pin 0 which is PORT F, Pin 0
 * Also known as ADC0
 *
 * From the arduino example sketch, we have:
 *
 *  if (adc_key > 1000 )   return btnNONE;
 *  if (adc_key_in < 50)   return btnRIGHT;  
 *  if (adc_key_in < 195)  return btnUP; 
 *  if (adc_key_in < 380)  return btnDOWN; 
 *  if (adc_key_in < 555)  return btnLEFT; 
 *  if (adc_key_in < 790)  return btnSELECT;   
 */

#define F_CPU 16000000UL

#include <avr/io.h>
#include <util/delay.h>

/*
 * See lcd_numbers example for details on this
 */
void displayValue ( int val )
{
	unsigned char toL = 0x00;
	unsigned char toB = 0x00;

	// We only have six LEDs, so only six bits of precision
	// mask off the rest
	// 0b0011 1111
	// 0x3F
	val = val & 0x3F;

	// This should be a loop but... 
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


int main (void)
{
	unsigned int count = 0;

	/* set PORTL and PORTB for output*/
	DDRL = 0xFF;
	DDRB = 0xFF;


	/* enable A2D: */

	/* ADCSRA:
	 * bit 7 - ADC enable
	 * bit 6 - ADC start conversion
	 * bit 5 - ADC auto trigger enable
	 * bit 4 - ADC interrupt flag
	 * bit 3 - ADC interrupt enable
	 * bit 2 |
	 * bit 1 |- ADC prescalar select bits
	 * bit 0 |
	 * 
	 * we want:
	 * 0b1000 0111
	 * which is:
	 * 0x87
	 */
	ADCSRA = 0x87;

	/* ADMUX - ADC Multiplexer Selection Register
	 *
	 * Select ADC0
     */
	ADMUX = 0x40;
	
	for (;;)
	{

	// start conversion
	ADCSRA |= 0x40;

	// bit 6 in ADCSRA is 1 while conversion is in progress
	// 0b0100 0000
	// 0x40
	while (ADCSRA & 0x40)
		;
	unsigned int val = ADCL;
	unsigned int val2 = ADCH;

	val += (val2 << 8);

	count = count + 1;
	
	if (val > 1000 )
	{
		displayValue(0);
		continue;
	}
			 
    if (val < 50) 
	  displayValue(1);  
    else if (val < 195)
	  displayValue(2);
    else if (val < 380)  
	  displayValue(4);
    else if (val < 555)  
	  displayValue(8);
    else 
	  displayValue(16);
	   

	/*
	if (count % 100 == 0)
	{
		displayValue(0x00);
		_delay_ms(300);
		displayValue(0x3F);
		_delay_ms(300);
		displayValue(0x00);
		_delay_ms(300);
	}
	*/
	
	}
}

