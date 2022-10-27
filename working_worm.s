#
# COMP1521 18s1 -- Assignment 1 -- Worm on a Plane!
#
# Base code by Jashank Jeremy and Wael Alghamdi
# Tweaked (severely) by John Shepherd
#
# Set your tabstop to 8 to make the formatting decent

# Requires:
#  - [no external symbols]

# Provides:
	.globl	wormCol
	.globl	wormRow
	.globl	grid
	.globl	randSeed

	.globl	main
	.globl	clearGrid
	.globl	drawGrid
	.globl	initWorm
	.globl	onGrid
	.globl	overlaps
	.globl	moveWorm
	.globl	addWormToGrid
	.globl	giveUp
	.globl	intValue
	.globl	delay
	.globl	seedRand
	.globl	randValue

	# Let me use $at, please.
	.set	noat

# The following notation is used to suggest places in
# the program, where you might like to add debugging code
#
# If you see e.g. putc('a'), replace by the three lines
# below, with each x replaced by 'a'
#
# print out a single character
# define putc(x)
# 	addi	$a0, $0, x
# 	addiu	$v0, $0, 11
# 	syscall
# 
# print out a word-sized int
# define putw(x)
# 	add 	$a0, $0, x
# 	addiu	$v0, $0, 1
# 	syscall

####################################
# .DATA
	.data

	.align 4
wormCol:	.space	40 * 4
	.align 4
wormRow:	.space	40 * 4
	.align 4
grid:		.space	20 * 40 * 1

randSeed:	.word	0

main__0:	.asciiz "Invalid Length (4..20)"
main__1:	.asciiz "Invalid # Moves (0..99)"
main__2:	.asciiz "Invalid Rand Seed (0..Big)"
main__3:	.asciiz "Iteration "
main__4:	.asciiz "Blocked!\n"
dot:        .byte '.'
newline:    .asciiz"\n"
at:         .byte '@'
o:          .byte 'o'



	# ANSI escape sequence for 'clear-screen'
main__clear:	.asciiz "\033[H\033[2J"
# main__clear:	.asciiz "__showpage__\n" # for debugging

giveUp__0:	.asciiz "Usage: "
giveUp__1:	.asciiz " Length #Moves Seed\n"

####################################
# .TEXT <main>
	.text
main:

# Frame:	$fp, $ra, $s0, $s1, $s2, $s3, $s4
# Uses: 	$a0, $a1, $v0, $s0, $s1, $s2, $s3, $s4
# Clobbers:	$a0, $a1

# Locals:
#	- `argc' in $s0
#	- `argv' in $s1
#	- `length' in $s2
#	- `ntimes' in $s3
#	- `i' in $s4

