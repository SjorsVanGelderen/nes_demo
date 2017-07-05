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

	.enum $0000
	bg_offset     .dsb 2
	bg_boundary   .dsb 1

	anim_address  .dsb 2
	anim_length   .dsb 1
	
	sprite_x      .dsb 1
	sprite_y      .dsb 1
	sprite        .dsb 1
	sprite_offset .dsb 2
	
	player_x      .dsb 1
	player_y      .dsb 1
	
	camera_x      .dsb 1
	
	frame         .dsb 1
	count         .dsb 1
	
	direction     .dsb 1
	dirty         .dsb 1
	
	.ende


;********************************
; iNES header
;********************************

	.db "NES",$1A		; ID of the header
	.db PRG_COUNT		; 1 PRG-ROM block
	.db CHR_COUNT		; 1 CHR-ROM block
	.db $00|MIRRORING	; Mapper 0 with vertical mirroring
	.dsb 9,$00		; Padding


;********************************
; PRG bank
;********************************
    
	.base $10000-(PRG_COUNT*$4000)

FlowerAnimation
	.db $08, $0A, $0C, $0A

Reset
	SEI			; Disable IRQs
	CLD			; Disable decimal mode
	LDX #$40
	STX $4017		; Disable APU frame IRQ
	LDX #$FF		
	TXS			; Set up stack
	INX
	STA $2000               ; Disable NMI
	STX $2001		; Disable rendering
	STX $4010		; Disable DMC IRQs


	JMP AwaitVerticalBlankDone
AwaitVerticalBlank
	BIT $2002
	BPL AwaitVerticalBlank
	RTS
AwaitVerticalBlankDone


	JSR AwaitVerticalBlank	; First wait


ClearMemory
	LDA #$00
	STA $0000,X
	STA $0100,X
				;STA $0200,X
	STA $0300,X
	STA $0400,X
	STA $0500,X
	STA $0600,X
	STA $0700,X
	LDA #$FE		; Better check what this value is
	STA $0200,X
				;STA $0300,X                  
	INX
	BNE ClearMemory


	JSR AwaitVerticalBlank	; Second wait


InitVariables
	LDA #$00		; Set initial camera position
	STA camera_x
	
	LDA #$80		; Set initial player position
	STA player_x
	STA player_y
	

LoadPalettes
	LDA $2002	        ; Read PPU status to reset high/low latch
	LDA #$3F
	STA $2006	        ; Write high byte
	LDA #$00
	STA $2006		; Write low byte

	LDA #$3C
	STA $2007
	
	LDX #$01
LoadPalettesLoop
	LDA Palettes,X             
	STA $2007
	INX
	CPX #$1F		
	BNE LoadPalettesLoop


LoadNametables
	LDA #<Nametable_0	; Store nametable address
	STA bg_offset
	LDA #>Nametable_0
	STA bg_offset+1

	LDY #$00
	LDX #$00		
	LDA #$00
	STA bg_boundary		; Set initial tile loading boundary

	LDA $2002	        ; Read PPU status, reset high/low latch
	LDA #$20
	STA $2006		; Write high byte
	LDA #$00
	STA $2006		; Write low byte

LoadNametablesLoop
	LDA (bg_offset),Y	; Push the current tile
	STA $2007

	INY                            
	CPY bg_boundary		; Check if the phase is done
	BNE LoadNametablesLoop

	CPX #$03		; Check if the first nametable is done
	BEQ LoadNextNametable

	CPX #$07		; Check if the second nametable is done
	BEQ LoadNametablesDone
	
	INX			; Increment iteration counter
	INC bg_offset+1         ; Increment high byte of offset

	CPX #$03		; Check if this is the last section
	BEQ LoadShortBoundary

	CPX #$07		; Check if this is the last section
	BEQ LoadShortBoundary
	
	JMP LoadNametablesLoop
	
LoadNextNametable
	LDA #<Nametable_1	; Store address of next nametable
	STA bg_offset
	LDA #>Nametable_1
	STA bg_offset+1

	INX			; Account for missed INX
	
	LDY #$00		; Reset registers and boundary
	LDA #$00
	STA bg_boundary

	LDA $2002	        ; Read PPU status, reset high/low latch
	LDA #$24
	STA $2006		; Write high byte
	LDA #$00
	STA $2006		; Write low byte
	
	JMP LoadNametablesLoop

LoadShortBoundary
	LDA #$C0		; Set the boundary to 192 tiles more
	STA bg_boundary                
	JMP LoadNametablesLoop
	
LoadNametablesDone
    

LoadAttributes
	LDA $2002	        ; Read PPU status, reset high/low latch
	LDA #$23
	STA $2006	        ; Write high byte
	LDA #$C0
	STA $2006		; Write low byte
	
	LDX #$00		
