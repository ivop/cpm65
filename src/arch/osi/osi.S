; CP/M-65 Copyright © 2022 David Given
; This file is licensed under the terms of the 2-clause BSD license. Please
; see the COPYING file in the root project directory for the full text.

; Ohio Scientific Instruments Port, Copyright © 2024 Ivo van Poorten

; - Minimum of 12 kB RAM (ramtop at $2fff)
; - BIOS init loads at $2200. Could be lower, but some older ROMs ignore
;       the address in the boot sector and have jmp $2200 hardcoded.
; - Floppy drive interface at $c000
; - 500 series:
;       + Model 540 video 64x32
;       + Model 542 polled keyboard @ $df00
; - 600 series:
;       + Model 600 polled keyboard @ $df00, and 64x16 video

#include "zif.inc"
#include "cpm65.inc"
#include "driver.inc"
#include "jumptables.inc"

ZEROPAGE

; We have all of page zero, which is a lot compared to several other ports.
; Hence, all variables are here. This results in smaller and faster code, too.
; For example, we can use (dma),y directly instead of first copying it to
; a ptr.

.global ptr, ptr1

ptr:        .fill 2
ptr1:       .fill 2

mem_end:    .fill 1

save_x:     .fill 1
save_y:     .fill 1

curx:       .fill 1
cury:       .fill 1

key_pending:.fill 1

trkbcd:     .fill 1
curtrk:     .fill 1
reqtrk:     .fill 1
reqsec:     .fill 1
retry:      .fill 1

drive_number:   .fill 1
sector_num:     .fill 3
dma:            .fill 2

#if OSI400
    SCREEN_WIDTH  = 32
    SCREEN_HEIGHT = 32
    SCREEN_PAGES  = 4
#elif OSI500
    SCREEN_WIDTH  = 64
    SCREEN_HEIGHT = 32
    SCREEN_PAGES  = 8
    CONTROL = $de00
#elif OSI600
    SCREEN_WIDTH  = 64
    SCREEN_HEIGHT = 16
    SCREEN_PAGES  = 4
    CONTROL = $d800
#endif

SCREENMEM = $d000

BDOS = __USERTPA_START__ + COMHDR_ENTRY

    .text

.global _start

.section loader, "ax"

_start:

init:
    ldx #$ff
    txs

    ldy #0
    sty ptr
    sty curx
    sty cury

    lda #>SCREENMEM
    sta ptr+1
    ldx #SCREEN_PAGES
    lda #' '

    zloop                   ; clear screen
        zloop
            sta (ptr),y
            dey
        zuntil_eq
        inc ptr+1
        dex
    zuntil_eq

#if OSI500 | OSI600
    iny             ; Y=1
    sty CONTROL     ; switch to 64x32 (500 series) or 64x16 (600 series)
#endif

    ; Copy BIOS to lower RAM

    zrepeat
        memload = .+1
        lda bios_load_addr
        memstore = .+1
        sta bios_exec_addr

        inc memload
        zif_eq
            inc memload+1
        zendif

        inc memstore
        zif_eq
            inc memstore+1
        zendif

        lda memstore
        cmp #<bios_end_addr
        zcontinueif_ne
        lda memstore+1
        memcmpmsb = .+1
        cmp #>bios_end_addr
    zuntil_eq

    ; Determine memory size. $0000-$2fff is assumed RAM (the 12kB minimum).
    ; Systems without BASIC can have RAM at $a000-$bfff. Floppy controller
    ; starts at $c000

    ; ptr is still zero

    lda #$2f
    sta ptr+1

    zloop
        inc ptr+1
        lda ptr+1
        cmp #$c0
        zbreakif_eq
        sta (ptr),y
        cmp (ptr),y
    zuntil_ne

    sta mem_end

    jsr init_pia
    jsr init_acia
    jsr initdrivers                 ; BIOS initialisation

    ldy #banner_end - banner
    zrepeat                         ; Print banner
        lda banner-1,y
        sty save_y
        jsr tty_conout
        ldy save_y
        dey
    zuntil_eq

    lda #$ff
    sta curtrk

    lda #<bdos_filename
    ldx #>bdos_filename
    ldy #>__USERTPA_START__
    jsr loadfile                    ; Load the BDOS image

    lda #>__USERTPA_START__
    ldx #__USERZEROPAGE_START__
    jsr bios_RELOCATE

    lda #<biosentry
    ldx #>biosentry
    jmp BDOS                        ; run!

banner:                             ; reversed
    .byte 10,13
    .ascii "cifitneicS oihO eht rof 56-M/PC"
banner_end:

bdos_filename:
    .ascii "BDOS    SYS"

; --- BIOS entrypoints ------------------------------------------------------

.data

.global drvtop
drvtop: .word drv_TTY

defdriver TTY, DRVID_TTY, drvstrat_TTY, 0

; TTY driver strategy routine.
; Y=TTY opcode.
zproc drvstrat_TTY

