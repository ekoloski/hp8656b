          ; HP 1820-3618 Mask ROM based off MC68705P5 (Or so I think)
          ; $000=PORTA, $001=PORTB, $002(low 4 bits)=PORTC, $003 not used
          ; $004=DDRA,  $005=DDRB,  $006(low 4 bits)=DDRC,  $007 not used (DDRs read as $FF)
          ; $008=Timer Data Reg, $009=Timer Control Reg
          ; $00A-$03F not used
          ; $040-$07F=RAM (stack starts at $07F)
            ; $40=status byte
            ; $41=command word
            ; $42-$52=buffered serial data
          ; $080-$0FF=Page Zero User ROM
          ; $0AC-$3BF not used
          ; $3C0-$664 Main User ROM
          ; $665-$783 not used
          ; $784-$7F7 Self-Check ROM
          ; $7F8-$7F9 Timer Interrupt Vector
          ; $7FA-$7FB External Interrupt Vector
          ; $7FC-$7FD SWI Vector
          ; $7FE-$7FF Reset Vector

          *ZERO-PAGE USER ROM
          ORG $80

00000080: a6 ff     lda   #$FF          ;
00000082: b7 04     sta   $04           ;set PORTA output
00000084: a6 80     lda   #$80          ;
00000086: b7 00     sta   $00           ;set PA7 (fm_off) high
00000088: b7 40     sta   $40           ;
0000008a: a6 0f     lda   #$0F          ;
0000008c: b7 05     sta   $05           ;set PB0:PB3 output
0000008e: a6 05     lda   #$05          ;
00000090: b7 01     sta   $01           ;set PB0 and PB2 `fm_en` and `S (L)` high
00000092: a6 00     lda   #$00
00000094: b7 06     sta   $06           ;set PORTC input

                                        ; Check test mode `TP26` is low
00000096: 05 02 03  brclr 2, $02, $09C  ;if PC2 `TP26` is low branch and check which mode to run
00000099: cc 03 c0  jmp   $03C0         ;else jump to the main program

0000009c: 0a 01 03  brset 5, $01, $0A2  ;if PB5 `TEST MODE FIXED LOOP` is low
0000009f: cc 05 b3  jmp   $05B3         ;jump to $5B3 [Test Mode Fixed Loop]

000000a2: 0c 01 03  brset 6, $01, $0A8  ;if PB6 (TEST MODE SIG ANA) is low
000000a5: cc 05 f0  jmp   $05F0         ;jump to $5F0 [Test Mode SIG ANA]

000000a8: 0e 01 f1  brset 7, $01, $09C  ;if PB7 (TEST MODE UNUSED) is low
000000ab: cc 06 64  jmp   $0664         ;jump to $664 [Test Mode UNUSED]
          ; Service manual lists this as unused but it jumps into an alternate point of sig analysis

          *USER ROM
          ORG $3C0                      ; [Main program start]
                                        ;Also, interrupt vectors if they were unmasked
000003c0: ae 41     ldx   #$41          ;start at address $41
000003c2: a6 10     lda   #$10          ;
000003c4: f7        sta   ,x            ;
000003c5: 5c        incx                ;
000003c6: a3 52     cpx   #$52          ;
000003c8: 26 fa     bne   $3C4          ;
                                        ;loop to fill 17 bytes of Buffer $41:$52 with 0x10
                                        ; placing a marker at bit at the end of the high nibble

                                        ; Receive the first byte of serial data (the command)
000003ca: 2f fe     bih   $3CA          ;
000003cc: 2f fc     bih   $3CA          ;wait until the clock pin is low, twice for debounce
000003ce: 02 02 00  brset 1, $02, $3D1  ;test the Serial Data Input pin and store result in carry
000003d1: 39 41     rol   $41           ;rotate left through carry $41
                                        ;   This is really elegant!
000003d3: 24 f5     bcc   $3CA          ; Check if entire command is received
                                        ;
000003d5: 07 41 11  brclr 3, $41, $3E9  ;jump to the command parser unless TX command is received
                                        ;otherwise received the next 16 words

                                        ; Receive the next 16 bytes of data
