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
	.eqv BRICK_AMOUNT 7		# the number of bricks
	.eqv BRICK_SECTION_AMOUNT 8	# the number of sections per brick

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
	
# The attributes of the bricks.
# we have a total of 7 rows of bricks
BRICK_ATTRIBUTES:
	.word 3		# thickness of the bricks, in units
	.word 1		# space between two bricks, in units
	.word 0xFF0000	# color of the outermost bricks
	.word 0xFF7F00
	.word 0xFFFF00
	.word 0x00FF00
	.word 0x0000FF
	.word 0x4B0082
	.word 0x9400D3
	
PADDLE_ATTRIBUTES:
	.word 0x01cc34	# paddle color
	.word 14		# paddle length, in units, should be divisible by 2
	.word 2		# paddle thickness, in units
	
BALL_ATTRIBUTES:
	.word 0xFFFFFF	# ball color
	.word 2		# ball radius

##############################################################################
# Mutable Data
##############################################################################



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
	lw $s7, ADDR_DSPL		# $s7 = the display base address

# registers: s0: left and right wall width, s1: left wall end, s2: right wall start
init_walls:
	# init walls
	# top walls
	addi $sp, $sp, -4		# start
	sw $zero, 0($sp)
	addi $sp, $sp, -4		# end
	li $t0, DISPLAY_WIDTH
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# width
	lw $t0, WALL_ATTRIBUTES + 4
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t0, WALL_ATTRIBUTES
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# increment
	li $t0, DISPLAY_WIDTH
	sw $t0, 0($sp)
	jal draw_block

	# left walls
	# calculate initial start pixel and store in $t0
	li $t0, DISPLAY_WIDTH		# $t0 = DISPLAY_WIDTH
	lw $t1, WALL_ATTRIBUTES + 4	# $t1 = WALL_ATTRIBUTES[1] = thickness
	mul $t0, $t0, $t1		# $t0 = DISPLAY_WIDTH * THINCKNESS = start pixel
	# calculate initial end pixel and store in $t1
	li $t1, UNIT_WIDTH		# $t1 = UNIT_WIDTH
	lw $t2, WALL_ATTRIBUTES + 4	# $t2 = WALL_ATTRIBUTES[1] = thickness
	mul $t1, $t1, $t2		# $t1 = UNIT_WIDTH * WALL_ATTRIBUTES[1]
	add $t1, $t0, $t1		# $t1 = initial start + UNIT_WIDTH * WALL_ATTRIBUTES[1]
	move $s1, $t1
	# calculate width and store in $s0
	li $t2, DISPLAY_HEIGHT		# $t2 = DISPLAY_HEIGHT
	li $t3, UNIT_HEIGHT		# $t3 = UNIT_HEIGHT
	div $t2, $t2, $t3		# $t2 = DISPLAY_HEIGHT // UNIT_HEIGHT
	lw $t3, WALL_ATTRIBUTES + 4	# $t4 = WALL_ATTRIBUTES[1]
	sub $s0, $t2, $t3
	
	addi $sp, $sp, -4		# start
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# end
	sw $t1, 0($sp)
	addi $sp, $sp, -4		# width
	sw $s0, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t0, WALL_ATTRIBUTES
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# increment
	li $t0, DISPLAY_WIDTH
	sw $t0, 0($sp)
	jal draw_block

	# right walls
	# initial start = $t0
	lw $t1, WALL_ATTRIBUTES + 4	# $t1 = WALL_ATTRIBUTES[1] = thickness
	addi $t1, $t1, 1
	mul $t2, $t1, DISPLAY_WIDTH	# $t2 = (WALL_ATTRIBUTES[1] + 1) * DISPLAY_WIDTH
	addi $t1, $t1, -1
	mul $t1, $t1, UNIT_WIDTH
	sub $t0, $t2, $t1		# $t0 = (WALL_ATTRIBUTES[1] + 1) * DISPLAY_WIDTH - WALL_ATTRIBUTES[1] * UNIT_WIDTH
	move $s2, $t0
	# initial end = $t1
	move $t1, $t2
	# width = $s0
	
	addi $sp, $sp, -4		# start
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# end
	sw $t1, 0($sp)
	addi $sp, $sp, -4		# width
	sw $s0, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t0, WALL_ATTRIBUTES
	sw $t0, 0($sp)
	addi $sp, $sp, -4		# increment
	li $t0, DISPLAY_WIDTH
	sw $t0, 0($sp)
	jal draw_block

