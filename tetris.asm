;; 
;; TETRIS for ALTAIR 8800
;; ----------------------
;; 
;; MIT License
;;
;; Copyright (c) 2022 Paul Hatchman
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;; 
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;; 
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.
;;

; BUILD OPTIONS
; Note the IF x - 1 syntax for the conditional assembly.
; This format is used to have code compile under both linuxa:load  (asl assembler)
; and CPM as they use different conditional logic.
CPM		EQU 	1		; Set to 0 for building without CPM.
					; Will load to address 0 and HLT on exit
ALTSHAPECHARS	EQU	0		; If set to 1, then use all
					; hashes for the tetromino chars
DAZZLER		EQU	0		; Set to 1 for dazzler support
DEBUG		EQU	0		; Includes some debug/helper routines

; Serial Port Configuration
;  - Currently only works on SIO-2
;  - SIO doesn't just use different status bits, 
;    the status logic is also inverted compared to SIO-2
SIOSTAT		EQU	16		; status port
SIODATA		EQU	17		; data port
SIOREADY	EQU	2		; output ready mask
SIOAVAIL	EQU	1		; input avail mask

; ARENA (Playing Field) Definition
ARENAW		EQU	10		; Arena is 10 blocks wide
ARENADN		EQU	(ARENAW+5)	; Offset to move down one row in arena
					; Arena width+4 side chars+1 null char
ARENAH		EQU	20		; Arena is 20 blocks high
ARENALST	EQU	(ARENADN*(ARENAH-1) + 2)
					; offset to first col of last arena line
	IF	DAZZLER-1
ARENAY		EQU	2		; Top / left arena draw location
ARENAX		EQU	0		; in screen co-ordinates
	; Make sure to change these if ARENAX or ARENAY are changed
MINUSARENAY	EQU	0FEh		; Negative of ARENAY. The CPM assembler 
					; doesn't like -ARENAY for ADI
MINUSARENAX	EQU	000h		; Negative of ARENAX
SPAWNYX		EQU	0206h		; Spawn on row 2, col 6
					; except for I shape, which is col 5

	ENDIF
	IF	DAZZLER
ARENAY		EQU	6		; Top / left arena draw location
ARENAX		EQU	9
	; Make sure to change these if ARENAX or ARENAY are changed
MINUSARENAY	EQU	0FAh		; Negative of ARENAY. The CPM assembler 
					; doesn't like -ARENAY for ADI
MINUSARENAX	EQU	0F7h		; Negative of ARENAX
SPAWNYX		EQU	060Fh		; Spawn on row 6, column 15
					; except for I shape, which is col 14
	; DAZZLER-specific
VIDEO           EQU     1400h           ; VRAM location (1400h = 5k)
NRCLRS		EQU	12		; Nr of colour table entries (clrtbl)
	ENDIF

; Make these speed values higher if you want a bigger challenge
; However, the speed gets fast pretty quickly as it is, so suggest to leave them
SPEEDINIT	EQU	0		; initial speed
SPEEDINC	EQU	1		; The value to increment speed each time
					; a shape is locked in place
					; Must be a power of 2
HDSCORE		EQU	2		; + score each row that was hard-dropped
SDSCORE		EQU	1		; + score each row that was soft-dropped

;
; About DAZZLER Support
;
; Uses the 512k vram, 32x32 pixel, colour mode.
; It is implemented by converting the ascii output of the SIO version into 
; coloured pixels to be written to the DAZZLER vram. Each character that would
; normally be output to the SIO is mapped to a colour and stored in the vram.
; The cursor movement outputs are stored as pointers into the associated VRAM 
; address.
; While this is not the most efficient way create a tetris for the DAZZLER,
; it does provide a relatively simple way to use the same source code for
; the SIO and DAZZLER versions, with only minor conditional assembly
;
; Output the should still go to the serial port, outstrsio and outchsio 
; subroutines. These also work as normal serial output in the SIO version.
;

	;; START OF CODE ;;
	IF 	CPM
	org	100h			
	ENDIF
	IF	CPM-1			; Logic done this way to be compatible 
	org	000h			; with CPM ASM and the ASL assembler
	ENDIF
	; Set up stack
	lxi	h,0
	dad	sp			; get current stack
	shld	stacko			; save as original stack
	lxi	sp,stack		; set new stack


	lxi	h,invis			; set cursor invisible
	call 	outstrsio

	IF	DAZZLER
        call    dazinit
	ENDIF

nwgame:	lxi	h,clr			; clear screen
	call	outstrsio
	IF	DAZZLER - 1		; Only output in the SIO version
	lxi	d,0000h
	call	csrpossio		; Set cursor to 0,0
	lxi	h,scrstr		; Print "SCORE"
	call	outstrsio
	ENDIF
	mvi	a,0
	sta	score			; reset score
	sta	score+1
	sta	score+2
	sta	nrclr			; Reset number of cleared rows
	call	displayscore		; Show score, draw arena
	call	drawarena		; and display help
	call 	displaycontrols

	; Wait for "S - START or Q - QUIT" keys
wait4s:	
	lxi	h,seed1			; increment random seed1 for 
	mvi	a,1			; each wait loop
	add	m			; We leave seed2 as a constant
	mov	m,a
	inx	h
	mvi	a,0
	adc	m
	mov	m,a
	call	inch
	jz	wait4s			; no char received, try again
	call	toupper
	cpi	'S'
	jnz	wait4q			; Did the user press S - START?
	call	drawarena		; then blank out the controls text
	lda	seed1			; make sure seed 1 is not 0 as 
	ora	a			; will break rng
	jnz	gameloop
	inr	a
	sta	seed1	
	jmp	gameloop		; Start the game
wait4q:	cpi	'Q'			; is this 'quit'?
	jnz	wait4s
	jmp	done			; Quit
	
	; Main Game Loop
	; Create a random shape in the start position
	; Each "tick", move it down until it collides 
	; with another shape or the arena floor
gameloop:
	lda	nrclr			; was something cleared this turn?
	ora	a			; Set Z flag
	jz	nodrop			; If nothing cleared, then continue
	call	delay			; delay half a cycle
	call	droprows		; Remove cleared rows and drop higher
					; rows down.
nodrop:	call	spawnshape		; spawn a new, random shape	
iploop:	; input loop for processing keystrokes and
	; then dropping the shape 1 row
	lda	updscr			; has the score been changed?
	ora	a
	jz	skpscr			; if not, skip
	call	displayscore		; otherwise update the score
	xra	a
	sta	updscr			; and set updscr = FALSE
skpscr:	call	inputdelay		; Process input for one game "tick"
	jc	lock			; CY set if a collision from user 
					; performing a soft or hard drop
					; If collided, lock shape in place
	call	movdown			; Otherwise, move the shape to next row
	jc	lock			; if collision, then lock shape
	jmp	iploop			; otherwise process more input
lock:	; lock the current piece in place on the arena
	lda	shapy
	cpi	ARENAY			; are we at top of arena?
	jz	over			; if so then game is over
					; as shape collided on row 0
	call	lockshape		; otherwise lock shape in place
	call	checkrows		; check if there are any full rows.
	jmp	gameloop		; process main loop
over:	; Game is over
	lhld	anyyx			; display "PRESS ANY KEY"
	xchg
	call	csrpossio		; DE = screen pos to display
	lxi	h,anystr
	call	outstrsio
	mvi	a,SPEEDINIT		; reset speed
	sta	speed
	call	delay			; delay slightly so user can read the
	call	delay			; ANY KEY message (in case they were in 
	call	delay			; middle of hitting a key)
	call	inflush			; flush any left over keys
overlp:	call	inch			; wait for new key press
	ora	a			; set Z flag
	jz	overlp			
	call	cleararena		; blank out arena
	jmp	nwgame			; start new game
done:	call	inflush			; flush out incoming serial chars
	lxi	h,vis			; Make the cursor visible again
	call	outstrsio
	lxi	h,clr			; Clear the screen
	call	outstrsio
	IF CPM
	lhld	stacko			; restore the CPM stack
	sphl
	ret				; return to CPM on quit
	ENDIF
	IF CPM - 1
	hlt				; halt on quit
	ENDIF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Shape Drawing and Manipulation Subroutines ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