LoadAttributesLoop
	LDA Attributes,X
	STA $2007
	INX
	
	CPX #$40		; Check if end of first table was reached
	BEQ LoadNextAttributes
	CPX #$80		; Check if end of second table was reached
	BEQ LoadAttributesDone

	JMP LoadAttributesLoop

LoadNextAttributes
	LDA $2002		; Reset high/low latch
	LDA #$27		; Set address of second attribute table
	STA $2006
	LDA #$C0
	STA $2006
	
	JMP LoadAttributesLoop

LoadAttributesDone


	JMP LoadSpritesDone
LoadSprites
	LDA #$00
	STA $2003	        ; Set the low byte (00) of the RAM address
	LDA #$02
	STA $4014               ; Set the high byte (02) of the RAM address, start the transfer

	LDA #$00
	STA sprite_offset
	LDA #$02		; Store initial offset
	STA sprite_offset+1
	
	LDA #$00		; Set initial sprite placement offset
	STA sprite_x
	STA sprite_y
	
	LDX #$00
	LDY #$00
	
LoadSpritesLoop
	CPX #$00		; Account for scanline
	LDA player_y
	BNE -
	SBC #$01		; Scanline correction
-
	ADC sprite_y
	STA (sprite_offset),Y	; Set Y

	INY

	LDA sprite
	STA (sprite_offset),Y	; Set tile

	INY

	LDA #%00000000
	STA (sprite_offset),Y	; Color palette 0, no flipping

	INY
	
	LDA player_x
	ADC sprite_x
	STA (sprite_offset),Y	; Set X
	
	INY
	
	INX
	CPX #$04
	BEQ LoadSpritesReturn

	JMP LoadNextSprite

LoadNextSprite
	CPX #$01
	BNE --
-
	INC sprite
	LDA sprite_x
	ADC #$07
	STA sprite_x
	JMP ++
--

	CPX #$02
	BNE +
	LDA sprite
	ADC #$0E
	STA sprite
	
	LDA sprite_x
	SBC #$07
	STA sprite_x
	
	LDA sprite_y
	ADC #$07
	STA sprite_y
	JMP ++
+

	CPX #$03
	BEQ -
	
++
	JMP LoadSpritesLoop

LoadSpritesReturn
	RTS
LoadSpritesDone
	

PPUCleanUp:
	LDA #%10010100	        ; Enable NMI, sprites from pattern table 0
	STA $2000
	LDA #%00011110          ; Enable sprites, background, disable clipping left
	STA $2001
	LDA #$00
	STA $2005		; Reset scrolling
	STA $2005
	

Forever				; Wait until NMI occurs	
	;; LDA dirty
	;; BEQ Forever
	
	;; LDA #$00             ; Clear dirty flag
	;; STA dirty

	;; LDA frame
;; 	CMP #$05
;; 	BNE Forever
;; 	LDA #$00
;; 	STA frame
	
;; 	LDA direction
;; 	BNE left
;; 	INC initialSprite
;; 	INC initialSprite
;; 	LDA initialSprite
;; 	CMP #$0C
;; 	BNE Forever
;; 	INC direction
;; 	JMP Forever
;; left
;; 	DEC initialSprite
;; 	DEC initialSprite
;; 	LDA initialSprite
;; 	CMP #$08
;; 	BNE Forever
;; 	LDA #$00
;; 	STA direction
	JMP Forever


NMI
	LDA #$01
	STA dirty

	INC frame

	JSR LoadSprites
	
	INC camera_x
	
	LDA camera_x
	STA $2005
	LDA #$00
	STA $2005
	
	RTI


IRQ
	RTI


;********************************
; Data
;********************************

Palettes
	;; .incbin "palette.pal"
	.incbin "remco.dat"


Nametable_0
	.incbin "remco.nam"

Nametable_1
	.incbin "remco.nam"
	
;; Nametable_0
;; 	.incbin "nametable_0.nam"
;; Nametable_1			
;;  	.incbin "nametable_1.nam"


Attributes
	.db %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101
	.db %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101
	.db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
	.db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
	.db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
	.db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
	.db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
	.db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
	
	.db %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101
	.db %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101
	.db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
	.db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
	.db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
	.db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
	.db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
	.db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000


;********************************
; Vectors
;********************************

	.pad $FFFA	        ; First of the three vectors starts here
	.dw NMI                        
	.dw Reset      		                                    
				;.dw IRQ
	.dw 0                        


;********************************
; CHR-ROM bank
;********************************

	.incbin "remco.chr"	; Includes 8KB graphics file
