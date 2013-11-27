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
.equ inputStatus_inputOk,			0
.equ inputStatus_acceptedControlCharacter,	1

.equ q_reject,	0
.equ q_accept,	1

.equ r_reject,	0
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
scanString:		.asciz "%2s"
scanResult:		.asciz "  "
sscanString:		.asciz "%d"
sscanResult:		.word 0
msgYuck:		.asciz "%s? Yuck! Try again!\r\n-> "
msgYouEntered:		.asciz "You entered %d\r\n"
hex1:			.asciz "Test mode = 0x%08X\r\n"
hex2:			.asciz "Min = 0x%08X\r\n"
hex3:			.asciz "Max = 0x%08X\r\n"
hex4:			.asciz "q = 0x%08X\r\n"
hex5:			.asciz "r = 0x%08X\r\n"
hex6:			.asciz "At 0x%08X = 0x%08X\r\n"
debug1: .asciz "Here1 0x%08X 0x%08X\r\n"
debug2: .asciz "here2 %d\r\n"

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

.L2_tryAgain:
	ldr r0, =scanString
	ldr r1, =scanResult
	bl scanf

	ldr r0, =scanResult
	mov r1, #0
	mov r2, #10
	bl strtol

	ldr r0, =scanResult
	ldr r1, =sscanString
	ldr r2, =sscanResult
	bl sscanf

	ldr r1, =scanResult
	ldr r1, [r1]
	mov r2, #0xFF
	lsl r2, #8
	add r2, #0xFF
	and r1, r2
	orr r1, #0x20

	cmp r1, #'q'
	bne .L2_checkR

	cmp r7, #q_accept
	bne .L2_yuck	
	b .L2_acceptControlCharacter

.L2_checkR:
	cmp r1, #'r'
	bne .L2_notQnotR

	cmp r8, #r_accept
	bne .L2_yuck
	b .L2_acceptControlCharacter

.L2_notQnotR:
	ldr r0, =sscanResult
	ldr r0, [r0]
	cmp r0, r5	@ Check against min
	blo .L2_yuck

	cmp r0, r6	@ Check against max
	bhi .L2_yuck

	mov r1, #inputStatus_inputOk
	b .L2_epilogue

.L2_yuck:
	ldr r0, =msgYuck
	ldr r1, =scanResult
	bl printf
	b .L2_tryAgain
 
.L2_acceptControlCharacter:
	mov r1, #inputStatus_acceptedControlCharacter

.L2_epilogue:
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

.L2_debug1: .asciz "sscanResult = 0x%08X\r\n"

msgEnterSpreadsheetSize:	.asciz "Enter the number of cells for the spreadsheet [2, 10] or 'Q' to quit\r\n"
msgDataWidthOptions:		.asciz "Data width options (enter 'Q' to quit):\r\n"
msgSeparator:			.asciz "---------------------------------------\r\n"
msgSelectDataWidth:		.asciz "Select data width:\r\n"
msgPrompt:			.asciz "-> "

dwo8:	.asciz "8 bits - range is [-128, 127]"
dwo16:	.asciz "16 bits - range is [-32768, 32767]"
dwo32:	.asciz "32 bits - range is [-2147483648, 2147483647]"

.align 3
dataWidthOptions: .word dwo8, dwo16, dwo32
.equ numberOfDataWidthOptions, 3

.section .text

getSpreadsheetSpecs:
	push {lr}

	ldr r0, =msgEnterSpreadsheetSize
	bl printf
	ldr r0, =msgPrompt
	bl printf

	mov r0, #r_reject
	push {r0}
	ldr r0, =testMode
	ldr r0, [r0]
	mov r1, #minimumCellCount
	mov r2, #maximumCellCount
	mov r3, #q_accept
	bl getMenuSelection

	cmp r1, #inputStatus_acceptedControlCharacter
	beq epilogue

	ldr r1, =numberOfCellsInSpreadsheet
	str r0, [r1]

	bl newline

	ldr r0, =msgDataWidthOptions
	bl printf
	ldr r0, =msgSeparator
	bl printf

	ldr r0, =dataWidthOptions
	mov r1, #numberOfDataWidthOptions
	bl showList

	mov r0, #r_reject
	push {r0}
	ldr r0, =testMode
	ldr r0, [r0]
	mov r1, #1
	mov r2, #3
	mov r3, #q_accept
	bl getMenuSelection

	cmp r1, #inputStatus_acceptedControlCharacter
	beq epilogue

	sub r0, #1	@ Convert 1-based to 0-based
	mov r1, #1	@ Will be data width
	lsl r1, r0	@ Now r1 has the data width in bytes
	ldr r0, =cellWidthInBytes
	str r1, [r0]

epilogue:
	mov r0, #0
	mov r1, #inputStatus_inputOk
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ newline
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data
msgNewline: .asciz "\r\n"

.section .text
newline:
	push {lr}
	ldr r0, =msgNewline
	bl printf
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ showList
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

msgListElement: .asciz "%d. %s\r\n"
.L3_debug1: .asciz "r4 = 0x%08X, r5 = 0x%08X, r6 = 0x%08X\r\n"

.section .text

showList:
	push {lr}
	push {r4 - r6}

	mov r4, r0	@ list offset
	mov r5, r1	@ number of elements

.L3_loopInit:
	mov r6, #0

.L3_loopTop:
	add r6, r6, #1
	ldr r0, =msgListElement
	mov r1, r6
	ldr r2, [r4]
	bl printf

	add r4, r4, #4
	subs r5, r5, #1
	bne .L3_loopTop

	pop {r4 - r6}
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
msgByeNow:	.asciz "'Bye now!\r\n"

percentD: .asciz "%d\r\n"

msgTriumph: .asciz "%d cells in spreadsheet; %d bytes per cell\r\n"
.L0_debug1: .asciz "r0 = 0x%08X, r1 = 0x%08X\r\n"

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

	cmp r1, #inputStatus_acceptedControlCharacter
	beq actionQuit 

	ldr r0, =msgTriumph
	ldr r1, =numberOfCellsInSpreadsheet
	ldr r1, [r1]
	ldr r2, =cellWidthInBytes
	ldr r2, [r2]
	bl printf

actionQuit:
	ldr r0, =msgByeNow
	bl printf

	mov r7, $1		@ exit syscall
	svc 0			@ wake kernel

	.end