;
; prepshape - Prepare shape to draw
; INPUTS: shapno - number of shape to draw
;	  shapo  - orientation of shape
; Find the pointer to the shape in shaptbl then get the orientation of the shape 
; Save a pointer to the shape and orientation in the shape pointer.
; prepshape must be called whenever the shapno or shapo (orientation) changes
prepshape:
	; Add 2*shapno to the shaptbl pointer to get a pointer 
	; to the first shape's orientation
	lda 	shapno		; get the shape to be drawn
	add	a		; double it to get the word offset into shaptbl
	mvi	b,0		
	mov	c,a		; BC will now contain the offset into shaptbl
	lxi	h,shaptbl	; load address of shaptbl into HL
	dad	b		; add the offset to the shape pointer
	; HL now contains a pointer into shaptbl with the address of the 
	; orientation 0 version of the shape
	mov	e,m		; move low byte of shape address into c
	inx	h		; increment to high addr
	mov	d,m		; move high byte of shape address into b
	xchg			; move DE into HL
	; HL now contains a pointer to the shape with orientation 0
	lxi	b,10h		; Each shape orientation takes up 16 bytes
	lda	shapo		; load shape orientation
psori:	cpi	0
	jz	psnx		; if done finding orientation, then jump to draw
	dad	b		; add the 16 byte offset
	dcr	a		; dec the number of orientations
	jmp	psori
	; HL will now contain a pointer to the correct shape and orientation
	; store it to the shape pointer
psnx:	shld	shape		; shape HL to shape
	
	ret

; spawnshape - Spawn a new, random shape at the top of the arena.
;		1. Get random shape
;		2. Set shape pointer to that shape in orientation 0
;		3. Spawn at origin for that shape.
;		4, Draw the shape
;		Note: that shapx and shapy are relative to arena top-left
; 		0 = Z ; 1 = S ; 2 = L ; 3 = J
; 		4 = T ; 5 = I ; 6 = O
spawnshape:
ssrnd:	call 	random			; get random number from 0-6
	ani	7			; this returns 0-7
	cpi	7			; if 7, then try again
	jz	ssrnd
	sta	shapno			; store the new shape 
	xra	a			; a = 0
	sta	shapo			; shapo (orientation) = 0
	call 	prepshape		; load the shape and orientation

	lxi	h,SPAWNYX		; H = spawn y, L = spawn x
	lda 	shapno
	cpi	5			; if shape is 5, then spawn 1 pos to left
	dcr	l			; spawn x = spawn x - 1
	shld	shapx			; store spawn y to shapy and x to shapx

	call	setarenaptr		; Set the arena pointer. 
	call	drawshape		; draw
	ret

;
; drawshape - Draw shape on screen
;             For blank parts of shape, draw the corresponding "arena" character
; INPUTS: shapx, shapy		; position of shape
;         shape			; pointer to the shape and orientation
; If shape or orientation changes, call prepshape to populate the 
; shape pointer before calling drawshape
; If shape position changes, call setarenaptr to update pointer to the shape's
; position in the arena
drawshape:
	lhld	shapx
	xchg			; D = shapy ; E = shapx
	call 	csrpos		; set cursor to draw position

	lhld	araptr		; load pointer to the location in the arena
				; to be used by drawline
	xchg			; and move to DE
	lhld	shape		; load current shape
	call 	drawline	; draw all 4 lines of the shape

	inx	h
	xchg			; swap, ready for the add below
	lxi	b,ARENADN-3	; move to next arena line minus the 4 shape cols
	dad	b		; + 1 to increment to next character
	xchg
	call	drawline

	inx	h
	xchg			; swap in prep for the add below
	lxi	b,ARENADN-3	; advance to next arena line
	dad	b
	xchg
	call	drawline

	inx	h
	xchg			; swap in prep for the add below
	lxi	b,ARENADN-3	; advance to next arena line
	dad	b
	xchg
	call	drawline

	ret

; drawline - Draw 1 line of the shape
;	     For blank chars of the shape, draw the corresponding 
;            arena "background" character instead.
; INPUTS:
; 	HL = pointer to current shape line to output
; 	DE = arena location pointer (araptr)
drawline:
	mov	a,m		; load the shape character to display
	cpi 	' '		; is it blank?
	jnz	dl1		; if not blank then display it
	ldax	d		; otherwise get the background char to draw
dl1:	mov	b,a		; store in b to output via outch
	call	outch		; output it

	inx	h		; get next char
	inx	d		; and next arena position
	mov	a,m		; and repeat
	cpi 	' '		;
	jnz	dl2		;
	ldax	d		;
dl2:	mov	b,a		;
	call	outch		;
	
	inx	h		; get next char
	inx	d
	mov	a,m		; and repeat
	cpi 	' '		;
	jnz	dl3		;
	ldax	d		;
dl3:	mov	b,a		;
	call	outch		;

	inx	h		; get next char
	inx	d
	mov	a,m		; and repeat
	cpi 	' '		;
	jnz	dl4		;
	ldax	d		;
dl4:	mov	b,a		;
	call	outch		;

	; OPT: Potential optimisation to use csrpos here instead.
	; Would only need 1 vt100 escape sequence instead of the current 2
	push 	h		; save the shape pointer
	push	d		; and arena pointer
        call    csrdownback     ; set cursor to start of shape on next line
	pop	d		; and arena pointer
	pop	h		; restore shape pointer

	ret

        IF      DAZZLER-1
;
; Move cursor down 1 line and back 4 chars
;
csrdownback:
	lxi	h,dwn		; go down 1 line
	call 	outstr
	lxi	h,bw4		; and back 4 characters
	call 	outstr
        ret
        ENDIF
	IF	DAZZLER
;
; Move cursor down 1 line and back 4 chars
; Dazzler version
csrdownback:
        lhld    vrptr           ; load vram pointer into HL
        lxi     d,16-2          ; move pointer to next line - 4 chars
        dad     d               ; (2 chars per byte = -2)
        shld    vrptr
        ret
	ENDIF

; erasehape - Erase the currently drawn shape
;
eraseshape:
	lhld	shapx		
	xchg			; D = shapy ; E = shapx
	call 	csrpos		; set cursor to draw position

	lhld	araptr		
	call	eraseline	; erase current line

	lxi	d,ARENADN-3	; move to next arena line 
	dad	d		; -3 to go back to start of shape
	call	eraseline	; erase current line
	
	lxi	d,ARENADN-3	; move to next arena line
	dad	d
	call	eraseline	; erase current line

	lxi	d,ARENADN-3	; move to next arena line
	dad	d
	call	eraseline	; erase current line

	ret

; eraseshapetop - Erase the top line of the currently drawn shape
;                 This is a slight optimisation for when the shape moves down
;                 Only the top row needs to be blanked as the rest of the shape
;                 will be redraw in the next drawshape.
;		  OPT: Similar optimisations could be provided in future for 
;		  moving the shape left and right.
eraseshapetop:
	lhld	shapx		
	xchg			; D = shapy ; E = shapx
	call 	csrpos		; set cursor to draw position

	lhld	araptr		
	call	eraseline	; erase current line
	ret

;
; eraseline - Erase the current shape line
; INPUTS:     HL = pointer to arena line to erase
eraseline:
	mov	b,m		; load arena character
	call	outch		; output 

	inx	h		; move to next and repeat
	mov	b,m
	call 	outch
	
	inx	h
	mov	b,m
	call 	outch

	inx	h
	mov	b,m
	call 	outch

	push 	h		; move to the next line
        call    csrdownback     ; OPT: this isn't needed for the last line
	pop	h

	ret
;
; lockshape - copies the current shape into the arena
;	       called when shape collides with something in the arena
;	       or with the arena itself.
; INPUTS: HL is pointer to arena
; 	  DE is pointer to shape
; Loops through each shape character and copies it into the arena.
; This makes the shape "permanent" and thus subject to collision and 
; "full row" checking
lockshape:
	lhld 	shape		; load current shape into HL
	xchg			; and copy to DE
	lhld	araptr		; load the shape's position in the arena into HL

	mvi	b,4		; B is col counter - each shape is 4 chars wide
	mov	c,b		; C is row counter - each shape is 4 lines tall
	jmp	lscpy		; don't increment pointers on first check
lsinc:	inx	h		; move to next arena pos
	inx	d		; move to next shape char
lscpy:	ldax	d		; get the first shape char
	cpi	' '		; only copy non-space chars
	jz	lsskip		; skip if space
	mov	m,a		; and copy into the arena
lsskip: dcr	b		; decrement column counter
	jnz	lsinc		; and jmp to copy next char
	mvi	b,4		; at end of column, reset
	dcr	c		; and move to next row
	jz	lsspd		; if no more rows to check, then done
	; move to next line of arena
	mov	a,c		; save the value of the row counter in A
	lxi	b,ARENADN-3	; move to next arena line minus the 4 shape cols
				; + 1 to increment to next character
	dad	b		; change HL to next arena row
	mvi	b,4		; reset the col counter
	mov	c,a		; restore the row counter
	inx	d		; move to the next shape character
	jmp	lscpy		; check the next row. 
