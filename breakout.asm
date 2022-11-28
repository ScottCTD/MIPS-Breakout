################ CSC258H1F Fall 2022 Assembly Final Project ##################
# This file contains our implementation of Breakout.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       4
# - Unit height in pixels:      4
# - Display width in pixels:    512
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################
	.eqv UNIT_WIDTH 4
	.eqv UNIT_HEIGHT 4
	.eqv DISPLAY_WIDTH 512
	.eqv DISPLAY_HEIGHT 256
	.eqv MAX_X 128
	.eqv MAX_Y 64
	.eqv SLEEP 30
	.eqv DEFAULT_HEARTS 3

	.data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
	.word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
	.word 0xffff0000

# The attributes of the wall.
WALL_ATTRIBUTES:
	.word 0xc7c1b5	# the color
	.word 6		# the thinckness
	
PADDLE_ATTRIBUTES:
	.word 0x01cc34	# paddle color
	.word 14		# paddle length, in units, should be divisible by 2
	.word 2		# paddle thickness, in units
	
BALL_ATTRIBUTES:
	.word 0xFFFFFF	# ball color
	.word 2		# ball radius
	
AUTO_MODE:
	.word 0

##############################################################################
# Mutable Data
##############################################################################

# The attributes of the bricks.
# we have a total of 7 rows of bricks
# the brick collision need also be modified
BRICK_ATTRIBUTES:
	.word 4		# thickness of the bricks, in units
	.word 8		# the number of sections per brick
	.word 1		# space between rows, in units
	.word 1		# space between sections, in units
	.word 0xFF0000	# color of the top bricks
	.word 0xFF7F00
	.word 0xFFFF00
	.word 0x00FF00
	.word 0x0000FF
	.word 0x4B0082
	.word 0x9400D3

GAME_STATUS: 
	.word 0		# 0 = paused, 1 = start

PLAYER_STATUS:
	.word DEFAULT_HEARTS	# number of hearts

# wall boundaries
WALL_AABB:
	.word 0		# top
	.word 0		# left
	.word 0 		# right

# ball AABB
BALL_AABB:
	.word 0:4	# upper left x0, y0, upper right x, lower left y
	
# default direction as upper left
BALL_DIRECTION:
	.word -1		# x direction
	.word -1		# y direction
	
# paddle AABB
PADDLE_AABB:
	.word 0:4	# upper left x0, y0, upper right x, lower left y

# brick AABBs
# we have 7 (row) * 9 (sections per row) = 63 bricks.
# Each brick object consists of 
# the health (1 integer) and the AABB (4 integers)
# so there are 63 * 5 = 315 integers
# if the health is 0, then we don't display and collide the brick
BRICKS_DATA:
	.word 0:315
	
BRICK_SOUND_PITCH_OFFSET:
	.word 0

##############################################################################
# Code
##############################################################################
	.text
	.globl main

##############################################################################
# INITIALIZATIONS
##############################################################################

	# Run the Brick Breaker game.
main:

init:
init_walls:
	# init walls
	# top walls
	addi $sp, $sp, -4		# start_x
	sw $zero, 0($sp)
	addi $sp, $sp, -4		# end_x
	li $t0, MAX_X
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# y
	sw $zero, 0($sp)
	addi $sp, $sp, -4		# width
	lw $t0, WALL_ATTRIBUTES + 4
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t0, WALL_ATTRIBUTES
	sw $t0, 0($sp)
	jal draw_block_unit
	
	# left walls
	addi $sp, $sp, -4		# start_x
	sw $zero, 0($sp)
	addi $sp, $sp, -4		# end_x
	lw $t0, WALL_ATTRIBUTES + 4
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# y
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# width
	lw $t0, WALL_ATTRIBUTES + 4
	li $t1, MAX_Y
	sub $t0, $t1, $t0
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t0, WALL_ATTRIBUTES
	sw $t0, 0($sp)
	jal draw_block_unit

	# right walls
	addi $sp, $sp, -4		# start_x
	li $t0, MAX_X
	lw $t1, WALL_ATTRIBUTES + 4
	sub $t0, $t0, $t1
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# end_x
	li $t0, MAX_X
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# y
	lw $t0, WALL_ATTRIBUTES + 4
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# width
	lw $t0, WALL_ATTRIBUTES + 4
	li $t1, MAX_Y
	sub $t0, $t1, $t0
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t0, WALL_ATTRIBUTES
	sw $t0, 0($sp)
	jal draw_block_unit
	
	# save wall boundaries
	lw $t0, WALL_ATTRIBUTES + 4
	sw $t0, WALL_AABB
	sw $t0, WALL_AABB + 4
	li $t0, MAX_X
	lw $t1, WALL_ATTRIBUTES + 4
	sub $t0, $t0, $t1
	sw $t0, WALL_AABB + 8
	

init_bricks_:
	li $t0, 0			# loop index
	li $t1, 7			# loop end (7 rows of bricks)
	la $t2, BRICK_ATTRIBUTES + 16	# initial color addr
	lw $t3, WALL_ATTRIBUTES + 4	# initial x
	lw $t4, WALL_ATTRIBUTES + 4	# initial y
	addi $t4, $t4, 1
	la $s0, BRICKS_DATA		# the base addr of BRICKS_DATA
