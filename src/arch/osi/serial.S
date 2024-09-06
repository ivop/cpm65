; Ohio Scientific Instruments serial tty routines.
; Copyright © 2024 by Ivo van Poorten
; This file is licensed under the terms of the 2-clause BSD license. Please
; see the COPYING file in the root project directory for the full text.

SERIAL_ACIA_CONTROL = $fc00
SERIAL_ACIA_STATUS  = $fc00
SERIAL_ACIA_RDR     = $fc01
SERIAL_ACIA_TDR     = $fc01

; ----------------------------------------------------------------------------

zproc init_serial
    lda #CONTROL_RESET
    sta SERIAL_ACIA_CONTROL
    lda #(TCB_nRTS_HIGH_IRQ_DIS << TCB_SHIFT) | (WS_8N2 << WS_SHIFT)
    sta SERIAL_ACIA_CONTROL
    rts
zendproc

zproc tty_conin
    zrepeat
        lda SERIAL_ACIA_STATUS       ; wait for bit 0 set, RDR full
        lsr
    zuntil_cs

    lda SERIAL_ACIA_RDR
    and #$7f
    rts
zendproc

zproc tty_const
    lda SERIAL_ACIA_STATUS
    lsr
    zif_cc
        lda #0
    zelse
        lda #$ff
    zendif
    rts
zendproc

zproc tty_conout
    pha
    zrepeat
        lda SERIAL_ACIA_STATUS       ; wait for bit 1 set, TDR empty
        lsr
        lsr
    zuntil_cs
    pla
    sta SERIAL_ACIA_TDR
    rts
zendproc

; ----------------------------------------------------------------------------

; vim: filetype=asm sw=4 ts=4 et
