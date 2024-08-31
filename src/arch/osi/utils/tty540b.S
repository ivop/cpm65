; -------------------------------------------------------------------------
;
; TTY and SCREEN driver for the Ohio Scientific Model 540B Grapphics Card
;
; Copyright © 2024 Ivo van Poorten
; This file is licensed under the terms of the 2-clause BSD license. Please
; see the COPYING file in the root project directory for the full text.
;
; -------------------------------------------------------------------------

#include "zif.inc"
#include "cpm65.inc"
#include "driver.inc"
#include "jumptables.inc"

ZEROPAGE

drv_zp_begin:

ptr:            .fill 2
ptr1:           .fill 2

cursorx:        .fill 1
cursory:        .fill 1

drv_zp_end:

SCREEN_WIDTH = 64
SCREEN_HEIGHT = 32

CONTROL = $de00

ENABLE_64X32 = 0x01
ENABLE_COLOR = 0x04

NORMAL  = $0e
INVERSE = $0f

SCREENMEM = $d000
COLORMEM  = $e000

; -------------------------------------------------------------------------

zproc main
    jmp init
zendproc

; -------------------------------------------------------------------------

; SCREEN DESCRIPTION AND DISPATCHER

drv_screen540b:
    .word DRVID_SCREEN
    .word drv_screen540b_strat
    .word 0
    .ascii "SCREEN540B"
    .byte 0

zproc drv_screen540b_strat
    jmpdispatch drv_screen540b_jump_lo, drv_screen540b_jump_hi

drv_screen540b_jump_lo:
    jmptablo screen540b_version
    jmptablo screen540b_getsize
    jmptablo screen540b_clear
    jmptablo screen540b_setcursor
    jmptablo screen540b_getcursor
    jmptablo screen540b_putchar
    jmptablo screen540b_putstring
    jmptablo screen540b_getchar
    jmptablo screen540b_showcursor
    jmptablo screen540b_scrollup
    jmptablo screen540b_scrolldown
    jmptablo screen540b_cleartoeol
    jmptablo screen540b_setstyle

drv_screen540b_jump_hi:
    jmptabhi screen540b_version
    jmptabhi screen540b_getsize
    jmptabhi screen540b_clear
    jmptabhi screen540b_setcursor
    jmptabhi screen540b_getcursor
    jmptabhi screen540b_putchar
    jmptabhi screen540b_putstring
    jmptabhi screen540b_getchar
    jmptabhi screen540b_showcursor
    jmptabhi screen540b_scrollup
    jmptabhi screen540b_scrolldown
    jmptabhi screen540b_cleartoeol
    jmptabhi screen540b_setstyle
zendproc

; -------------------------------------------------------------------------

; TTY80 DESCRIPTION AND DISPATCHER

drv_tty540b:
    .word DRVID_TTY
    .word drv_tty540b_strat
    .word 0
    .ascii "TTY80"
    .byte 0

zproc drv_tty540b_strat
    jmpdispatch drv_tty540b_jump_lo, drv_tty540b_jump_hi

drv_tty540b_jump_lo:
    jmptablo tty540b_const
    jmptablo tty540b_conin
    jmptablo tty540b_conout

drv_tty540b_jump_hi:
    jmptabhi tty540b_const
    jmptabhi tty540b_conin
    jmptabhi tty540b_conout

zendproc

; -------------------------------------------------------------------------

; INITIALIZE DRIVERS

zproc init
    ldy #BDOS_GET_BIOS
    jsr BDOS
    sta BIOS+1
    stx BIOS+2

; find current TTY driver which we reuse for keyboard input

    lda #<DRVID_TTY
    ldx #>DRVID_TTY
    ldy #BIOS_FINDDRV
    jsr BIOS
    sta next_tty+1
    stx next_tty+2

; register new drivers

    lda #<drv_screen540b
    ldx #>drv_screen540b
    ldy #BIOS_ADDDRV
    jsr BIOS

    lda #<drv_tty540b
    ldx #>drv_tty540b
    ldy #BIOS_ADDDRV
    jsr BIOS

