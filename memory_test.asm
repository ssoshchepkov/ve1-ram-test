WriteIndicatorPort      equ 8
ReadIndicatorPort       equ 12
RamStartAddress         equ 3072
RamEndAddress           equ 4096
RamSize                 equ RamEndAddress - RamStartAddress
RomSize                 equ 1024

TestByteValue1          equ 0
TestByteValue2          equ 255
TestByteValue3          equ 10101010b
TestByteValue4          equ 01010101b

CtcChannel0             equ 0
CtcChannel1             equ 1
CtcChannel2             equ 2
CtcChannel3             equ 3

callTest                macro(testByte, testProc)
                        ld a, testByte
                        call testProc
                        jr nz, Exit
                        mend

setIndicators           macro(value)
                        ld a, value
                        out (WriteIndicatorPort), a
                        out (ReadIndicatorPort), a
                        mend

                        org 0
                        jr InitCtc

                        org 16h
                        DEFW CT3_ZERO                   ; interrupt vector

InitCtc:
;init CH 0 and 1
                        ld a, 00000011b                 ; int off, timer on, prescaler=16, don't care ext. TRG edge,
                                                        ; start timer on loading constant, no time constant follows
                                                        ; sw­rst active, this is a ctrl cmd
                        out (CtcChannel0),A             ; CH0 is on hold now
                        out (CtcChannel1),A             ; CH1 is on hold now

;init CH2
;CH2 divides CPU CLK by (256*256) providing a clock signal at TO2. TO2 is connected to TRG3.
                        ld A,00100111b                  ; int off, timer on, prescaler=256, no ext. start,
                                                        ; start upon loading time constant, time constant follows
                                                        ; sw reset, this is a ctrl cmd
                        out (CtcChannel2), A
                        ld A, 0FFh                      ; time constant 255d defined
                        out (CtcChannel2), A            ; and loaded into channel 2
                                                        ; T02 outputs f= CPU_CLK/(256*256)
;init CH3
;input TRG of CH3 is supplied by clock signal from TO2
;CH3 divides TO2 clock by AFh
;CH3 interupts CPU appr. every 2 (5?) sec to service int routine CT3_ZERO
                        ld A, 11000111b                 ; int on, counter on, prescaler don't care, edge don't care,
                                                        ; time trigger don't care, time constant follows
                                                        ; sw reset, this is a ctrl cmd
                        out (CtcChannel3), A
                        ld A, 0AFh                      ; time constant AFh defined
                        out (CtcChannel3), A            ; and loaded into channel 3
                        ld A, 10h                       ; it vector defined in bit 7­3,bit 2­1 don't care, bit 0 = 0
                        out (CtcChannel0), A            ; and loaded into channel 0

INT_INI:
                        ld A, 0
                        ld I, A                         ;load I reg with zero
                        im 2                            ;set int mode 2
                        ei                              ;enable interupt

                        setIndicators(255)

                        halt                            ; waiting for timer interrupt

                        callTest(TestByteValue1, ByteCheck)
                        callTest(TestByteValue2, ByteCheck)
                        callTest(TestByteValue3, ByteCheck)
                        callTest(TestByteValue4, ByteCheck)

                        callTest(TestByteValue1, BlockCheck)
                        callTest(TestByteValue2, BlockCheck)
                        callTest(TestByteValue3, BlockCheck)
                        callTest(TestByteValue4, BlockCheck)

                        setIndicators(255)

Exit:
                        halt                            ; end of program


ByteCheck:
                        ld hl, RamStartAddress
                        ld bc, RamSize
ByteCompare:
                        ld (hl), a
                        cpi                             ; hl+=1, bc-=1, compare (hl) to a
                                                        ; set z flag to (hl) == a; set c/v flag to bc != 0
                        jr nz, Error                    ; if z flag is 0, then we got an error
                        jp pe, ByteCompare              ; if c/v flag is not 0 then go check next memory cell

                        ret

BlockCheck:
                        ld hl, RamStartAddress
                        ld bc, RamSize
                        ld (hl), a
                        dec bc
                        ld d, h
                        ld e, l
                        inc de
                        ldir

                        ld hl, RamStartAddress
                        ld bc, RamSize
BlockCompare:
                        cpi
                        jr nz, Error                ; if z flag is 0, then we got an error
                        jp pe, BlockCompare         ; if c/v flag is not 0 then go check next memory cell

                        ret

; error handler
Error:
                        out (WriteIndicatorPort), a
                        dec hl                      ; hl was incremented after comparsion by cpi command
                        ld a, (hl)
                        out (ReadIndicatorPort), a

                        ret

; timer interrupt handler
CT3_ZERO:
                        setIndicators(0)        ; turn indicators off
                        reti                    ; return without re-enabling interrupts

output_bin      "memory_test.bin", 0, RomSize
