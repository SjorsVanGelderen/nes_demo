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
bg_offset   .dsb 2
bg_boundary .dsb 1
player_vx   .dsb 1
player_vy   .dsb 1
frame       .dsb 1
count       .dsb 1
direction   .dsb 1
dirty       .dsb 1
	.ende


;********************************
; iNES header
;********************************

	.db "NES",$1A		; ID of the header
	.db PRG_COUNT		; 1 PRG-ROM block
	.db CHR_COUNT		; 1 CHR-ROM block
	.db $00|MIRRORING	; Mapper 0 with mirroring
	.dsb 9,$00		; Padding


;********************************
; PRG bank
;********************************
    
	.base $10000-(PRG_COUNT*$4000)

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


LoadPalettes:
	LDA $2002	        ; Read PPU status to reset high/low latch
	LDA #$3F
	STA $2006	        ; Write high byte
	LDA #$00
	STA $2006		; Write low byte

	LDX #$00
LoadPalettesLoop:
	LDA Palettes,X                   
	STA $2007
	INX
	CPX #$20                       
	BNE LoadPalettesLoop


LoadBackground
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

LoadBackgroundLoop
	LDA (bg_offset),Y	; Push the current tile
	STA $2007

	INY                            
	CPY bg_boundary		; Check if the phase is done
	BNE LoadBackgroundLoop

	CPX #$03		; Check if the first nametable is done
	BEQ LoadNextNametable

	CPX #$07		; Check if the second nametable is done
	BEQ LoadBackgroundDone
	
	INX			; Increment iteration counter
	INC bg_offset+1         ; Increment high byte of offset

	CPX #$03		; Check if this is the last section
	BEQ LoadShortBoundary

	CPX #$07		; Check if this is the last section
	BEQ LoadShortBoundary
	
	JMP LoadBackgroundLoop
	
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
	
	JMP LoadBackgroundLoop

LoadShortBoundary
	LDA #$C0		; Set the boundary to 192 tiles more
	STA bg_boundary                
	JMP LoadBackgroundLoop
	
LoadBackgroundDone
    

LoadAttributes
	LDA $2002	        ; Read PPU status, reset high/low latch
	LDA #$23
	STA $2006	        ; Write high byte
	LDA #$C0
	STA $2006		; Write low byte

	LDX #$00
LoadAttributesLoop:
	LDA Attributes,X               
	STA $2007
	INX
	CPX #$08
	BNE LoadAttributesLoop


	JMP LoadSpritesDone
LoadSprites
	LDA #$80
	STA $0200		; Set Y
				;LDA #$80
	LDA player_vx
	STA $0203		; Set X
	LDA #$03
	STA $0201		; Tile 0
	STA $0202		; Color palette 0, no flipping

	RTS

;    LDA #$80
;    STA $0204                      ; Set Y
;    LDA #$88
;    STA $0207                      ; Set X
;    LDA #$01
;    STA $0205                      ; Tile 1
;    LDA #$00
;    STA $0206                      ; Color palette 0, no flipping

;    LDA #$88
;    LDA #$00
;    STA $0208                      ; Set Y
;    LDA #$80
;    STA $020B                      ; Set X
;    LDA #$10
;    STA $0209                      ; Tile 2
;    LDA #$00
;    STA $020A                      ; Color palette 0, no flipping

;    LDA #$10
;    STA $020C                      ; Set Y
;    LDA #$88
;    STA $020F                      ; Set X
;    LDA #$11
;    STA $0209                      ; Tile 4
;    LDA #$00
;    STA $020E                      ; Color palette 0, no flipping

;LoadSpritesLoop   
;    BNE LoadSpritesLoop

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
	LDA frame
	BNE Forever
	LDA dirty
				;CMP #$00
	BEQ Forever
	INC player_vy
	LDA #$00
	STA dirty

	JMP Forever


NMI
	LDA #$00
	STA $2003	        ; Set the low byte (00) of the RAM address
	LDA #$02
	STA $4014               ; Set the high byte (02) of the RAM address, start the transfer

	LDA #$01
	STA dirty

	INC frame

	LDA direction
				;CMP #$00
	BNE left
	INC player_vx
	LDA player_vx
	CMP #$FF
	BNE skip
	INC direction
	JMP skip
left
	DEC player_vx
				;LDA player_vx
				;CMP #$00
	BNE skip
	DEC direction
skip
	LDA player_vx
	STA $2005
				;LDA #$00
	LDA player_vy
	STA $2005

	JSR LoadSprites		; Could certainly be improved
	RTI


IRQ
	RTI


;********************************
; Data
;********************************

Palettes
	.incbin "palette.pal"


Nametable_0
	.incbin "nametable_0.nam"
Nametable_1			
 	.incbin "nametable_1.nam"


Attributes
	.db %00000000, %01010101, %10101010, %11111111, %00000000, %00000000, %00000000, %00000000
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

	.incbin "graphics.chr"	; Includes 8KB graphics file