# draw sections in the row
init_bricks_outer_loop:
	beq $t0, $t1, init_bricks_outer_loop_end
	# calculate section length and store in $t5
	lw $t5, WALL_ATTRIBUTES + 4	# wall thickness
	li $t6, MAX_X			
	mul $t5, $t5, 2			# wall thickness * 2
	sub $t6, $t6, $t5		# $t6 = MAX_X - wall thickness * 2
	lw $t7, BRICK_ATTRIBUTES + 12	# $t7 = space between sections
	lw $t9, BRICK_ATTRIBUTES + 4	# $t9 = number of sections
	mul $t8, $t7, $t9		# $t8 = space * number of sections
	mul $t5, $t7, 2
	add $t7, $t8, $t5		# $t7 = space * (number of sections + 2)
	sub $t6, $t6, $t7		# $t6 = MAX_X - wall thickness * 2 - spaces
	div $t5, $t6, $t9		# useable area // number of sections = the length of each section	
	# calculate inner loop end and store in $t6
	lw $t6, WALL_ATTRIBUTES + 4	# $t6 = wall thickness
	mul $t7, $t5, $t9		# $t7 = number of sections * section length
	add $t6, $t6, $t7
	lw $t8, BRICK_ATTRIBUTES + 12	# $t8 = space between sections
	mul $t7, $t8, $t9		# $t7 = space * number of sections
	add $t7, $t7, $t8		# $t7 = space * (number of sections + 1)
	add $t6, $t6, $t7		# $t6 = the start of n + 1th section = end
	# inner loop index $t8
	li $t9, MAX_X
	lw $t8, WALL_ATTRIBUTES + 4	# $t8 = wall thickness
	sub $t9, $t9, $t8		# $t9 = MAX_X - wall thickness	
	sub $t9, $t9, $t6 		# $t9 = MAX_X - wall thickness - end = remaining empty space
	div $t9, $t9, 2			# $t9 = (MAX_X - end) // 2
	lw $t8, BRICK_ATTRIBUTES + 12	# $t8 = space
	add $t8, $t8, $t3		# x = initial x + space
	add $t8, $t8, $t9		# x = initial x + space + extra space // 2
	# update end accordingly
	add $t6, $t6, $t9		# inner loop end += extra space // 2
	# initial section end in $t7
	add $t7, $t8, $t5		# x + length
init_bricks_inner_loop:
	bge $t8, $t6, init_bricks_inner_loop_end	# if x >= inner loop end
	# draw one section
	# store the temporiries
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	addi $sp, $sp, -4
	sw $t2, 0($sp)
	addi $sp, $sp, -4
	sw $t3, 0($sp)
	addi $sp, $sp, -4
	sw $t4, 0($sp)
	addi $sp, $sp, -4
	sw $t5, 0($sp)
	addi $sp, $sp, -4
	sw $t8, 0($sp)
	addi $sp, $sp, -4
	sw $t9, 0($sp)
	# call the draw block function
	addi $sp, $sp, -4		# start_x
	sw $t8, 0($sp)
	addi $sp, $sp, -4		# end_x
	sw $t7, 0($sp)
	addi $sp, $sp, -4		# y
	sw $t4, 0($sp)
	addi $sp, $sp, -4		# thickness
	lw $t0, BRICK_ATTRIBUTES
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t0, 0($t2)			# get color from the color addr
	sw $t0, 0($sp)
	jal draw_block_unit
	# restore the temporaries
	lw $t9, 0($sp)
	addi $sp, $sp, 4
	lw $t8, 0($sp)
	addi $sp, $sp, 4
	lw $t5, 0($sp)
	addi $sp, $sp, 4
	lw $t4, 0($sp)
	addi $sp, $sp, 4
	lw $t3, 0($sp)
	addi $sp, $sp, 4
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	# save the bricks data
	li $t9, 7
	sub $t9, $t9, $t0
	sw $t9, 0($s0)			# health
	sw $t8, 4($s0)			# x0
	sw $t4, 8($s0)			# y0
	sw $t7, 12($s0)			# right x
	lw $t9, BRICK_ATTRIBUTES		# $t9 = thickness
	add $t9, $t9, $t4		# $t9 = y0 + thickness = lower y
	sw $t9, 16($s0) 			# lower y
	# updathe the bricks data bass addr
	addi $s0, $s0, 20
	# update the loop
	# x = prev x end + space
	lw $t9, BRICK_ATTRIBUTES + 12 	# space
	add $t8, $t7, $t9
	# x end = x + length
	add $t7, $t8, $t5
	j init_bricks_inner_loop
init_bricks_inner_loop_end:
	# update outer loop
	addi $t2, $t2, 4			# update the color
	# addi $t3, $t3, MAX_X		# update the x
	lw $t5, BRICK_ATTRIBUTES		# update the y
	add $t4, $t4, $t5		
	lw $t5, BRICK_ATTRIBUTES + 8
	add $t4, $t4, $t5
	addi $t0, $t0, 1			# update loop index
	j init_bricks_outer_loop
	
init_bricks_outer_loop_end:

