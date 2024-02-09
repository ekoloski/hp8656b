; Modern replacement for HP 1820-3618 _fractional-n microprocessor_ using an _ATMEGA32U4_
; 
; Copyright 2024 Edward Koloski <ekoloski@gmail.com>
; Licensed under MIT (https://github.com/ekoloski/hp8656b/LICENSE)
;
; TODO: The basic functionality has been tested. Here is what still remains:
;  - Test and compare the fixed loop mode against the original
;  - Verify any delays that have a TODO comment on them
;  - Verify that command 0 works as expected

    .include "m32U4def.inc"

    .dseg
    .org    SRAM_START
sStatus:
    .BYTE   1
sCommand:
    .BYTE   1
sBuffer:
    .BYTE   16
sDataType:
    .BYTE   1

    .cseg
    .org    0x00

init:
    ldi     r16,LOW(RAMEND)     ; initialize
    out     SPL,r16             ; stack pointer
    ldi     r16,HIGH(RAMEND)    ; to RAMEND
    out     SPH,r16             ;

    ldi     r16,0xFF            ;
    out     DDRD,r16            ; set PORTD PD0:7 Output
    ldi     r16,0x05            ;
    out     PORTB,r16           ; set PB0 `fm_en` and PB2`S_L` high
    ldi     r16,0x0F            ;
    out     DDRB,r16            ; set PB0:PB3 Output
    ldi     r16,0xF0            ; 
    out     PORTB,r16           ; Set pull-ups on test mode input pins PB4:7
    sbi     PORTC,7             ; set PC7 pull-up
    sbi     PORTC,6             ; set PC6 pull-up `TP26`

    sbis    PINF,6
    rjmp    test_mode_tp26      ; if PF6 `TP26` is low then jump to TP26 routine
    rjmp    main                ; otherwise proceed to main program

test_mode_tp26:
    sbis    PINB,5                          ; if PB5 `Test mode fixed loop` is LOW
    jmp     testmode_lf_loop_vco_fixed      ;  jump to fixed loop routine
    sbis    PINB,6                          ; if PB6 `Signal Analysis` mode is LOW 
    jmp     testmode_signature_analysis     ;  jump to sig ana routine
    sbis    PINB,7
    jmp     testmode_unused                 ; if PB7 `Unused` is LOW jump to unused test routine
                                            ; Service manual lists as unused, but it jumps into
                                            ; signal analysis at an alternate point.
    rjmp    test_mode_tp26                  ; We're stuck here until a test mode is selected

main:
; Goofing off while testing
; Nothing uses the parallel bus most of the time, so I am using this idle time and the data 
; bits to output the last command run. This is displayed on a 7segment LED on the breadboard.
;    ldi     XL,LOW(sCommand)
;    ldi     XH,HIGH(sCommand)
;    ld      r16,X
;    out     PORTD,r16

    ldi     XL,LOW(sCommand)    ; initialize X pointer
    ldi     XH,HIGH(sCommand)   ; to SRAM array address
    ldi     r16,0x10            ;
buffer_fill_loop:
    st      X+,r16              ; Initialize the buffer (17 bytes) with all 0x10s 
    cpi     XL,Low(sBuffer+17)  ; Done yet?
    brne    buffer_fill_loop    ;
                                ;
                                ;Serial data is valid on the falling edge of the clock.
                                ;The first 4-bit word is always a command to this chip followed
                                ; by a 70uS wait, to allow the Fractional-N Controller time
                                ; to receive a Cycle Start Pulse.
                                ;The next 16 4-bit words are data words
    ldi     XL,LOW(sCommand)    ;
    ldi     XH,HIGH(sCommand)   ;
    ld      r16,X               ; Load the first word from the buffer and wait to receive
receive_command:
    sbic    PINC,7
    rjmp    receive_command     ; wait for PC7 `SCL` to go low
    sbis    PINF,5              ; 
    clc                         ; funny little dance
    sbic    PINF,5              ; to get the data bit into the carry bit
    sec                         ;
    rol     r16                 ; rotate the byte through carry to store the bit
                                ;  It's cooler in m6805 due to the indexed address mode on rol    
command_clockwait:
    sbis    PINC,7
    rjmp    command_clockwait   ; wait for PC7 `SCL` to go high
    brcc    receive_command     ; Loop to receive the word
    st      X,r16
    sbrs    r16,3               ; check if command is 0-7 and go run it
    rjmp    command_parser      ; otherwise loop to receive 16 more 4-bit words
    ldi     XL,LOW(sBuffer)
    ldi     XH,HIGH(sBuffer)
    ld      r16,X
receive_word:
    ld      r16,x
receive_bits:
    sbic    PINC,7
    rjmp    receive_bits        ; wait for PC7 `SCL` to go low
    sbis    PINF,5
    clc                         ; Transfer to carry
    sbic    PINF,5
    sec
    rol     r16                 ; rotate in the bit
rx_clockwait:
    sbis    PINC,7
    rjmp    rx_clockwait        ; Wait for the clock to go high
    brcc    receive_bits        ; make sure the entire word was received
    st      X+,r16              ; store it
    cpi     XL,Low(sBuffer+16)  ; check if all 16 bytes have been received
    brne    receive_word

command_parser:
    ldi     XL,LOW(sCommand)    ; initialize X pointer
    ldi     XH,HIGH(sCommand)   ; to Command address in SRAM
    ld      r16,X               ; load it
    cpi     r16,0x00
    breq    command_0           ; Command 0
    cpi     r16,0x01
    breq    command_1           ; Command 1
    cpi     r16,0x02
    breq    command_2           ; Command 2
    cpi     r16,0x03
    breq    command_3           ; Command 3
    cpi     r16,0x04
    breq    command_4           ; Command 4
    cpi     r16,0x05
    breq    command_5           ; Command 5
    cpi     r16,0x08
    breq    command_8           ; Command 8
    cpi     r16,0x09
    breq    command_9           ; Command 9
    cpi     r16,0x0A
    breq    command_a           ; Command A
    jmp     main                ; Not a valid command. Jump back to the start and try again

command_0:                      ; Not entirely sure what this one is for. 
                                ; It seems to preserve PORTD but set `data_valid`
                                ; Then send a a control, or terminate, word to the 'N Controller
    ldi     r16,0x00            ; load 0x00 into r16
    ldi     XL,LOW(sStatus)     ;
    ldi     XH,HIGH(sStatus)    ;
    ld      r17,X               ; load sStatus into r17
    or      r16,r17             ; or r16 and sStatus
    ldi     XL,LOW(sBuffer+15)  ;  ** Should this be sDataType or the last word in sBuffer? **
    ldi     XH,HIGH(sbuffer+15) ;
    st      X,r16               ; store it into the last word
    call    tx_last_word        ; transmit the last word
    jmp     main                ; all done

command_1:                      ; Report the status of OOL on the Serial Data line
    cbi     PORTF,5             ; This is used in the built-in self tests under option `6`
    sbic    PINF,7              ;
    sbi     PORTF,5             ; Transfer status of PF7 `OOL` to PF5 `SDA`
    ldi     r16,0x20            ;
    out     DDRF,r16            ; set PF5 `serial data in` as output
    ldi     r16,0x0D            ; Delay a moment
command_1_delay:
    dec     r16
    brne    command_1_delay
    ldi     r16,0x00
    out     DDRF,r16            ; Set PF5 `serial data in` back to an input
    sbi     PORTF,5             ; Set the pullup on PF5
    jmp     main                ; Back to program start

command_2:                      ; FM Disable
    ldi     r16,0x80
    call    update_status_byte

command_3:                      ; FM Enable
    ldi     r16,0x00
    call    update_status_byte

command_4:                      ; FM DC Mode Enable
    ldi     r16,0x40
    call    update_status_byte

command_5:                      ; Start an FM Calibration
    sbis    PINB,4              ; 
    jmp     main                ; Skip this if Test Mode pin `FM NO CAL` is LOW
    call    fm_calibration      ;
    jmp     main
                                ; There are three parallel transmit modes. Each appends a word that
                                ; indicates the data type. I have only seen my 8656B use command 8.
command_8:                      ; Transmit buffer - set data type to 0x04
    ldi     r17,0x04
    jmp     send_parallel_data

command_9:                      ; Transmit buffer - set data type to 0x08
    ldi     r17,0x08
    jmp     send_parallel_data

command_a:                      ; Transmit buffer - set data type to 0x09
    ldi     r17,0x09
    jmp     send_parallel_data
                                ; End of commands

send_parallel_data:             ; r17 should contain the last word to transmit
    ldi     XL,LOW(sDataType)
    ldi     XH,HIGH(sDataType)
    st      X,r17               ; Update the last word in the buffer with the contents of r17
    ldi     r16,0x0C            ; Delay before sending parallel data added to match original timing
parallel_data_start_delay:    
    dec     r16
    brne    parallel_data_start_delay
    call    initialize_buffer
    call    tx_parallel_data    ; Send a start word followed by all 16 words and a data type word
    jmp     main                ; All done

update_status_byte:             ; Update sStatus after changing FM mode
    ldi     XL,LOW(sStatus)
    ldi     XH,HIGH(sStatus)
    st      X,r16               ; Store the new status from r16 into sStatus
    out     PORTD,r16           ; Update the control lines on PORTD with new status
    ldi     r16,0x04            ; Set bit 2 of portB `S (L)`
    ld      r17,X
    sbrs    r17,7               ; If bit 7 of sStatus is clear then write sStatus to portB
    rjmp    update_status_byte_1
    ori     r16,0x01            ; Else write sStatus to portB and set `fm_enable`
update_status_byte_1:
    out     PORTB,r16           ; Write it to portB
    jmp     main

initialize_buffer:              ; Set status bits in the buffer to match sStatus
    ldi     XL,LOW(sBuffer)
    ldi     XH,HIGH(sBuffer)
    ldi     YL,LOW(sStatus)
    ldi     YH,HIGH(sStatus)
initialize_buffer_loop:
    ld      r16,X               ; pointer to the buffer
    ld      r17,Y               ; pointer to sStatus
    or      r16,r17             ; 'or' in the status bytes
    st      X+,r16              ; save and increment
    cpi     XL,Low(sDataType)   ; done?
    brne    initialize_buffer_loop
    ret

                                ; 4-bit parallel data out. Data is valid on rising edge of clk
                                ; This also preserves the status of control lines PD6:7
tx_parallel_data:               ; Wake up the Fractional-N controller
    ldi     r16,0x01            ; Set r16 to 0x01
    ld      r17,Y               ; Load the status byte into r17
    or      r16,r17
    out     PORTD,r16           ; Set PD0 `D1` high
    ori     r16,0x20
    out     PORTD,r16           ; Set PD5 `data_valid`
    nop                         ; Pulse stretcher
    andi    r16,0xCF            ; Clear data_valid and clk bits
    out     PORTD,r16
    eor     r17,r17             ; 
data_valid_delay_1:             ; This delay sets the length of the first word
    inc     r17                 ;
    cpi     r17,0x07
    brne    data_valid_delay_1
transmit_words:
    ldi     XL,LOW(sBuffer)
    ldi     XH,HIGH(sBuffer)    ; Pointer to the first word of data

    ld      r16,X+              ;  Word 1
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4             ; But, data_valid should be low already. replace with a nop
    nop                         ; to make CLK 6uS instead of 8uS
    nop

    ld      r16,X+              ;  Word 2
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop
    nop

    ld      r16,X+              ;  Word 3
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop

    ld      r16,X+              ;  Word 4
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop
    nop

    ld      r16,X+              ;  Word 5
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop

    ld      r16,X+              ;  Word 6
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop
    nop

    ld      r16,X+              ;  Word 7
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop

    ld      r16,X+              ;  Word 8
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop
    nop

    ld      r16,X+              ;  Word 9
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop

    ld      r16,X+              ;  Word 10
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop
    nop

    ld      r16,X+              ;  Word 11
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop

    ld      r16,X+              ;  Word 12
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop
    nop

    ld      r16,X+              ;  Word 13
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop

    ld      r16,X+              ;  Word 14
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4     
    nop
    nop
    nop

    ld      r16,X+              ;  Word 15
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4
    nop
    nop

    ld      r16,X+              ;  Word 16
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,4             ; Set `clk`
    cbi     PORTD,5             ; De-Assert `data_valid` and `clk`
    cbi     PORTD,4
    nop

    ld      r16,X+              ;  Data Type Word 
    out     PORTD,r16           ; Set the data bits
    sbi     PORTD,5             ; Set `clk`
    nop
    nop
    cbi     PORTD,5             ; De-Assert `data_valid`

    eor     r17,r17             ; Delay before sending terminate command
data_valid_delay_2:             ; Delay between last falling clk and D4 high
    inc     r17
    cpi     r17,0x05
    brne    data_valid_delay_2
tx_last_word:
    ldi     r16,0x00            ; Clear r16
    ld      r17,Y               ; Pointer to sStatus was set in initialize_buffer
    or      r16,r17             ; Bring in the status bits
    eor     r17,r17
tx_last_word_delay:             ; Delay before start of data_valid
    inc     r17
    cpi     r17,0x02
    brne    tx_last_word_delay
    out     PORTD,r16
    ori     r16,0x20            ; Set `data_valid` high
    out     PORTD,r16           
    andi    r16,0xCF
    nop
    nop
    out     PORTD,r16           ; Clear `clk` and `data_valid`
    ret

fm_calibration:                 ; Initiates an FM Calibration cycle
    ldi     XL,LOW(sStatus)
    ldi     XH,HIGH(sStatus)
    ld      r16,X
    ori     r16,0x40
    out     PORTD,r16           ; Set PD6 `fm_dc_en` set the remaining bits from sStatus
    ldi     r16,0x0B
    out     PORTB,r16           ; Set `fm_en`, `B+C` and `fm_add_cyc`
    call    delay_60mS          ; wait 60 milliseconds
    sbi     PORTB,2             ; Set PB2 `S (L)` pin
    cbi     PORTB,3             ; Clear PB3 `fm_add_cyc` pin
fm_cal_delay:
    ldi     r16,0x08            ; 
    out     OCR0A,r16           ; Set compareA to 0x08, about 5mS
    ldi     r16,0x00            ;
    out     TCNT0,r16           ; Clear TIMER0 Data Register
    ldi     r16,(1<<OCF0A)
    out     TIFR0,r16           ; Clear pending interrupt flags
    ldi     r16,(1<<CS02)
    out     TCCR0B,r16          ; Set the prescaler to /256, timer now running
fm_cal_delay_1:
    in      r16,TIFR0           ;
    sbrs    r16,OCF0A           ; Skip if compare matched
    rjmp    fm_cal_delay_1
    ldi     r16,(1<<OCF0A)
    out     TIFR0,r16           ; Clear pending interrupt flags
    ldi     r16,0x00
    out     TCCR0B,r16          ; Disable the timer and clean up   

    eor     r16,r16             ; Clock/Prescaler comination don't have enough resolution
fm_cal_delay_2:                 ; Extra delay before clearing `B+C H`
    inc     r16
    cpi     r16,0x2e            ; was 2e
    brne    fm_cal_delay_2
    cbi     PORTB,1             ; Clear PB1 `B+C H`
    eor     r16,r16             ; Clock/Prescaler comination don't have enough resolution
fm_cal_delay_3:                 ; Extra delay before setting port back to stored status
    inc     r16
    cpi     r16,0x04
    brne    fm_cal_delay_3      ; Delay loop
    ldi     XL,LOW(sStatus)
    ldi     XH,HIGH(sStatus)
    ld      r16,X               ; Load sStatus into r16
    sbrc    r16,7               ; Keep 'fm_en' pin set if status was already enabled
    rjmp    fm_cal_done
    cbi     PORTB,0             ; Otherwise clear PB0 `fm_en` pin
fm_cal_done:
    ldi     XL,LOW(sStatus)
    ldi     XH,HIGH(sStatus)
    ld      r16,X               ; Load sStatus into r16
    out     PORTD,r16           ; Put the contents of status byte on PORTD
    sbis    PINF,6              ;
    call    fm_calibration_wait ; Extra delay if TP26 is low (Test modes enabled)

    ret
; TODO: Look into this. If we got to this delay, TP26 is set. But if TP26 is set, aren't we in 
; test modes already and ignoring commands? If so, how did we get here in the first place?
fm_calibration_wait:
    ldi     r16,0x80            ; <-- Adjust this for the proper delay
    out     OCR0A,r16           ; Set compareA to ????
    ldi     r16,0x00            ;
    out     TCNT0,r16           ; Clear timer0 Data Register
    ldi     r16,(1<<OCF0A)
    out     TIFR0,r16           ; Clear pending interrupt flags
    ldi     r16,(1<<CS02)|(1<<CS00)
    out     TCCR0B,r16          ; Set the prescaler to /1024, timer running
fm_calibration_wait_loop:
    in      r16,TIFR0           ;
    sbrs    r16,OCF0A           ; Skip if compare matched
    rjmp    fm_calibration_wait_loop
    ldi     r16,(1<<OCF0A)
    out     TIFR0,r16           ; Clear pending interrupt flags
    ldi     r16,0x00
    out     TCCR0B,r16          ; Disable the timer and clean up   
    jmp     fm_calibration

delay_60mS:                     ; 60 millisecond delay
    ldi     r16,0x00            ;
    out     TCNT0,r16           ; Zero the timer
    ldi     r16,0x74            ; 
    out     OCR0A,r16           ; Set compareA to 0x74
    ldi     r16,(1<<OCF0A)
    out     TIFR0,r16           ; Clear pending interrupt flags
    ldi     r16,(1<<CS02)|(CS00)
    out     TCCR0B,r16          ; Set the prescaler to /1024, timer now running
delay_60mS_loop:
    in      r16,TIFR0           ;
    sbrs    r16,OCF0A           ; Skip if compare matched
    rjmp    delay_60mS_loop
    ldi     r16,(1<<OCF0A)
    out     TIFR0,r16           ; Clear pending interrupt flags
    ldi     r16,0x00
    out     TCCR0B,r16          ; Disable the timer and clean up
    eor     r17,r17             ; Clock/Prescaler combination doesn't have enough resolution.
delay_60mS_padding:             ; Add some padding
    inc     r17
    cpi     r17,0x08
    brne    delay_60mS_padding
    ret

                                ; Test Mode: Fixed Loop - Low Frequency Loop VCO's 
                                ; frequency is set to 66.80001MHz
testmode_lf_loop_vco_fixed:
    ldi     r17,0x21
testmode_lf_loop_vco_fixed_dly: ; Wait about two seconds
    jmp     delay_60mS    
    dec     r17
    brne    testmode_lf_loop_vco_fixed_dly
    ldi     XL,LOW(sBuffer+14)
    ldi     XH,HIGH(sBuffer+14) ; Set X to the 15th byte in buffer
    ldi     r16,0x00
    st      x,r16
    ldi     XL,LOW(sBuffer)
    ldi     XH,HIGH(sBuffer)    ; Set X to the 1st byte in buffer
    st      x+,r16              ; Zero 1st byte
    st      x+,r16              ; Zero 2nd byte
    st      x+,r16              ; Zero 3rd byte
    st      x+,r16              ; Zero 4th byte
    st      x+,r16              ; Zero 5th byte
    st      x+,r16              ; Zero 6th byte
    st      x,r16               ; Zero 7th byte
    ldi     XL,LOW(sBuffer+8)   ;
    ldi     XH,HIGH(sBuffer+8)  ; Set X to the 9th byte in buffer
    st      x+,r16              ; Zero the 9th byte
    st      x+,r16              ; Zero the 10th byte
    st      x+,r16              ; Zero the 11th byte
    st      x,r16               ; Zero the 12th byte
    ldi     XL,LOW(sBuffer+7)   ;
    ldi     XH,HIGH(sBuffer+7)  ; Set X to the 8th byte in buffer
    ldi     r16,0x05
    st      x,r16               ; Set the 8th byte to 0x05
    ldi     XL,LOW(sBuffer+12)  ;
    ldi     XH,HIGH(sBuffer+12) ;
    ldi     r16,0x04            ;
    st      x+,r16              ; Set the 13th byte to 0x04
    ldi     r16,0x01            ;
    st      x+,r16              ; Set the 14th byte to 0x01
    ldi     r16,0x03
    st      x,r16               ; Set the 15th byte to 0x03
    ldi     XL,LOW(sBuffer+16)
    ldi     XH,HIGH(sBuffer+16)
    ldi     r16,0x04
    st      x,r16               ; Set the 17th byte to 0x04
                                ; Manualy fill the buffer:
                                ;  41:00 00 00 00 00 00 00 05 00 00 00 00 04 01 03 00 04:52
    jmp     initialize_buffer   ; Initialize the buffer, set the appropriate signal lines
    jmp     tx_parallel_data    ; Send it
halt:
    jmp     halt

                                        ;This mode should only be run when
                                        ;  SCL and SDA are disconnected!
                                        ;   A3TP26 to GND
                                        ;   A3TP17 to GND
                                        ; The alternate signature at pins 14, 20, 27 check the
                                        ; input at pins 2, 8 to 11 and 16 to 19. When the input is
                                        ; low, the signature at the related pin is the alternate
                                        ; signature

                                        ;PB0 TP24 CLK fm_enable
                                        ;PB1 TP25 DSA B+C L (start_stop)

                                        ;PIN            NORMAL      ALTERNATE   Condition
                                        ;1(VSS)         0000        ----        ---
                                        ;2(SCL)         7U39        0000        Pin tied low
                                        ;3(VCC)         7U39        ----        ----
                                        ;6(VPP)         0000        ----        ----
                                        ;7(HIGH)        7U39        ----        ----
                                        ;8(LOW)         0000        ----        ----
                                        ;9(SDA)         0000        7U39        PF5 pulled high
                                        ;10(TP26)       7U39        0000        PF6 tied low
                                        ;11(OOL)        7U39        0000        Out of Lock LED on
                                        ;14(S (L))      0021        0020        INT pin low
                                        ;15(fm_add_cyc  0010        40C5        RAM Error
                                        ;16(S (L))      7U39        0000        PB4 tied low
                                        ;17(fixed_loop) 7U39        0000        PB5 tied low
                                        ;18(sig_ana)    7U39        0000        PB6 tied low
                                        ;19(unused)     7U39        0000        PB7 tied low
                                        ;20(D1)         2050        2052        PF4 low
                                        ;21(D2)         102C        1029        PF5 low
                                        ;22(D4)         0816        0814        PF6 low
                                        ;23(D8)         0408        040A        Out of Lock LED ON
                                        ;24(PCLK)       0201        0205        PB4 low
                                        ;25(data_valid) 0105        0102        PB5 low
                                        ;26(fm_dc_en)   0085        0081        PB6 low
                                        ;27(fm_off)     0044        0040        PB7 low
                                        ;28 RESET       7U39        ----        ----
testmode_signature_analysis:
    ldi     r16,0x00
    out     PORTD,r16           ; Blank PORTD
    out     PORTB,r16           ; Blank PORTB
    ldi     r16,0x10            ; Load an initial value into r16
ramtest_resetX:
    ldi     XL,LOW(sStatus)
    ldi     XH,HIGH(sStatus)
ramtest:
    st      X,r16               ; Store t16 into RAM location
    ld      r17,X+              ; Load that memory location into r17 and increment
    cp      r16,r17             ; memory test
    brne    ramfail
    cpi     XL,Low(sStatus+81)  ; Not all the ram is tested, but more is tested than is used.
    brne    ramtest             ; The 80 bytes is arbitrary to get close to the original timing.
    ldi     r17,0x11
    add     r16,r17             ; Add 0x11 without carry
    brcc    ramtest_resetX      ; branch if carry is clear to start over
    rjmp    rampass
ramfail:
    sbi     PORTB,3             ; Set PB3 `fm_add_cyc`
rampass:
    eor     r17,r17             ; Clock/Prescaler combination doesn't have enough resolution.
ramtest_padding:                ; Timing here is not critical, regardless a delay is added
    inc     r17                 ; to more closely match the original.
    cpi     r17,0x02
    brne    ramtest_padding
    sbi     PORTB,1             ; Set bit PB1 `B+C H` (Open SA window)
    call    dsa_clock           ; Clock the signature analyzer
    cbi     PORTB,3             ; Clear bit PB3 `fm_add_cyc`
    ldi     r16,0x01
bit_shift_loop:                 ; Walk a bit through PORTD
    out     PORTD,r16           ; Update PORTD
    call    dsa_clock           ; Clock the signature analyzer
    lsl     r16                 ; shift the bit left
    brcc    bit_shift_loop      ; Walk through the entire port
    clr     r16
    out     PORTD,r16           ; Clear PORTD
    sbi     PORTB,2             ; Set PB2 `S (L)`
    call    dsa_clock           ;
    cbi     PORTB,2             ; Clear PB2 `S (L)`
    sbi     PORTB,3             ; Set PB3 `FM_CAL_ADD_CYC`
    call    dsa_clock           ;
    cbi     PORTB,3             ; Clear PB3 `FM_CAL_ADD_CYC`
    clr     r16
    out     PORTD,r16           ; Clear PORTD
    call    dsa_clock           ; Clock the signature analyzer
    in      r16,PINB            ; Load PORTB into r16
    andi    r16,0xF0            ; Only take the top 4 bits
    out     PORTD,r16           ; Mirror it onto PORTD
    call    dsa_clock           ; Clock the DSA
    clr     r16
    in      r16,PINF            ; Load PORTF into r16
    andi    r16,0xF0            ; Clear the unused bits at the top half
    ;swap    r16                 ; swap the nibbles
    out     PORTD,r16           ; output the contents of PORTF onto PORTD0:3
    call    dsa_clock
    clr     r16
    out     PORTD,r16           ; Clear PORTD
    jmp     testmode_unused

dsa_clock:                      ; Deliver a brief pulse to `fm_en` pin PB0
    sbi     PORTB,0
    nop
    nop
    cbi     PORTB,0
    ret

testmode_unused:
    sbis    PINC,7              ; If PC7 `serial_clock_in` is low then clear PB2 and clock sig ana
    rjmp    test_mode_1
    sbi     PORTB,2             ; Otherwise set PB2 `S (L)`
    call    dsa_clock
    rjmp    test_mode_2
test_mode_1:
    cbi     PORTB,2             ; Clear PB2 `S (L)`
    call    dsa_clock
test_mode_2:
    cbi     PORTB,1             ; Clear PB1 `B+C H`
    call     dsa_clock
    ldi     r16,0x28            ; <--Adjust this for the proper delay between cycles, about 28mS
    out     OCR0A,r16           ; Set output compare A to set delay
    ldi     r16,0x00            ;
    out     TCNT0,r16           ; Clear TIMER0 Data Register
    ldi     r16,(1<<OCF0A)
    out     TIFR0,r16           ; Clear pending interrupt flags
    ldi     r16,(1<<CS01)|(1<<CS00)
    out     TCCR0B,r16          ; Set the prescaler, timer now running
test_mode_unused_dly:
    in      r16,TIFR0           ;
    sbrs    r16,OCF0A           ; Skip if compareA matched
    rjmp    test_mode_unused_dly
    ldi     r16,(1<<OCF0A)
    out     TIFR0,r16           ; Clear pending interrupt flags
    ldi     r16,0x00
    out     TCCR0B,r16          ; Disable the timer and clean up
    jmp     testmode_signature_analysis