000003d8: ae 42     ldx   #$42          ;index register to $42 - start of data words
000003da: 2f fe     bih   $3DA          ;
000003dc: 2f fc     bih   $3DA          ;wait until the clock pin is low, wice for debounce
000003de: 02 02 00  brset 1, $02, $3E1  ;test the Serial Data Input pin and store result in carry
000003e1: 79        rol   ,x            ;rotate X left thru carry
000003e2: 24 f6     bcc   $3DA          ;check if the whole word is received
000003e4: 5c        incx                ;increment to the next word
000003e5: a3 52     cpx   #$52          ;check if all 16 words are received
000003e7: 26 f1     bne   $3DA          ; loop for all 17 bytes

                                        ; [Command Parser]
                                        ;Determine which command was received and run it
000003e9: b6 41     lda   $41           ;load $41 into A
000003eb: a1 00     cmpa  #$00          ;compare A with 00
000003ed: 27 22     beq   $411          ;jump to $411 if equal
000003ef: a1 01     cmpa  #$01          ;compare A with 01
000003f1: 27 29     beq   $41C          ;jump to $41C if equal
000003f3: a1 02     cmpa  #$02          ;compare A with 02
000003f5: 27 3c     beq   $433          ;jump to $433 if equal
000003f7: a1 03     cmpa  #$03          ;compare A with 03
000003f9: 27 3c     beq   $437          ;jump to $437 if equal
000003fb: a1 04     cmpa  #$04          ;compare A with 04
000003fd: 27 3c     beq   $43B          ;jump to $43B if equal
000003ff: a1 05     cmpa  #$05          ;compare A with 05
00000401: 27 49     beq   $44C          ;jump to $44C if equal
00000403: a1 08     cmpa  #$08          ;compare A with 08
00000405: 27 4d     beq   $454          ;jump to $454 if equal
00000407: a1 09     cmpa  #$09          ;compare A with 9
00000409: 27 4d     beq   $458          ;jump to $458 if equal
0000040b: a1 0a     cmpa  #$0A          ;compare A with 0A
0000040d: 27 4d     beq   $45C          ;jump to $45C if equal
0000040f: 20 57     bra   $468          ;jump to $468

                                        ; START OF COMMANDS
                                        ;The service manual does not explain these

                                        ; [Command 00] Unsure when this is called
                                        ;It preserves PORTA and sets `fm_dc_en`
00000411: a6 00     lda   #$00          ;
00000413: ba 40     ora   $40           ;
00000415: b7 52     sta   $52           ;
00000417: cd 05 4f  jsr   $054F         ; Transmit terminate word to N controller [tx_last_frame]
0000041a: 20 4c     bra   $468          ;jump back to program start

                                        ; [Command 01] (Send Status Of OOL)
                                        ;This one is interesting
                                        ;It asserts the OOL input onto the SCL pin
0000041c: b6 02     lda   $02           ;
0000041e: 44        lsra                ;
0000041f: 44        lsra                ;
00000420: a4 02     anda  #$02          ;
00000422: b7 02     sta   $02           ;
00000424: a6 02     lda   #$02          ;
00000426: b7 06     sta   $06           ;Set PC1 as an output (Serial Data Pin)
00000428: ae 0d     ldx   #$0D          ;
0000042a: 5a        decx                ;
0000042b: 26 fd     bne   $42A          ; delay loop (52 cycles about 13 uS)
0000042d: a6 00     lda   #$00          ;
0000042f: b7 06     sta   $06           ;set portC back to all input
00000431: 20 35     bra   $468          ; jump back to program start

                                        ; [Command 02] (FM Disable)
00000433: a6 80     lda   #$80          ;load 0x80 into A
00000435: 20 06     bra   $43D          ;jump to $43D

                                        ; [Command 03] (FM Enable)
                                        ;Loads a 0 into $40 and jumps into command 4
00000437: a6 00     lda   #$00          ;load 0 into A
00000439: 20 02     bra   $43D          ;jump to $43D [Update FM Status]

                                        ; [Command 04] (FM Enable DC Mode)
0000043b: a6 40     lda   #$40          ;load 0x40 into A

0000043d: b7 40     sta   $40           ; [Update FM Status]
0000043f: b7 00     sta   $00           ;Update the status byte
00000441: a6 04     lda   #$04          ;Update the control lines
00000443: 0f 40 02  brclr 7, $40, $448  ;If bit 7 of sStatus is clear then set bit1 on portB