; If we need more RAM, we can use this smaller dispatcher
;    cpy #0
;    beq tty_const
;    dey
;    beq tty_conin
;    dey
;    beq tty_conout
; For now, we use the "official" method:

    jmpdispatch jmptable_lo, jmptable_hi

jmptable_lo:
    jmptablo tty_const
    jmptablo tty_conin
    jmptablo tty_conout
jmptable_hi:
    jmptabhi tty_const
    jmptabhi tty_conin
    jmptabhi tty_conout
zendproc

; --- TTY DRIVER ------------------------------------------------------------

; Blocks and waits for the next keypress; returns it in A.

zproc tty_conin
    jsr show_cursor

    lda key_pending

    ldx #$80                    ; clear pending key
    stx key_pending

    zloop
        cmp #$80                ; works for both polled and ASCII keyboards
        zbreakif_cc             ; < $80, valid key
        jsr scan_keyboard
    zendloop

    pha
    jsr hide_cursor
    pla
    rts
zendproc

; Return 0 if no key is pending, $ff if there is

zproc tty_const
    jsr scan_keyboard
    sta key_pending
    cmp #$80
    zif_cc
        lda #$ff                ; < $80, valid key
    zelse
        lda #0
    zendif
    rts
zendproc

; cursor char: 0xa1 = white square, 0xbb = checkerboard, 0x80 = underline

zproc show_cursor
    lda #$a1
    pha
    bne do_cursor
zendproc

zproc hide_cursor
    lda #' '
    pha
    ; [[fallthrough]]
zendproc

zproc do_cursor
    jsr calculate_cursor_address
    ldy #0
    pla
    sta (ptr),y
    rts
zendproc

; ----------------------------------------------------------------------------

; Output character in A

zproc tty_conout
    cmp #13
    zif_eq
        lda #0
        sta curx
        rts
    zendif
    cmp #10
    zif_eq
increase_cury:
        inc cury
        lda cury
        cmp #SCREEN_HEIGHT
        zif_eq
            dec cury
            jsr scroll_up
        zendif
        rts
    zendif
    cmp #127
    zif_eq
        dec curx
        zif_mi
            lda #SCREEN_WIDTH-1
            sta curx

            dec cury
            zif_mi
                lda #0
                sta cury
            zendif
        zendif
        jsr calculate_cursor_address
        lda #' '
        sta (ptr),y
        rts
    zendif

    pha
    jsr calculate_cursor_address
    pla

    ldy #0
    sta (ptr),y

    inc curx
    lda curx
    cmp #SCREEN_WIDTH
    zif_eq
        sty curx            ; Y = 0
        beq increase_cury
    zendif

    rts
zendproc

; Set cursor address in ptr

zproc calculate_cursor_address
    ; multiply cury by 64 --> * 256 / 4
    lda #0
    sta ptr
    lda cury
    lsr
    ror ptr
    lsr
    ror ptr
#if OSI400
    lsr                     ; multiply cury by 32 --> * 256 / 8
    ror ptr
#endif
    sta ptr+1

    ; add curx
    lda ptr
;    clc                    ; C = 0 because of ror
    adc curx
    sta ptr
    zif_cs
        inc ptr+1
    zendif

    ; add screen base, only add MSB because SCREENMEM is page aligned
    clc
    lda ptr+1
    adc #>SCREENMEM
    sta ptr+1

    rts
zendproc

zproc scroll_up
    lda #<(SCREENMEM)
    sta ptr
    lda #<(SCREENMEM+SCREEN_WIDTH)
    sta ptr1
    lda #>SCREENMEM
    sta ptr+1
    sta ptr1+1

    ldy #0
    zloop                       ; Copy all lines one up
        lda (ptr1),y
        sta (ptr),y
        inc ptr
        zif_eq
            inc ptr+1
        zendif
        inc ptr1
        zif_eq
            inc ptr1+1
        zendif
        lda ptr1+1
        cmp #>(SCREENMEM+SCREEN_PAGES*256)
    zuntil_eq

    lda #' '
    zloop                       ; Clear last line
        sta (ptr),y
        iny
        cpy #SCREEN_WIDTH
    zuntil_eq

    rts
zendproc

; ---------------------------------------------------------------------------

; Sets the current DMA address.

zproc bios_SETDMA
    sta dma+0
    stx dma+1
    rts
zendproc

; Select a disk.
; A is the disk number.
; Returns the DPH in XA.
; Sets carry on error.

zproc bios_SELDSK
    cmp #0
    zif_ne
        sec                 ; invalid drive
        rts
    zendif

    sta drive_number

    lda #<dph
    ldx #>dph
    clc
    rts
zendproc

; Set the current absolute sector number.
; XA is a pointer to a three-byte number.
; BDOS looks at DPH to see how many sectors to skip.

zproc bios_SETSEC
    sta ptr+0
    stx ptr+1
    ldy #2
    zrepeat
        lda (ptr), y
        sta sector_num, y
        dey
    zuntil_mi
    rts