# registers: s1: left wall end, s2: right wall start
init_bricks:
	li $t0, 0			# loop index
	li $t1, BRICK_AMOUNT		# loop end
	la $t2, BRICK_ATTRIBUTES + 8	# initial color addr
init_bricks_loop:
	beq $t0, $t1, init_bricks_loop_end
	# store $t0, $t1, and $t2 in the stack
	addi $sp, $sp, -4
	sw $t0, 0($sp)
	addi $sp, $sp, -4
	sw $t1, 0($sp)
	addi $sp, $sp, -4
	sw $t2, 0($sp)
	# draw a brick
	addi $sp, $sp, -4		# start
	sw $s1, 0($sp)
	addi $sp, $sp, -4		# end
	sw $s2, 0($sp)
	addi $sp, $sp, -4		# width
	lw $t9, BRICK_ATTRIBUTES
	sw $t9, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t9, 0($t2)
	sw $t9, 0($sp)
	addi $sp, $sp, -4		# increment
	li $t9, DISPLAY_WIDTH
	sw $t9, 0($sp)
	jal draw_block
	# restore $t0, $t1, and $t2 from the stack
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	# update loop
	addi $t0, $t0, 1
	# update start and end
	lw $t3, BRICK_ATTRIBUTES		# $t3 = brick thickness
	lw $t4, BRICK_ATTRIBUTES + 4	# $t4 = space between bricks
	add $t3, $t3, $t4		# $t3 = brick thickness + space between bricks
	mul $t3, $t3, DISPLAY_WIDTH	# $t3 = (brick thickness + space between bricks) * DISPLAY_WIDTH
	add $s1, $s1, $t3
	add $s2, $s2, $t3
	# update color
	addi $t2, $t2, 4
	j init_bricks_loop
init_bricks_loop_end:

# registers: $s2: the starting height of the paddle
init_paddle:
	# start position $s0
	li $t0, DISPLAY_HEIGHT		#
	li $t1, DISPLAY_WIDTH		# 
	div $t0, $t0, UNIT_HEIGHT	# $t1 = DISPLAY_HEIGHT // UNIT_HEIGHT = height
	lw $t9, PADDLE_ATTRIBUTES + 8
	sub $t0, $t0, $t9		# $t0 is the starting height of the paddle
	move $s2, $t0
	mul $t0, $t0, $t1		# $t0 = DISPLAY_WIDTH * (height - paddle thickness)
	div $t1, $t1, 2			# $t1 = DISPLAY_WIDTH // 2
	lw $t2, PADDLE_ATTRIBUTES + 4	# $t2 = paddle length
	mul $t2, $t2, UNIT_WIDTH
	div $t2, $t2, 2			# $t2 = paddle length // 2
	sub $t3, $t1, $t2		# $t3 = DISPLAY_WIDTH // 2 - paddle length // 2
	add $s0, $t0, $t3		# $s0 = DISPLAY_WIDTH * (height - paddle thickness) + DISPLAY_WIDTH // 2 - paddle length // 2
	# end position $s1
	add $t3, $t1, $t2
	add $s1, $t0, $t3
	# draw the paddle
	addi $sp, $sp, -4		# start
	sw $s0, 0($sp)
	addi $sp, $sp, -4		# end
	sw $s1, 0($sp)
	addi $sp, $sp, -4		# width
	lw $t9, PADDLE_ATTRIBUTES + 8
	sw $t9, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t9, PADDLE_ATTRIBUTES
	sw $t9, 0($sp)
	addi $sp, $sp, -4		# increment
	li $t9, DISPLAY_WIDTH
	sw $t9, 0($sp)
	jal draw_block