00000446: aa 01     ora   #$01          ; else, set 
00000448: b7 01     sta   $01           ;Set bit 1 on PORTB `fm_enable`
0000044a: 20 1c     bra   $468          ;jump back to program start

                                        ; [Command 05] (FM Calibration)
0000044c: 09 01 19  brclr 4, $01, $468  ;Return to main program if (TEST MODE FM NO CAL) is low
0000044f: cd 05 5e  jsr   $055E         ;do an FM Calibration cycle
00000452: 20 14     bra   $468          ;jump to $468
                                        ;jump back to main program start

                                        ;These last commands send parallel date to the N controller
                                        ;and set the last word based on which command is called
                                        ; I only ever see command 8 on my 8656B
                                        ; [Command 08] (TRANSMIT ALL OVERRIDE LAST WORD AS 0x04)
00000454: a6 04     lda   #$04          ;load 0x04 into A
00000456: 20 08     bra   $460          ;jump to $460

                                        ; [Command 09] (TRANSMIT ALL OVERRIDE LAST WORD AS 0x08)
00000458: a6 08     lda   #$08          ;Load 0x08 into A
0000045a: 20 04     bra   $460          ;jump to $460

                                        ; [Command 0A] (TRANSMIT ALL OVERRIDE LAST WORD AS 0x09)
0000045c: a6 09     lda   #$09          ;load 0x09 into A
0000045e: 20 00     bra   $460          ;jump to $460
                                        ;  END OF COMMANDS

                                        ; [Send Parallel Data]
                                        ;A should contain whatever we want the last word to be
00000460: b7 52     sta   $52           ;store A into memory at $52
00000462: cd 05 a7  jsr   $05A7         ;Initialize the buffer
                                        ; sets bit 6 of each byte in the buffer `fm_dc_en`
00000465: cd 04 6b  jsr   $046B         ;Send the parallel data
00000468: cc 03 c0  jmp   $03C0         ;jump to the start of the program

                                        ; [Send all 16 words and associated control signals]