# registers: $s0, $s1, $s2, $s3
init_paddle:
	# $s0 = x0
	li $t0, MAX_X
	div $t0, $t0, 2			# $t0 = center of the screen
	lw $t1, PADDLE_ATTRIBUTES + 4	# $t1 = paddle length
	div $t1, $t1, 2			# $t1 = paddle length // 2
	sub $s0, $t0, $t1		# $s0 = paddle start
	# $s1 = right x
	add $s1, $t0, $t1
	# $s2 = y0
	li $s2, MAX_Y
	lw $t0, PADDLE_ATTRIBUTES + 8
	sub $s2, $s2, $t0
	# $s3 = lower y
	li $s3, MAX_Y
	# save
	sw $s0, PADDLE_AABB
	sw $s2, PADDLE_AABB + 4
	sw $s1, PADDLE_AABB + 8
	sw $s3, PADDLE_AABB + 12
	lw $a0, PADDLE_ATTRIBUTES
	jal clear_paddle
	

# registers: $s0, $s1, $s2
init_ball:
	# $s0 = x0
	li $t0, MAX_X
	div $t0, $t0, 2
	lw $t1, BALL_ATTRIBUTES + 4
	sub $s0, $t0, $t1
	# $s1 = right x
	add $s1, $t0, $t1
	# $s2 = y0
	lw $t0, BALL_ATTRIBUTES + 4
	mul $t0, $t0, 2
	sub $s2, $s2, $t0
	add $s2, $s2, -1
	# $s3 = lower y
	add $s3, $s2, $t0
	# save
	sw $s0, BALL_AABB
	sw $s2, BALL_AABB + 4
	sw $s1, BALL_AABB + 8
	sw $s3, BALL_AABB + 12
	lw $a0, BALL_ATTRIBUTES
	jal clear_ball
	
	j game_loop

##############################################################################
# GAME LOOP
##############################################################################

# for paddle, we clear it only if its position changed
game_loop:
	# 1a. Check if key has been pressed
    	# 1b. Check which key has been pressed
    	lw $s0, ADDR_KBRD		# $s0 = the keyboard address
	lw $t0, 0($s0)			# $t0
    	beq $t0, 1, process_input 	# if $t0 == 1, then we process the keyboard input
after_process_input:
	lw $t0, GAME_STATUS
	beq $t0, 0, game_loop		# if the game has not started yet, then jump back to game_loop

	# 2a. Check for collisions
	# check for wall collisions
	# get part of AABB of the ball
	lw $t0, BALL_AABB		# x0
	lw $t1, BALL_AABB + 4		# y0
	lw $t2, BALL_AABB + 8		# right x
	# collide with top wall
	lw $t3, WALL_AABB		# top wall
	ble $t1, $t3, do_collision_top_wall
	# left wall
	lw $t3, WALL_AABB + 4
	ble $t0, $t3, do_collision_side_wall
	# right wall
	lw $t3, WALL_AABB + 8
	bge $t2, $t3, do_collision_side_wall

	# paddle collision
	la $a0, BALL_AABB
	la $a1, PADDLE_AABB
	jal is_collide
	# if no collisions 
	beq $v0, 0, brick_collisions
	jal play_paddle_sound
	# if collide
	beq $v1, 1, do_collision_1
	beq $v1, 2, do_collision_2
	beq $v1, 3, do_collision_3
	
brick_collisions:
	# brick collisions
	la $t0, BRICKS_DATA
	lw $t1, BRICK_ATTRIBUTES + 4
	mul $t1, $t1, 7
	mul $t1, $t1, 20
	add $t1, $t1, $t0
brick_collision_loop:
	beq $t0, $t1, brick_collision_loop_end
	lw $t2, 0($t0)			# $t2 = health
	# if health = 0, then we jump to unhealthy
	beq $t2, 0, brick_collision_loop_unhealthy
	# if healthy, then we decide collision
	# decide if there is a collision
	la $a0, BALL_AABB
	addi $a1, $t0, 4
	# save temps
	addi $sp, $sp -4
	sw $t0, 0($sp)
	addi $sp, $sp -4
	sw $t1, 0($sp)
	jal is_collide
	# restore temps
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	# if no collisions 
	beq $v0, 0, brick_collision_loop_unhealthy
	# save temps
	addi $sp, $sp -4
	sw $t0, 0($sp)
	addi $sp, $sp -4
	sw $t1, 0($sp)
	jal play_brick_sound
	# restore temps
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	# if collide
	# health - 1
	lw $t2, 0($t0)
	addi $t2, $t2 -1
	sw $t2, 0($t0)
	jal clear_bricks
	beq $v1, 1, do_collision_1
	beq $v1, 2, do_collision_2
	beq $v1, 3, do_collision_3
brick_collision_loop_unhealthy:
	# update the loop
	add $t0, $t0, 20
	j brick_collision_loop
brick_collision_loop_end:

	# otherwise, no collisions
	j update_locations
# top collision
do_collision_top_wall:
	jal play_wall_sound
	j do_collision_1
do_collision_side_wall:
	jal play_wall_sound
	j do_collision_2
do_collision_1:
	# invert vertically
	lw $t0, BALL_DIRECTION + 4
	mul $t1, $t0, 2
	sub $t0, $t0, $t1
	sw $t0, BALL_DIRECTION + 4
	
	j update_locations
do_collision_2:
	# invert horizontally
	lw $t0, BALL_DIRECTION
	mul $t1, $t0, 2
	sub $t0, $t0, $t1
	sw $t0, BALL_DIRECTION
	
	j update_locations
