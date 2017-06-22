;===============================
; (C)2017, Sjors van Gelderen
;===============================

;********************************
; Constants
;********************************

PRG_COUNT = 1
CHR_COUNT = 1
MIRRORING = %0001


;********************************
; Variables
;********************************

; None yet


;********************************
; iNES header
;********************************

    .db "NES",$1A		           ; ID of the header
    .db PRG_COUNT		           ; 1 PRG-ROM block
    .db CHR_COUNT		           ; 1 CHR-ROM block
    .db $00|MIRRORING              ; Mapper 0 with mirroring
    .dsb 9,$00                     ; Padding


;********************************
; Setup
;********************************
    .base $10000-(PRG_COUNT*$4000)

Reset
    SEI			                   ; Disable IRQs
    CLD 		                   ; Disable decimal mode
    LDX #$40
    STX $4017		               ; Disable APU frame IRQ
    LDX #$FF
    TXS			                   ; Set up stack
    INX 		                   ; Now X = 0
    STA $2000                      ; Disable NMI
    STX $2001	                   ; Disable rendering
    STX $4010	                   ; Disable DMC IRQs

    JMP AwaitVerticalBlankDone
AwaitVerticalBlank
    BIT $2002
    BPL AwaitVerticalBlank
    RTS
AwaitVerticalBlankDone

    JSR AwaitVerticalBlank         ; First wait

ClearMemory
    LDA #$00
    STA $0000, x
    STA $0100, x
    ;STA $0200, x
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    LDA #$FE
    STA $0200, x
    ;STA $0300, x                  
    INX
    BNE ClearMemory

    JSR AwaitVerticalBlank         ; Second wait

LoadPalettes:
    LDA $2002                      ; Read PPU status to reset high/low latch
    LDA #$3F
    STA $2006                      ; Write high byte
    LDA #$00
    STA $2006                      ; Write low byte

    LDX #$00
LoadPalettesLoop:
    LDA Palettes,X                   
    STA $2007
    INX
    CPX #$10                       ; Palette for 4 sprites
    BNE LoadPalettesLoop

LoadBackground
    LDA $2002                      ; Read PPU status, reset high/low latch
    LDA #$20
    STA $2006                      ; Write high byte
    LDA #$00
    STA $2006                      ; Write low byte

    LDA #<Nametable                ; Store offset address
    STA $0000
    LDA #>Nametable
    STA $0001

    LDX #$00
    LDY #$00
    LDA #$00                       
    STA $0008                      ; Set tile loop boundary
LoadBackgroundLoop
    CPX #$04                       ; Check for last iteration
    BEQ LoadBackgroundDone
    LDA ($00),Y
    STA $2007
    INY
    CPY $0008                      ; Compare to loop boundary
    BNE LoadBackgroundLoop
    INC $01                        ; Set the new offset address
    INX
    CPX #$03
    BNE LoadBackgroundLoop
    LDA #$C0
    STA $0008                      ; Set the boundary to 192 tiles more
    JMP LoadBackgroundLoop
LoadBackgroundDone

LoadAttributes:
    LDA $2002                      ; Read PPU status, reset high/low latch
    LDA #$23
    STA $2006                      ; Write high byte
    LDA #$C0
    STA $2006                      ; Write low byte

    LDX #$00
LoadAttributesLoop:
    LDA Attributes,X               
    STA $2007
    INX
    CPX #$08
    BNE LoadAttributesLoop

PPUCleanUp:
    LDA #%10010000                  ; Enable NMI, sprites from PT1
    STA $2000
    LDA #%00011110                  ; Enable sprites, background, disable clipping left
    STA $2001
    LDA #$00
    STA $2005                       ; Disable scrolling
    STA $2005

    RTI

Palettes:
    .db $00,$30,$06,$17,  $00,$30,$06,$17,  $00,$30,$06,$17,  $00,$30,$06,$17   ;;background palette
    .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

Nametable
    .incbin "map.nam"

Attributes:
    .db %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000

  ;.db $24,$24,$24,$24, $47,$47,$24,$24 ,$47,$47,$47,$47, $47,$47,$24,$24 ,$24,$24,$24,$24 ,$24,$24,$24,$24, $24,$24,$24,$24, $55,$56,$24,$24  ;;brick bottoms

;********************************
; Logic
;********************************

NonMaskableInterrupt
    LDA #$00
    STA $2003       	           ; Set the low byte (00) of the RAM address
    LDA #$02
    STA $4014       	           ; Set the high byte (02) of the RAM address, start the transfer

                                   ; Clean up PPU
    LDA #%10010000                 ; Enable NMI, sprites from PT0, background from PT1
    STA $2000
    LDA #%00011110                 ; Enable sprites, background, no clipping left
    STA $2001
    LDA #$00                       ; No background scrolling
    STA $2005
    STA $2005

;    LDX #$00
;    LDA #$23
;TestLoop
;    STA $2007
;    INX
;    CPX #$00
;    BNE TestLoop

InterruptRequest
    ; Nothing yet


;********************************
; Vectors
;********************************

    .pad $FFFA     		           ; First of the three vectors starts here
    .dw NonMaskableInterrupt       ; When an NMI happens (once per frame if enabled) the 
                                   ; Processor will jump to the label NMI:
    .dw Reset      		           ; When the processor first turns on or is reset, it will jump
                                   ; To the label RESET:
    .dw InterruptRequest           ; Not really used at present

    .incbin "mario.chr"            ; Includes 8KB graphics file