# Structure:
#	main
#	-> [prologue]
#	-> main_seed
#	  -> main_seed_t
#	  -> main_seed_end
#	-> main_seed_phi
#	-> main_i_init
#	-> main_i_cond
#	   -> main_i_step
#	-> main_i_end
#	-> [epilogue]
#	-> main_giveup_0
#	 | main_giveup_1
#	 | main_giveup_2
#	 | main_giveup_3
#	   -> main_giveup_common

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	sw	$s2, -20($sp)
	sw	$s3, -24($sp)
	sw	$s4, -28($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -28

	# save argc, argv
	add	$s0, $0, $a0
	add	$s1, $0, $a1

	# if (argc < 3) giveUp(argv[0],NULL);
	slti	$at, $s0, 4
	bne	$at, $0, main_giveup_0

	# length = intValue(argv[1]);
	addi	$a0, $s1, 4	# 1 * sizeof(word)
	lw	$a0, ($a0)	# (char *)$a0 = *(char **)$a0
	jal	intValue

	# if (length < 4 || length >= 40)
	#     giveUp(argv[0], "Invalid Length");
	# $at <- (length < 4) ? 1 : 0
	slti	$at, $v0, 4
	bne	$at, $0, main_giveup_1
	# $at <- (length < 40) ? 1 : 0
	slti	$at, $v0, 40
	beq	$at, $0, main_giveup_1
	# ... okay, save length
	add	$s2, $0, $v0

	# ntimes = intValue(argv[2]);
	addi	$a0, $s1, 8	# 2 * sizeof(word)
	lw	$a0, ($a0)
	jal	intValue

	# if (ntimes < 0 || ntimes >= 100)
	#     giveUp(argv[0], "Invalid # Iterations");
	# $at <- (ntimes < 0) ? 1 : 0
	slti	$at, $v0, 0
	bne	$at, $0, main_giveup_2
	# $at <- (ntimes < 100) ? 1 : 0
	slti	$at, $v0, 100
	beq	$at, $0, main_giveup_2
	# ... okay, save ntimes
	add	$s3, $0, $v0

main_seed:
	# seed = intValue(argv[3]);
	add	$a0, $s1, 12	# 3 * sizeof(word)
	lw	$a0, ($a0)
	jal	intValue

	# if (seed < 0) giveUp(argv[0], "Invalid Rand Seed");
	# $at <- (seed < 0) ? 1 : 0
	slt	$at, $v0, $0
	bne	$at, $0, main_giveup_3

main_seed_phi:
	add	$a0, $0, $v0
	jal	seedRand

	# start worm roughly in middle of grid

	# startCol: initial X-coord of head (X = column)
	# int startCol = 40/2 - length/2;
	addi	$s4, $0, 2
	addi	$a0, $0, 40
	div	$a0, $s4
	mflo	$a0
	# length/2
	div	$s2, $s4
	mflo	$s4
	# 40/2 - length/2
	sub	$a0, $a0, $s4

	# startRow: initial Y-coord of head (Y = row)
	# startRow = 20/2;
	addi	$s4, $0, 2
	addi	$a1, $0, 20
	div	$a1, $s4
	mflo	$a1

	# initWorm($a0=startCol, $a1=startRow, $a2=length)
	add	$a2, $0, $s2
	jal	initWorm

main_i_init:
	# int i = 0;
	add	$s4, $0, $0
main_i_cond:
	# i <= ntimes  ->  ntimes >= i  ->  !(ntimes < i)
	#   ->  $at <- (ntimes < i) ? 1 : 0
	slt	$at, $s3, $s4
	bne	$at, $0, main_i_end

	# clearGrid();
	jal	clearGrid

	# addWormToGrid($a0=length);
	add	$a0, $0, $s2
	jal	addWormToGrid

	# printf(CLEAR)
	la	$a0, main__clear
	addiu	$v0, $0, 4	# print_string
	syscall

	# printf("Iteration ")
	la	$a0, main__3
	addiu	$v0, $0, 4	# print_string
	syscall

	# printf("%d",i)
	add	$a0, $0, $s4
	addiu	$v0, $0, 1	# print_int
	syscall

	# putchar('\n')
	addi	$a0, $0, 0x0a
	addiu	$v0, $0, 11	# print_char
	syscall

	# drawGrid();
	jal	drawGrid

	# Debugging? print worm pos as (r1,c1) (r2,c2) ...

	# if (!moveWorm(length)) {...break}
	add	$a0, $0, $s2
	jal	moveWorm
	bne	$v0, $0, main_moveWorm_phi

	# printf("Blocked!\n")
	la	$a0, main__4
	addiu	$v0, $0, 4	# print_string
	syscall

	# break;
	j	main_i_end

main_moveWorm_phi:
	addi	$a0, $0, 1
	jal	delay

main_i_step:
	addi	$s4, $s4, 1
	j	main_i_cond
main_i_end:

	# exit (EXIT_SUCCESS)
	# ... let's return from main with `EXIT_SUCCESS' instead.
	addi	$v0, $0, 0	# EXIT_SUCCESS

main__post:
	# tear down stack frame
	lw	$s4, -24($fp)
	lw	$s3, -20($fp)
	lw	$s2, -16($fp)
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

main_giveup_0:
	add	$a1, $0, $0	# NULL
	j	main_giveup_common
main_giveup_1:
	la	$a1, main__0	# "Invalid Length"
	j	main_giveup_common
main_giveup_2:
	la	$a1, main__1	# "Invalid # Iterations"
	j	main_giveup_common
main_giveup_3:
	la	$a1, main__2	# "Invalid Rand Seed"
	# fall through
main_giveup_common:
	# giveUp ($a0=argv[0], $a1)
	lw	$a0, ($s1)	# argv[0]
	jal	giveUp		# never returns

####################################
# clearGrid() ... set all grid[][] elements to '.'
# .TEXT <clearGrid>
	.text
clearGrid:

# Frame:	$fp, $ra, $s0, $s1
# Uses: 	$s0, $s1, $t1, $t2
# Clobbers:	$t1, $t2

# Locals:
#	- `row' in $s0
#	- `col' in $s1
#	- `&grid[row][col]' in $t1
#	- '.' in $t2

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -16

### to be done

    li $s0, 0               #int row = 0; 
    li $s1, 0               #int col = 0;
    lb $t2, dot             #$t2 = "."
    li $t3, 20              #NROWS
    li $t4, 40              #NCOLS
    la $t1, grid            #put address of grid[row][col] into $t3
loop_1:
    li $s1, 0               #col = 0;
    beq $s0, 20, end_loop   #if row = NROWS goto end_loop

sec:
    beq $s1, $t4, sec_exit  # if col = 40 
    mul $t5, $s0, $t4
    add $t5, $t5, $s1
    add $t5, $t5, $t1
    
    sb  $t2, ($t5)          # put dot into the address
    addi $s1, $s1, 1        # col++
    j sec
sec_exit:
    addi $s0, $s0, 1        #row++
    j loop_1
end_loop:
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

####################################
# drawGrid() ... display current grid[][] matrix
# .TEXT <drawGrid>
	.text
drawGrid:

# Frame:	$fp, $ra, $s0, $s1, $t1
# Uses: 	$s0, $s1
# Clobbers:	$t1

# Locals:
#	- `row' in $s0
#	- `col' in $s1
#	- `&grid[row][col]' in $t1

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -16
	
    li $s0, 0               #int row = 0;
    li $s1, 0               #int col = 0;
    la $t1, grid            #put address of grid[row][col] into $t3
    li $t3, 20              #NROWS
    li $t4, 40              #NCOLS
loop_1_DB:
    li $s1, 0               #col = 0;
    beq $s0, 20, end_loop_DB#if row = NROWS goto end_loop
sec_DB:
    beq $s1, $t4, exit_sec_DB#if col = 40 

    mul $t5, $s0, $t4       # $t0 = 40 * col  
    add $t5, $t5, $s1       # goto the cell
    add $t5, $t5, $t1       # t0 = t0 + base_address
    
    lb $a0,($t5)             #put what's in Grid address into a0
    li $v0,11                #print_string                       
    syscall    
    
    addi $s1, $s1, 1        # col++
    j sec_DB
exit_sec_DB:
    lb $a0, newline         #printf("\n")
    li $v0, 11
    syscall
    addi $s0, $s0, 1        #row ++;
    j loop_1_DB
end_loop_DB:
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# initWorm(col,row,len) ... set the wormCol[] and wormRow[]
#    arrays for a worm with head at (row,col) and body segements
#    on the same row and heading to the right (higher col values)
# .TEXT <initWorm>
	.text
initWorm:

# Frame:	$fp, $ra
# Uses: 	$a0, $a1, $a2, $t0, $t1, $t2
# Clobbers:	$t0, $t1, $t2

# Locals:
#	- `col' in $a0
#	- `row' in $a1
#	- `len' in $a2
#	- `newCol' in $t0
#	- `nsegs' in $t1
#	- temporary in $t2

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8
	

	li $t1, 1 					#int nsegs = 1;
	addi $t0, $a0, 1 			#int newCol = col + 1


	li $t4, 0 					# 0 byte offset 
	li $t2, 40 					#NCOLS 40
	li $t5, 4 					#int size 4

	sw $a0, wormCol($t4) 		#wormCol[0] = col
	sw $a1, wormRow($t4)		#wormRow[0] = row

L_initW:
	
	bge $t1, $a2, E_initW 		# if nsegs>=len break and go to end
	beq $t0, $t2, break_IW 		#if nsegs == NCOLS then jump to end
	mul $t6, $t5, $t1			#4*nsegs offset


	sw $t0, wormCol($t6)		# wormCol[newoffset] = newCol		
	sw $a1, wormRow($t6) 	    # wormRow[newoffset] = row
	addi $t0, $t0, 1			#newCol++
break_IW:	
	addi $t1, $t1, 1 		    #nsegs++;

	j L_initW

E_initW:
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra



####################################
# ongrid(col,row) ... checks whether (row,col)
#    is a valid coordinate for the grid[][] matrix
# .TEXT <onGrid>
	.text
onGrid:

# Frame:	$fp, $ra
# Uses: 	$a0, $a1, $v0
# Clobbers:	$v0

# Locals:
#	- `col' in $a0
#	- `row' in $a1

# Code:

    sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8
	
	li $t5, 20          # NROWS
    li $t6, 40          # NCOLS

    move $t0, $a0       # int con1 = col
    slti $t0, $t0, 0    # t0 = 1 if t0 < 0, or t0 = 0 
    not $t0, $t0        # t0 = 0 if t0 < 0, or t0 = 1
    
    move $t3, $a0       # int con2 = col;
    slti $t3, $t3, 40   # if(con2<40)con2 = 1,OR con2 = 0;
    
    and $t0, $t0, $t3   # t0 = (col >= 0 && col < NCOLS)
    
    li $t2, -1          # t2 = -1
    slt $t3, $t2, $a1   # t3 = 1 if -1 < row, Rd = 0 otherwise
    slt $t4, $a1, $t5   # t4 = 1 if row < NROWS, otherwise
    
    and $t2, $t3,$t4    # t2 = (row >= 0 && row < NROWS)
    and $t0, $t0,$t2    # t0 = t0 & t2
    move $v0, $t0
    
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# overlaps(r,c,len) ... checks whether (r,c) holds a body segment
# .TEXT <overlaps>
	.text
overlaps:

# Frame:	$fp, $ra
# Uses: 	$a0, $a1, $a2
# Clobbers:	$t6, $t7

# Locals:
#	- `col' in $a0
#	- `row' in $a1
#	- `len' in $a2
#	- `i' in $t6

# Code:
    sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8
    
    li $t6, 0               # int i = 0;
    la $t1, wormCol         # load address of wormCol into t1
    la $t2, wormRow         # load address of wormRow into t2
Loop_1_OL:
    beq $t6, $a2, return_0  # if (i = len), break
    j loop_2_OL
loop_2_OL:
    lw  $t3, ($t1)          # t3 = wormCol[i]
    lw  $t4, ($t2)          # t4 = wormRow[i]
    addi $t1, $t1 ,4
    addi $t2, $t2, 4
    beq $t3, $a0, case_1    # if wormCol[i] == col goto case 1
    
    addi $t6, $t6, 1        #i++
    j Loop_1_OL
case_1:
    beq $t4, $a1, return_1  # if wormRow[i] = row go return_1
    addi $t6, $t6, 1        #i++
    j Loop_1_OL
return_1:
    li $v0, 1
    lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

return_0:
    li $v0, 0              #v0 = 0
    lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# moveWorm() ... work out new location for head
#         and then move body segments to follow
# updates wormRow[] and wormCol[] arrays

# (col,row) coords of possible places for segments
# done as global data; putting on stack is too messy
	.data
	.align 4
possibleCol: .space 8 * 4	# sizeof(word)
possibleRow: .space 8 * 4	# sizeof(word)

# .TEXT <moveWorm>
	.text
moveWorm:

# Frame:	$fp, $ra, $s0, $s1, $s2, $s3, $s4, $s5, $s6, $s7
# Uses: 	$s0, $s1, $s2, $s3, $s4, $s5, $s6, $s7, $t0, $t1, $t2, $t3
# Clobbers:	$t0, $t1, $t2, $t3

# Locals:
#	- `col' in $s0
#	- `row' in $s1
#	- `len' in $s2
#	- `dx' in $s3
#	- `dy' in $s4
#	- `n' in $s7
#	- `i' in $t0
#	- tmp in $t1
#	- tmp in $t2
#	- tmp in $t3
# 	- `&possibleCol[0]' in $s5
#	- `&possibleRow[0]' in $s6

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	sw	$s2, -20($sp)
	sw	$s3, -24($sp)
	sw	$s4, -28($sp)
	sw	$s5, -32($sp)
	sw	$s6, -36($sp)
	sw	$s7, -40($sp),
	la	$fp, -4($sp)
	
	addiu	$sp, $sp, -40

    move  $s2, $a0                         # $s2 = len
    li    $s3, -1                          # dx = -1
    li    $s4, -1                          # dy = -1
    li    $s7, 0                           # n = 0
    li    $t7, 1                           # 1
   
loop_1_MV:
    bgt   $s3, $t7, loop_1_MV_end           # if dx > 1  end_loop
    li    $s4, -1                          # dy = -1
   
loop_1_MV_1:
    bgt   $s4, $t7, end_MW                   # if dx > 1  end_inner_loop
   
    lw    $s0, wormCol($0)
    add   $s0, $s0, $s3                    # col = wormCol[0] + dx
    
    lw    $s1, wormRow($0)
    add   $s1, $s1, $s4                    # row = wormRow[0] + dy

    move  $a0, $s0                         # $a0 = col
    move  $a1, $s1                         # $a1 = row
    move  $a2, $s2                         # $a2 = len
    jal   onGrid
    beqz  $v0, compare_1            # if onGrid() == 0  end_if
    jal   overlaps
    bnez  $v0, compare_1            # if overlaps() != 0  end_if
   
    li    $t8, 4
    mul   $t8, $t8, $s7                    # $t8 = n * sizeof(int)
    sw    $s0, possibleCol($t8)            # possibleCol[n] = col
    sw    $s1, possibleRow($t8)            # possibleRow[n] = row
    addi  $s7, $s7, 1                      # n++

compare_1:   
    addi  $s4, $s4, 1                      # dy++
    j     loop_1_MV_1
   
end_MW:
    addi  $s3, $s3, 1                      # dx++
    j     loop_1_MV

loop_1_MV_end:
    li    $v0, 0
    beqz  $s7, MW_return                   # if n == 0  return 0

    addi  $t0, $s2, -1                     # i = len - 1

MW_loop2:
    blez  $t0, MW_loop2_end                # if i <= 0  end_loop
    addi  $t1, $t0, -1                     # $t1 = i - 1
    li    $t2, 4                           # $t2 = sizeof(int)
    mul   $t1, $t1, $t2                    # $t1 = (i - 1) * sizeof(int)
    mul   $t2, $t2, $t0                    # $t2 = i * sizeof(int)
    lw    $t3, wormRow($t1)                # $t3 = wormRow[i - 1]
    sw    $t3, wormRow($t2)                # wormRow[i] = wormRow[i - 1]
    lw    $t3, wormCol($t1)                # $t3 = wormCol[i - 1]
    sw    $t3, wormCol($t2)                # wormCol[i] = wormCol[i - 1]

    addi  $t0, $t0, -1                     # i--
    j     MW_loop2
      
MW_loop2_end:
    move  $a0, $s7                         # $a0 = n
    jal randValue
    move  $t0, $v0                         # i = randValue(n)

    li    $t2, 4                           # $t2 = sizeof(int)
    mul   $t2, $t2, $t0                    # $t2 = i * sizeof(int)
    lw    $t3, possibleRow($t2)            # $t3 = possibleRow[i]
    sw    $t3, wormRow($0)                 # wormRow[0] = possibleRow[i]
    lw    $t3, possibleCol($t2)            # $t3 = possibleCol[i]
    sw    $t3, wormCol($0)                 # wormCol[0] = possibleCol[i]

    li    $v0, 1
   
MW_return:

	# tear down stack frame
	lw	$s7, -36($fp)
	lw	$s6, -32($fp)
	lw	$s5, -28($fp)
	lw	$s4, -24($fp)
	lw	$s3, -20($fp)
	lw	$s2, -16($fp)
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)

	jr	$ra

	