lsspd:	lxi	h,speed		; speed+=SPEEDINC for each piece locked in place
	mov	a,m
	cpi	0ffh		; is speed already max?
	jz	lsdon		; then don't increase
	mvi	a,SPEEDINC	
	add	m		; speed += SPEEDINC
	mov	m,a		; store
	jnz	lsdon		; if speed not wrapped to 0, then done
	dcr	a		; Set speed to FFh
	mov	m,a		; and store
lsdon:	
	ret			; copy is done

;
; kickshape - "Kicks" the shape to a different position if the current rotation
;             of the shape causes a collision. Called if rotcw detects a 
;             collision.
; Note: This function does not restore old x/y values on a failed kick. 
; 	The calling routine must store them before calling.
;       Nor does it check if the new position still causes a collision.
;	The calling routine must do a collision check and deny the rotation
;	if there is still a collision after the "kick"
; Note: This should never be called for shape 6 as it can't collide when 
;       rotating. Kick on shape 6 is undefined.
;	1. Get the shape number
;	2. Get the orientation
;	3. Get the "pixel" which collided
;	4. For not shape5, kick based on orientation
;       5. For shape 5, use the kick table to determine which way to kick
;       Shapes can be moved up to 2 chars in any direction
kickshape:
	lda	shapno			; the type of kick depends on the shape
	; For shape 0-4, the kick is determined by the orientation
	cpi	4			; is shape <= 4
	jnc	ksnext			
	lda	shapo			; load the shape orientation
	cpi	0			; is it orientation 0
	jnz	ks1
	lxi	h,shapx			; then kick to left
	dcr	m			; decrement  shapx by 1
	jmp 	ksdone			; done. 
ks1:	cpi	1			; is orientation 1?
	jnz	ks2
	lxi	h,shapy			; then kick up
	dcr	m
	jmp	ksdone
ks2: 	cpi	2			; is it orientation 2?
	jnz	ks3
	lxi	h,shapx			; then kick right
	inr	m
	jmp	ksdone
ks3:	lxi	h,shapy			; otherwise orientation 3
	inr	m			; which needs to kick down
	jmp	ksdone			
ksnext:					; Must be shape 5 - the I shape
	mvi	b,0			; B/C used for offset into kick table
	lda 	shapo			; get the orientation
	cpi	0			
	jnz	ks51		
	lda 	clsnx			; get column which collided
	mov	c,a			; into low of BC
	lxi	h,kick1
	dad	b			; find kick value
	lda	shapx			; get shape's current x position
	add	m			; move x l/r based on kick table
	sta	shapx			; and save
	jmp	ksdone
ks51:	cpi	1			
	jnz	ks52			; Orientation 1 - as above but for y
	lda 	clsny			; get column which collided
	mov	c,a			; into low of BC
	lxi	h,kick1
	dad	b			; find kick value
	lda	shapy			; get shape's current x position
	add	m			; move y l/r based on kick table
	sta	shapy			; and save
	jmp	ksdone
ks52:	cpi	2			; Orientation 2 - either right 1 or 2 
	jnz	ks53			; or left 1
	lda 	clsnx			; get column which collided
	mov	c,a			; into low of BC
	lxi	h,kick2
	dad	b			; find kick value
	lda	shapx			; get shape's current x position
	add	m			; move x l/r based on kick table
	sta	shapx			; and save
	jmp	ksdone
ks53:					; Orientation 3 - either down 1 or 2 
					; or up 1
	lda 	clsny			; get column which collided
	mov	c,a			; into low of BC
	lxi	h,kick2
	dad	b			; find kick value
	lda	shapy			; get shape's current x position
	add	m			; move y l/r based on kick table
	sta	shapy			; and save
	; fallthrough to ksdone
ksdone:	ret				

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Shape Movement Subroutines ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; rotcw - Rotate current shape clockwise
rotcw:
	lda 	shapo			; load the shape orientation
	sta	tmp			; store the old shape orientation
					; in case have to restore
	inr	a			; inc the orientation
	cpi	4			; if orientation is 4
	jnz	rlnxt
	xra	a			; then wrap back to 0
rlnxt:	sta	shapo			; save the new orientation
	call	prepshape		; update the shape pointer
	call	collischeck		; does the rotation cause a collision
	jnc	rldraw			; if not, then draw the shape
	; Kick may change the current x/y so save them
	lhld	shapx			; load the current shape x,y
	shld	tmpptr			; and save
	call	kickshape		; try and kick the shape into a 
	call	setarenaptr		; non-colliding position
	call	collischeck		; Does it still collide after kick?
	jnc	rldraw			; if still no collision, then draw kicked version
	lda	tmp			; no kicks work, so restore old orientation
	sta	shapo
	lhld	tmpptr			; restore the old x,y
	shld	shapx			
	call	prepshape
	call	setarenaptr		; if the shape was kicked, reset the 
					; position in arena
rldraw:	call	drawshape		; redraw the shape
	ret
;
; moveleft - Move the shape 1 char to the left
movleft:
	call	eraseshape		; OPT: could erase right col of shape 
	lxi	h,shapx			; decrease shape's x position
	dcr	m
	call	setarenaptr		; update position in arena
	call	collischeck		; does it collide?
	jnc	mlnocl			; if no, jump to no collision
	lxi	h,shapx			; otherwise move back to original pos
	inr	m
	call	setarenaptr		; reset arena position
mlnocl:	call	drawshape
mlclsn:	ret

;
; moveright - Move the shape one character to the right
movright:
	call 	eraseshape		; OPT: could erase left col of shape
	lxi	h,shapx			; increase shape's x position
	inr	m
	call	setarenaptr		; recalc arena position
	call	collischeck		; does it collide
	jnc	mrnocl			; if no then jump to no collision
	lxi	h,shapx			; otherwise move back to original pos
	dcr	m
	call	setarenaptr		; OPT: we could optimize just to 
					; inc/dec arena ptr here?
mrnocl:	call 	drawshape
	ret				

;
; movdown - Move the shape down one line
; 	    and check if it collides with anything
; 	    If it collides, then don't move it and 
; 	    lock it in position
; RETURNS: CY = 0 shape not locked. 1 = shape locked
movdown:
	call	eraseshapetop		; erase the current shape (top row only)
	lxi 	h,shapy			; increment y position by 1
	inr	m			
	call	setarenaptr		; calculate the new arena pointer
	call	collischeck		; does this shape collide with anything 
					; in the arena?
	jnc	mdnocl			; if no then next
	lxi	h,shapy			; else restore position if collision
	dcr	m			
	call	setarenaptr		; recalculate the arena pointer
	call	drawshape		; redraw the shape 
	; return that a collision occurred
	xra	a
	cmc				; set carry = collision
	ret	
mdnocl:	; no collision	
	call	drawshape		; draw shape in new position
	xra	a			; clear carry = no collision
	ret

;
; collischeck - Check if the current shape/position collides with anything 
;               in the arena
; OUTPUTS: 	CY = 0 if no collision, 1 if collision
;
; DE contains a pointer to the current shape
; HL contains a pointer to the arena
; * Check current shape character until find a non-space
; * Check the corresponding arena char. If also not a space, then a collision
; * Otherwise increment to next shape position and next arena position
; * And repeat until all shape characters are checked.
;
collischeck:
	lhld 	shape		; load current shape into HL
	xchg			; and copy to DE
	lhld	araptr		; load the shape's position in the arena into HL

	mvi	b,4		; B is col counter - each shape is 4 chars wide
	mov	c,b		; C is row counter - each shape is 4 lines tall
	jmp	ccchk		; don't increment pointers on first check
ccinc: 	inx	h		; move to next arena pos
	inx	d		; move to next shape char
ccchk:	ldax	d		; get the first shape char
	cpi	' '		; if it is a space char, then ignore
	jz	ccnxt
	; otherwise there is a shape character at this location
	; check there is not an arena character  also at this location
	mov	a,m		; load the arena character
	cpi	' '		; if no arena char, then ignore
	jz	ccnxt
	jmp	cccln		; otherwise here is a collision.
				; exit function
ccnxt:	dcr	b		; decrement column counter
	jnz	ccinc		; and check next char
	mvi	b,4		; at end of column, reset
	dcr	c		; and move to next row
	jz	ccdon		; if no more rows to check, then no collision
				; done
	; need to move to next line of arena
	mov	a,c		; save the value of the row counter in A
	lxi	b,ARENADN-3	; move to next arena line minus the 4 shape cols
				; + 1 to increment to next character
	dad	b		; move HL to next arena row
	mvi	b,4		; reset the col counter
	mov	c,a		; restore the row counter
	inx	d		; move to the next shape character
	jmp	ccchk		; check the next row. 
	; Collision detected - set carry and return
