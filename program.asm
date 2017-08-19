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

	
	.enum $0000		; Not quite clear on this yet

;;; Background
	bg_offset     		.dsb 2
	bg_boundary   		.dsb 1

;;; Animations
	anim_address  		.dsb 2
	anim_length   		.dsb 1

;;; Sprites
	sprite_big              .dsb 1 ; Whether or not the sprite is big (2x2 as opposed to 1x1)
	sprite_source		.dsb 1 ; Number of sprite to render
	sprite_data_offset	.dsb 1 ; Determines which byte of the transfer is written
	sprite_target		.dsb 2 ; Where to put the sprite

;;; Player
	player_pos      	.dsb 2 	; Position
	player_vel      	.dsb 2	; Velocity

;;; Collision
	collision_pos   	.dsb 2	; Coordinates of the collision check
	coll_nt_offset		.dsb 2	; Nametable offset
	collision		.dsb 1	; Flag to be set by collision subroutine
	;; blocking_tiles  	.db $20,$21,$30,$31
	blocking_tiles          .dsb 4
	blocking_tiles_amount 	.db 4
	current_blocking_tile   .dsb 1
	
;;; Camera
	camera_x      		.dsb 1

;;; Logic
	dirty         		.dsb 1
	
	.ende


;;; Predefined bytes
	LDA #$20
	STA blocking_tiles
	LDA #$21
	STA blocking_tiles+1
	LDA #$30
	STA blocking_tiles+2
	LDA #$31
	STA blocking_tiles+3
	LDA #$04
	STA blocking_tiles_amount

	
;;; Player setup
	LDA #$10		; Set initial position
	STA player_pos
	STA player_pos+1
	
	LDA #$00		; Set initial velocity
	STA player_vel
	STA player_vel+1

	
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


	JMP StartSpriteTransferDone
StartSpriteTransfer
	LDA #$00		; Reset data offset
	STA sprite_data_offset
	
	LDA #$00
	STA $2003	        ; Set the low byte (00) of the RAM address
	LDA #$02
	STA $4014               ; Set the high byte (02) of the RAM address, start the transfer
	RTS
	
StartSpriteTransferDone


	JMP DrawSpriteDone
DrawSprite
	LDX #$00
	LDY sprite_data_offset 	; Load the saved offset
	
DrawSpriteLoop
	CPX #$00  		; Write Y coordinate
	LDA sprite_target+1
	BNE +
	CLC
	SBC #$01		; Scanline correction
+
	STA ($0200),Y
	
	INY
	
	LDA sprite_source	; Write tile number
	STA ($0200),Y
	
	INY
	
	LDA #%00000000 		; Color palette 0, no flipping
	STA ($0200),Y
	
	INY
	
	LDA sprite_target	; Write X coordinate
	CPX #$03
 	BNE ++
	CLC
 	SBC #$01		; Fix weird glitch on last tile X
++
	STA ($0200),Y

	INY
	
	LDA sprite_big
	CMP #$00		; Possibly redundant?
	BEQ DrawSpriteLoopDone	; Sprite isn't big (0)

	INX
	CPX #$04		; Finished rendering 4 segments of big sprite
	BEQ DrawSpriteLoopDone

	CPX #$02		; Account for bottom row
	BNE +++
	
	LDA sprite_source	; Move one row down
	;; CLC
	ADC #$0D
	STA sprite_source
	
	LDA sprite_target	; Reset X
	;; CLC
	SBC #$0F
	STA sprite_target
	
	LDA sprite_target+1	; Increase Y
	;; CLC
	ADC #$07
	STA sprite_target+1
+++

	CPX #$03                ; Weird drawing bug fix for last tile X
	BNE ++++
	INC sprite_target
++++
	
	INC sprite_source
	LDA sprite_target
	;; CLC
	ADC #$08
	STA sprite_target
	JMP DrawSpriteLoop
	
	
DrawSpriteLoopDone
	TYA
	STA sprite_data_offset	; Save the offset
	RTS
	
DrawSpriteDone


	JMP ReadControllerDone
ReadController
	LDA #$01		; Initiate read
	STA $4016
	LDA #$00
	STA $4016

	LDX #$00		; Reset X
	
ReadController1Loop
	LDA $4016
	AND #%00000001		; Check if the button is pressed
	BEQ NotPressed

	CPX #$00		;A
	BNE +
	LDA #$00
	STA player_vel
	STA player_vel+1
+
	
	CPX #$04		; Up
	BNE +++++
	LDA #$00
	STA player_vel+1
	DEC player_vel+1
	LDA #$00
	STA player_vel
+++++
	
	CPX #$05		; Down
	BNE ++++++
	LDA #$01
	STA player_vel+1
	LDA #$00
	STA player_vel
++++++

	CPX #$06		; Left
	BNE +++++++
	LDA #$00
	STA player_vel
	DEC player_vel
	LDA #$00
	STA player_vel+1
+++++++

	CPX #$07		; Right
 	BNE ++++++++
 	;; INC player_vel
	LDA #$01
	STA player_vel
	LDA #$00
	STA player_vel+1
++++++++

NotPressed
	INX
	CPX #$08
	BNE ReadController1Loop
ReadController1LoopDone

;; 	LDX #$00		; Reset X
	
;; ReadController2Loop
;; 	LDA $4017
;; 	INX
;; 	CPX #$08
;; 	BNE ReadController2Loop
;; ReadController2LoopDone
	
	RTS
ReadControllerDone
	