0000046b: a6 01     lda   #$01          ; load 0x01 into A
0000046d: ba 40     ora   $40           ; or sStatus with A
0000046f: b7 00     sta   $00           ;store A into PortA setting PA0 `D1` and PA6 `fm_dc_en`
00000471: aa 20     ora   #$20          ;or A with 0x20 (0x61)
00000473: b7 00     sta   $00           ;bring PA5 `data_valid` high as well
00000475: a4 cf     anda  #$CF          ;
00000477: b7 00     sta   $00           ;clear PA5 `data_valid`
00000479: ae 06     ldx   #$06          ;
0000047b: 5a        decx                ;
0000047c: 26 fd     bne   $47B          ; delay
0000047e: b6 42     lda   $42           ;Load first byte
00000480: b7 00     sta   $00           ;Write the byte onto PORTA
00000482: aa 10     ora   #$10          ;
00000484: b7 00     sta   $00           ;set bit `data_valid`
00000486: a4 cf     anda  #$CF          ;
00000488: b7 00     sta   $00           ;clear `data_valid` and `clk`
0000048a: b6 43     lda   $43           ;
0000048c: b7 00     sta   $00           ;(next byte) 2
0000048e: aa 10     ora   #$10          ;
00000490: b7 00     sta   $00           ;
00000492: a4 cf     anda  #$CF          ;
00000494: b7 00     sta   $00           ;
00000496: b6 44     lda   $44           ;
00000498: b7 00     sta   $00           ;(next byte) 3
0000049a: aa 10     ora   #$10          ;
0000049c: b7 00     sta   $00           ;
0000049e: a4 cf     anda  #$CF          ;
000004a0: b7 00     sta   $00           ;
000004a2: b6 45     lda   $45           ;
000004a4: b7 00     sta   $00           ;(next byte) 4
000004a6: aa 10     ora   #$10          ;
000004a8: b7 00     sta   $00           ;
000004aa: a4 cf     anda  #$CF          ;
000004ac: b7 00     sta   $00           ;
000004ae: b6 46     lda   $46           ;
000004b0: b7 00     sta   $00           ;(next byte) 5
000004b2: aa 10     ora   #$10          ;
000004b4: b7 00     sta   $00           ;
000004b6: a4 cf     anda  #$CF          ;
000004b8: b7 00     sta   $00           ;
000004ba: b6 47     lda   $47           ;
000004bc: b7 00     sta   $00           ;(next byte) 6
000004be: aa 10     ora   #$10          ;
000004c0: b7 00     sta   $00           ;
000004c2: a4 cf     anda  #$CF          ;
000004c4: b7 00     sta   $00           ;
000004c6: b6 48     lda   $48           ;
000004c8: b7 00     sta   $00           ;(next byte) 7
000004ca: aa 10     ora   #$10          ;
000004cc: b7 00     sta   $00           ;
000004ce: a4 cf     anda  #$CF          ;
000004d0: b7 00     sta   $00           ;
000004d2: b6 49     lda   $49           ;
000004d4: b7 00     sta   $00           ;(next byte) 8
000004d6: aa 10     ora   #$10          ;
000004d8: b7 00     sta   $00           ;
000004da: a4 cf     anda  #$CF          ;
000004dc: b7 00     sta   $00           ;
000004de: b6 4a     lda   $4A           ;
000004e0: b7 00     sta   $00           ;(next byte) 9
000004e2: aa 10     ora   #$10          ;
000004e4: b7 00     sta   $00           ;
000004e6: a4 cf     anda  #$CF          ;
000004e8: b7 00     sta   $00           ;
000004ea: b6 4b     lda   $4B           ;
000004ec: b7 00     sta   $00           ;(next byte) 10
000004ee: aa 10     ora   #$10          ;
000004f0: b7 00     sta   $00           ;
000004f2: a4 cf     anda  #$CF          ;
000004f4: b7 00     sta   $00           ;
000004f6: b6 4c     lda   $4C           ;
000004f8: b7 00     sta   $00           ;(next byte) 11
000004fa: aa 10     ora   #$10          ;
000004fc: b7 00     sta   $00           ;
000004fe: a4 cf     anda  #$CF          ;
00000500: b7 00     sta   $00           ;
00000502: b6 4d     lda   $4D           ;
00000504: b7 00     sta   $00           ;(next byte) 12
00000506: aa 10     ora   #$10          ;
00000508: b7 00     sta   $00           ;
0000050a: a4 cf     anda  #$CF          ;
0000050c: b7 00     sta   $00           ;
0000050e: b6 4e     lda   $4E           ;
00000510: b7 00     sta   $00           ;(next byte) 13
00000512: aa 10     ora   #$10          ;
00000514: b7 00     sta   $00           ;
00000516: a4 cf     anda  #$CF          ;
00000518: b7 00     sta   $00           ;
0000051a: b6 4f     lda   $4F           ;
0000051c: b7 00     sta   $00           ;(next byte) 14
0000051e: aa 10     ora   #$10          ;
00000520: b7 00     sta   $00           ;
00000522: a4 cf     anda  #$CF          ;
00000524: b7 00     sta   $00           ;
00000526: b6 50     lda   $50           ;
00000528: b7 00     sta   $00           ;(next byte)
0000052a: aa 10     ora   #$10          ;
0000052c: b7 00     sta   $00           ;
0000052e: a4 cf     anda  #$CF          ;
00000530: b7 00     sta   $00           ;
00000532: b6 51     lda   $51           ;
00000534: b7 00     sta   $00           ;(next byte)
00000536: aa 10     ora   #$10          ;
00000538: b7 00     sta   $00           ;
0000053a: a4 cf     anda  #$CF          ;
0000053c: b7 00     sta   $00           ;
0000053e: b6 52     lda   $52           ;
00000540: b7 00     sta   $00           ;(next byte)
00000542: aa 20     ora   #$20          ;
00000544: b7 00     sta   $00           ;
00000546: a4 cf     anda  #$CF          ;
00000548: b7 00     sta   $00           ;
0000054a: ae 06     ldx   #$06          ;
0000054c: 5a        decx                ;Delay loop
0000054d: 26 fd     bne   $54C          ;
0000054f: a6 00     lda   #$00          ;Clear PORTA
00000551: ba 40     ora   $40           ;
00000553: b7 00     sta   $00           ;set `fm_dc_enable`
00000555: aa 20     ora   #$20          ;or A with 0x20
00000557: b7 00     sta   $00           ;set `data_valid`
00000559: a4 cf     anda  #$CF          ;
0000055b: b7 00     sta   $00           ;clear `data_valid` `clk`
0000055d: 81        rts                 ;return from subroutine

                                        ; [FM Calibration] called any time VCO frequency changes