zendproc

; ---------------------------------------------------------------------------

; Decided against a custom 128-byte per sector format, because it's a pain to
; maintain, it's difficult to support different CPU speeds at the same time,
; and writing several sectors during one rotation is nigh impossible if you
; do not want to accidentally overwrite part of the previous or next sector.
; You also need sector skew, and it would be a lot of code which won't fit in
; the boot sector.
;
; Hence the format is as follows:
;
; track 0       Boot ROM boot sector, 2048 bytes
; track 1-39    OS65D compatible track marker and 1 sector of 8 pages (2048B)
;
; Tracks are always read or written to/from trkbuf in one go.
; This means that:
;       a) Reading is very fast because full tracks are buffered. Multiple
;          sectors from the same track will just be memcopies.
;       b) Writing a sector to the current track takes one rotation.
;       c) Writing a sector to a different track takes two rotations
;          (one for reading the track, one for writing the modified track).
;       d) Disks can be copied with standard OS65D disk copier, even though
;          there is no OS65D directory.
;       e) Works out-of-the-box for every CPU speed (0.98Mhz-2MHz)
;       f) Code is small and easy to understand (BIOS+init needs to be <=2kB)

zproc calculate_reqtrk_and_reqsec
    lda sector_num
    sta reqtrk
    and #$0f
    sta reqsec

    lda sector_num+1

    ldx #3
    zloop                   ; loop is smaller than unrolled
        lsr
        ror reqtrk
        dex
    zuntil_mi

    rts
zendproc

zproc calculate_trkbuf_sector_location
    lda reqsec
    lsr
    sta ptr+1
    lda #0
    tay
    ror
    clc
    adc #<trkbuf
    sta ptr
    lda ptr+1
    adc #>trkbuf
    sta ptr+1

    rts
zendproc

zproc fill_trkbuf
    jsr calculate_reqtrk_and_reqsec

    ; check at which track we are

    lda #3
    sta retry

do_retry:
    lda curtrk
    cmp reqtrk
    zif_ne
        cmp #$ff
        zif_eq
            jsr seek_to_track0
        zendif
        ; seek track, step in/out
        lda curtrk
        cmp reqtrk
        zif_cc          ; we need to step in
            lda reqtrk
            sec
            sbc curtrk
            tay
            zloop
                sty save_y
                jsr step_in
                ldy save_y
                dey
            zuntil_eq
        zelse           ; we need to step out
            lda curtrk
            sec
            sbc reqtrk
            tay
            zloop
                sty save_y
                jsr step_out
                ldy save_y
                dey
            zuntil_eq
        zendif
        lda reqtrk
        sta curtrk

        jsr read_track
        zif_cs
            lda #$ff            ; force resync on retry
            sta curtrk
            dec retry
            bne do_retry
            sec
            rts
        zendif
    zendif
    clc
    rts
zendproc

zproc bios_READ
    jsr fill_trkbuf

    zif_cs
        rts
    zendif

    jsr calculate_trkbuf_sector_location

    zloop                       ; copy sector from trkbuf to (dma)
        lda (ptr),y
        sta (dma),y
        iny
    zuntil_mi

    clc
    rts
zendproc

zproc bios_WRITE
    jsr fill_trkbuf             ; no-op if current track

    zif_cs
        rts
    zendif

    jsr calculate_trkbuf_sector_location

    zloop                       ; copy sector from (dma) to trkbuf
        lda (dma),y
        sta (ptr),y
        iny
    zuntil_mi

    jsr write_track             ; returns status in C

    rts                         ; ...and so do we
zendproc

; ---------------------------------------------------------------------------

zproc bios_GETTPA
    lda mem_base
    ldx mem_end
    rts
zendproc

zproc bios_SETTPA
    sta mem_base
    stx mem_end
    rts
zendproc

zproc bios_GETZP
    lda zp_base
    ldx zp_end
    rts
zendproc

zproc bios_SETZP
    sta zp_base
    stx zp_end
    rts
zendproc

zproc bios_SETBANK
    rts
zendproc

; ---------------------------------------------------------------------------

#if OSI400
#include "ascii.S"
#else
#include "keyboard.S"
#endif

#include "floppy.S"

; ---------------------------------------------------------------------------

    .data

zp_base: .byte __USERZEROPAGE_START__
zp_end:  .byte __USERZEROPAGE_END__

mem_base: .byte __USERTPA_START__@mos16hi
; mem_end moved to page zero

; DPH for drive 0 (our only drive)

; number of sectors, blocksize, direntries, reserved _sectors_

define_drive dph, 640, 1024, 64, 16

    .section .noinit, "ax", @nobits

    .global directory_buffer

directory_buffer:   .fill 128

trkbuf:     .fill 2048

; ---------------------------------------------------------------------------

; vim: filetype=asm sw=4 ts=4 et
