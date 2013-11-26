@* Spreadsheet
@*
@* written by			Rob Bishop
@* created on			23 October 2013
@* last modified on		17 November 2013
@*
@* Create a simple one-row spreadsheet. The number of cells in the row
@*		will be selected by the user (minimum number of cells: 2, maximum
@*		number of cells: 10), with one cell extra to contain a calculation result.
@*
@* Your program must provide the following functionality:
@*
@* 1. allow the user to specify how many cells are desired (add one extra cell for the calculation)
@*
@* 2. allow the user to specify what data type (int8, int16, or int32) is desired for her/his "spreadsheet"
@*
@* 3. dynamically allocate a number of bytes to match the number of cells (plus one for the calculation cell)
@*		desired by the user, scaled to match the selected data type -- default value for each cell is zero (0)
@*
@* 4. allow the user to select individual cells (by number) and edit the contents of these cells
@*
@* 5. allow the user to select between sum, average, minimum value, and maximum value calculations
@*		(default is sum) -- the selected calculation will be run on the cells and stored/displayed in the
@*		extra/calculation result cell
@*
@* 6. display the type and result (using the extra/calculation cell) of the calculation (sum, avg, min,
@*		or max) selected by the user -- on overflow (which may happen for sum and average (since average
@*		uses sum), also display "[ERROR]" next to the result
@*
@* 7. allow the user to reset -- the current row of cells will be freed from memory and the user will be
@*		returned to the prompt and be asked once again for the number of cells and the data type desired
@*
@* 8. allow the user to quit at any time -- to achieve this, you should include a menu of options (edit, change
@*		calculation, change presentation, reset, quit)
@*
@* 9. above the menu of options, display all of the cell values and the calculation result cell vertically
@*		(up-and-down) -- this display should be updated each time the user does something that changes the
@*		contents of any of the cells
@*
@* 10. allow the user to toggle between binary, decimal, and hexadecimal presentations of the values in all
@*		of the cells (including the calculation result cell) -- default is decimal
@*/
.equ q_reject,	0
.equ q_accept,	1

.equ r_reject,	0xCE
.equ r_accept,	1

.equ menuMode_main,			0
.equ menuMode_changeFormula,		1
.equ menuMode_changeDataRepresentation,	2
.equ menuMode_getCellToEdit,		3
.equ menuMode_getNewValueForCell,	4

.equ formula_sum,	0
.equ formula_average,	1
.equ formula_minimum,	2
.equ formula_maximum,	3

.equ representationMode_hex, 0
.equ representationMode_dec, 1
.equ representationMode_bin, 2

.section .bss

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ clearScreen()
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

msgClearScreen: .ascii "\033[2J\033[H"
L_msgClearScreen = . - msgClearScreen

.section .text

clearScreen:
	push {r7}
	mov r0, $1
	ldr r1, =msgClearScreen
	ldr r2, =L_msgClearScreen
	mov r7, $4
	svc 0
	pop {r7}
	mov pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ displaySheet()
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .text

displaySheet:
	push {lr}

.L1_loopInit:
	ldr r5, =spreadsheetData
	mov r4, #0

.L1_loopTop:
	cmp r4, #10
	bhs .L1_loopExit

	ldr r0, =percentD
	ldr r1, [r5]
	bl printf

.L1_loopBottom:
	add r5, r5, #4
	add r4, r4, #1
	b .L1_loopTop

.L1_loopExit:
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getMenuSelection()
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

msgEnterAnything:	.asciz "Enter something! -> "
scanString:		.asciz "%d"
scanResult:		.word 0
msgYouEntered:		.asciz "You entered %d\r\n"
hex1:			.asciz "Test mode = 0x%08X\r\n"
hex2:			.asciz "Min = 0x%08X\r\n"
hex3:			.asciz "Max = 0x%08X\r\n"
hex4:			.asciz "q = 0x%08X\r\n"
hex5:			.asciz "r = 0x%08X\r\n"
hex6:			.asciz "At 0x%08X = 0x%08X\r\n"

.section .text

getMenuSelection:
	push {lr}
	push {r4 - r8}

	mov r4, r0	@ testMode
	mov r5, r1	@ minimum
	mov r6, r2	@ maximum
	mov r7, r3	@ accept or reject 'q'

	mov r8, sp
	add r8, #24
	ldr r8, [r8]	@ accept or reject 'r'

	ldr r0, =hex1
	mov r1, r4
	bl printf

	ldr r0, =hex2
	mov r1, r5
	bl printf

	ldr r0, =hex3
	mov r1, r6
	bl printf

	ldr r0, =hex4
	mov r1, r7
	bl printf

	ldr r0, =hex5
	mov r1, r8
	bl printf

	ldr r0, =scanString
	ldr r1, =scanResult
	bl scanf

	ldr r0, =msgYouEntered
	ldr r1, =scanResult
	ldr r1, [r1]
	bl printf

	pop {r4 - r8}
	pop {lr}
	add sp, #4
	bx lr
	
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getSpreadsheetSpecs
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.equ minimumCellCount, 2
.equ maximumCellCount, 10

.section .data

msgEnterSpreadsheetSize:	.asciz "Enter the number of cells for the spreadsheet [2, 10] or 'Q' to quit\r\n"
msgDataWidthOptions:		.asciz "Data width options (enter 'Q' to quit):\r\n"
msgSeparator:			.asciz "---------------------------------------\r\n"
msgSelectDataWidth:		.asciz "Select data width:\r\n"
msgPrompt:			.asciz "-> "

dataWidthOptions:		.asciz "8 bits - range is [-128, 127]", "16 bits - range is [-32768, 32767]", "32 bits - range is [-2147483648, 2147483647]"

.section .text

getSpreadsheetSpecs:
	push {lr}

	mov r0, #r_reject
	push {r0}
	mov r0, #0 @testMode
	mov r1, #minimumCellCount
	mov r2, #maximumCellCount
	mov r3, #q_accept
	bl getMenuSelection

	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ main
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

testMode:			.word 0
numberOfCellsInSpreadsheet:	.word 0
cellWidthInBytes:		.word 0

formula:			.word 0
representationMode:		.word 0
menuMode:			.word 0
cellToEdit:			.word 0
overflowFlag:			.word 0

spreadsheetData:		.word 47, 48, 49, 50, 51, 19, 18, 17, 16, 15
offsetOfResultCell:		.word 0

operationsFunction:		.word 0

msgGreeting:	.asciz "Greetings, data analyzer.\r\n\r\n"
msgSetupIntro:	.asciz "To set up, enter spreadsheet size and data width.\r\n"

percentD: .asciz "%d\r\n"

.section .text

	.global main

main:
	mov r0, #1
	ldr r1, =testMode
	str r0, [r1]

	bl clearScreen

greet:
	ldr r0, =msgGreeting
	bl printf

showSetupIntro:
	mov r0, #menuMode_main
	ldr r1, =menuMode
	str r0, [r1]

	mov r0, #formula_sum
	ldr r1, =formula
	str r0, [r1]

	mov r0, #representationMode_dec
	ldr r1, =representationMode
	str r0, [r1]

	ldr r0, =msgSetupIntro
	bl printf

	bl getSpreadsheetSpecs 

	mov r7, $1		@ exit syscall
	svc 0			@ wake kernel

	.end