0000055e: b6 40     lda   $40           ;
00000560: aa 40     ora   #$40          ;
00000562: b7 00     sta   $00           ;set `fm_dc_en`
00000564: a6 0b     lda   #$0B          ;
00000566: b7 01     sta   $01           ;set `fm_en`, `B+C`, and `fm_add_cyc`
00000568: cd 05 98  jsr   $0598         ;delay
0000056b: 14 01     bset  2, $01        ;set PB2 `S (L)`
0000056d: 17 01     bclr  3, $01        ;clear PB3 `FM Add Cycle`
0000056f: a6 27     lda   #$27          ;
00000571: b7 08     sta   $08           ;
00000573: 3f 09     clr   $09           ;
00000575: 0f 09 fd  brclr 7, $09, $575  ;Calibrated delay
00000578: 13 01     bclr  1, $01        ;clear PB1 `B+C`
0000057a: ae 05     ldx   #$05          ;
0000057c: 5a        decx                ;
0000057d: 26 fd     bne   $57C          ;delay
0000057f: 0e 40 02  brset 7, $40, $584  ;skip if bit 7 of $40 is set
00000582: 11 01     bclr  0, $01        ;clear bit PB0 `FM EN`
00000584: b6 40     lda   $40           ;
00000586: b7 00     sta   $00           ;
00000588: 05 02 01  brclr 2, $02, $58C  ;skip extra delay if `TP26` is low
0000058b: 81        rts                 ;return from subroutine

                                        ;[Delay 256uS] (Plus a few extra)
                                        ; @4MHz / 4 = 1MHz = 1uS per timer tick
0000058c: a6 ff     lda   #$FF          ;Load 0xFF into A
0000058e: b7 08     sta   $08           ;store A into $08 (Timer Data Register to 0xFF)
00000590: 3f 09     clr   $09           ;clear $09 (Timer Control Register)
                                        ;(clear interrupt mask, set fosc / 4, disable timer pin)
00000592: 0f 09 fd  brclr 7, $09, $592  ;jump to $592 if bit 7 of $09 (Timer Control Register) is clear
00000595: cc 05 5e  jmp   $055E         ;jump to $55E

                                        ;[Delay 430uS] (Plus a few extra)
                                        ; Timer counts down one tick per 1uS
00000598: a6 d5     lda   #$D5          ;Load 0xD5 into A
0000059a: b7 08     sta   $08           ;Store D5 into $08 (timer data register)
0000059c: 3f 09     clr   $09           ;Clear $09 (Timer Control Register)
0000059e: 0f 09 fd  brclr 7, $09, $59E  ;if bit 7 of $09 is clear jump to $59E
000005a1: 3f 09     clr   $09           ;Clear $09 (Timer Control Register)
000005a3: 0f 09 fd  brclr 7, $09, $5A3  ;if bit 7 of $09 is clear jump to $5A3
000005a6: 81        rts                 ;return from subroutine

                                        ;[Initialize Buffer]
                                        ; set bit 6 (0x40) in each data word
000005a7: ae 42     ldx   #$42          ;
000005a9: f6        lda   ,x            ;
000005aa: ba 40     ora   $40           ;set bit 6
000005ac: f7        sta   ,x            ;store it
000005ad: 5c        incx                ;
000005ae: a3 53     cpx   #$53          ;loop for 16 data words
000005b0: 26 f7     bne   $5A9          ; 
000005b2: 81        rts                 ;return from subroutine

                                        ;[Test Mode: Fixed Loop]
