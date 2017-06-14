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

    JMP AwaitVerticalBlankDone
AwaitVerticalBlank:
    BIT $2002
    BPL AwaitVerticalBlank
    RTS
AwaitVerticalBlankDone:

    JSR AwaitVerticalBlank         ; First wait

ClearMemory:
    LDA #$00
    STA $0000, x
    STA $0100, x
    STA $0200, x
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    LDA #$FE
    STA $0200, x
    ;STA $0300, x                  ; Not sure how this works yet
    INX
    BNE ClearMemory

    JSR AwaitVerticalBlank         ; Second wait


;********************************
; Graphics
;********************************

LoadPalettes:
    LDA $2002		               ; Read PPU status to reset the high/low latch
    LDA #$3F
    STA $2006             	       ; Write the high byte of $3F00 address
    LDA #$00
    STA $2006 	                   ; Write the low byte of $3F00 address
    LDX #$00              	       ; Start out at 0
LoadPalettesLoop:
    LDA Palette, x         	       ; Load data from address (palette + the value in x)
    STA $2007             	       ; Write to PPU
    INX                   	       ; X = X + 1
    CPX #$20              	       ; Compare X to hex $20, decimal 32 - copying 32 bytes = 4 sprites
    BNE LoadPalettesLoop 	       ; Branch to LOAD_PALETTES_LOOP if compare was Not Equal to zero
                               
LoadSprites:
    LDX #$00
LoadSpritesLoop:
    LDA Sprites, x        	       ; Load data from address (sprites +  x)
    STA $0200, x          	       ; Store into RAM address ($0200 + x)
    INX                   	       
    CPX #$20              	       ; Load 2 sprites
    BNE LoadSpritesLoop  	       

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
;    LDA $2002                     ; read PPU status to reset the high/low latch
;    LDA #$23
;    STA $2006                     ; write the high byte of $23C0 address
;    LDA #$C0
;    STA $2006                     ; write the low byte of $23C0 address
;    LDX #$00                      ; start out at 0
;LoadAttributesLoop:
;    LDA Attributes, x             ; load data from address (attribute + the value in x)
;    STA $2007                     ; write to PPU
;    INX                           ; X = X + 1
;    CPX #$03                      ; Compare X to hex $08, decimal 8 - copying 8 bytes
;    BNE LoadAttributesLoop

    LDA #%10010000                 ; Enable NMI, sprites from PT1
    STA $2000
    LDA #%00011110                 ; Enable sprites, background, disable clipping left
    STA $2001


;********************************
; Logic
;********************************

NonMaskableInterrupt:
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

; Should be possible to reduce duplication here
    JMP MovePlayerUpDone           ; Skip this behavior
MovePlayerUp:
    LDX #$00                       ; Clear X register

MovePlayerUpLoop:
    LDA $0200, x         	       ; For each segment, move up
    SBC #$01
    CLC
    STA $0200, x

    TXA                            ; Increment the counter
    ADC #$04
    CLC
    TAX
    CPX #$10
    BNE MovePlayerUpLoop

    RTS
MovePlayerUpDone:

    JMP MovePlayerDownDone         ; Skip this behavior
MovePlayerDown:
    LDX #$00                       ; Clear X register

MovePlayerDownLoop:
    LDA $0200, x         	       ; For each segment, move up
    ADC #$01
    CLC
    STA $0200, x

    TXA                            ; Increment the counter
    ADC #$04
    CLC
    TAX
    CPX #$10
    BNE MovePlayerDownLoop

    RTS
MovePlayerDownDone:

    JMP MovePlayerLeftDone         ; Skip this behavior
MovePlayerLeft:
    LDX #$00                       ; Clear X register

MovePlayerLeftLoop:
    LDA $0203, x         	       ; For each segment, move up
    SBC #$01
    CLC
    STA $0203, x

    TXA                            ; Increment the counter
    ADC #$04
    CLC
    TAX
    CPX #$10
    BNE MovePlayerLeftLoop

    RTS
MovePlayerLeftDone:

    JMP MovePlayerRightDone        ; Skip this behavior
MovePlayerRight:
    LDX #$00                       ; Clear X register

MovePlayerRightLoop:
    LDA $0203, x         	       ; For each segment, move up
    ADC #$01
    CLC
    STA $0203, x

    TXA                            ; Increment the counter
    ADC #$04
    CLC
    TAX
    CPX #$10
    BNE MovePlayerRightLoop

    RTS
MovePlayerRightDone:


;********************************
; Input
;********************************

LatchController:                  ; Tell both the controllers to latch buttons
    LDA #$01
    STA $4016
    LDA #$00
    STA $4016       	       

Player1ReadA: 
    LDA $4016		
    AND #%00000001  	
    BEQ Player1ReadADone
Player1ReadADone:

Player1ReadB: 
    LDA $4016       	
    AND #%00000001  	
    BEQ Player1ReadBDone	
Player1ReadBDone:        		

Player1ReadSelect: 
    LDA $4016       	
    AND #%00000001  	
    BEQ Player1ReadSelectDone
Player1ReadSelectDone:   		

Player1ReadStart: 
    LDA $4016       	
    AND #%00000001  	
    BEQ Player1ReadStartDone
Player1ReadStartDone:   	

Player1ReadUp:
    LDA $4016       	
    AND #%00000001
    BEQ Player1ReadUpDone
    JSR MovePlayerUp
    LDA $4016                      ; Query the next button and ignore it
    JMP Player1ReadUpDownDone
Player1ReadUpDone

Player1ReadDown: 
    LDA $4016       	
    AND #%00000001  	
    BEQ Player1ReadUpDownDone
    JSR MovePlayerDown
Player1ReadUpDownDone:
	
Player1ReadLeft:
    LDA $4016
    AND #%00000001
    BEQ Player1ReadLeftDone
    JSR MovePlayerLeft
    LDA $4016                      ; Query the next button and ignore it
    JMP Player1ReadLeftRightDone
Player1ReadLeftDone

Player1ReadRight: 
    LDA $4016       	
    AND #%00000001  	
    BEQ Player1ReadLeftRightDone
    JSR MovePlayerRight
Player1ReadLeftRightDone:

;********************************
; Drawing
;********************************

    RTI
  
    .bank 1
    .org $E000

Palette:
    .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ; Background
    .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ; Sprites

Sprites:
                                   ; Vert tile attr horiz
    .db $00, $02, $00, $80         ; Sprite 0
    .db $00, $03, $00, $88         ; Sprite 1
    .db $08, $12, $08, $80         ; Sprite 2
    .db $08, $13, $08, $88         ; Sprite 3

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
    .dw NonMaskableInterrupt       ; When an NMI happens (once per frame if enabled) the 
                                   ; Processor will jump to the label NMI:
    .dw Reset      		           ; When the processor first turns on or is reset, it will jump
                                   ; To the label RESET:
    .dw 0          		           ; External interrupt IRQ is not used
                
    .bank 2
    .org $0000
    .incbin "mario.chr"            ; Includes 8KB graphics file
;.incbin "map.nam"                 ; Includes nametable
