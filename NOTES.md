**8656B Notes**

## Clock considerations
The 68705P5 internal clock generator prescales the oscillator input by four. A 4MHz AT cut parallel resonance crystal at about 27pF is populated on the 8656B, meaning that the microcontroller will run at a clock frequency of 1MHz.

The 32U4 does have an internal prescaler on it's oscillator input, however this one is a divide-by-8. Fortunately most instructions run a little quicker in AVR so the timings are not too far off. Consideration should be taken when calculating delays.

## Fractional N Microprocessor
Various notes about this thing. In general it slurps up (up to) 17 bytes of serial information. It digests the first byte as a command and actuates a number of control lines in response. The main functionality is to convert this 16 bytes of data into 4 bit chunks spit out of it's parallel port.

### Serial Data Input
  - Serial data is sampled on rising edge of clock pulse and is sent in 4-bit words. Data always begins with a 4-bit command to this microcontroller. Commands are listed below. If the command is 0x8 or higher, 16 words of 4-bit data are expected to follow. 

### Serial Commands

The command is the first byte received on the serial line and directs the microprocessor to actuate
different modes on it's output. For example, enable FM mode.


  |Command|Description|
  |---|---|
  |0x00|Set `fm_dc_en` and update the controller ? |
  |0x01|Send status of PLL Out of Lock indicator, used in built-in self test mode `6` (Press Shift+INCR SET to enter test mode) |
  |0x02|Disable FM|
  |0x03|Enable FM|
  |0x04|Enable FM DC Mode|
  |0x05|FM Calibration Cycle|
  |0x08|Standard transmit - sends data to Fractional-N controller - last byte is a **0x04**|
  |0x09|Alternate transmit - last byte is a **0x08**|
  |0x0A|Alternate transmit - last byte is a **0x09**|

### Signals (Pin Registers as they are on the 68705P5)
  - PA0:3 Parallel Data Out
  - PA4 : Parallel Clock Out
  - PA5 : Data Valid Output
    - Typically a 7.2uS positive pulse, otherwise low
  - PA6 : FM DC Enable
  - PA7 : FM Offset
  - PB0 : FM Enable
  - PB1 : B+C (H) Blank/Compare Out
  - PB2 : S (L)
  - PB3 : FM Cal Add Cycle
  - PB4 : (Test Mode Input) FM No Calibration
  - PB5 : (Test Mode Input) LF Loop set to 66.80001MHz
  - PB6 : (Test Mode Input) Signal Analysis Test Mode
  - PB7 : (Test Mode Input) Unused
  - PC1 : Serial Data Input
  - PC2 : Mode Select Input
    - Normal operation: High
    - Test mode: Low
  - PC3 : PLL Out Of Lock Indicator
  - INT : Serial Clock In

### Signals (Pin Registers as they are on the 32U4)
  - PD0:3 Parallel Data Out
  - PD4 : Parallel Clock Out
  - PD5 : Data Valid Output
    - Typically a 7.2uS positive pulse, otherwise low
  - PD6 : FM DC Enable
  - PD7 : FM Offset
  - PB0 : FM Enable
  - PB1 : B+C (H) Blank/Compare Out
  - PB2 : S (L)
  - PB3 : FM Cal Add Cycle
  - PB4 : (Test Mode Input) FM No Calibration
  - PB5 : (Test Mode Input) LF Loop set to 66.80001MHz
  - PB6 : (Test Mode Input) Signal Analysis Test Mode
  - PB7 : (Test Mode Input) Unused
  - PF5 : Serial Data Input
  - PF6 : Mode Select Input
    - Normal operation: High
    - Test mode: Low
  - PF7 : PLL Out Of Lock Indicator
  - PC7 : Serial Clock In

### fuses:
  -  _lfuse_ **0xED** - Ext Crystal Osc, Freq 3.0-8.0MHz, 16KCK _ 4.1mS delay, /8 Divider
  -  _hfuse_ **0xD9** - Boot flash 2048, start $3800, JTAG disabled SPI Programming enabled
  -  _efuse_ **0xC8** - Brownout Detection 4.3V, HW Boot Enable=0
  -  _lock_  **0xFF** - No lock set

  - `avrdude -c dragon_isp -p m32u4 -P usb -U lfuse:w:0x6D:m`
  - `avrdude -c dragon_isp -p m32u4 -P usb -U hfuse:w:0xD9:m`
  - `avrdude -c dragon_isp -p m32u4 -P usb -U efuse:w:0xC8:m`
  - `avrdude -c dragon_isp -p m32u4 -P usb -U lock:w:0xFF:m`
  - `avrdude -c dragon_isp -p m32u4 -P usb -U flash:w:1820-3618.hex`