;;; Could certainly be compressed
	JMP MapCollisionDone
MapCollision
	LDA #$00		; Reset collision flag
	STA collision
	
	LDA #<Nametable_0	; Store nametable address
	STA coll_nt_offset
	LDA #>Nametable_0
	STA coll_nt_offset+1
	
;;; Horizontal collision coordinate
	LDA collision_pos	; Extract least significant hex
	AND #%00001111
	TAX
	
	LDA collision_pos	; Extract most significant hex
	AND #%11110000		
	LSR A
	LSR A
	LSR A
	LSR A
	ASL
	
	CPX #$08		; Determine sub-tile
 	BCC +
	CLC
	ADC #$01
+
	STA collision_pos       ; Store X coordinate of NT query

;;; Vertical collision coordinate
	LDA collision_pos+1	; Extract least significant hex
	AND #%00001111
	TAX
	
	LDA collision_pos+1
	AND #%11110000          ; Extract most significant hex
	LSR A
	LSR A
	LSR A
	LSR A
	ASL
	
	CPX #$08                ; Determine sub-tile
	BCC ++
	CLC
	ADC #$01
++

	STA collision_pos+1	; Store Y coordinate of NT query

	LDX #$FF		; Determine NT offset according to Y
-
	INX
	CPX collision_pos+1	; Until Y has been accounted for
	BEQ +++
	LDA coll_nt_offset	; Load least significant byte of offset
	CLC
	ADC #$20		; Add a row of 32 tiles (hex 20)
	STA coll_nt_offset
	BCC -
	INC coll_nt_offset+1	; If we exceeded the limit, INC the most significant byte of offset
	JMP -			; Continue the loop
+++
	
	LDX #$FF

--
	INX			; For each blocking tile
	CPX blocking_tiles_amount
	BEQ ++++
	
	LDA blocking_tiles,X	; Load the current tile to check against
	STA current_blocking_tile
	
	LDY collision_pos	; Check if the tile is blocking
	LDA (coll_nt_offset),Y
	CMP current_blocking_tile
	BNE --			; No collision, continue the check
	LDA #$01		; Set collision flag
	STA collision
++++
	
	RTS
MapCollisionDone

	
	JMP PlayerDrawDone
PlayerDraw
	LDA #$01		; Big sprite
	STA sprite_big
	
	LDA #$00		; Set tile
	STA sprite_source
	LDA player_pos		; Set position
	STA sprite_target
	LDA player_pos+1
	STA sprite_target+1
	JSR DrawSprite		; Actually draw sprite 1
	
	LDA #$02		; Set tile
	STA sprite_source
	LDA #$30		; Set position
	STA sprite_target
	STA sprite_target+1
	JSR DrawSprite		; Actually draw sprite 2
	
	RTS
PlayerDrawDone

	
	JMP PlayerUpdateDone
PlayerUpdate
	LDA player_pos		; Increment X by VX
	CLC
	ADC player_vel
	STA player_pos

	LDA player_pos+1	; Increment Y by VY
	CLC
	ADC player_vel+1
	STA player_pos+1

	LDA player_pos		; Perform collision check TOP LEFT
	STA collision_pos
	LDA player_pos+1
	STA collision_pos+1
	JSR MapCollision

	LDA #$01		
	CMP collision
	BNE +
	LDA #$00
	STA player_vel		; Stop all velocity
	STA player_vel+1
+

	LDA player_pos		; Perform collision check TOP RIGHT
	ADC #$10
	STA collision_pos
	LDA player_pos+1
	STA collision_pos+1
	JSR MapCollision

	LDA #$01		
	CMP collision
	BNE ++
	LDA #$00
	STA player_vel		; Stop all velocity
	STA player_vel+1
++

	LDA player_pos		; Perform collision check BOTTOM LEFT
	STA collision_pos
	LDA player_pos+1
	ADC #$10
	STA collision_pos+1
	JSR MapCollision

	LDA #$01		
	CMP collision
	BNE +++
	LDA #$00
	STA player_vel		; Stop all velocity
	STA player_vel+1
+++

	LDA player_pos		; Perform collision check BOTTOM RIGHT
	ADC #$10
	STA collision_pos
	LDA player_pos+1
	ADC #$10
	STA collision_pos+1
	JSR MapCollision

	LDA #$01		
	CMP collision
	BNE ++++
	LDA #$00
	STA player_vel		; Stop all velocity
	STA player_vel+1
++++

	RTS
PlayerUpdateDone
	

PPUCleanUp:
	LDA #%10010100	        ; Enable NMI, sprites from pattern table 0
	STA $2000
	LDA #%00011110          ; Enable sprites, background, disable clipping left
	STA $2001
	LDA #$00
	STA $2005		; Reset scrolling
	STA $2005

	
Forever				; Wait until NMI occurs
	LDA dirty		; Check if dirty
	BEQ Forever
	DEC dirty		; Set clean

	JSR ReadController
	JSR PlayerUpdate
	
	JMP Forever


NMI				; This is the time to do all drawing
	LDA #$01		; Set dirty flag
	STA dirty
	
	JSR StartSpriteTransfer
	JSR PlayerDraw
	
	RTI


IRQ
	RTI


;********************************
; Data
;********************************

Palettes
	.incbin "palette.dat"

	
Nametable_0
	.incbin "nametable_0.nam"
Nametable_1			
 	.incbin "nametable_1.nam"


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

	.incbin "graphics.chr"	; Includes 8KB graphics file