do_collision_3:
	# invert both
	lw $t0, BALL_DIRECTION
	mul $t1, $t0, 2
	sub $t0, $t0, $t1
	sw $t0, BALL_DIRECTION
	lw $t0, BALL_DIRECTION + 4
	mul $t1, $t0, 2
	sub $t0, $t0, $t1
	sw $t0, BALL_DIRECTION + 4
	
	j update_locations

update_locations:
	# 2b. Update locations (paddle, ball)
	# game start
	# clear the previous ball pos
	li $a0, 0x000000
	jal clear_ball
	# start moving the ball
	jal move_ball
	
	# CHEAT: move the paddel accordingly
	lw $t0, AUTO_MODE
	bne $t0, 1, update_screen
	li $a0, 0x000000
	jal clear_paddle
	lw $a0, BALL_DIRECTION
	jal move_paddle

update_screen:
	# 3. Draw the screen
	jal draw_screen

	# 4. Sleep
	li $v0, 32
	li $a0, SLEEP
	syscall 
	
	# 5. Go back to 1
	j game_loop
	
draw_screen:
	# save the $ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	# draw the ball
	lw $a0, BALL_ATTRIBUTES
	jal clear_ball

	# redraw the paddle
	lw $a0, PADDLE_ATTRIBUTES 	# default paddle color
	jal clear_paddle

	# restore the return addr and return
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
process_input:
	lw $t0, 4($s0)
	# start the game
	# if key is "s"
	beq $t0, 0x73, process_input_s
	# quit the game
	# if key is "s"
	beq $t0, 0x71, process_input_q
	# pause the game
	# if key is "p"
	beq $t0, 0x70, process_input_p
	
	# change levels of the game
	# if key is "1"
	beq $t0, 0x31, process_input_1
	# if key is "2"
	beq $t0, 0x32, process_input_2
	# if key is "3"
	beq $t0, 0x33, process_input_3
	# if key is "4"
	beq $t0, 0x34, process_input_4
	# if key is "5"
	beq $t0, 0x35, process_input_5
	# if key is "6"
	beq $t0, 0x36, process_input_6
	# if key is "7"
	beq $t0, 0x37, process_input_7
	# if key is "8"
	beq $t0, 0x38, process_input_8
	# if key is "9"
	beq $t0, 0x39, process_input_9
	
	# paddle movement
	# if key is "a"
	beq $t0, 0x61, process_input_a
	# if key is "d"
	beq $t0, 0x64, process_input_d
	
	# ball cheat movement
	# if key is "i"
	beq $t0, 0x69, process_input_i
	# if key is "k"
	beq $t0, 0x6B, process_input_k
	# if key is "j"
	beq $t0, 0x6A, process_input_j
	# if key is "l"
	beq $t0, 0x6C, process_input_l
	# if key is "u"
	beq $t0, 0x75, process_input_u
	# if key is "o"
	beq $t0, 0x6F, process_input_o
	# if key is "m"
	beq $t0, 0x6D, process_input_m
	# if key is "."
	beq $t0, 0x2E, process_input_dot
	
	j after_process_input

# start the game
process_input_s:
	# mark the GAME_STATUS
	li $t0, 1
	sw $t0, GAME_STATUS
	j after_process_input
	
# quit the game
process_input_q:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	
	jal reset_display
	
	li $v0, 10
	syscall
	
	j after_process_input

# pause the game
process_input_p:
	# mark the GAME_STATUS
	lw $t0, GAME_STATUS
	not $t0, $t0
	and $t0, $t0, 1
	sw $t0, GAME_STATUS
	j after_process_input

# switch level 1
process_input_1:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	jal reset_display
	li $t0, 1
	sw $t0, BRICK_ATTRIBUTES + 4
	# reset player heart
	li $t0, DEFAULT_HEARTS
	sw $t0, PLAYER_STATUS
	j init
	
# switch level 2
process_input_2:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	jal reset_display
	li $t0, 2
	sw $t0, BRICK_ATTRIBUTES + 4
	# reset player heart
	li $t0, DEFAULT_HEARTS
	sw $t0, PLAYER_STATUS
	j init
	
# switch level 3
process_input_3:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	jal reset_display
	li $t0, 3
	sw $t0, BRICK_ATTRIBUTES + 4
	# reset player heart
	li $t0, DEFAULT_HEARTS
	sw $t0, PLAYER_STATUS
	j init
	
# switch level 4
process_input_4:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	jal reset_display
	li $t0, 4
	sw $t0, BRICK_ATTRIBUTES + 4
	# reset player heart
	li $t0, DEFAULT_HEARTS
	sw $t0, PLAYER_STATUS
	j init
	
# switch level 5
process_input_5:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	jal reset_display
	li $t0, 5
	sw $t0, BRICK_ATTRIBUTES + 4
	# reset player heart
	li $t0, DEFAULT_HEARTS
	sw $t0, PLAYER_STATUS
	j init
	
# switch level 6
process_input_6:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	jal reset_display
	li $t0, 6
	sw $t0, BRICK_ATTRIBUTES + 4
	# reset player heart
	li $t0, DEFAULT_HEARTS
	sw $t0, PLAYER_STATUS
	j init
	
