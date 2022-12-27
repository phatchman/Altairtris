VIDEO		EQU     1000h           ; location of dazzler video 2K RAM
ARENAH		EQU	20		; Arena is 20 blocks high
;ARENAYX		EQU	0A06h		; Top / left arena draw location
					; Y=10,X=6
ARENAY		EQU	6
ARENAX		EQU	9
SHAPEY		EQU	ARENAY + 5
SHAPEX		EQU	ARENAX+6
	org     100h
	lxi     h,0             
	dad     sp              ; get old stack
	shld    stacko
	lxi     sp,stack        ; set local stack

	call    clrvideo        ; Clear dazzler video ram
	mvi     a,00011111b     ; Normal Res, Colour, low intens,rgbs
				; RGB not used in normal mode (only in x4 mode)
				; high intensity, not used in normal mode.
	out     17o
	mvi     a,VIDEO >> 9    ; Set video ram location
	ori     80h             ; Set dazzler to "on"
	out     16o             ; out to dazzler control reg
	call	drawarena
	call    drawshape
loop:   jmp     loop

;
; Clear 8 x 256 bytes = 2k of video ram
;
clrvideo:
	xra     a               ; a = 0
	lxi     h,vram
	lxi     b,8             ; B = 0 ; C = 8
cvloop: mov     m,a             ; clear byte
	inx     h               ; next byte
	inr     b
	jnz     cvloop          ; clear 1x256 bytes
	dcr     c
	jnz     cvloop          ; Repeat 8 times
	ret

drawshape:
	lhld    shape		
	xchg                    ; DE = shape
	lxi     h,vram+SHAPEY*16+(SHAPEX/2)		; HL = vram  TODO: FIX where shape falls on a half a vram byte
	lxi     b,16-1          ; offset to next line
	call    drawrow         ; row 1
	dad     b
	inx     d
	call    drawrow         ; row 2
	dad     b
	inx     d
	call    drawrow         ; row 3
	dad     b
	inx     d
	call    drawrow         ; row 4
	ret

drawrow:
	ldax    d               ; pixel 1 & 2
	mov     m,a             

	inx     h               ; Pixel 3 & 4
	inx     d
	ldax    d
	mov     m,a             

	ret

drawarena:
	mvi     c,ARENAH+1		; C = row counter
	lxi     h,arena			; 
	xchg				; DE = arena
	lxi     h,vram+ARENAY*16+(ARENAX/2)	; HL = vram start of arena
daloop:	ldax 	d			; read arena char
	ora	a			; null = end of arena row
	jnz	danxt			; if not null, continue
	dcr	c			; otherwise dec row counter
	jz	dadone			; If 0 rows left, then done
	push	b			; save row counter
	lxi	b,16-(14/2)		; and move to next vram line
	dad	b
	pop	b			; restore row counter
	inx	d			; and process next arena char
	jmp	daloop			
danxt:	call    calcbotpixel		; calc the pixel value
	mov	b,a			; save pixel value in b
	inx    	d			; next arena char
	ldax	d
	call    calctoppixel		; calc the pixel value
	ora     b			; combine the two arena pixels into 1 vram byte
	mov	m,a			; store in vram
	inx     h			; next vram byte
	inx	d			; next arena byte
	jnz	daloop
dadone:	ret	

; Convert ascii value to 4 bit pixel colour
calctoppixel:
	cpi     ' '             ; space = black
	jnz     ctp2
	mvi     a,01110000b
	ret
ctp2:   mvi     a,11110000b         ; otherwise white
	ret

; Convert ascii value to 4 bit pixel colour
calcbotpixel:
	cpi     ' '                     ; space = black
	jnz     cbp2
	mvi     a,0111b
	ret
cbp2:   mvi     a,1111b         ; otherwise white
	ret



shapx   db      0
shapy   db      0

shape:  dw      zshape      

zshape:		
z1:	db	0AAh,077h
	db	0A7h,07Ah
	db	077h,077h
	db	077h,077h


arena:	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' |          | ',0
	db	' +==========+ ',0
	db	'              ',0	; shape can extend 1 below the arena
arenaend:

	;;;;;;;;;;;;;;;;;
	;; Local Stack ;;
	;;;;;;;;;;;;;;;;;
	ds      32              ; 16 level stack
stack:
stacko: dw      0               ; orig stack
	org     VIDEO
vram:   ds      512
	end