# registers: 
init_ball:
	# start position $s0
	lw $t0, BALL_ATTRIBUTES + 4	# $t0 = ball radius
	mul $t1, $t0, 2			# $t1 = ball diameter (length and width)
	sub $s2, $s2, $t1		# ball staring height = paddle starting height - ball diameter
	mul $t0, $t0, UNIT_WIDTH		# $t0 = ball radius (in units)	
	li $t2, DISPLAY_WIDTH
	mul $t3, $t2, $s2		# $t3 = ball starting height * DISPLAY_WIDTH
	div $t2, $t2, 2			# $t2 = DISPLAY_WIDTH // 2
	sub $t4, $t2, $t0		# $t4 = DISPLAY_WIDTH // 2 - ball radius
	add $s0, $t3, $t4		# $s0 = ball starting height * DISPLAY_WIDTH + DISPLAY_WIDTH // 2 - ball radius
	# end position $s1
	add $t4, $t2, $t0		# $t4 = DISPLAY_WIDTH // 2 + ball radius
	add $s1, $t3, $t4		# $s0 = ball starting height * DISPLAY_WIDTH + DISPLAY_WIDTH // 2 + ball radius
	# draw the paddle
	addi $sp, $sp, -4		# start
	sw $s0, 0($sp)
	addi $sp, $sp, -4		# end
	sw $s1, 0($sp)
	addi $sp, $sp, -4		# width
	sw $t1, 0($sp)
	addi $sp, $sp, -4		# color
	lw $t9, BALL_ATTRIBUTES
	sw $t9, 0($sp)
	addi $sp, $sp, -4		# increment
	li $t9, DISPLAY_WIDTH
	sw $t9, 0($sp)
	jal draw_block

	j game_loop

##############################################################################
# FUNCTIONS FOR INITIALIZATIONS
##############################################################################

# parameters: start, end, increment, color
# 	      $a0,  $a1,  $a2	    $a3
# preconditions: $s7 is the base address of the display
# registers: $t0, $t1
draw_row:
	add $t0, $a0, $zero
draw_row_loop:
	beq $t0, $a1, draw_row_loop_end	# ...
	add $t1, $s7, $t0		# $t1 is the display base address + index
	sw $a3, 0($t1)			# draw the unit sqaure
	add $t0, $t0, $a2		# update the loop index, index = index + UNIT_WIDTH
	j draw_row_loop
draw_row_loop_end:
	jr $ra				# return the function

# draw_block will draw a block with length specified by start and end, and width specified by width.
# preconditions: $s7 is the base address of the display
# parameters: start, end, width, color, increment
# registers: $t0, $t1, $t2, $t3, $t4, $t5
draw_block:
	# pop parameters from the stack
	lw $t4, 0($sp)			# $t4 = increment
	addi $sp, $sp, 4
	lw $t3, 0($sp)			# $t3 = color
	addi $sp, $sp, 4
	lw $t2, 0($sp)			# $t2 = width
	addi $sp, $sp, 4
	lw $t1, 0($sp)			# $t1 = end
	addi $sp, $sp, 4
	lw $t0, 0($sp)			# $t0 = start
	addi $sp, $sp, 4
	# loop setup
	move $t5, $zero			# $t5 = loop index start from 0
	# store the return address
	addi $sp, $sp, -4
	sw $ra, 0($sp)
draw_block_loop:
	beq $t5, $t2, draw_block_end
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
	move $a3, $t3			# color
	jal draw_row
	# restore $t0 and $t1 from the stack
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	# update start $t0 and end $t1
	add $t0, $t0, $t4
	add $t1, $t1, $t4
	# update loop
	addi $t5, $t5, 1
	j draw_block_loop
draw_block_end:
	# restore the return address from the stack
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra


##############################################################################
# GAME LOOP
##############################################################################

game_loop:
	# 1a. Check if key has been pressed
    	# 1b. Check which key has been pressed
   	# 2a. Check for collisions
	# 2b. Update locations (paddle, ball)
	# 3. Draw the screen
	# 4. Sleep

	#j game_loop	#5. Go back to 1
	li $v0, 10
	syscall