# switch level 7
process_input_7:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	jal reset_display
	li $t0, 7
	sw $t0, BRICK_ATTRIBUTES + 4
	# reset player heart
	li $t0, DEFAULT_HEARTS
	sw $t0, PLAYER_STATUS
	j init
	
# switch level 8
process_input_8:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	jal reset_display
	li $t0, 8
	sw $t0, BRICK_ATTRIBUTES + 4
	# reset player heart
	li $t0, DEFAULT_HEARTS
	sw $t0, PLAYER_STATUS
	j init
	
# switch level 9
process_input_9:
	# mark the GAME_STATUS
	li $t0, 0
	sw $t0, GAME_STATUS
	jal reset_display
	li $t0, 9
	sw $t0, BRICK_ATTRIBUTES + 4
	# reset player heart
	li $t0, DEFAULT_HEARTS
	sw $t0, PLAYER_STATUS
	j init

# move the paddle
process_input_a:
	lw $t0, GAME_STATUS
	beq $t0, 0, after_process_input
	# clear the paddle
	li $a0, 0x000000
	jal clear_paddle

	# move the paddle leftward 5 unit
	li $a0, -5
	jal move_paddle
	
	j after_process_input
	
process_input_d:
	lw $t0, GAME_STATUS
	beq $t0, 0, after_process_input
	# clear the paddle
	li $a0, 0x000000
	jal clear_paddle

	# move the paddle leftward 5 unit
	li $a0, 5
	jal move_paddle
	
	j after_process_input
	
# move the ball upward
process_input_i:
	# move the ball upward
	li $t0, 0
	li $t1, -1
	sw $t0, BALL_DIRECTION
	sw $t1, BALL_DIRECTION + 4
	
	j after_process_input
	
# move the ball downward
process_input_k:
	# move the ball downward
	li $t0, 0
	li $t1, 1
	sw $t0, BALL_DIRECTION
	sw $t1, BALL_DIRECTION + 4
	
	j after_process_input

# move the ball leftward
process_input_j:
	# move the ball leftward
	li $t0, -1
	li $t1, 0
	sw $t0, BALL_DIRECTION
	sw $t1, BALL_DIRECTION + 4
	
	j after_process_input
	
# move the ball rightward
process_input_l:
	# move the ball rightward
	li $t0, 1
	li $t1, 0
	sw $t0, BALL_DIRECTION
	sw $t1, BALL_DIRECTION + 4
	
	j after_process_input

# move the ball left up 
process_input_u:
	# move the ball leftward up
	li $t0, -1
	li $t1, -1
	sw $t0, BALL_DIRECTION
	sw $t1, BALL_DIRECTION + 4
	
	j after_process_input
	
# move the ball right up 
process_input_o:
	# move the ball rightward up
	li $t0, 1
	li $t1, -1
	sw $t0, BALL_DIRECTION
	sw $t1, BALL_DIRECTION + 4
	
	j after_process_input

# move the ball left down
process_input_m:
	# move the ball leftward down
	li $t0, -1
	li $t1, 1
	sw $t0, BALL_DIRECTION
	sw $t1, BALL_DIRECTION + 4
	
	j after_process_input

# move the ball right down
process_input_dot:
	# move the ball rightward down
	li $t0, 1
	li $t1, 1
	sw $t0, BALL_DIRECTION
	sw $t1, BALL_DIRECTION + 4
	
	j after_process_input

##############################################################################
# FUNCTIONS
##############################################################################
	
# decide if two AABBs collide
# parameter: $a0 = the addr of AABB1, $a2 = the addr of AABB2
# returns: $v0 = if collided, $v1 = the colission type, -1 if not collide
# collision type 1 = flip vertically
# collision type 2 = flip horizontally
# collision type 3 = flip both
# registers: $t0 - $t7
is_collide:
	# save variables
	addi $sp, $sp, -4
	sw $s0, 0($sp)
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	addi $sp, $sp, -4
	sw $s2, 0($sp)
	addi $sp, $sp, -4
	sw $s3, 0($sp)
	addi $sp, $sp, -4
	sw $s4, 0($sp)
	# get AABBs
	lw $t0, 0($a0)				# $t0 = x0 of AABB1
	lw $t1, 4($a0)				# $t1 = y0 of AABB1
	lw $t2, 8($a0)				# $t2 = right x of AABB1
	lw $t3, 12($a0)				# $t3 = lower y of AABB1
	
	lw $t4, 0($a1)				# $t4 = x0 of AABB2
	lw $t5, 4($a1)				# $t5 = y0 of AABB2
	lw $t6, 8($a1)				# $t6 = right x of AABB2
	lw $t7, 12($a1)				# $t7 = lower y of AABB2
	
	# collision on x?
	sgeu $s0, $t2, $t4
	sgeu $s1, $t6, $t0
	and $s2, $s0, $s1
	# collision on y?
	sgeu $s0, $t3, $t5
	sgeu $s1, $t7, $t1
	and $s3, $s0, $s1
	# if collide, type?
	and $s4, $s2, $s3
	# if collide
	beq $s4, 1, is_collide_true
	# if not collide
	li $v0, 0
	li $v1, -1
	j is_collide_end