cccln:	
	mov	a,b		; save which part of the shape had a collision
	sta	clsnx		; in case shape needs to be wall kicked
	mov	a,c
	sta	clsny
	xra	a		; clear carry
	cmc			; set carry to indicate collision
	ret
	; No collision - clear carry and return
ccdon:	xra	a		; clear carry to indicate no collision
	ret

;;;;;;;;;;;;;;;;;;;;;;;
;; Arena Subroutines ;; 
;;;;;;;;;;;;;;;;;;;;;;;

;
; setarenaptr - Set HL to point to the arena.
;		Store in araptr
; Loads the start of arena into HL
; Then advances pointer to the row and col co-ordinates stored
; in shapy and shapx
; The result is that araptr points to the position in the arena
; that is the top-left position of that shape in the arena.
; araptr is used when drawing or erasing shapes so that the "background"
; arena character can be output for blank areas of the shape.
; RETURNS: HL points to arena location
;	  HL stored to araptr
; OPT: This recalculates from top of arena each time.
;      Instead it would be quicker to move the pointer left/right/up/down
;      based on the direction the shape moves
setarenaptr:
	lxi 	h,arena		; load the start of arena into HL
	lxi	b,ARENADN	; Set BC to num chars to move down to next row 
	; find the row in the arena that matches the shape y pos
	lda	shapy		; get shape row
	adi	MINUSARENAY	; convert screen-coords to arena co-ords
				; note use ADI as SBI includes carry
sarow:	jz	sacol		; have we finished processing the row position?
	dad	b		; move to next arena row
	dcr	a		; decrement row count
	jmp	sarow		; keep adding until find correct row
	; find the column in the arena that maches the shape x position
sacol:	lda 	shapx		; load shape x position
	adi	MINUSARENAX	; convert screen co-ords to arena co-ords.
	mov	c,a		; and store in C. B will already be 0
	dad	b		; add the column offset.
	; HL will now contain a pointer to the top-left char in the arena
	; that matches the top-left position of the current shape
	shld	araptr		; save in araptr, so don't need to always
				; recalculate
	ret

;
; drawarena - Draw the current arena on screen
;
drawarena:
	mvi	d,ARENAY
	mvi	e,ARENAX	; Set cursor to arena display pos d = y, e = x
	call	csrpos
	mov	a,d		; a = top left col of arena (ARENAY)
	sta	tmp		; store current row nr in tmp
	lxi	h,arena		; load the first line of the arena display
daloop:	call	outstr		; output the current arena line
	lda	tmp
	inr	a
	cpi	ARENAH+ARENAY+2	; have we drawn all the lines? ARENA height + y 
				; screen offset
	jz	dadone		; if so, done?
	sta	tmp		; store current line nr to tmp
	inx	h		; relies on outstr leaving HL are the string 
				; null char
	mov	d,a		; set row to current screen row
	mvi	e,ARENAX	; set col to ARENAX 
	push	h		; save string position
	call	csrpos		; move to next line
	pop	h		; restore string position
	jmp	daloop
dadone:	ret
;
; drawarenaline - draw a single line of the arena 
; INPUTS: HL = pointer to start of line to draw
; 	  D = arena row number to draw
; Note: Converts arena co-ords to screen co-ords
drawarenaline:
	mvi	e,ARENAX	; E = column (ARENAX), D already contains row
	mov	a,d
	adi	ARENAY		; add the arena screen top position
	mov	d,a		; to convert to screen co-ords
	push	h
	call	csrpos		; set cursor to correct row/col
	pop	h
	call	outstr
	ret

;
; cleararena - Reset the arena. 
;              Remove all shapes and return to initial state
;
cleararena:
	lxi 	h,arena+2	; HL = first shape char in arena
	mvi	c,ARENAH	; c = row counter
	mvi	b,ARENAW	; d = col counter
	mvi	a,' '		; a = blank
	lxi	d,5		; DE chars to skip are end of arena line
				; 2x side + 2x space + null
caloop:	mov	m,a		; blank out the arena char
	dcr	b
	inx	h		; move to next char
	jnz	caloop		; for each char in row
	dad	d		; increment h to start of next row
	mvi	b,ARENAW	; reset width
	dcr	c		; dec row counter
	jnz	caloop
	ret

;
; checkrows - Check each row to see if it is filled.
; 	      Change the the filled rows to '-' and count the number
;             of cleared rows
; OUTPUT:     nrclr = number of full rows found
checkrows:
	xra	a		; a = 0
	mov	d,a		; d = 0
	sta	nrclr		; mark number of cleared rows as 0
	lxi	h,arena+2	; load pointer to the first arena shape char 
crckrw:	lxi	b,ARENAW	; BC is loop counter for each char in row
	mvi	a,' '
crchk:	cmp	m		; is this arena char a space?
	jz	crnxrw		; If so, not a full line, so check next row
	inx	h
	dcr	c		; Note: dcr (not dcx) to set Z flag
	jnz	crchk		; if more chars, check next char
	; If ran out of chars to check on this line, then it is a full line
	; mark it will '-'s
crfuln:	lda	nrclr		; nrclr++
	inr	a
	sta	nrclr
	lxi	b,-ARENAW	; jump back to start of line
	dad	b
	lxi	b,ARENAW	; restore the BC column counter	
	mvi	a,'-'		; '-' is the char displayed when line is full
	; now loop aver each char in row and replace with '-'
crmark:	mov	m,a		; copy '-' into arena
	inx	h
	dcr	c		; are we at end of row?
	jnz	crmark		; if no, keep copying
	; Now we want to redisplay this line of the arena
	; so the '-' are output to the user
	push	h		; save registers
	push	b
	push	d
	lxi	b,-(ARENAW+2)	; go back to start of arena line
	dad	b
	call	drawarenaline	; redraw the arena line
	pop	d		; restore registers
	pop	b
	pop	h
	; fall through to crnxrw
	; row count in BC should be 0
crnxrw:	dad	b		; add what is remaining of the row count
	lxi	b,5		;side,spc,null,spc,side = 5. TODO: Make const
	dad	b
	inr	d		; row counter ++
	mvi	a,'='		; '-' means we are at bottom of arena
	cmp	m		; if at bottom, then done
	jz	crscor
	jmp	crckrw		; otherwise check the next row
	; calculate the score
crscor:	lda	nrclr		; how many lines were cleared?
	ora	a		; set status flags
	jz	crdone		; no rows cleared?, then done
	call	calcscore	; otherwise calculate the score
crdone:	
	ret

;
; dropwrows - Erase full rows and drop down existing rows
; Note: Only call this if at least 1 row needs to be dropped.
;
; Starts on last arena row and move upwards
; rowsrc is used as pointer to source row to copy from
; rowdst is used as pointer to dest row to copy to
; Starts at the last arena row.
; If that row is '-' then keep dst row the same, 
;  	move src row one line up and don't copy anything.
; Otherwise check if we're previously found a '-' row.
;	If we have then copy from src to dst
;	If not then move src and dst up one row.
; This basically means that dst stays on the '-' line until it is copied into
; and src is always decremented one row
; 
droprows:
	lxi	h,arena+ARENALST; move to first shape col on last arena line
	shld	rowdst		; init copy dst to last row
	shld	rowsrc		; init copy src to last row
	mvi	b,ARENAH	; keep track of the arena row number
	mvi	a,0
	sta	nrclr		; zero out number of cleared lines
drcmp:	mvi	a,'-'		
	cmp	m		; if first char is a '-' then just dec the src ptr
	jnz	drnxt
	lxi	h,nrclr		; increment number of 'cleared' lines
	inr	m
	jmp	drdecs		; until find a non-'-' row
drnxt:	lda	nrclr		; check if we have already found cleared lines
	ora	a		; if nrclr > 0 then need to copy src to dst
	jz	drdecd		; otherwise skip the copy and dec src and dst 
	call	copyrow	
drdecd:	lxi	d,-ARENADN	; move src and dst back one row each
	lhld	rowdst
	dad	d		; position at first char 1 line up
	shld	rowdst		
drdecs:	lxi	d,-ARENADN	; need to set this again in case only decing src
	lhld	rowsrc
	dad	d
	shld	rowsrc		; LH now set to the first char of the next row
				; to check
	dcr	b		; dec the row number
	jz	drtop		; finish process top lines of arena
	jmp	drcmp		; compare the next line
