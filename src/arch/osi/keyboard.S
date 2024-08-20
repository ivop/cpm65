; Ohio Scientific Instruments floppy routines.
; Copyright © 2024 by Ivo van Poorten
; This file is licensed under the terms of the 2-clause BSD license. Please
; see the COPYING file in the root project directory for the full text.

ZEROPAGE

cur_char:   .fill 1
wait_cntr:  .fill 1
last_char:  .fill 1
modifiers:  .fill 1
tmpval:     .fill 1

KEYBD = $df00

#ifdef OSI500
    .macro STA_KEYBD
        sta KEYBD
    .endm
    .macro LDA_KEYBD
        lda KEYBD
    .endm
#endif
#ifdef OSI600
    .macro STA_KEYBD
        eor #$ff
        sta KEYBD
        eor #$ff
    .endm
    .macro LDA_KEYBD
        lda KEYBD
        eor #$ff
    .endm
#endif

; ----------------------------------------------------------------------------

    .section .text, "ax"

scan_keyboard:

scan_again:
    lda #$01                ; Row mask
    ldy #0                  ; Row counter
    sty modifiers
    dey

0:
    STA_KEYBD

    pha
    LDA_KEYBD
    tax                     ; Key pressed in X
    pla

    cpx #0
    bne key_pressed

next:
    iny                     ; Increase row counter
    asl
    bne 0b
    beq no_key_pressed      ; branch always

; ----------------------------------------------------------------------------

key_pressed:
    lsr                     ; check if row 0 ($01)
    bcc normal_key_pressed

    rol                     ; correct back to $01
    stx modifiers           ; save modifiers

    pha
    txa
    and #$20
    tax
    pla
    cpx #$20
    bne next

    lda #$1b                ; ESC
    bne lookup_done

normal_key_pressed:
    lda matrix_index_tab,y
    sta tmpval              ; store "corrected" row*7 

    txa                     ; A=column
    ldy #7                  ; convert to index 0-7
0:
    dey
    asl
    bcc 0b

    bcs lookup_key          ; branch always

; ----------------------------------------------------------------------------

no_key_pressed:
    sta last_char

new_char:
    sta cur_char

    lda #2
    sta wait_cntr
    bne scan_again          ; branch always

; ----------------------------------------------------------------------------

lookup_key:                 ; we _always_ enter lookup_key with C=1 
    tya                     ; A=column
    adc tmpval              ; add saved row*7 + 1 (carry)
    tay

    lda keyboard_matrix-1,y ; retrieve ASCII from table (-1 compensates C)

lookup_done:
    cmp cur_char
    bne new_char

    dec wait_cntr
    beq debounce_done

    ldy #$10

delay_loop:
    ldx #$40
0:
    dex
    bne 0b

    dey
    bne delay_loop

    beq scan_again

debounce_done:
    ldx #$64                ; long delay on first character
    cmp last_char
    bne set_wait_cntr

    ldx #$0f                ; shorter repeat rate

set_wait_cntr:
    stx wait_cntr
    sta last_char
    sta tmpval

; Apply key modifiers --------------------------------------------------------

    lda modifiers
    tay                     ; save modifiers in Y

    and #7
    tax
    beq no_shift_or_caps

    lda tmpval
    cmp #$5f                ; RUB, case modifiers have no effect
    beq getkey_done

    cmp #$61                ; >= 0x61 always toupper() SHIFT+CAPS
    bcc 0f

    eor #$20
    bne case_adjust_done

0:
    cpx #1                  ; just CAPS?
    beq case_adjust_done    ; for < 0x60, CAPS has no effect

    cmp #$30                ; special case, add #$10
    bne 0f

    clc
    adc #$10
    bne case_adjust_done

0:
    cmp #$21                ; don't adjust space (0x20) and below
    bcc case_adjust_done

    eor #$10                ; all other keys with lshift or rshift

case_adjust_done:
    sta tmpval

no_shift_or_caps:
    tya                     ; restore saved modifiers
    and #$40                ; control key?
    beq getkey_done

    lda tmpval
    and #$1f
    rts

getkey_done:
    lda tmpval
    rts

; ----------------------------------------------------------------------------

keyboard_matrix:
    .ascii "p;/ zaq"
    .ascii ",mnbvcx"
    .ascii "kjhgfds"
    .ascii "iuytrew"
    .byte $0d,$0a       ; removed unused columns
    .ascii "ol."
    .byte $5F           ; idem
    .ascii "-:098"
    .ascii "7654321"

matrix_index_tab:
    .byte 0, 7, 14, 21, 26, 32, 39 ; corrected indeces for removed unused keys

; vim: filetype=asm sw=4 ts=4 et
