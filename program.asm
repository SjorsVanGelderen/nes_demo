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

LoadPalette:
    LDA $2002                      ; Read PPU status to reset high/low latch
    LDA #$3F
    STA $2006                      ; Write high byte
    LDA #$00
    STA $2006                      ; Write low byte

    LDX #$00
LoadPaletteLoop:
    LDA Palette,X                   
    STA $2007
    INX
    CPX #$10                       ; Palette for 4 sprites
    BNE LoadPaletteLoop

LoadBackground
    LDA $2002                      ; Read PPU status, reset high/low latch
    LDA #$20
    STA $2006                      ; Write high byte
    LDA #$00
    STA $2006                      ; Write low byte

    LDA #<Nametable0               ; Store offset addresses
    STA $0000
    LDA #>Nametable0
    STA $0001

;    LDA #<Nametable1
;    STA $0002
;    LDA #>Nametable1
;    STA $0003

;    LDA #<Nametable2
;    STA $0004
;    LDA #>Nametable2
;    STA $0005

;    LDA #<Nametable3
;    STA $0006
;    LDA #>Nametable3
;    STA $0007

    LDA #$00                       ; Set tile loop boundary
    STA $0008

    LDX #$00
    LDY #$00
LoadBackgroundLoop
    LDA ($00),Y
    STA $2007
    INY
    CPY $0008
    BNE LoadBackgroundLoop
    ;CPX #$6                         ; Check if this is the last iteration
    CPX #$2
    BEQ LoadBackgroundDone
    INX                             
    INX
    LDA $00,X                       ; Get new offset address
    STA $00                         ; Overwrite address used in loop
    INX
    LDA $00,X
    STA $01
    DEX
    ;CPX #$6                         ; 3 increments of X per loop
    BNE LoadBackgroundLoop
    LDA #$C0
    STA $0008                       ; Set the boundary to 192 tiles more
    JMP LoadBackgroundLoop
LoadBackgroundDone


PPUCleanUp:
    LDA #%10010000                  ; Enable NMI, sprites from PT1
    STA $2000
    LDA #%00011110                  ; Enable sprites, background, disable clipping left
    STA $2001
    LDA #$00
    STA $2005                       ; Disable scrolling
    STA $2005

    RTI

Palette:
    .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
    .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

Nametable0
    .incbin "map.nam"
    ;.db $47,$20,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1
    ;.db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

    ;.db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
    ;.db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

    ;.db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    ;.db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    ;.db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    ;.db $24,$24,$24,$12,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    ;.db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    ;.db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    ;.db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    ;.db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    ;.db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    ;.db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    ;.db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    ;.db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;Nametable1
;    .db $20,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;Nametable2
;    .db $33,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;Nametable3
;    .db $43,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

;    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

;    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
;    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms


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