is_collide_true:
	# decide which type
	# if the at least one distance between lower y1 and y02, or between y01 and lower y2 is 0, then it is a type 1
	sub $s0, $t1, $t7			# $s0 = y01 - lower y2
	sub $s1, $t3, $t5			# $s1 = lower y1 - y02
	and $s2, $s0, $s1			# $s2 = 0 iff at least one of them is zero
	# at least one 0, go type 1
	beq $s2, 0, is_collide_type1
	# if the at least one distance between right x1 and x02, or between x01 and right x2 is 0, then it is a type 2
	sub $s0, $t0, $t6			# $s0 = x01 - right x2
	sub $s1, $t2, $t4			# $s1 = right x1 - x02
	and $s2, $s0, $s1			# $s2 = 0 iff at least one of them is zero
	# at least one 0, go type 2
	beq $s2, 0, is_collide_type2
	# otherwise, type 3
	li $v0, 1
	li $v1, 3
	j is_collide_end
is_collide_type1:
	li $v0, 1
	li $v1, 1
	j is_collide_end
is_collide_type2:
	li $v0, 1
	li $v1, 2
	j is_collide_end
is_collide_end:
	# restore variables
	lw $s4, 0($sp)
	addi $sp, $sp, 4
	lw $s3, 0($sp)
	addi $sp, $sp, 4
	lw $s2, 0($sp)
	addi $sp, $sp, 4
	lw $s1, 0($sp)
	addi $sp, $sp, 4
	lw $s0, 0($sp)
	addi $sp, $sp, 4
	# return the function
	jr $ra

# move the ball with x movement and y movement. +x = right, -x = left, +y = down, -y = up
# registers: $t0 - $t3
move_ball:
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	lw $a0, BALL_DIRECTION
	lw $a1, BALL_DIRECTION + 4

	# current AABB of the ball
	lw $t0, BALL_AABB			# $t0 = x0
	lw $t1, BALL_AABB + 4			# $t1 = y0
	lw $t2, BALL_AABB + 8			# $t2 = right x
	lw $t3, BALL_AABB + 12			# $t3 = lower y

	# if the ball lower y hit the void, then decreases player heart, sleep, and reinit the paddle and ball
	bne $t3, 64, move_ball_normal
	lw $t0, PLAYER_STATUS
	
	# if no hearts any more, quit the game
	beq $t0, 1, process_input_q
	
	addi $t0, $t0, -1
	sw $t0, PLAYER_STATUS
	
	# sleep
	li $v0, 32
	li $a0, 2000
	syscall

	# pause
	li $t0, 0
	sw $t0, GAME_STATUS
	
	li $a0, 0x000000
	jal clear_paddle
	li $a0, 0x000000
	jal clear_ball
	
	j init_paddle
	
	lw $ra, 0($sp)
	addi $sp, $sp 4
	jr $ra

move_ball_normal:
	# move the ball vertically
	add $t1, $t1, $a1
	add $t3, $t3, $a1
	# move the ball horizontally
	add $t0, $t0, $a0
	add $t2, $t2, $a0
	
	# save the new AABB
	sw $t0, BALL_AABB			# $t0 = x0
	sw $t1, BALL_AABB + 4			# $t1 = y0
	sw $t2, BALL_AABB + 8			# $t2 = right x
	sw $t3, BALL_AABB + 12			# $t3 = lower y
	
	lw $ra, 0($sp)
	addi $sp, $sp 4
	jr $ra


# parameters: $a0 = color
# registers: $t0, $t1, $t2, $t3, $t4, $t5, $t8, $t9
clear_ball:
	# save the return address
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# save the saved variables
	addi $sp, $sp, -4
	sw $s0, 0($sp)
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	addi $sp, $sp, -4
	sw $s2, 0($sp)
	# clear the ball
	# get the coordinates of the paddle
	lw $s0, BALL_AABB + 0		# upper left x
	lw $s2, BALL_AABB + 4		# y
	lw $s1, BALL_AABB + 8		# right x 
	# call the draw block function
	addi $sp, $sp, -4		# start_x
	sw $s0, 0($sp)
	addi $sp, $sp, -4		# end_x
	sw $s1, 0($sp)
	addi $sp, $sp, -4		# y
	sw $s2, 0($sp)
	addi $sp, $sp, -4		# thickness
	lw $t0, BALL_ATTRIBUTES + 4
	mul $t0, $t0, 2
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# color	
	sw $a0, 0($sp)
	jal draw_block_unit
	# restore the saved variables
	lw $s2, 0($sp)
	addi $sp, $sp, 4
	lw $s1, 0($sp)
	addi $sp, $sp, 4
	lw $s0, 0($sp)
	addi $sp, $sp, 4
	# restore the return addr
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	# return
	jr $ra

# parameters: $a0 = color
# registers: $t0, $t1, $t2, $t3, $t4, $t5, $t8, $t9
clear_paddle:
	# save the return address
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# save the saved variables
	addi $sp, $sp, -4
	sw $s0, 0($sp)
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	addi $sp, $sp, -4
	sw $s2, 0($sp)
	# get the coordinates of the paddle
	lw $s0, PADDLE_AABB + 0			# upper left x
	lw $s2, PADDLE_AABB + 4			# y
	lw $s1, PADDLE_AABB + 8			# right x 
	# call the draw block function
	addi $sp, $sp, -4		# start_x
	sw $s0, 0($sp)
	addi $sp, $sp, -4		# end_x
	sw $s1, 0($sp)
	addi $sp, $sp, -4		# y
	sw $s2, 0($sp)
	addi $sp, $sp, -4		# thickness
	lw $t0, PADDLE_ATTRIBUTES + 8
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# color		
	sw $a0, 0($sp)
	jal draw_block_unit
	# restore the saved variables
	lw $s2, 0($sp)
	addi $sp, $sp, 4
	lw $s1, 0($sp)
	addi $sp, $sp, 4
	lw $s0, 0($sp)
	addi $sp, $sp, 4
	# restore the return addr
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	# return
	jr $ra
	