000005b3: ae 21     ldx   #$21          ;
000005b5: cd 05 98  jsr   $0598         ;
000005b8: 5a        decx                ;delay for a while
000005b9: 26 fa     bne   $5B5          ;
000005bb: 4f        clra                ;clear A
000005bc: b7 51     sta   $51           ;store A into $51
000005be: b7 42     sta   $42           ;store A into $42
000005c0: b7 43     sta   $43           ;store A into $43
000005c2: b7 44     sta   $44           ;store A into $44
000005c4: b7 45     sta   $45           ;store A into $45
000005c6: b7 46     sta   $46           ;store A into $46
000005c8: b7 47     sta   $47           ;store A into $47
000005ca: b7 48     sta   $48           ;store A into $48
000005cc: b7 4a     sta   $4A           ;store A into $4A
000005ce: b7 4b     sta   $4B           ;store A into $4B
000005d0: b7 4c     sta   $4C           ;store A into $4C
000005d2: b7 4d     sta   $4D           ;store A into $4D
000005d4: a6 05     lda   #$05          ;store 0x05 into A
000005d6: b7 49     sta   $49           ;store A into $49
000005d8: a6 04     lda   #$04          ;store 0x04 into A
000005da: b7 4e     sta   $4E           ;store A into $4E
000005dc: a6 01     lda   #$01          ;store 0x01 into A
000005de: b7 4f     sta   $4F           ;store A into $4F
000005e0: a6 03     lda   #$03          ;store 0x03 into A
000005e2: b7 50     sta   $50           ;store A into $50
000005e4: a6 04     lda   #$04          ;store 0x04 into A
000005e6: b7 52     sta   $52           ;store A into $52
                                        ; Manualy fill the buffer:
                                        ;41:00 00 00 00 00 00 00 05 00 00 00 00 04 01 03 00 04:52