drtop:	; reached the top of the arena, so no more src rows to copy
	; set the src to an all blank row
	lxi	h,nrclr	
	mov	b,m		; nrclr = number of cleared out rows
				; so we need to blank the top nrclr rows
				; to fill in the 'missing' rows at the top
	lxi	h,blnkrw	; row contains all blanks
	shld 	rowsrc
	; rowdst has already already points to correct dst row
	; when we get here.
drtopl:	call	copyrow		; copy blank into destination
	lxi	d,-ARENADN	
	lhld	rowdst		; move dst to prev arena row
	dad	d
	shld	rowdst
	dcr	b
	jnz	drtopl		; keep copying until nrclr rows are blanked
	; done with all the copying
	lxi	h,nrclr		; nrclr = 0
	mvi	m,0
	call	drawarena	; redraw the whole arena
	ret
;
; copyrows - copy a row of arena chars from src to dst 
; INPUT: rowsrc, rowdst
; PRESERVES:	b
copyrow:
	lhld	rowsrc		; load src into DE
	xchg
	lhld	rowdst		; load dst into H
	mvi	c,ARENAW	; C = char counter
crloop:	ldax	d		; copy src char
	mov	m,a		; store in dst
	dcr	c		; dec char counter
	inx	d		; inc src ptr
	inx	h		; inc dst ptr
	jnz	crloop
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input / Output Subroutines ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; inputdelay - Process user input while delaying until next "tick"
;		delay speed is variable based on the number of
;               previously locked shapes
;		Handles left, right, rotate, down and drop
inputdelay:
	xra	a		; a = 0
	mov	b,a		; b = 0
	lxi	h,speed		; outer wait loop
	mov	c,m		; c = speed
idwait:	inr	b		; inner wait loop
	jnz	idwait		; wait 255 loop cycles
	inr	c
	jz	iddone
	call 	inch		; get a char
	call	toupper
	jz	idwait		; return to waiting if no char
	cpi	'W'		; W = rotate clockwise
	jnz	id1
	push	b		; save current loop counters
	call	rotcw
	pop	b
	jmp	idwait
id1:	cpi	'A'		; A = move left
	jnz	id2
	push	b
	call 	movleft	
	pop	b
	jmp	idwait
id2:	cpi	'D'		; D = move right
	jnz	id3
	push	b
	call	movright
	pop	b
	jmp	idwait
id3:	cpi	'S'		; S = move down
	jnz	id4		
	push	b
	call	addsdscore	; add to score for soft-drop
	call	movdown
	pop	b
	jc 	idcoll		; if collision then done
	jmp	inputdelay	; otherwise process next key
id4:	cpi	' '		; hard-drop
	jnz	id5
idhdrp:	call	movdown
	jc	idcoll
	call	addhdscore	; increment the hard-drop score
	inr	c
	mvi	b,0		; drop at fastest speed the pieces
idhdwt:	inr	b		; could ever drop in game
	jnz	idhdwt		; only use inner wait loop
	jmp	idhdrp		; drop until collision
id5:	jmp	idwait		; if key not recognised, then continue to wait
				; for key or delay to expire
idcoll:	ret			; carry set if collision detected
iddone:	xra	a		; clear the carry to indicate no collision
	ret

;
; delay - delay for half a cycle. Don't process input
;         Primarily used as a small delay for to display a row clear
;         before dropping down the non-cleared lines
;
delay:
	xra	a		; clear carry
	mov	b,a		; b = 0
	lda	speed
	rar
	mov	c,a		; c = speed / 2
dlwait:	inr	b		; inner wait loop
	jnz	dlwait		; wait 255 loop cycles
	inr	c
	jnz	dlwait
	ret

;
; Output string to serial port
; HL: zero-terminated string to be output
;
	IF      DAZZLER-1
outstr:				
	ENDIF	
outstrsio:			; outstrsio used in DAZZLER verions to output
				; to SIO, rather than DAZZLER vram
	in 	SIOSTAT		; read serial status
	ani	SIOREADY	; is ready to send character?
	jz	outstrsio	; try again if not ready
	mov	a,m		; get char to output
	cpi	0
	jz	ossret		; done if 0 terminator
	out	SIODATA		; output char
	inx	h		; move to next char
	jmp	outstrsio
ossret:	ret

	IF	DAZZLER
; outstr - Output pixels to the vram.
; This converts the serial port characters to coloured pixels on the dazzler.
; It doesn't output text
; Doesn't handle wrapping to next line.
; TODO: does this need to preserve anything?
outstr:
        xchg                    ; DE = ptr to output string
        lhld    vrptr           ; load pointer to vram into HL
osloop: ldax    d               ; get the char to output
        ora     a               ; set Z flag
        jz      osdone          ; If null then done.
        call    convert2daz     ; convert the character to dazzler
        mov     b,a             ; save to b (not this has char stored in both nibbles)
        lda     vrmask
        cpi     0fh             ; bottom nibble?
        jnz     ostop
        ana     b               ; get bottom nibble
        mov     b,a             ; save
        mvi     a,0f0h          ; swap nibble mask
        sta     vrmask
        ana     m               ; get top nibble from vram
        ora     b               ; merge with top nibble of new pixel
        mov     m,a             ; and save to vram
        inx     d               
        jmp     osloop          ; next char
ostop:  ana     b               ; same as above, but for other nibble
        mov     b,a
        mvi     a,0fh
        sta     vrmask
        ana     m
        ora     b
        mov     m,a             ; top nibble is 2nd pixel. 
        inx     h               ; so need to increment to vramptr.
        inx     d
        jmp     osloop
osdone: shld    vrptr           ; save current vram ptr.
        xchg                    ; outstr needs to return HL to end of string
        ret

;
; convert2daz - Convert a character to a coloured pixel.
;		clrtbl variable contains the mappings between chracters and
;		colours.
;		If the mapping between the input character and colour is 
;               not found, use a default value (last colour in clrtbl)
; INPUTS:  A - Character to convert
; OUTPUTS: A - DAZZLER pixel colour 
;               returns same value in top/bottom nibble. Calling 
;               function needs to determine the correct nibble to use
convert2daz:
	push	h
	push	b
	mvi	c,NRCLRS	; C = nr colours to search for in the table
	lxi	h,clrtbl	; HL = pointer to colour lookup table
c2dfnd:	mov	b,m		; format of table is ascii char, colour
	cmp	b		; is this the right char?
	jz	c2dok		
	dcr	c
	jz	c2dok		; colour 16 is the "default colour"
	inx	h		; move to next table character		
	inx	h
	jmp	c2dfnd		; find next char
c2dok:	inx	h		; get the colour from the table
	mov	a,m		; and replace A with the colour
	pop	b		; restore saved registers
	pop	h
        ret
	ENDIF

;
; Output single character to serial port
; B: char to be output
;
	IF	DAZZLER - 1
outch:
	ENDIF
outchsio:			; Used in DAZZLER version to output to SIO
	in 	SIOSTAT		; read serial status
	ani	SIOREADY	; is ready to send character (bit 1 set)?
	jz	outchsio	; try again if not ready
	mov	a,b		; restore the char to output
	out	SIODATA		; output char
	ret

	IF	DAZZLER
;
; Output single pixel to dazzler
; B: char to be output
; Note does not wrap to next line
;
outch:	push    h               ; need to save HL to be compatibile 
				; with serial version
        lhld    vrptr           ; load pointer to vram into HL
ocloop: mov     a,b             
        call    convert2daz     ; convert the character to dazzler
				; note top and bottom nibble contain converted
				; character
        mov     b,a             ; save to b
        lda     vrmask
        cpi     0fh             ; bottom nibble?
        jnz     octop
        ana     b               ; get bottom nibble
        mov     b,a             ; save
        mvi     a,0f0h          ; swap nibble mask
        sta     vrmask
        ana     m               ; get top nibble from vram
        ora     b               ; merge with top nibble of new pixel
        mov     m,a             ; and save to vram
        jmp     ocdone          ; done
octop:  ana     b               ; same as above, but for other nibble
        mov     b,a
        mvi     a,0fh
        sta     vrmask
        ana     m
        ora     b
        mov     m,a             ; top nibble is 2nd pixel. 
        inx     h               ; so need to increment to vramptr.
        shld    vrptr           ; save current vram ptr.
        ; fallthrough
ocdone: pop     h               
        ret
	ENDIF
;
; inch - Read a char from serial.
; Returns: A = 0 if no char. A = ch if char
inch:	in	SIOSTAT		; read serial status
	ani	SIOAVAIL	; is there an input char? (bit 0 set)
	jz	noch
	in	SIODATA		; get the char
noch:	ret			; A will be 0 if no char