####################################
# addWormTogrid(N) ... add N worm segments to grid[][] matrix
#    0'th segment is head, located at (wormRow[0],wormCol[0])
#    i'th segment located at (wormRow[i],wormCol[i]), for i > 0
# .TEXT <addWormToGrid>
	.text
addWormToGrid:

# Frame:	$fp, $ra, $s0, $s1, $s2, $s3
# Uses: 	$a0, $s0, $s1, $s2, $s3, $t1
# Clobbers:	$t1

# Locals:
#	- `len' in $a0
#	- `&wormCol[i]' in $s0
#	- `&wormRow[i]' in $s1
#	- `grid[row][col]'
#	- `i' in $t0

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	sw	$s2, -20($sp)
	sw	$s3, -24($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -24
    
    lw $t1, wormRow($0)     # row = wormRow[0];
    lw $t2, wormCol($0)     # col = wormCol[0];
    li $t3, 40              # 40
   
    mul $t3, $t3, $t1       # $t6 = 40 * col  
    add $t3, $t3, $t2       # goto the cell
    add $t4, $0,  0x40       # t0 = t0 + base_address
    sb $t4, grid($t3)
    
    li $t0, 1               # i = 1
    add $t4, $0,  0x6F       # t0 = t0 + base_address
loop_AG:
    beq $t0, $a0, end_AG    # if i = len goto end
   
    li $t5, 4
    mul $t5, $t0, $t5
    lw $t1, wormRow($t5)     # row = wormRow[i];
    lw $t2, wormCol($t5)     # col = wormCol[i];
    li $t3, 40              # 40
   
    mul $t3, $t3, $t1       # $t6 = 40 * col  
    add $t3, $t3, $t2       # goto the cell
    sb $t4, grid($t3)
    addi $t0, $t0, 1
    
    j loop_AG

end_AG:    
	# tear down stack frame
	lw	$s3, -20($fp)
	lw	$s2, -16($fp)
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

####################################
# giveUp(msg) ... print error message and exit
# .TEXT <giveUp>
	.text
giveUp:

# Frame:	frameless; divergent
# Uses: 	$a0, $a1
# Clobbers:	$s0, $s1

# Locals:
#	- `progName' in $a0/$s0
#	- `errmsg' in $a1/$s1

# Code:
	add	$s0, $0, $a0
	add	$s1, $0, $a1

	# if (errmsg != NULL) printf("%s\n",errmsg);
	beq	$s1, $0, giveUp_usage

	# puts $a0
	add	$a0, $0, $s1
	addiu	$v0, $0, 4	# print_string
	syscall

	# putchar '\n'
	add	$a0, $0, 0x0a
	addiu	$v0, $0, 11	# print_char
	syscall

giveUp_usage:
	# printf("Usage: %s #Segments #Moves Seed\n", progName);
	la	$a0, giveUp__0
	addiu	$v0, $0, 4	# print_string
	syscall

	add	$a0, $0, $s0
	addiu	$v0, $0, 4	# print_string
	syscall

	la	$a0, giveUp__1
	addiu	$v0, $0, 4	# print_string
	syscall

	# exit(EXIT_FAILURE);
	addi	$a0, $0, 1 # EXIT_FAILURE
	addiu	$v0, $0, 17	# exit2
	syscall
	# doesn't return

####################################
# intValue(str) ... convert string of digits to int value
# .TEXT <intValue>
	.text
intValue:

# Frame:	$fp, $ra
# Uses: 	$t0, $t1, $t2, $t3, $t4, $t5
# Clobbers:	$t0, $t1, $t2, $t3, $t4, $t5

# Locals:
#	- `s' in $t0
#	- `*s' in $t1
#	- `val' in $v0
#	- various temporaries in $t2

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

	# int val = 0;
	add	$v0, $0, $0

	# register various useful values
	addi	$t2, $0, 0x20 # ' '
	addi	$t3, $0, 0x30 # '0'
	addi	$t4, $0, 0x39 # '9'
	addi	$t5, $0, 10

	# for (char *s = str; *s != '\0'; s++) {
intValue_s_init:
	# char *s = str;
	add	$t0, $0, $a0
intValue_s_cond:
	# *s != '\0'
	lb	$t1, ($t0)
	beq	$t1, $0, intValue_s_end

	# if (*s == ' ') continue; # ignore spaces
	beq	$t1, $t2, intValue_s_step

	# if (*s < '0' || *s > '9') return -1;
	blt	$t1, $t3, intValue_isndigit
	bgt	$t1, $t4, intValue_isndigit

	# val = val * 10
	mult	$v0, $t5
	mflo	$v0

	# val = val + (*s - '0');
	sub	$t1, $t1, $t3
	add	$v0, $v0, $t1

intValue_s_step:
	# s = s + 1
	addi	$t0, $t0, 1	# sizeof(byte)
	j	intValue_s_cond
intValue_s_end:

intValue__post:
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

intValue_isndigit:
	# return -1
	addi	$v0, $0, -1
	j	intValue__post

####################################
# delay(N) ... waste some time; larger N wastes more time
#                            makes the animation believable
# .TEXT <delay>
	.text
delay:

# Frame:	$fp, $ra
# Uses: 	$a0
# Clobbers:	$t0, $t1, $t2

# Locals:
#	- `n' in $a0
#	- `x' in $6
#	- `i' in $t0
#	- `j' in $t1
#	- `k' in $t2

# Code:
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

    li  $t6, 3                          # $t6 = x = 3
    li  $t0, 0                          # $t0 = i = 0
    li  $t1, 0                          # $t1 = j = 0
    li  $t2, 0                          # $t2 = k = 0
    li  $t3, 3
delay_loop:
    bge $t0, $a0, delay_loop_end

delay_innerloop:
    li   $t4, 40000
    slt  $t8, $t1, $t4            # $t8 = (j < 40000)? 1: 0
    beqz $t8, delay_innerloop_end

delay_inner2loop:
    slti $t7, $t2, 1000                 # $t7 = (k < 1000)? 1: 0
    beqz $t7, delay_inner2loop_end
    mul $t6, $t6, $t3
    addi $t2, $t2, 1
    j   delay_inner2loop
    
delay_inner2loop_end:
    addi $t1, $t1, 1
    j   delay_innerloop
    
delay_innerloop_end:
    addi $t0, $t0, 1
    j   delay_loop
delay_loop_end:


	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra



####################################
# seedRand(Seed) ... seed the random number generator
# .TEXT <seedRand>
	.text
seedRand:

# Frame:	$fp, $ra
# Uses: 	$a0
# Clobbers:	[none]

# Locals:
#	- `seed' in $a0

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

	# randSeed <- $a0
	sw	$a0, randSeed

seedRand__post:
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

####################################
# randValue(n) ... generate random value in range 0..n-1
# .TEXT <randValue>
	.text
randValue:

# Frame:	$fp, $ra
# Uses: 	$a0
# Clobbers:	$t0, $t1

# Locals:	[none]
#	- `n' in $a0

# Structure:
#	rand
#	-> [prologue]
#       no intermediate control structures
#	-> [epilogue]

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

	# $t0 <- randSeed
	lw	$t0, randSeed
	# $t1 <- 1103515245 (magic)
	li	$t1, 0x41c64e6d

	# $t0 <- randSeed * 1103515245
	mult	$t0, $t1
	mflo	$t0

	# $t0 <- $t0 + 12345 (more magic)
	addi	$t0, $t0, 0x3039

	# $t0 <- $t0 & RAND_MAX
	and	$t0, $t0, 0x7fffffff

	# randSeed <- $t0
	sw	$t0, randSeed

	# return (randSeed % n)
	div	$t0, $a0
	mfhi	$v0

rand__post:
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