# move the paddle with x movemen. +x = right, -x = left
# registers: $t0 - $t3
move_paddle:
	# current AABB of the paddle
	lw $t0, PADDLE_AABB			# $t0 = x0
	lw $t1, PADDLE_AABB + 8			# $t1 = right x
	
	# we need |a0|
	abs $t3, $a0
	# if a0 < 0
	blt $a0, 0, move_paddle_1
	# if a0 > 0
	bgt $a0, 0, move_paddle_2
	# if a0 == 0
	j move_paddle_end
move_paddle_1:
	lw $t2, WALL_AABB + 4			# left bound
	sub $t2, $t0, $t2			# $t2 = x0 - left bound = gap
	# if the gap < t3, then we change a0
	ble $t2, $t3, move_paddle_special_1
	j move_paddle_end
move_paddle_special_1:
	mul $t2, $t2, -1
	move $a0, $t2
	j move_paddle_end
move_paddle_2:
	lw $t2, WALL_AABB + 8			# right bound
	sub $t2, $t2, $t1			# $t2 = right bound - right x = gap
	# if the gap < t3, then we change a0
	ble $t2, $t3, move_paddle_special_2
	j move_paddle_end
move_paddle_special_2:
	move $a0, $t2
	j move_paddle_end
move_paddle_end:
	# move the paddle horizontally
	add $t0, $t0, $a0
	add $t1, $t1, $a0
	
	# save the new AABB
	sw $t0, PADDLE_AABB			# $t0 = x0
	sw $t1, PADDLE_AABB + 8			# $t1 = right x
	
	jr $ra


# the coordinate system is constructed as the upper left corner = (0, 0), lower right corner = (DISPLAY_WIDTH / UNIT_WIDTH, ...)
# parameters: x, y
# return values: the number of units given x and y
# registers: $t8, $t9
coordinate_to_display:
	# pop parameters from the stack
	lw $t9, 0($sp)			# y
	addi $sp, $sp, 4
	lw $t8, 0($sp)			# x
	addi $sp, $sp, 4
	# convert
	mul $t9, $t9, DISPLAY_WIDTH	# $t9 = DISPLAY_WIDTH * y
	mul $t8, $t8, UNIT_WIDTH		# $t8 = x * UNIT_WIDTH
	add $t8, $t8, $t9		# $t8 = x * UNIT_WIDTH + DISPLAY_WIDTH * y
	# push the return value
	addi $sp, $sp, -4
	sw $t8, 0($sp)
	jr $ra 				# return the function

# parameters: start, end, increment, color
# 	      $a0,  $a1,  $a2	    $a3
# registers: $t0, $t1
draw_row:
	# push $s7 to the stack
	addi $sp, $sp, -4
	sw $s7, 0($sp)
	lw $s7, ADDR_DSPL		# $s7 = the display base address
	add $t0, $a0, $zero
draw_row_loop:
	beq $t0, $a1, draw_row_loop_end	# ...
	add $t1, $s7, $t0		# $t1 is the display base address + index
	sw $a3, 0($t1)			# draw the unit sqaure
	add $t0, $t0, $a2		# update the loop index, index = index + UNIT_WIDTH
	j draw_row_loop
draw_row_loop_end:
	# restore $s7 from the stack
	lw $s7, 0($sp)
	addi $sp, $sp, 4
	jr $ra				# return the function
	
# draw_block will draw a block with length specified by start and end, and width specified by width.
# end_x is exclusive
# preconditions: $s7 is the base address of the display
# parameters: start_x, end_x, y, width, color
# registers: $t0, $t1, $t2, $t3, $t4, $t5, $t8, $t9
draw_block_unit:
	# pop parameters from the stack
	lw $t4, 0($sp)			# $t4 = color
	addi $sp, $sp, 4
	lw $t3, 0($sp)			# $t3 = width
	addi $sp, $sp, 4
	lw $t2, 0($sp)			# $t2 = y
	addi $sp, $sp, 4
	lw $t1, 0($sp)			# $t1 = end_x
	addi $sp, $sp, 4
	lw $t0, 0($sp)			# $t0 = start_x
	addi $sp, $sp, 4
	# store the return address
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# calculate the start in display
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	addi $sp, $sp, -4
	sw $t2, 0($sp)
	jal coordinate_to_display
	# get the return value
	lw $t0, 0($sp)			# $t0 = start_x
	addi $sp, $sp, 4
	# calculate the end in display
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	addi $sp, $sp, -4
	sw $t2, 0($sp)
	jal coordinate_to_display
	# get the return value
	lw $t1, 0($sp)			# $t1 = end_x
	addi $sp, $sp, 4
	# loop setup
	move $t5, $zero			# $t5 = loop index start from 0