;
; inflush - Flush out the serial input
;
inflush:
	in	SIOSTAT		; keep reading until 
	ani	SIOAVAIL	; no input chars to read
	jz	ifdone
	in	SIODATA		; get the char
	jmp	inflush
ifdone:	ret



;
; csrpos - Set cursor to position in D, E (row, col)
; Note: current only supports a 24x24 screen
;	D,E of 0,0 is output as 1,1 as screen home is 1,1
;
; Takes the passed in row/col and uses that as an index into the xh2dec 
; conversion table.
; The converted value is written to the relevant row/col parts of the 'csr' 
; string variable before being output on the serial port to position the cursor
;

        IF      DAZZLER-1
csrpos:
	ENDIF
csrpossio:			; Used by DAZZLER version to set vt100 
				; cursor position, instead of DAZZLER vram pos
	xra	a		; zero a, clear carry
	; first translate the row to ascii value
	; via hx2dec translation table
	mov	b,a		; zero b as we are only adding 8 bits
	mov	c,d		; get the row
	lxi	h,hx2dec	; load index to hex->dec conversion table
	dad	b		; find offset into table
	dad	b		; add twice to cal the offset in the table
	mov	b,m		; get the first ascii char of the row
	inx	h
	mov	c,m		; get the second ascii char of the row
	lxi	h,csr+2		; load address of cursor row out
	mov	m,b		; save 1st char of row
	inx	h
	mov	m,c		; save 2nd char of row
	; now do the column
	xra	a		; make sure carry is zero
	mov	b,a		; same logic as above, just for register E
	mov 	c,e
	lxi	h,hx2dec	 
	dad	b
	dad	b
	mov 	b,m
	inx 	h
	mov	c,m
	lxi	h,csr+5		; start of the 'col' component of the csr string
	mov 	m,b		; save 1st char of col
	inx	h
	mov	m,c		; save 2nd char of col
	; now output the formatted csr move string
	lxi 	h,csr		; load the cursor position command
	call	outstrsio	; and output it 
	ret

	IF 	DAZZLER
;
; csrpos - Set cursor to position in D, E (row, col)
; Note: current only supports a 24x24 screen
;	D,E of 0,0 is output as 1,1 as screen home is 1,1
;
; Save pointer to VRAM that equals the equivalent vt100 cursor position
; Needs to preserve D to be compatible with serial version
csrpos:
        push    d
        lxi     h,vram
        lxi     b,16            ; move down 16 bytes for each row 
        inr     d               ; inc/dec to set the Z flag
cposy:  dcr     d
        jz      cposx           ; Add 16 for each row
        dad     b
        jmp     cposy           ; until done
cposx:  mov     a,e             ; A = X position
        ora     a               ; reset carry
        rar                     ; each vram byte contains 2 pixels. Divide x by 2
                                ; carry will contain the bottom bit, which indicates
                                ; whether top or bottom nibble is used for the current pixel
                                ; bottom nibble is pixel 0, top nibble is pixel 1
        jc     cptop            ; If there was carry from the RRC, then we are 
        mov     c,a             ; B will already be 0
        dad     b               ; add X/2
                                ; on top half of the vram byte (odd pixel)
        mvi     a,0fh          	; set mask to bottom nibble
        jmp     cpdone
cptop:  mov     c,a             ; B will already be 0  
        dad     b               ; add X/2
	mvi     a,0f0h          ; set mask to top nibble
cpdone: sta     vrmask          ; store mask
        shld    vrptr           ; save pointer to vram location for cursor pos
        pop     d
        ret
	ENDIF
;
; displaycontrols - Display control help before game
;
displaycontrols:
	lhld	ctrlxy			; position to display game controls
	xchg				; D = Y pos ; E = x pos
	call	csrpossio		; move cursor
	lxi	h,controls
dcloop:	xra	a			; A = 0
	cmp	m			; if null string, then end
	jz	dcdone
	call	outstrsio		; output first line. DE preserved
	inr	d			; move y down one line
	push	h
	call	csrpossio
	pop	h
	inx	h			; H will be on the prev string null char
					; this moves HL to next string
	jmp	dcloop
dcdone:	ret

;;;;;;;;;;;;;;;;;;;;;;;
;; Score Subroutines ;;
;;;;;;;;;;;;;;;;;;;;;;;

;
; calcscore - calculate the score from line clears
; INPUTS:     A = nr cleared lines
calcscore:
	lxi	h,scrtbl-2	; index into score table to find how much to add
	mvi	b,0
	mov	c,a
	dad	b		; HL = scrtbl + 2 * (nrclr - 1)
	dad	b
	mov	b,m		; c = high bcd byte of score to add
	inx	h
	mov	c,m		; b = low bcd byte of score to add
	lxi	h,score		; get current score h = score
	mov	a,m		; load low byte of score to A
	add	c		; add low byte of score
	daa			; do the bcd adjustment
	mov	m,a		; and save
	inx 	h
	mov	a,m		; get the next bcd byte of score
	adc	b		; add the next bcd byte of score to add
	daa			; bcd adjust
	mov	m,a		; and save
	inx	h		; get last bcd byte of score
	mvi	a,0		; add zero to last score digit to cater for CY
	adc	m
	mov	m,a		; and save
	lxi	h,updscr	; flag score for update
	inr	m
	ret
;
; addhdscore - Add to score for each hard-drop row
;
addhdscore:
	mvi	a,HDSCORE
	jmp	addscore

; addsdscore - Add to score for each soft-drop row
;
addsdscore:
	mvi	a,SDSCORE
	jmp	addscore
;
; Increment the score for soft/hard drop
;
; INPUTS A - score to add
addscore:
	lxi	h,score
	add	m
	daa
	mov	m,a		; add the score
	inx	h
	mvi	a,0		; process the carries
	adc	m
	daa
	mov	m,a		; for the next score bcd bytes
	inx	h
	mvi	a,0
	adc	m
	daa
	mov	m,a
	lxi	h,updscr	; flag score for update
	inr	m		
	ret

;
; displayscore - Display the current score
; SIO version
	IF 	DAZZLER-1
displayscore:
	lhld	scoryx
	xchg
	call	csrpossio
	lxi	h,score+2		; load first digits of score
	mvi	c,3			; score is 3 bcd bytes
dsnxt:	mov	a,m
	ani	0f0h			; get first digit of score
	rrc				; move high nibble to low nibble
	rrc
	rrc	
	rrc
	adi	'0'			; convert to ascii
	mov	b,a
	call	outchsio		; print it
	mov	a,m
	ani	0fh			; get lower nibble
	adi	'0'			; convert to ascii
	mov	b,a			; outch uses reg B
	call	outchsio
	dcx	h			; move to next score byte
	dcr	c
	jnz	dsnxt
	ret
	ENDIF
	IF	DAZZLER
;
; displayscore - Display the current score on DAZZLER
;
displayscore:
	lxi	d,0002h		; first score char top/left
	lxi	h,score+2
	mov	a,m
	ani	0f0h		; get first digit of score
	rrc			; move high nibble to low nibble
	rrc			
	rrc
	rrc
	call	dspscoredigit	; display

	; 2nd digit
	lxi	d,0007h		; 2nd score digit top left
	lxi	h,score+2
	mov	a,m
	ani	0fh		; get bottom nibble
	call	dspscoredigit

	; 3rd digit
	lxi	d,000Ch		
	lxi	h,score+1	; next bcd byte
	mov	a,m
	ani	0f0h		
	rrc			
	rrc			
	rrc
	rrc
	call	dspscoredigit	

	; 4th digit
	lxi	d,0011h		
	lxi	h,score+1	
	mov	a,m
	ani	0fh		
	call	dspscoredigit

	; 5th digit
	lxi	d,0016h		
	lxi	h,score		; next bcd byte
	mov	a,m
	ani	0f0h		
	rrc			
	rrc			
	rrc
	rrc
	call	dspscoredigit	

	; 6th digit
	lxi	d,001Bh		
	lxi	h,score
	mov	a,m
	ani	0fh		
	call	dspscoredigit

	ret


; dspscoredigit - display a digit of the score on the DAZZLER
; INPUTS - DE row,col to display at
;        - Score digit to display
dspscoredigit:
	lxi	h,scr0		; init pointer to digit '0'
	lxi	b,4*5		; BC = num bytes in a score digit
	ora	a		; Set Z flag
dsdadd:	jz	dsdrw		; once found correct digit, draw it
	dad	b
	dcr	a
	jmp 	dsdadd		; get offset to next digit
