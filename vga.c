#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

#define VIDEO_ISR_CLKS 636
#define HSYNC_COMPARE_MATCH 74 // port changes on the next cycle then the pin on the next, so 76 - 2

#define disableAnalogCompar() \
{ \
    ACSR &= ~(1 << ACIE); \
    ACSR |= 1 << ACD; \
}

extern void asm_test();

uint16_t g_scanline;
uint8_t g_colour = 3;


static void initPortsAndRegs()
{

    disableAnalogCompar()

    // LED2 = PC7   
    DDRC |= (1 << PINC7);
    
    // SWITCH = PC6 (input with pull ups)
    DDRC &= ~(1 << PINC6);
    PORTC |= (1 << PINC6);

    // VGA (R, R, G, G, B, B)
    DDRA |= (1 << PINA0) | (1 << PINA1) | (1 << PINA2) | (1 << PINA3) | (1 << PINA4) | (1 << PINA5);
    

    // Timer1 setup (Fast PWM Mode)
    /* The counter counts from BOTTOM to TOP then restarts from BOTTOM
     *       
     * Non-inverting Compare Output mode:
     * Output Compare (OCnx) is cleared on the compare match between
     * TCNTn and OCRnx, and set at BOTTOM
     */
    ICR1  = VIDEO_ISR_CLKS; // TOP
    OCR1A = HSYNC_COMPARE_MATCH; // trigger. Note: must be set before timer is initialized!
    TCCR1A |= (1<< COM1A1) | (1<< COM1A0) | (1 << WGM11); // set on Compare Match and clear at BOTTOM (inverting). Mode 14
    TCCR1B |= (1 << WGM13) | (1 << WGM12); // Mode 14    
    DDRD |= (1 << PIND5); // Set HSYNC Compare output pin for OC1A to output        
    TIMSK1 |= (1 << TOIE1); // enable timer1 overflow interrupt


    // Timer2 setup 
    TCCR2A |= (1 << COM2A1) | (1 << WGM21); // Clear OC2A on Compare Match. CTC mode
    //TCCR2A |= (1 << COM2A1) | (1 << COM2A0) | (1 << WGM21); // Set OC2A on Compare Match. CTC mode
    OCR2A = 0xFF; // (an extra 1*8 + 1 normal clock cycle are needed before a match occurs)
    DDRD |= (1 << PIND7); // Set VSYNC Compare output pin for OC2A to output
    

    // Start timers    
    TCCR1B |= (1 << CS10); // Timer 1 - start clock running with no prescaling
    TCCR2B |= (1 << CS21); // Timer 2 - start clock running with /8 prescaler    
    
    sei();
}


static uint8_t readInputLoop(uint8_t havedelay, uint8_t iterations)
{
    uint8_t ret = 0;

    for(uint8_t i = 0; i < iterations; i++)
    {
        if(bit_is_clear(PINC, 6))
        {
            ret = 1;
            while(1)
            {
                if(bit_is_set(PINC, 6))
                {
                    break;
                }
            }
            break;
        }
        else
        {
            if(havedelay) { _delay_ms(64); }
        }
    }
    
    return ret;
}


static void setColour()
{
    if(g_colour == 3)
    {
        g_colour = 12;
        return;
    }
    if(g_colour == 12)
    {
        g_colour = 48;
        return;
    }
    if(g_colour == 48)
    {
        g_colour = 3;
        return;
    }
    
}


int main(void)
{    
    initPortsAndRegs();    

    while(1)
    {   
        //asm_test();
       
        uint8_t pressed = readInputLoop(0, 6);
        if(pressed) { setColour(); }                
    }       
}
