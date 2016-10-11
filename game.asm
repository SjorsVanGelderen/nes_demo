;;; NES demo
;;; Copyright 2016, Sjors van Gelderen

;;; Initial setup
	.inesprg 1		; 16KB PRG code
	.ineschr 1		; 8KB CHR data
	.inesmap 0		; Mapper 0 = NROM, no bank swapping
	.inesmir 1 		; Background mirroring

	.bank 0			
	.org $C000
	
RESET:
	SEI			; Disable IRQs
	CLD 			; Disable decimal mode
	LDX #$40
	STX $4017		; Disable APU frame IRQ
	LDX #$FF
	TXS			; Set up stack
	INX 			; Now X = 0
	STX $2000		; Disable NMI
	STX $2001		; Disable rendering
	STX $4010		; Disable DMC IRQs

VBLANK_1:			; First wait for vblank, make sure the PPU is ready
	BIT $2002
	BPL VBLANK_1

CLEAR_MEMORY:
	LDA #$00
	STA $0000, x
	STA $0100, x
 	STA $0200, x
	STA $0400, x
	STA $0500, x
	STA $0600, x
	STA $0700, x
	LDA #$FE
	STA $0300, x
	INX
	BNE CLEAR_MEMORY
	   
VBLANK_2:			; Second wait for vblank, PPU is ready after this
	BIT $2002
	BPL VBLANK_2

	
;;; Graphics
	
LOAD_PALETTES:
	LDA $2002		; Read PPU status to reset the high/low latch
	LDA #$3F
	STA $2006             	; Write the high byte of $3F00 address
	LDA #$00
	STA $2006 	        ; Write the low byte of $3F00 address
	LDX #$00              	; Start out at 0
	
LOAD_PALETTES_LOOP:	
	LDA PALETTE, x        	; Load data from address (palette + the value in x)
	STA $2007             	; Write to PPU
	INX                   	; X = X + 1
	CPX #$20              	; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
	BNE LOAD_PALETTES_LOOP 	; Branch to LOAD_PALETTES_LOOP if compare was Not Equal to zero
				; If compare was equal to 32, keep going down

LOAD_SPRITES:
	LDX #$00              	; Start at 0
	
LOAD_SPRITES_LOOP:
	LDA SPRITES, x        	; Load data from address (sprites +  x)
	STA $0200, x          	; Store into RAM address ($0200 + x)
	INX                   	; X = X + 1
	CPX #$20              	; Compare X to hex $20, decimal 32
	BNE LOAD_SPRITES_LOOP  	; Branch to LOAD_SPRITES_LOOP if compare was Not Equal to zero
				; If compare was equal to 32, keep going down

	LDA #%10000000   	; Enable NMI, sprites from Pattern Table 1
	STA $2000

	LDA #%00010000   	; Enable sprites
	STA $2001

FOREVER:
	JMP FOREVER     	; Jump back to FOREVER, infinite loop

NMI:
	LDA #$00
	STA $2003       	; Set the low byte (00) of the RAM address
	LDA #$02
	STA $4014       	; Set the high byte (02) of the RAM address, start the transfer

	
;;; INPUT
	
LATCH_CONTROLLER:
	LDA #$01
	STA $4016
	LDA #$00
	STA $4016       	; Tell both the controllers to latch buttons
	
;;; PLAYER 1
	
P1_READ_A: 
	LDA $4016		
	AND #%00000001  	
	BEQ P1_READ_A_DONE 	
	;; Do something here
P1_READ_A_DONE:

P1_READ_B: 
	LDA $4016       	
	AND #%00000001  	
	BEQ P1_READ_B_DONE 	
	;; Do something here	
P1_READ_B_DONE:        		

P1_READ_SELECT: 
	LDA $4016       	
	AND #%00000001  	
	BEQ P1_READ_SELECT_DONE
	;; Do something here
P1_READ_SELECT_DONE:   		

P1_READ_START: 
	LDA $4016       	
	AND #%00000001  	
	BEQ P1_READ_START_DONE 
	;; Do something here
P1_READ_START_DONE:   	

P1_READ_UP: 
	LDA $4016       	
	AND #%00000001  	
	BEQ P1_READ_UP_DONE
	LDA $0204       	; Move player up
	SEC             	
	SBC #$01        	
	STA $0204
P1_READ_UP_DONE:   	

P1_READ_DOWN: 
	LDA $4016       	
	AND #%00000001  	
	BEQ P1_READ_DOWN_DONE  
	LDA $0204       	; Move player down
	SEC             	
	ADC #$01        	
	STA $0204       	
	
P1_READ_DOWN_DONE:
	
P1_READ_LEFT: 
	LDA $4016       	
	AND #%00000001  	
	BEQ P1_READ_LEFT_DONE 
	LDA $0203		; Move player left
	SEC             	
	SBC #$01        	
	STA $0203       	
P1_READ_LEFT_DONE:   	

P1_READ_RIGHT: 
	LDA $4016       	
	AND #%00000001  	
	BEQ P1_READ_RIGHT_DONE 
	LDA $0203       	; Move player right
	SEC             	
	ADC #$01        	
	STA $0203       	
P1_READ_RIGHT_DONE:
	
	RTI             	; Return from interrupt
  
	.bank 1
	.org $E000
	
PALETTE:
	.db $0F,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
	.db $0F,$1C,$15,$14,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C

SPRITES:
				; Vert tile attr horiz
	.db $80, $32, $00, $80  ; Sprite 0
	.db $80, $33, $00, $88  ; Sprite 1
	.db $88, $34, $00, $80  ; Sprite 2
	.db $88, $35, $00, $88  ; Sprite 3

	.org $FFFA     		; First of the three vectors starts here
	.dw NMI        		; When an NMI happens (once per frame if enabled) the 
				; Processor will jump to the label NMI:
	.dw RESET      		; When the processor first turns on or is reset, it will jump
				; To the label RESET:
	.dw 0          		; External interrupt IRQ is not used
  
	.bank 2
	.org $0000
	.incbin "graphics.chr"  ; Includes 8KB graphics file
