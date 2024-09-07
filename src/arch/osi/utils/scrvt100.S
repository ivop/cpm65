; -------------------------------------------------------------------------
;
; VT100 Serial Screen Driver for Ohio Scientific serial systems
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

ptr:    .fill 2

drv_zp_end:

; -------------------------------------------------------------------------

zproc main
    jmp init
zendproc

; -------------------------------------------------------------------------

defdriver SCREEN, DRVID_SCREEN, drv_screen_strat, 0

zproc drv_screen_strat
    jmpdispatch drv_screen_jump_lo, drv_screen_jump_hi

drv_screen_jump_lo:
    jmptablo screen_version
    jmptablo screen_getsize
    jmptablo screen_clear
    jmptablo screen_setcursor
    jmptablo screen_getcursor
    jmptablo screen_putchar
    jmptablo screen_putstring
    jmptablo screen_getchar
    jmptablo screen_showcursor
    jmptablo screen_scrollup
    jmptablo screen_scrolldown
    jmptablo screen_cleartoeol
    jmptablo screen_setstyle
 
drv_screen_jump_hi:
    jmptabhi screen_version
    jmptabhi screen_getsize
    jmptabhi screen_clear
    jmptabhi screen_setcursor
    jmptabhi screen_getcursor
    jmptabhi screen_putchar
    jmptabhi screen_putstring
    jmptabhi screen_getchar
    jmptabhi screen_showcursor
    jmptabhi screen_scrollup
    jmptabhi screen_scrolldown
    jmptabhi screen_cleartoeol
    jmptabhi screen_setstyle

zendproc

; -------------------------------------------------------------------------

zproc init
    ldy #BDOS_GET_BIOS
    jsr BDOS
    sta BIOS+1
    stx BIOS+2

; register new driver

    lda #<drv_SCREEN
    ldx #>drv_SCREEN
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

    lda #<banner
    ldx #>banner
    ldy #BDOS_WRITE_STRING
    jsr BDOS

    rts
zendproc

; -------------------------------------------------------------------------

zproc screen_version
    lda #0
    rts
zendproc

zproc screen_getsize
    lda #80-1
    ldx #24-1
    rts
zendproc

.macro PUT char tail:vararg
    lda #\char
    jsr screen_putchar
    .ifnb \tail
        PUT \tail
    .endif
.endm

zproc screen_clear
    PUT 27 '[' '2' 'J' 27 '[' 'H'
    rts
zendproc

zproc screen_cleartoeol
    PUT 27 '[' 'K'
    rts
zendproc

; A = xpos [0-width), X = ypos [0-height)
zproc screen_setcursor
    rts
zendproc

; exit: A = xpos [0-width), X = ypos [0-height]
zproc screen_getcursor
    rts
zendproc

zproc screen_setstyle
    pha
    PUT 27 '['
    pla
    cmp #STYLE_REVERSE
    zif_eq
        PUT '7' 'm'
    zelse
        PUT 'm'
    zendif
    rts
zendproc

zproc screen_putchar
    ldy #BIOS_CONOUT
    jmp BIOS
zendproc

zproc screen_putstring
    sta 1f+1
    stx 1f+2

    ldx #0
    zloop
    1:
        lda $1234,x
        zbreakif_eq

        jsr screen_putchar
        inx
    zendloop

    rts
zendproc

zproc screen_getchar
    ldy #BIOS_CONIN
    jmp BIOS
zendproc

zproc screen_scrollup
    PUT 27 '[' '2' '4' ';' '1' 'f' 27 'D'
    rts
zendproc

zproc screen_scrolldown
    PUT 27 '[' '1' ';' '1' 'f' 27 'M'
    rts
zendproc

zproc screen_showcursor
    cmp #0
    zif_eq
        PUT 27 '[' '?' '2' '5' 'l'      ; le hidden (it's french)
    zelse
        PUT 27 '[' '?' '2' '5' 'h'      ; honestlyvisible
    zendif
    rts
zendproc

; -------------------------------------------------------------------------

; Trampoline

zproc BIOS
    jmp $1234
zendproc

; -------------------------------------------------------------------------

; MISCELLANEOUS DATA

    .data

banner:
    .ascii "vt100 screen driver loaded."
    .byte 13, 10, 0

; -------------------------------------------------------------------------

; UNINITIALIZED

    .bss

reserve_tpa_end:

; -------------------------------------------------------------------------