dsdrw:	mvi	c,5		; 5 lines in each digit
dsdlp:	push	b		; save row counter
	push	h		; save digit pointer
	call	csrpos		; position cursor to DE
	pop	h		; restore digit pointer
	push	d		; store cursor pos
	call	outstr		
	pop	d		; restore cursor pos
	pop	b		; restore row counter
	dcr	c		; decrement row counter
	jz	dsddne
	inx	h		; get next score char
	inr	d		; move cursor to next line
	jmp	dsdlp		; draw next line
dsddne:	ret			; digit drawn
	ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;
;; Utility Subroutines ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

; toupper - Convert lowercase char to upper case
; 
; INPUTS A - char to convert
; OUTPUTS A - converted char
;
toupper:
	cpi	'a'			; is char <= 'a'
	jc	tudone			; if so done
	cpi	'z'			; is char > 'z'
	jnc	tudone			; if so, done
	sbi	'a'-'A'-1		; convert
tudone:	ret	


;					
; random - Generate an 8 bit random number
; Based on code by Patrik Rad
; https://worldofspectrum.org/forums/discussion/23070
; Output: A = random number
; Seeds can be anything, except 0
seed1:	dw	0A281h
seed2:	dw	0C0DEh

random:
	lhld	seed2
	xchg
	lhld	seed1
	mov	a,h		; t = x ^ (x << 1)
	add	a
	xra	h
	mov	h,l		; x = y
	mov	l,d		; y = z
	mov	d,e		; z = w
	mov	e,a
	rar			; t = t ^ (t >> 1)
	xra 	e
	mov	e,a
	mov	a,d		; w = w ^ (w << 3) ^ t
	add	a
	add	a
	add	a
	xra	d
	xra	e
	mov	e,a
	shld	seed1
	xchg
	shld	seed2
	ret

	IF	DAZZLER
;;;;;;;;;;;;;;;;;;;;;;;;;
;; DAZZLER Subroutines ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

; vram is laid out from top-left to bottom right.
; Each pixel is contained in 4 bits, with the format
; 3 = Intensity, 2 = Red, 1 = Greem, 0 = Blue 
; Bits 0-4 are for the first pixel and 5-7 are for the second pixel.
;
; The variable vrptr is used to keep track of where the current "cursor" pos
; with the variable vrmask, telling us whether the cursor points to the
; top or bottom nibble of the byte pointed to by vrptr.
;
; This provides a simple way to treat the DAZZLER vram like it is a vt100 
; terminal. 
; The clrtbl variable is used to map characters that would normally be output to
; the serial/vt100 to different colours.

; dazinit - Initialise the DAZZLER 
;         - Init to 32x32 (512k)
dazinit:
	call    clrvideo        ; Clear dazzler video ram
	mvi     a,000010000b    ; Normal Res, colour mode
	out     17o
	mvi     a,VIDEO / 512   ; Set video ram location
				; VIDEO >> 9 (/512 used for asm compatibility)
	ori     80h             ; Set dazzler to "on"
	out     16o             ; out to dazzler control reg
        lxi     h,vram
        shld    vrptr           ; init vram pointer to start of vram
        mvi     a,0fh           ; set mask to bottom nibble (first pixel)
        sta     vrmask
        ret

;
; clrvideo - Clear 2 x 256 bytes = 512 bytes of video ram
;
clrvideo:
	xra     a               ; a = 0
	lxi     h,vram
	lxi     b,2             ; B = 0 ; C = 2
cvloop: mov     m,a             ; clear byte
	inx     h               ; next byte
	inr     b
	jnz     cvloop          ; clear 1x256 bytes
	dcr     c
	jnz     cvloop          ; Repeat 
	ret
	ENDIF

	IF	DEBUG
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Unused Debug / Helper Routines ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; drawall - test drawing all shapes and all rotations
drawall:
	call	drawarena
	mvi	a,0
	sta	shapno
        lxi     h,SPAWNYX
        shld    shapx
	call	setarenaptr	; set pointer to current shape location in arena
draloop:
	call 	prepshape
	call 	drawshape
	call	inputdelay

	call	rotcw
	call	drawshape
	call 	inputdelay
	
	call	rotcw
	call	drawshape
	call 	inputdelay

	call	rotcw
	call	drawshape
	call 	inputdelay
	
	lda	shapno
	inr	a
	cpi	7
	jz	dradone
	sta	shapno
	jmp	draloop
dradone:	ret

;
; dbgspeed - show current speed
;
dbgspeed:
	lxi	d,0100h		; show at row 1, col 0
	call	csrpos
	lda	speed
	mov	c,a
	ani	0f0h
	rrc
	rrc
	rrc
	rrc
	adi	'0'
	mov	b,a
	call	outch
	mov	a,c
	ani	0fh
	adi	'0'
	mov	b,a
	call	outch
	ret
;
; Print out 255 random numbers
;
testrandom:
	xra 	a
	sta 	tmp
rloop:
	lda	tmp
	dcr	a
	jz	done
	sta	tmp
	call	random
	mov	c,a
	ani	07
	adi	'0'
	mov	b,a
	call	outch
	mvi	b,' '
	call 	outch
	jmp	rloop
	ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;
;; START OF VARIABLES ;;
;;;;;;;;;;;;;;;;;;;;;;;;
tmp:	dw	0		
tmpptr:	dw	0
speed:	db	SPEEDINIT	; Initial block drop speed. Bigger = faster
scrstr:	db	' SCORE: ',0
scoryx:	dw	0007h		; col,row position of the score
score:	db	0,0,0		; 6 bcd chars. low byte to high byte
blnkrw:	db	'          '	; a full blank arena row
anyyx:	dw	1701h		; 23, 1
anystr:	db	'PRESS ANY KEY',0
updscr:	db	0		; should the score be updated?
; vt100 codes
clr:	db	27,'[2J',0	; clear screen
invis:	db	27,'[?25l',0	; invisible cursor
vis:	db	27,'[?25h',0	; visible cursor
csr:	db	27,'[ll;ccH',0	; move cursor to line,col
bw4:	db	27,'[4D',0	; move back 4 characters
dwn:	db	27,'[1B',0	; move down 1 line
	; lookup table for cursor positioning (csr)
	; Used to translate binary position to ascii
	; position required by vt100
hx2dec:	db	'01','02','03','04','05','06'
	db	'07','08','09','10','11','12'
	db	'13','14','15','16','17','18'
	db	'19','20','21','22','23','24'
	; scores in bcd
	; a full hard drop = ~ 40 points if 2 points per row
scrtbl:	db	02h,00h		; 200 points for 1 line clear
	db	05h,00h		; 500 points for a 2 line clear +300
	db	09h,00h		; 900 points for a 3 line clear +400
	db	14h,00h		; 1400 points for a 4 line clear +500
; Kick tables for kickshape subroutine when moving shape 5 (I shape)
; As and example if collision is on col 0 in
; orientation 2, then move right 2
; In this case I shape is against left wall, 1 away from or on right wall
; Note: Collision is calculated from right-side of shape and is 1 based, 
; so tables are backward to what you would normally expect
; Note: CPM doesn't allow -ve values in db. Using 255=-1, 254=-2 instead
kick1:	db	0,255,254,0,1	; kicks for orientation 0 and 1
kick2:	db	0,255,0,1,2	; kicks for orientation 2 and 3

shape:	dw	zshape		; pointer to current shape to draw
shapno:	db	0		; the number of the shape to draw
; shapx and shapy are relative to the top of the arena, not screen
; they can be loaded as a 16 bit pair, so shapx 
; must be located immediately before shapy
shapx:	db	0		; x position of the shape
shapy:	db	0		; y position of the shape
shapo:	db	0		; shape orientation
clsnx:	db	0		; x co-ord of the collision within the shape
clsny:	db	0		; y co-ord of the collision within the shape
araptr: dw	0		; pointer to the top left arena position 
				; matching the shape position
nrclr:	db	0		; number of full rows cleared this turn
rowsrc:	dw	0		; source row for droprows
rowdst:	dw	0		; destination row for droprows

shaptbl:	; pointer the first orientation of each shape
	dw	zshape, sshape, lshape, jshape
	dw	tshape, ishape, oshape

	; Tetromino definitions for each orientation
	IF ALTSHAPECHARS - 1	
zshape:		
z1:
	db	'##  '
	db	' ## '
	db	'    '
	db	'    '
		
z2:		
	db	'  # '
	db	' ## '
	db	' #  '
	db	'    '
		
z3:		
	db	'    '
	db	'##  '
	db	' ## '
	db	'    '
z4:		
	db	' #  '
	db	'##  '
	db	'#   '
	db	'    '
sshape:		
s1:	db	' ** '
	db	'**  '
	db	'    '
	db	'    '