draw_block_loop_unit:
	beq $t5, $t3, draw_block_end_unit
	# draw one line
	# store $t0 and $t1 in the stack
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	# call draw_row
	move $a0, $t0			# start pixel
	move $a1, $t1			# end pixel
	li $a2, UNIT_WIDTH		# increment is always the UNIT_WIDTH because we draw horizontal line by line
	move $a3, $t4			# color
	jal draw_row
	# restore $t0 and $t1 from the stack
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	# update start $t0 and end $t1
	li $t9, MAX_X
	mul $t9, $t9, UNIT_WIDTH
	add $t0, $t0, $t9
	add $t1, $t1, $t9
	# update loop
	addi $t5, $t5, 1
	j draw_block_loop_unit
draw_block_end_unit:
	# restore the return address from the stack
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
# clear the bricks 
# registers: $t0 - $t5, $t8 - $t9
clear_bricks:
	# store the ra
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	li $t0, 0			# loop index from 0 to 7 - 1
	li $t1, 7			# loop end	
# draw each row of the brick
clear_bricks_outer_loop:
	beq $t0, $t1, clear_bricks_end
	li $t2, 0			# inner loop index from 0 to number of sections - 1
	lw $t3, BRICK_ATTRIBUTES + 4	# inner loop end
clear_bricks_inner_loop:
	beq $t2, $t3, clear_bricks_inner_loop_end
	# if health == 0, then we set the color to black, else the normal color
	la $t4, BRICKS_DATA		# the base addr of BRICKS_DATA
	lw $t5, BRICK_ATTRIBUTES + 4
	mul $t5, $t5, 20
	mul $t5, $t0, $t5
	mul $t6, $t2, 20
	add $t5, $t5, $t6
	add $t4, $t4, $t5		# $t4 = current brick data
	lw $t5, 0($t4)			# $t5 = health
	# if health is not 0
	bne $t5, 0, clear_bricks_health_normal
	# if health is 0
	li $t9, 0x000000			# $t9 = color black
	j clear_bricks_draw_brick
clear_bricks_health_normal:
	# if health is not 0, set color to the normal color (corresponding to the health )
	la $t9, BRICK_ATTRIBUTES + 16	# $t9 = starting color addr
	li $t8, 7
	sub $t8, $t8, $t5		# $t8 = 7 - health
	mul $t8, $t8, 4
	add $t9, $t9, $t8		# $t9 = current color addr
	lw $t9, 0($t9)			# $t9 = current color
	j clear_bricks_draw_brick
clear_bricks_draw_brick:
	# draw one brick
	# store the temporaries
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	addi $sp, $sp, -4
	sw $t2, 0($sp)
	addi $sp, $sp, -4
	sw $t3, 0($sp)
	addi $sp, $sp, -4
	sw $t4, 0($sp)
	addi $sp, $sp, -4
	sw $t9, 0($sp)
	# call the draw block function
	addi $sp, $sp, -4		# start_x
	lw $t0, 4($t4)
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# end_x
	lw $t0, 12($t4)
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# y
	lw $t0, 8($t4)
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# thickness
	lw $t0, BRICK_ATTRIBUTES
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# color		
	sw $t9, 0($sp)
	jal draw_block_unit
	
	# restore the temporaries
	lw $t9, 0($sp)
	addi $sp, $sp, 4
	lw $t4, 0($sp)
	addi $sp, $sp, 4
	lw $t3, 0($sp)
	addi $sp, $sp, 4
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	
	# update the inner loop
	addi $t2, $t2, 1
	j clear_bricks_inner_loop
clear_bricks_inner_loop_end:
	# update the outer loop
	addi $t0, $t0, 1
	j clear_bricks_outer_loop
clear_bricks_end:
	# restore the ra
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	# return 
	jr $ra
	
# registers: $t0 - $t5, $t8 - $t9
reset_display:
	add $sp, $sp, -4
	sw $ra 0($sp)
	addi $sp, $sp, -4		# start_x
	sw $zero, 0($sp)
	addi $sp, $sp, -4		# end_x
	li $t0, MAX_X
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# y
	sw $zero, 0($sp)
	addi $sp, $sp, -4		# thickness
	li $t0, MAX_Y
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# color		
	sw $zero, 0($sp)
	jal draw_block_unit
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

play_brick_sound:	
	lw $t0, BRICK_SOUND_PITCH_OFFSET
	addi $a0, $t0, 72		# pitch
	li $a1, 600			# duration in miliseconds
	li $a2, 0			# instrument
	li $a3, 127			# volume
	li $v0, 31
	syscall
	
	addi $t0, $t0, 1
	li $t1, 24
	div $t0, $t1
	mfhi $t0
	sw $t0, BRICK_SOUND_PITCH_OFFSET
	
	jr $ra
	
play_paddle_sound:
	# generate a random number from 0 to 12, result in $a0
	li $a0, 1
	li $a1, 12
	li $v0, 42
	syscall
	
	addi $a0, $a0, 36		# pitch
	li $a1, 1000			# duration in miliseconds
	li $a2, 38			# instrument
	li $a3, 127			# volume
	li $v0, 31
	syscall
	
	jr $ra
	
play_wall_sound:
	addi $a0, $a0, 60		# pitch
	li $a1, 1000			# duration in miliseconds
	li $a2, 117			# instrument
	li $a3, 127			# volume
	li $v0, 31
	syscall
	
	jr $ra
	