000005e8: cd 05 a7  jsr   $05A7         ;initialize the buffer
000005eb: cd 04 6b  jsr   $046B         ;transmit the buffer
000005ee: 20 fe     bra   $5EE          ; halt here

                                        ; [Test: Mode SIG ANA]
                                        ;This mode should only be run when
                                        ;  SCL and SDA are disconnected!
                                        ;   A3TP26 to GND
                                        ;   A3TP17 to GND
                                        ; The alternate signature at pins 14, 20, 27 check the input at pins 2, 8 to 11 and 16 to 19. When the input is low, the signature at the related pin is the alternate signature

                                        ;PB0 TP24 CLK fm_enable
                                        ;PB1 TP25 DSA B+C L

                                        ;PIN            NORMAL      ALTERNATE   Condition
                                        ;1(VSS)         0000        ----        ---
                                        ;2(SCL)         7U39        0000        Pin tied low
                                        ;3(VCC)         7U39        ----        ----
                                        ;6(VPP)         0000        ----        ----
                                        ;7(HIGH)        7U39        ----        ----
                                        ;8(LOW)         0000        ----        ----
                                        ;9(SDA)         0000        7U39        PC1 pulled high
                                        ;10(TP26)       7U39        0000        PC2 tied low
                                        ;11(OOL)        7U39        0000        Out of Lock LED on
                                        ;14(S (L))      0021        0020        INT pin low
                                        ;15(fm_add_cyc  0010        40C5        RAM Error
                                        ;16(S (L))      7U39        0000        PB4 tied low
                                        ;17(fixed_loop) 7U39        0000        PB5 tied low
                                        ;18(sig_ana)    7U39        0000        PB6 tied low
                                        ;19(unused)     7U39        0000        PB7 tied low
                                        ;20(D1)         2050        2052        PC0 low
                                        ;21(D2)         102C        1029        PC1 low
                                        ;22(D4)         0816        0814        PC2 low
                                        ;23(D8)         0408        040A        Out of Lock LED ON
                                        ;24(PCLK)       0201        0205        PB4 low
                                        ;25(data_valid) 0105        0102        PB5 low
                                        ;26(fm_dc_en)   0085        0081        PB6 low
                                        ;27(fm_off)     0044        0040        PB7 low
                                        ;28 RESET       7U39        ----        ----
                                        ;
000005f0: 3f 00     clr   $00           ;clear portA
000005f2: 3f 01     clr   $01           ;clear portB

000005f4: a6 01     lda   #$01          ;load 0x01 into A
000005f6: ae 40     ldx   #$40          ;
000005f8: f7        sta   ,x            ; store A into RAM location
000005f9: f1        cmpa  ,x            ;RAM Test
000005fa: 26 0b     bne   $607          ; branch to 607 if not equal
000005fc: 5c        incx                ;check the next byte
000005fd: a3 80     cpx   #$80          ;Make sure all of the bytes are checked
000005ff: 26 f7     bne   $5F8          ;
00000601: ab 11     adda  #$11          ;otherwise add 0x11 to A
00000603: 24 f1     bcc   $5F6          ; jump to back to the start if carry is clear
00000605: 20 02     bra   $609          ;do NOT set fm_add_cyc bit
00000607: 16 01     bset  3, $01        ;set PB3 `fm_add_cyc`
00000609: 12 01     bset  1, $01        ;set PB1 `b+c H`

0000060b: cd 06 5f  jsr   $065F         ;DSA Clock (pulse `fm_en`)
0000060e: 17 01     bclr  3, $01        ;clear PB3 `fm_add_cyc`

00000610: a6 01     lda   #$01          ;
bit_shift_loop:
00000612: b7 00     sta   $00           ;store A into PortA
00000614: cd 06 5f  jsr   $065F         ;DSA Clock (pulse `fm_en`)
00000617: 48        asla                ;left shift A
00000618: 24 f8     bcc   $612          ; jump back to set PA0 if carry is clear
0000061a: 3f 00     clr   $00           ;clear PortA
0000061c: 14 01     bset  2, $01        ;set PORTB bit 2 `S (L)`
0000061e: cd 06 5f  jsr   $065F         ;DSA Clock (pulse `fm_en`)
00000621: 15 01     bclr  2, $01        ;clear PORTB bit 2 `S (L)`
00000623: 16 01     bset  3, $01        ;set PORTB bit 3 `FM_CAL_ADD_CYC`
00000625: cd 06 5f  jsr   $065F         ;DSA Clock (pulse `fm_en`)
00000628: 17 01     bclr  3, $01        ;clear PB3 `fm_add_cyc`

0000062a: 3f 00     clr   $00           ;clear PortA
0000062c: cd 06 5f  jsr   $065F         ;DSA Clock (pulse `fm_en`)

0000062f: b6 01     lda   $01           ;
00000631: a4 f0     anda  #$F0          ;
00000633: b7 00     sta   $00           ;write A to PORTA (clk,data_valid,fm_dc_en,fm_off)
00000635: cd 06 5f  jsr   $065F         ;DSA Clock (pulse `fm_en`)

00000638: b6 02     lda   $02           ;load portC into A
0000063a: a4 0f     anda  #$0F          ;blank out the top 4 bits of PortC that always read high
0000063c: b7 00     sta   $00           ;Mirror PC0:3's contents to PA0:3

0000063e: cd 06 5f  jsr   $065F         ;DSA Clock (pulse `fm_en`)
00000641: 3f 00     clr   $00           ;clear PortA

                                        ; [Test Mode: UNUSED]
00000643: 2e 04     bil   $649          ;jump to $649 if interrupt line is low (Serial Clock)
00000645: 14 01     bset  2, $01        ;set PB2 `S (L)`
00000647: 20 02     bra   $64B          ;jump to $64B
00000649: 15 01     bclr  2, $01        ;clear PB2 `S (L)`
0000064b: cd 06 5f  jsr   $065F         ;DSA Clock (pulse `fm_en`)
0000064e: 13 01     bclr  1, $01        ;clear PB1 `B+C (H)`
00000650: cd 06 5f  jsr   $065F         ;DSA Clock (pulse `fm_en`)

00000653: a6 28     lda   #$28          ;
00000655: b7 08     sta   $08           ;
00000657: 3f 09     clr   $09           ;
00000659: 0f 09 fd  brclr 7, $09, $659  ;delay
0000065c: cc 05 f0  jmp   $05F0         ;jump to $5F0 (Run signature analys test mode)

                                        ; [dsa_clock]
                                        ;Used in signal analysis and unused test modes
0000065f: 10 01     bset  0, $01        ;set PB0 `fm_en`
00000661: 11 01     bclr  0, $01        ;clear PB0`fm_en`
00000663: 81        rts                 ;return from subroutine

00000664: 20 fe     bra   $664          ;halt

          *SELF-TEST ROM
          *putting 9V on TIMER input shifts vectors up 8 bytes
          *for self-test, loop high bits (7-4) to low bits (3-0) of ports A and B, connect PA7 to \INT
          *results are output on port C - data sheet just says that LEDs should flash, no specific error codes
          *self-test reset jumps here

00000784: 9C                 rsp               ;set stack pointer to $07F; not needed on reset???
00000785: 33 02              com   $02         ;complement port C
00000787: 26 FE              bne   $787        ;stop here if not 0 - port C must read $FF at start
00000789: 10 06              bset  0,$006      ;set DDRC<0>
0000078B: 3F 09              clr   $09         ;clear timer control reg - code jumps back here to loop
0000078D: 83                 swi               ;SWI jumps to $7E7, incs $02 and returns (port C=1)
0000078E: AE 01              ldx   #$01        ;port test
00000790: A6 F0              lda   #$F0
00000792: AD 47              bsr   $7DB        ;store $F0 in (X+4) (DDRs), and store $55 and $AA in (X) (ports) and verify
00000794: A9 BA              adca  #$BA
00000796: AD 43              bsr   $7DB        ;store $0F in (X+4), and store $55 and $AA in (X) and verify
00000798: 5A                 decx              ;x=0
00000799: 27 F5              beq   $790
0000079B: 4F                 clra
0000079C: 83                 swi               ;SWI jumps to $7E7, incs $02 and returns (port C=2)
0000079D: AE 40              ldx   #$40        ;test RAM from $040-$07F (C is set on entry)
0000079F: F7                 sta   (x)
000007A0: 46                 rora
000007A1: 5C                 incx
000007A2: 2A FB              bpl   $79F
000007A4: 49                 rola
000007A5: AE 40              ldx   #$40
000007A7: F8                 eora  (x)
000007A8: 26 FE              bne   $7A8        ;hang if comparison fails
000007AA: F6                 lda   (x)
000007AB: 46                 rora
000007AC: 5C                 incx
000007AD: 2A F8              bpl   $7A7
000007AF: 24 EC              bcc   $79D
000007B1: 83                 swi               ;SWI jumps to $7E7, incs $02 and returns (port C=3)
000007B2: AE C8              ldx   #$C8        ;self-modifying code - EOR $0080-$07FF
000007B4: BF 40              stx   $40         ;C8=EOR extended
000007B6: 39 43              rol   $43         ;makes $43=#$81=RTS
000007B8: BD 40              jsr   $40
000007BA: 3C 42              inc   $42
000007BC: 22 FA              bhi   $7B8
000007BE: 3C 41              inc   $41
000007C0: 07 41 F5           brclr 3,$41,$7B8
000007C3: 40                 nega
000007C4: A2 00              sbca  #$00
000007C6: 26 FE              bne   $7C6        ;hang if checksum doesn't match
000007C8: 83                 swi               ;SWI jumps to $7E7, incs $02 and returns (port C=4)
000007C9: 9A                 cli
000007CA: 9B                 sei
000007CB: 2C FE              bmc   $7CB        ;hang if interrupt mask clear
000007CD: B0 7C              suba  $7C
000007CF: 26 FE              bne   $7CF        ;hang if not zero
000007D1: B3 7D              cpx   $7D
000007D3: 26 FE              bne   $7D3        ;hang if different
000007D5: 0B 4B FD           brclr 5,$4B,$7D5  ;hang if $4B<5>=0 - changed in timer and ext interrupts
000007D8: DC 06 C3           jmp   (x+$06C3)   ;x=0xc8 here so this jumps to $78B to restart

000007DB: E7 04              sta   (x+$04)
000007DD: A6 55              lda   #$55
000007DF: F7                 sta   (x)
000007E0: F1                 cmpa  (x)
000007E1: 26 FE              bne   $7E1        ;hang if comparison fails
000007E3: 48                 asla              ;now try $AA
000007E4: 2B F9              bmi   $7DF
000007E6: 81                 rts

000007E7: 3C 02              inc   $02         ;self-test SWI vector
000007E9: 80                 rti

000007EA: 1F 09              bclr  7,$009      ;self-test timer int vector
000007EC: 37 4B              asr   $4B         ;self-test ext int vector
000007EE: 80                 rti

000007EF: B3                 FCB $B3           ;this must be the ROM checksum

000007F0: 07 EA              FCB $07,$EA       ;self-test timer int vector
000007F2: 07 EC              FCB $07,$EC       ;self-test ext int vector
000007F4: 07 E7              FCB $07,$E7       ;self-test SWI vector
000007F6: 07 84              FCB $07,$84       ;self-test reset vector

000007F8: 03 C0              FCB $03,$C0       ;timer int vector
000007FA: 03 C0              FCB $03,$C0       ;ext int vector
000007FC: 03 C0              FCB $03,$C0       ;SWI vector
000007FE: 03 C0              FCB $03,$C0       ;reset vector
