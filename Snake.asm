;This does not use R2TERM's keyboard.
;Use Qweryntino's controller directly instead.
;Responsiveness is good due to low delay time.

;r0,r1,r2: registers usable in any part of this code
;r4: head position
;r5: tail position
;r6: position of apple
;r9: game speed timer
;r10 : terminal port address = 0
;r11 : random number generator port address = 1
start:
	mov r10, 0		;Specify the terminal port number.
	mov r11, 1		;the port addr of input device
	mov r12, 2		;the port addr of RNG
	mov sp, 0x0200		;the stack pointer
	mov r7, 0x30		;digits on the scoreboard.
	mov r8, 0x2F
	send r10, 0x1000
	call draw_hori_wall	;Draw the border of the game screen.
	send r10, 0x10B0
	call draw_hori_wall
	mov r0, 0x1000
	call draw_vert_wall
	mov r0, 0x100F
	call draw_vert_wall
	jmp setup		;Jump to the game preparation routine.

draw_hori_wall:			;Border drawing routine
	send r10, 0x200F
	mov r1, 16
	.loop:
		send r10, 0x7F
		send r10, 0x7F
		sub r1, 2
		jnz .loop
	ret
draw_vert_wall:			;Border drawing routine
		send r10, r0
		mov r1, 12
		.loop:
		send r10, r0
		send r10, 0x7F
		add r0, 0x10
		send r10, r0
		send r10, 0x7F
		add r0, 0x10
		sub r1, 2
		jnz .loop
		ret

;This is a routine that prepares you for the game to begin.
setup:
	send r10, 0x1057		;Before the game starts, the controller should point to the right..
	send r10, 0x2004
	send r10, 0x7F
	.right:						
		recv r0, r11
		.chk:
		cmp r0, 'd'
		jne .right
	send r10, 0x200F
	jmp game
game:
	mov r4, map			;Set the snake's head position.
	add r4, 86
	mov r5, map			;Set the snake's tail position.
	add r5, 84
	jmp apple			;Jump to the apple creation routine to generate the first apple.

MAIN_loop:				;This is the main loop of the game.
	.speed_regulator:		;This is the part that does nothing to control the speed of the game.
	sub r9, 1
	jnz .speed_regulator
	recv r0, r11
	add r0, keymap			;Jump to the designated place according to the keymap.
	jmp [r0]

;Specify the speed of the game.
;should be tuned with the frequency of R2.
n_speed: dw 6				;Timer when proceeding normally without eating an apple
a_speed: dw 2				;Timer when eating an apple and creating an apple

;This is a routine that is executed when each key is pressed.
;Draw the snake's head on the terminal and place the head on the game map.
key_up:
	sub r4, 16			;Change the head position.
	send r10, r4			;Draw the head.
	send r10, 0x7F
	mov r1, [r4]			;Check if the snake hit a wall or body.
	jnz gameover
	mov [r4+16], 3			;Place the snake's body on the game map.
	jmp chkapple			;Jump to the routine to check if an apple has been eaten.
key_down:
	add r4, 16
	send r10, r4
	send r10, 0x7F
	mov r1, [r4]
	jnz gameover
	mov [r4-16], 4
	jmp chkapple
key_left:
	sub r4, 1
	send r10, r4
	send r10, 0x7F
	mov r1, [r4]
	jnz gameover
	mov [r4+1], 1
	jmp chkapple
key_right:
	add r4, 1
	send r10, r4
	send r10, 0x7F
	mov r1, [r4]
	jnz gameover
	mov [r4-1], 2
	jmp chkapple

;If the controller is not properly installed
;and a value other than wasd is entered, the program stops.
key_error:
	send r10, 0x1005
	send r10, 'E'
	send r10, ':'
	send r10, 'h'
	send r10, 'a'
	send r10, 'l'
	send r10, 't'
	hlt

;Check if the snake's head touches the apple.
chkapple:
	cmp r4, r6
	jne tail

;If the head touches the apple, run apple creation routine.
apple:
	recv r6, r12			;Receive a random number from RNG.
	and r6, 0x00FF			;Trim random number so they can be placed on the game map.
	add r6, 0x1000
	cmp r6, r4			;If the apple is generated in the same place
	je apple			;as the current head position, it receives a random number again.

	cmp [r6], 0			;Make sure it doesn't spawn on the snake's body or walls.
	jne apple
	mov r9, [a_speed]		;Set the game timer.
	add r8, 1			;increase score
	cmp r8, 0x3A			;If r8 goes beyond 9, we increase r7.
	jne .output_score		;If not, the score is printed immediately.
	add r7, 1
	mov r8, 0x30
	.output_score:
	send r10, 0x1007
	send r10, 0x20F0
	send r10, r7
	send r10, r8
	send r10, 0x200F
	.show_apple:	
	send r10, r6
	send r10, 0x30
	jmp MAIN_loop

;It is a routine to draw the tail.
;When scored, this part is skipped to stretch the tail.
tail:
	mov r9, [n_speed]		;Set the game timer.
	mov r0, [r5]			;Read where to move the tail position.
	add r0, .t_table
	jmp [r0]			;Jumps to the direction routine where the tail needs to be moved.
	.t_table:
		dw 0, t_left, t_right, t_up, t_down
t_up:
	send r10, r5			;Draw the tail.
	send r10, 0x20
	mov [r5], 0			;Records that there is no snake in the previous tail position.
	sub r5, 16			;Change the position of the tail.
	jmp MAIN_loop
t_down:
	send r10, r5
	send r10, 0x20
	mov [r5], 0
	add r5, 16
	jmp MAIN_loop
t_left:
	send r10, r5
	send r10, 0x20
	mov [r5], 0
	sub r5, 1
	jmp MAIN_loop
t_right:
	send r10, r5
	send r10, 0x20
	mov [r5], 0
	add r5, 1
	jmp MAIN_loop


;If the head touches the wall or the body of a snake, output the game over and halt.
gameover:
	send r10, 0x1006
	send r10, 0x20F0
	send r10, 'X'
	send r10, r7
	send r10, r8
	send r10, 'X'
	hlt

;This is a keymap that also exists in the keyboard version.
;Unlike the keyboard version, input other than the designated key is regarded as an error.
keymap:
	dw key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error		;
	dw key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error		;
	dw key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error		;
	dw key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error		;   !"#$%&'
	dw key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error		;()*+,-./01
	dw key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error		;23456789:;
	dw key_error, key_error, key_error, key_error, key_error, key_left, key_error, key_error, key_right, key_error		;<=>?@ABCDE
	dw key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error		;FGHIJKLMNO
	dw key_error, key_error, key_error, key_down, key_error, key_error, key_error, key_up, key_error, key_error			;PQRSTUVWXY
	dw key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_left, key_error, key_error		;Z[\]^_`abc
	dw key_right, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error		;defghijklm
	dw key_error, key_error, key_error, key_error, key_error, key_down, key_error, key_error, key_error, key_up			;nopqrstuvw
	dw key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error, key_error		;xyz{|}~   



;This is why this code should run on R216K8B.
;To run the game, the game map coordinates must be converted to terminal cursor commands.
;However, I was able to save resources to convert by placing the game map at the address that matches the 0x10XX command one-to-one.
org 0x1000

map:
	dw 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	dw 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
	dw 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
	dw 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
	dw 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
	dw 1,0,0,0,2,2,2,0,0,0,0,0,0,0,0,1
	dw 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
	dw 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
	dw 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
	dw 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
	dw 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
	dw 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	dw 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	dw 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	dw 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	dw 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1