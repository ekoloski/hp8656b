## HP1820-3618 replacement

This project aims to use modern hardware to recreate the functionality of a mask rom microcontroller known as 1820-3618 in HP catalogs. It was used in the HP 8656B Signal Generator, and possibly other equipment, to interface the generators main cpu with both the fractional-n divider asic and various modulation circuits. It's a serial to parallel converter that also manages some gpio control lines.

The service manual describes a high level overview of the chips functions but lacks enough detail to create a suitable replacement. As I later found out, this firmware also does a couple of interesting things in response to a few serial commands I've never seen my 8656B issue. It also provides some routines for troubleshooting the rest of the circuitry.

### But...why go to the effort when you can just get one from a junk unit?

I purchased this signal generator on one of the auction sites with the understanding that it was for parts only and needed repair. My goal from the start was to restore the unit and use it as part of my electronics lab. After quite a bit of debugging I ultimately traced the issues to a failing adjustment potentiometer and a failed transistor. This is where the story should happily end, however it does not. In the course of troubleshooting I did some sloppy probing around A13U9 which led to the introduction of **-15V** to the 'Out of Lock' comparator output pin, which is directly connected to pin 11 of the 1820-3618, A13U28.

The chip never functioned properly after that event. The unit was not able to achieve PLL lock even after the original faults were discovered and repaired. I probed the serial input of A13U28 and found data. I then probed the 4 parallel output pins and the control lines, still no activity.

I was unable to find any information on this chip, labeled as a Motorola SC87336CP. Comparing the pinout in the 8656B service manual I found it to be fairly unique pinout in the world of Motorola 8bit microcontrollers of the time. Some educated guesses led me to the MC68705P5, which fit the description. I suspect that my chip is a mask rom variant of this microprocessor. Which is great, but without the ability to read the ROM I am still stuck.

Thinking that it was a lost cause to recreate the chip at this point I decided to purchase a second 8656B in much worse cosmetic condition. The part was harvested, transplanted, and the repaired unit works great. Everything should have been wonderful! Unfortunately I decided to investigate what in addition to a missing A13U28 was wrong with the donor unit. Much to my disappointment, the only problem was a faulty electrolytic capacitor. Of course I had to replace it but now I'm back to the start and stuck with an otherwise functional boat anchor in need of one unobtanium chip.

### Extracting the ROM

After quite a bit of reading I had come to the belief that the chip would need to be carefully decapped and photographed under a microscope. It could then be possible to locate the ROM on the die and optically recover the bits. I've seen it done on the internet, so it's got to be easy, right?

Probably not. So I shelved this project in lieu of some others and spent a while just not thinking about it. Then I did a little more research and came across the work by [Sean Riddle](http://seanriddle.com/mc68705p5.html). He details an obscure operating mode of the same family of CPU, and how he exploited it.

This mode is entered by powering the chip with /RESET /INT and TIMER high, and pulling PC0 high to 7.5V. When the micro comes out of reset it will ingest opcodes to execute from PortA. At the same time, an output is latched onto PortB. If the instruction on PortA happens to be 0x9d (nop) then the chip will simply continue to iterate through all 2K of it's address space. The output on PortB is a permutation of the current address, and the contents in memory. There is also apparently some data on PortC, but that's damaged on my chip so I didn't bother. I suspect it's the missing bits of the address.

As mentioned, the damage to my chip was conveniently located on PortC. Maybe there's hope that this method works on my particular mask rom, and that it's not too badly damaged? I figured it's worth a shot, so I breadboarded everything up and hooked up the scope.

To my amazement, there was data. A stream of it! The byte is sampled on the falling edge of each clock, 8 clocks are required to produce one byte of actual data, as it appears in the form of:
    {ADDR} {ADDR} {DATA} {DATA} {ADDR} {ADDR} {DATA} {DATA}

I noticed that the pattern was repeating at each 16K boundary, meaning we have a 2K address space. The chip will happily loop through and read out the address space until reset.

A healthy chunk of data was captured on the logic analyzer. The data was sifted from the noise to produce a raw dump.

### Interpreting the ROM

Next I needed to figure out what I was looking at. Nothing lined up with the memory mapping from the MC68705P5's datasheet. I realized that not only did the chip fetch an opcode from PortA, it fetched an address. The 0x9D must have been read in as $59D, meaning my capture started at 1437 bytes in! I shifted the data to realign it and it lined up perfectly with the memory map in the datasheet. I overwrote all non-ROM addresses with 0x9D to make disassembly easier and was ready to disassemble.

The [MAME project](https://www.mamedev.org/) has done a lot of work with this type of micro, and it's no surprise they have a nice disassembler called unidasm, which happily ingested the ROM from my crippled chip.

It took a moment and help from the Motorola M68HC05 Applications Guide, but I was able to wrap my head around the result. The only code I've written for microprocessors has been interrupt driven and was written in C. This is neither of those things. Instead it's beautify simple and elegant.

Beyond that, recreating the functionality of the chip be considerably more difficult without it. There are nuances that are not discussed in the service manual. I've also found that a test pin labeled as unused in the service manual does have a routine associated with it. Perhaps this chip was used in other equipment?

### Converting to something more modern

Now that I have the program from the chip and it's datasheet there's no reason not to create a modern replacement.

I decided on an Atmel ATMEGA32U4-MUR. It was available, came in a small enough package that I could build a board to fit the original DIP-28W, and had more than enough capability for the job. After creating a small breakout board and soldering pin headers to emulate the original DIP28W, I was ready to start adapting the program.

With how purpose built the code is, and with the role it plays in setting up things like the FM calibration and other support circuitry in the 8656B, I suspect that the timings involved may be somewhat critical. I likely wouldn't achieve anything as close to the original if I wrote it in C, unless I did a bunch of extra work. So, AVR8 it is.

### Again...why?

The chances of anyone else needing a replacement for an HP1820-3618 are pretty slim. The chances of finding this and needing a replacement? Negligible.

But I would bet that there are others who may find themselves, for whatever reason, wanting to get a peek into a similar mask rom. I'd be glad if it helps in that case and maybe even resurrects some piece of hardware. It's been a lot of fun, and I've rediscovered a bit of code that, in all likelihood, no one else has even looked at in at least the last 25 years.