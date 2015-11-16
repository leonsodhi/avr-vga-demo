AVR VGA Demo
============

Illustrates how a VGA signal can be generated entirely in software using an AVR microcontroller. This simple demo fills the entire screen with a single colour, which can be changed by connecting a switch up to pin 6 on PORT C. For other pin assignments, take a look at `initPortsAndRegs` in `vga.c`.

Note that this demo requires the AVR to be running off an external 20 Mhz clock. Also, it was tested on an old Dell LCD screen and may or may not work on other monitors, particularly CRTs.

This implementation is slightly different to others found elsewhere via googling in that it uses two timers - one for HSYNC and one for VSYNC.


Resources
=========

In putting this together, I found the following to be invaluable sources of information:

* [Blondihacks - Bit-banging a VGA signal generator](http://quinndunki.com/blondihacks/?p=955)
* [LucidScience’s ATmega VGA generator](http://www.lucidscience.com/pro-vga%20video%20generator-1.aspx)
* [Vishnu's Blogs - Using AVR ATTiny2313 to generate VGA (video) signals – Part 2](https://vsblogs.wordpress.com/2012/10/30/using-avr-attiny2313-to-generate-vga-video-signals-part-2/)
* [Wikipedia - Video Graphics Array](https://en.wikipedia.org/wiki/Video_Graphics_Array)
* [DigitalCold's ARM Challenge FPGA Implementation](http://io.smashthestack.org/arm/digitalcold/)
