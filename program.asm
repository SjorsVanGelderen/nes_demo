;===============================
; (C)2017, Sjors van Gelderen
;===============================

;********************************
; Setup
;********************************

    .inesprg 1		               ; 16KB PRG code
    .ineschr 1		               ; 8KB CHR data
    .inesmap 0		               ; Mapper 0 = NROM, no bank swapping
    .inesmir 1 		               ; Background mirroring
    .bank 0                        ; Select an 8KB ROM bank
    .org $C000                     ; Set the location of the program counter

Reset:
    SEI			                   ; Disable IRQs
    CLD 		                   ; Disable decimal mode
    LDX #$40
    STX $4017		               ; Disable APU frame IRQ
    LDX #$FF
    TXS			                   ; Set up stack
    INX 		                   ; Now X = 0
    STA $2000                      ; Set PPU flags with contents of A
    STX $2001	                   ; Disable rendering
    STX $4010	                   ; Disable DMC IRQs

VerticalBlank_1:
    BIT $2002
    BPL VerticalBlank_1

ClearMemory:
    LDA #$00
    STA $0000, x
    STA $0100, x
    ;STA $0200, x ; Possibly should be ommitted?
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    LDA #$FE
    STA $0200, x
    INX
    BNE ClearMemory

VerticalBlank_2:			
    BIT $2002
    BPL VerticalBlank_2


;********************************
; Graphics
;********************************

LoadPalettes:
    LDA $2002		           ; Read PPU status to reset the high/low latch
    LDA #$3F
    STA $2006             	   ; Write the high byte of $3F00 address
    LDA #$00
    STA $2006 	               ; Write the low byte of $3F00 address
    LDX #$00              	   ; Start out at 0
LoadPalettesLoop:
    LDA Palette, x         	   ; Load data from address (palette + the value in x)
    STA $2007             	   ; Write to PPU
    INX                   	   ; X = X + 1
    CPX #$20              	   ; Compare X to hex $20, decimal 32 - copying 32 bytes = 4 sprites
    BNE LoadPalettesLoop 	   ; Branch to LOAD_PALETTES_LOOP if compare was Not Equal to zero
                               
;LoadSprites:
;    LDX #$00              	   ; Start at 0
;LoadSpritesLoop:
;    LDA Sprites, x        	   ; Load data from address (sprites +  x)
;    STA $0200, x          	   ; Store into RAM address ($0200 + x)
;    INX                   	   ; X = X + 1
;    CPX #$10              	   ; Compare X to hex $10, decimal 16
;    BNE LoadSpritesLoop  	   ; Branch to LOAD_SPRITES_LOOP if compare was Not Equal to zero
                               ; If compare was equal to 16, keep going down

; Improve this please.. it has to be possible
LoadBackground:
    LDA $2002 ; Read PPU status, reset high/low latch
    LDA #$20
    STA $2006 ; Write high byte
    LDA #$00
    STA $2006 ; Write low byte

    LDX #$00 ; Set X for loop
    LDY #$00 ; Set Y for loop
LoadBackgroundLoop0:
    LDA Nametable0, x
    STA $2007
    INX
    CPX #$00 ; 256 tiles
    BNE LoadBackgroundLoop0

    LDX #$00 ; Set X for loop
    LDY #$00 ; Set Y for loop
LoadBackgroundLoop1:
    LDA Nametable1, x
    STA $2007
    INX
    CPX #$00 ; 256 tiles
    BNE LoadBackgroundLoop1

    LDX #$00 ; Set X for loop
    LDY #$00 ; Set Y for loop
LoadBackgroundLoop2:
    LDA Nametable2, x
    STA $2007
    INX
    CPX #$00 ; 256 tiles
    BNE LoadBackgroundLoop2

    LDX #$00 ; Set X for loop
    LDY #$00 ; Set Y for loop
LoadBackgroundLoop3:
    LDA Nametable3, x
    STA $2007
    INX
    CPX #$C0 ; 192 tiles
    BNE LoadBackgroundLoop3

; Something fishy about the attributes, better review
;LoadAttributes:
;    LDA $2002             ; read PPU status to reset the high/low latch
;    LDA #$23
;    STA $2006             ; write the high byte of $23C0 address
;    LDA #$C0
;    STA $2006             ; write the low byte of $23C0 address
;    LDX #$00              ; start out at 0
;LoadAttributesLoop:
;    LDA Attributes, x      ; load data from address (attribute + the value in x)
;    STA $2007             ; write to PPU
;    INX                   ; X = X + 1
;    CPX #$03              ; Compare X to hex $08, decimal 8 - copying 8 bytes
;    BNE LoadAttributesLoop

    LDA #%10010000          ; Enable NMI
    STA $2000
    LDA #%00011110          ; Enable sprites, background, disable clipping left
    STA $2001

Forever:
    JMP Forever

NonMaskableInterrupt:
    LDA #$00
    STA $2003       	       ; Set the low byte (00) of the RAM address
    LDA #$02
    STA $4014       	       ; Set the high byte (02) of the RAM address, start the transfer
	

;********************************
; Drawing
;********************************
    
    ; Clean up PPU
    LDA #%10010000 ; Enable NMI, sprites from PT0, background from PT1
    STA $2000
    LDA #%00011110 ; Enable sprites, background, no clipping left
    STA $2001
    LDA #$00       ; No background scrolling
    STA $2005
    STA $2005

    RTI
  
    .bank 1
    .org $E000

Palette:
    .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ; Background
    .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ; Sprites

;Sprites:
; Vert tile attr horiz
    ;.db $80, $32, $00, $80         ; Sprite 0
    ;.db $80, $33, $00, $88         ; Sprite 1
    ;.db $88, $34, $00, $80         ; Sprite 2
    ;.db $88, $35, $00, $88         ; Sprite 3

; Get these with an inc from YY-chr
Nametable0:
    .db $47,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;all sky

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

Nametable1:
    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

Nametable2:
    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

Nametable3:
    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

    .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24  ;;row 3
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24  ;;some brick tops

    .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24  ;;row 4
    .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24  ;;brick bottoms

Attributes:
    .db %00000000, %00010000, %0010000, %00010000, %00000000, %00000000, %00000000, %00110000
    .db $24,$24,$24,$24, $47,$47,$24,$24 ,$47,$47,$47,$47, $47,$47,$24,$24 ,$24,$24,$24,$24 ,$24,$24,$24,$24, $24,$24,$24,$24, $55,$56,$24,$24

    .org $FFFA     		           ; First of the three vectors starts here
    .dw NonMaskableInterrupt        		           ; When an NMI happens (once per frame if enabled) the 
                               ; Processor will jump to the label NMI:
    .dw Reset      		           ; When the processor first turns on or is reset, it will jump
                               ; To the label RESET:
    .dw 0          		           ; External interrupt IRQ is not used
                
    .bank 2
    .org $0000
    .incbin "mario.chr"         ; Includes 8KB graphics file
;.incbin "map.nam"              ; Includes nametable