; claim memory

    ldy #BIOS_GETTPA
    jsr BIOS
    lda #>(reserve_tpa_end+256)
    ldy #BIOS_SETTPA
    jsr BIOS

    ldy #BIOS_GETZP
    jsr BIOS
    clc
    adc #drv_zp_end-drv_zp_begin
    ldy #BIOS_SETZP
    jsr BIOS

; init display

    lda #(ENABLE_64X32 | ENABLE_COLOR)
    sta CONTROL

    jsr screen540b_clear

    lda #<banner
    ldx #>banner
    ldy #BDOS_WRITE_STRING
    jsr BDOS

    rts
zendproc

; -------------------------------------------------------------------------

; SCREEN IMPLEMENTATION

zproc screen540b_version
    lda #0
    rts
zendproc

zproc screen540b_getsize
    lda #SCREEN_WIDTH-1
    ldx #SCREEN_HEIGHT-1
    rts
zendproc

zproc screen540b_clear
    ldy #0
clearscrn:
    lda #' '
    sta SCREENMEM+0*256,y
    sta SCREENMEM+1*256,y
    sta SCREENMEM+2*256,y
    sta SCREENMEM+3*256,y
    sta SCREENMEM+4*256,y
    sta SCREENMEM+5*256,y
    sta SCREENMEM+6*256,y
    sta SCREENMEM+7*256,y
    lda #NORMAL
    sta COLORMEM+0*256,y
    sta COLORMEM+1*256,y
    sta COLORMEM+2*256,y
    sta COLORMEM+3*256,y
    sta COLORMEM+4*256,y
    sta COLORMEM+5*256,y
    sta COLORMEM+6*256,y
    sta COLORMEM+7*256,y
    dey
    bne clearscrn

    rts
zendproc

zproc screen540b_cleartoeol
    rts
zendproc

; On top of the official specification, we clip (A,X) at the screen edges

zproc screen540b_setcursor
    cmp #SCREEN_WIDTH
    zif_cs
        lda #SCREEN_WIDTH-1
    zendif
    sta cursorx

    txa
    cmp #SCREEN_HEIGHT
    zif_cs
        lda #SCREEN_HEIGHT-1
    zendif
    sta cursory

    rts
zendproc

zproc screen540b_getcursor
    rts
zendproc

zproc screen540b_putchar
    rts
zendproc

zproc screen540b_setstyle
    sta style
    rts
zendproc

zproc screen540b_putstring
    rts
zendproc

zproc screen540b_getchar
    rts
zendproc

zproc screen540b_scrollup
    rts
zendproc

zproc screen540b_scrolldown
    rts
zendproc

zproc screen540b_showcursor
    rts
zendproc

; -------------------------------------------------------------------------

; TTY IMPLEMENTATION

; Call embedded BIOS tty driver for input

zproc tty540b_const
    jmp next_tty
zendproc

; We use CONST first so we can be sure that the old CONIN will return
; a character immediately without drawing and erasing the old cursor(!)

zproc tty540b_conin
    zloop
        ldy #BIOS_CONST
        jsr next_tty
        cmp #$ff
    zuntil_eq

    ldy #BIOS_CONIN
    jmp next_tty
zendproc

zproc tty540b_conout
    jmp next_tty
zendproc

; -------------------------------------------------------------------------

zproc toggle_cursor
    rts
zendproc

; Trampolines

zproc BIOS
    jmp $1234
zendproc

zproc next_tty
    jmp $1234
zendproc

; -------------------------------------------------------------------------

; MISCELLANEOUS DATA

    .data

banner:
    .ascii "tty540b/screen540b driver loaded."
    .byte 13, 10, 0

; -------------------------------------------------------------------------

; UNINITIALIZED

    .bss

style:  .fill 1

; Increase TPA bottom to here

reserve_tpa_end:

; -------------------------------------------------------------------------

