#include <avr/io.h>


#define mainreg r16
#define tempreg r17
#define zeroreg r1

; 1st high part of 16-bit reg
#define H161 ZH

; 1st low part of 16-bit reg
#define L161 ZL

.extern g_scanline

/*
 front porch = 11  lines = hsync & black
 vsync       = 2   lines = hsync & black
 back porch  = 32  lines = hsync & black
 video       = 480 lines = hsync, black, video, black
*/

; min time to service interrupt = 7 cycles
; max time to service interrupt = 10 cycles
.global TIMER1_OVF_vect
TIMER1_OVF_vect: ; 7 cycles + interrupted instruction time to get here
    
    ; HSync was activated by timer

    push	mainreg ; 2    
    in		mainreg, _SFR_IO_ADDR(SREG) ; 1
    push	mainreg ; 2
    
    lds		mainreg, TCNT1L ; 2 (takes 1 cycle to grab TCNT1L)
    
    cpi mainreg, 16 ; 1
    breq waste3 ; false = 1, true = 2    

    cpi mainreg, 15 ; 1
    breq waste2 ; false = 1, true = 2    

    cpi mainreg, 14 ; 1
    breq waste1 ; false = 1, true = 2    

    cpi mainreg, 13 ; 1
    breq waste0 ; false = 1, true = 2

    ; if we make it here something went wrong
    lds mainreg, PORTC
    ori mainreg, 0x80    
    out _SFR_IO_ADDR(PORTC), mainreg

waste3:
    nop ; 1
waste2:    
    nop ; 1
waste1:
    nop ; 1  
waste0:
        

    ; 89 cycles left
    push L161 ; 2
    push H161 ; 2
    push tempreg ; 2
  
    lds L161, g_scanline ; 2
    lds H161, g_scanline+1 ; 2
    
    ; if(g_scanline == 525)
    ldi mainreg, lo8(525) ; 1
    ldi tempreg, hi8(525) ; 1
    cp  L161, mainreg ; 1
    cpc H161, tempreg ; 1        
    breq ZERO_SCANLINE ; false = 1, true = 2 
    rjmp INC_SCANLINE ; 2

; linecounter == 525
ZERO_SCANLINE:
    ; g_scanline = 0 (Note: write to g_scanline happens below)
    clr L161 ; 1
    clr H161 ; 1
    
; linecounter != 525
INC_SCANLINE:
    ; g_scanline++
    adiw L161, 1 ; 2
    sts g_scanline, L161 ; 2
    sts g_scanline+1, H161 ; 2

VIDEO_CHECK:
    ; if(g_scanline >= 46)
    ldi mainreg, lo8(46) ; 1
    ldi tempreg, hi8(46) ; 1
    cp  L161, mainreg ; 1
    cpc H161, tempreg ; 1    
    brsh VIDEO_JUMP ; false = 1, true = 2 

VSYNC_NEXT_CHECK:
    ; if(g_scanline == 11)
    ldi mainreg, lo8(11) ; 1
    ldi tempreg, hi8(11) ; 1
    cp  L161, mainreg ; 1
    cpc H161, tempreg ; 1
    breq VSYNC_NEXT; false = 1, true = 2 

END_VSYNC_NEXT_CHECK:
    ; if(g_scanline == 13)
    ldi mainreg, lo8(13) ; 1
    ldi tempreg, hi8(13) ; 1
    cp  L161, mainreg ; 1
    cpc H161, tempreg ; 1
    breq END_VSYNC_NEXT; false = 1, true = 2

  
    ; None of the g_scanline checks above matched
    rjmp COMMON_NOT_VIDEO_DONE ; 2


VIDEO_JUMP: ; extends reach of branch instruction
    rjmp VIDEO ; 2


; g_scanline == 11
VSYNC_NEXT: // startTimer2ToClearVsync   
    sts TCNT2, zeroreg ; 2 // TCNT2 = 0

    // TCCR2A &= ~(1 << COM2A0)
    lds mainreg, TCCR2A ; 2
    andi mainreg, ~(1 << COM2A0) ; 1
    sts TCCR2A, mainreg ; 2

    // OCR2A = VALUE
    ldi mainreg, 68 ; 1
    sts OCR2A, mainreg ; 2    
    
    ; reset everything!
    nop
    nop
    ldi mainreg, 2
    sts GTCCR, mainreg ; 2 (reset timer/counter2 prescaler)
    sts TCNT2, zeroreg ; 2 // TCNT2 = 0
   
    rjmp COMMON_NOT_VIDEO_DONE ; 2     
    

; g_scanline == 13
END_VSYNC_NEXT: //startTimer2ToSetVsync    
    sts TCNT2, zeroreg ; 2 // TCNT2 = 0
    
    // TCCR2A |= (1 << COM2A0)
    lds mainreg, TCCR2A ; 2
    ori mainreg, (1 << COM2A0) ; 1    
    sts TCCR2A, mainreg ; 2

    // OCR2A = VALUE
    ldi mainreg, 67 ; 1
    sts OCR2A, mainreg ; 2           

    ; reset everything!    
    nop
    nop
    nop
    nop
    nop
    ldi mainreg, 2
    sts GTCCR, mainreg ; 2 (reset timer/counter2 prescaler)
    sts TCNT2, zeroreg ; 2 // TCNT2 = 0       

    rjmp COMMON_NOT_VIDEO_DONE ; 2        

COMMON_NOT_VIDEO_DONE:
    pop tempreg ; 2
    pop H161 ; 2
    pop L161 ; 2
    rjmp DONE ; 3

/*  
    ; 89 cycles left  
    if(g_scanline == 525)
    {
        g_scanline = 0
    }
    g_scanline++
    
    if(g_scanline > 45)
    {
        ldi mainreg, 0xFF ; white
        rjmp VIDEO
    } 
    if(g_scanline == 11) // vsync is next
    {
        // startTimer2ToClearVsync
        TCNT2 = 0
        OCR2A = VALUE // don't forget to use the prescaler
        TCCR2A = (1 << COM2A1) | ...
        rjmp DONE
    }
    if(g_scanline == 13) // end of vsync is next
    {
        //startTimer2ToSetVsync
        TCNT2 = 0
        OCR2A = VALUE // don't forget to use the prescaler
        TCCR2A = (1 << COM2A1 | 1 << COM2A0) | ...
        rjmp DONE
    }  
  
    rjmp DONE ; blank line.

VIDEO:
    ldi mainreg, 0xFF ; white

    out PORTA, mainreg ; 1 outputVideo
    nop * 511
*/
    ; DO SOMETHING USEFUL HERE
    

VIDEO:
    pop tempreg ; 2
    pop H161 ; 2
    pop L161 ; 2

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    ;nop    

    ;ldi mainreg, 1 ; red
    lds mainreg, g_colour ; 2
    out _SFR_IO_ADDR(PORTA), mainreg ; 1 ; outputVideo
    
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    out _SFR_IO_ADDR(PORTA), zeroreg ; 1

DONE:
    ; 12 cycles left - must be black    
    nop
    pop mainreg ; 2
    out _SFR_IO_ADDR(SREG), mainreg ; 1
    pop mainreg ; 2
    reti ; 4


; function asm_test_two
/*asm_test_two:
    push mainreg
    pop mainreg
    ret


; function asm_test
.global asm_test
asm_test:    
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    nop
    nop
    nop
    nop
    ;out _SFR_IO_ADDR(PORTC), r0
    ;push mainreg
    ;rjmp .-2
    nop
    ;call asm_test_two
    rjmp asm_test  
    ret*/