s2:		
	db	' *  '
	db	' ** '
	db	'  * '
	db	'    '
s3:		
	db	'    '
	db	' ** '
	db	'**  '
	db	'    '
s4:		
	db	'*   '
	db	'**  '
	db	' *  '
	db	'    '
lshape:		
l1:		
	db	'  @ '
	db	'@@@ '
	db	'    '
	db	'    '
l2:		
	db	' @  '
	db	' @  '
	db	' @@ '
	db	'    '
l3:		
	db	'    '
	db	'@@@ '
	db	'@   '
	db	'    '
l4:		
	db	'@@  '
	db	' @  '
	db	' @  '
	db	'    '
jshape:		
j1:		
	db	'+   '
	db	'+++ '
	db	'    '
	db	'    '
j2:		
	db	' ++ '
	db	' +  '
	db	' +  '
	db	'    '
j3:		
	db	'    '
	db	'+++ '
	db	'  + '
	db	'    '
j4:		
	db	' +  '
	db	' +  '
	db	'++  '
	db	'    '
tshape:		
t1:		
	db	' X  '
	db	'XXX '
	db	'    '
	db	'    '
t2:		
	db	' X  '
	db	' XX '
	db	' X  '
	db	'    '
t3:		
	db	'    '
	db	'XXX '
	db	' X  '
	db	'    '
t4:		
	db	' X  '
	db	'XX  '
	db	' X  '
	db	'    '
ishape:		
i1:		
	db	'    '
	db	'HHHH'
	db	'    '
	db	'    '
i2:		
	db	'  H '
	db	'  H '
	db	'  H '
	db	'  H '
i3:		
	db	'    '
	db	'    '
	db	'HHHH'
	db	'    '
i4:		
	db	' H  '
	db	' H  '
	db	' H  '
	db	' H  '
oshape:		
o1:		
	db	' OO '
	db	' OO '
	db	'    '
	db	'    '
o2:		
	db	' OO '
	db	' OO '
	db	'    '
	db	'    '
o3:		
	db	' OO '
	db	' OO '
	db	'    '
	db	'    '
o4:		
	db	' OO '
	db	' OO '
	db	'    '
	db	'    '
	ENDIF
	IF ALTSHAPECHARS 
zshape:		
z1:		
	db	'##  '
	db	' ## '
	db	'    '
	db	'    '
		
z2:		
	db	'  # '
	db	' ## '
	db	' #  '
	db	'    '
		
z3:		
	db	'    '
	db	'##  '
	db	' ## '
	db	'    '
z4:		
	db	' #  '
	db	'##  '
	db	'#   '
	db	'    '
sshape:		
s1:	db	' ## '
	db	'##  '
	db	'    '
	db	'    '
s2:		
	db	' #  '
	db	' ## '
	db	'  # '
	db	'    '
s3:		
	db	'    '
	db	' ## '
	db	'##  '
	db	'    '
s4:		
	db	'#   '
	db	'##  '
	db	' #  '
	db	'    '
lshape:		
l1:		
	db	'  # '
	db	'### '
	db	'    '
	db	'    '
l2:		
	db	' #  '
	db	' #  '
	db	' ## '
	db	'    '
l3:		
	db	'    '
	db	'### '
	db	'#   '
	db	'    '
l4:		
	db	'##  '
	db	' #  '
	db	' #  '
	db	'    '
jshape:		
j1:		
	db	'#   '
	db	'### '
	db	'    '
	db	'    '
j2:		
	db	' ## '
	db	' #  '
	db	' #  '
	db	'    '
j3:		
	db	'    '
	db	'### '
	db	'  # '
	db	'    '
j4:		
	db	' #  '
	db	' #  '
	db	'##  '
	db	'    '
tshape:		
t1:		
	db	' #  '
	db	'### '
	db	'    '
	db	'    '
t2:		
	db	' #  '
	db	' ## '
	db	' #  '
	db	'    '
t3:
	db	'    '
	db	'### '
	db	' #  '
	db	'    '
t4:		
	db	' #  '
	db	'##  '
	db	' #  '
	db	'    '
ishape:		
i1:		
	db	'    '
	db	'####'
	db	'    '
	db	'    '
i2:		
	db	'  # '
	db	'  # '
	db	'  # '
	db	'  # '
i3:		
	db	'    '
	db	'    '
	db	'####'
	db	'    '
i4:		
	db	' #  '
	db	' #  '
	db	' #  '
	db	' #  '
oshape:		
o1:		
	db	' ## '
	db	' ## '
	db	'    '
	db	'    '
o2:		
	db	' ## '
	db	' ## '
	db	'    '
	db	'    '
o3:		
	db	' ## '
	db	' ## '
	db	'    '
	db	'    '
o4:		
	db	' ## '
	db	' ## '
	db	'    '
	db	'    '
	ENDIF	
	; The arena. 10 x 20 blocks
	; arena padded by space to left, right and below
	; as blank parts of shapes can be drawn outside the arena.
	; Shapes need a 2 char buffer, which is the side (or bottom) 
	; plus an additional space or blank line
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
	db	' [==========] ',0
	db	'              ',0	; shape can extend 1 below the arena
;
; Display game controls at start of game
;
ctrlxy:	db 02,04
controls:
	db	' CONTROLS',0
	db	' --------',0
	db	' ',0
	db	'W - ROTATE',0
	db	'A - RIGHT', 0
	db	'D - LEFT', 0
	db	'S - DOWN', 0
	db	'<SPACE>',0
	db	'  - FAST',0
	db	'    DROP',0
	db	' ',0
	db	' ',0
	db	'PRESS: ',0
	db	'S - START',0
	db	'Q - QUIT',0
	db	0

	IF	DAZZLER
; DAZZLER Variables
vrptr   dw      0               ; "cursor" position into VRAM
vrmask: ds      0fh             ; bottom nibble is first pixel

; DAZZLER Colour table for converting ascii chars to colours
;Shape	Char	ASCII		IRGB	Binary	Hex		
;Z	#	35		1001	10011001	99		35,099h
;S	*	42		1010	10101010	AA		42,0AAh
;L	@	64		1011	10111011	BB		64,0BBh
;J	+	43		1100	11001100	CC		43,0CCh
;T	X	88		1101	11011101	DD		88,0DDh
;I	H	72		1110	11101110	EE		72,0EEh
;O	O	79		0001	00010001	11		79,011h
;N/A	<spc>	60		0111	01110111	77		60,077h
;N/A	-	45		0111	01110111	77		45,077h
;N/A	S	83		0010	00100010	22		83,022h
;deflt	$	36		1111	11111111	FF		36,0FFh
; NOTE: Change NRCLRS if adding / removing from the colour table
clrtbl:	db	35,099h,42,0AAh,64,0BBh,43,0CCh
	db	88,0DDh,72,0EEh,79,011h,32,077h
	db	45,077h,83,022h,120,000h,36,0FFh

	; Score characters - S = foureground colour, x = background colour
scr0:		
	db	'SSS',0
	db	'SxS',0
	db	'SxS',0
	db	'SxS',0
	db	'SSS',0
scr1:		
	db	'xSx',0
	db	'xSx',0
	db	'xSx',0
	db	'xSx',0
	db	'xSx',0
scr2:		
	db	'SSS',0
	db	'xxS',0
	db	'SSS',0
	db	'Sxx',0
	db	'SSS',0
scr3:		
	db	'SSS',0
	db	'xxS',0
	db	'SSS',0
	db	'xxS',0
	db	'SSS',0
scr4:		
	db	'SxS',0
	db	'SxS',0
	db	'SSS',0
	db	'xxS',0
	db	'xxS',0
scr5:		
	db	'SSS',0
	db	'Sxx',0
	db	'SSS',0
	db	'xxS',0
	db	'SSS',0
scr6:		
	db	'SSS',0
	db	'Sxx',0
	db	'SSS',0
	db	'SxS',0
	db	'SSS',0
scr7:		
	db	'SSS',0
	db	'xxS',0
	db	'xxS',0
	db	'xxS',0
	db	'xxS',0
scr8:		
	db	'SSS',0
	db	'SxS',0
	db	'SSS',0
	db	'SxS',0
	db	'SSS',0
scr9:		
	db	'SSS',0
	db	'SxS',0
	db	'SSS',0
	db	'xxS',0
	db	'SSS',0
	ENDIF

; LOCAL STACK 
	ds	32			; 16 level stack
stack:
stacko:	dw	0			; original CPM stack
	IF	DAZZLER
	; DAZZLER video ram
	org     VIDEO
vram:   ds      512
	ENDIF
	end
