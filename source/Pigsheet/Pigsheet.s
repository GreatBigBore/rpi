@* Pigsheet
@*
@* written by			Rob Bishop
@* created on			11 December 2013
@* last modified on		11 December 2013
@*/

.equ inputStatus_inputOk,			0
.equ inputStatus_inputNotOk,			1
.equ inputStatus_acceptedControlCharacter,	2

.equ operation_store, 0
.equ operation_display, 1
.equ operation_initAForMin, 2
.equ operation_initAForMax, 3
.equ operation_min, 4
.equ operation_max, 5
.equ operation_accumulate, 6
.equ operation_validateRange, 7

.equ terminalCommand_clearScreen, 0
.equ terminalCommand_cursorUp, 1
.equ terminalCommand_clearToEOL, 2
.equ terminalCommand_colorsError, 3
.equ terminalCommand_colorsNormal, 4

.equ q_reject,	0
.equ q_accept,	1

.equ r_reject,	0
.equ r_accept,	1

.equ inputBufferSize, 100

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Some macros to make the code a little bit easier to read
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.macro mFunctionSetup
	push {fp}	@ setup local stack frame
	mov fp, sp

	push {lr}	@ preserve return address
	push {v1 - v7}	@ always preserve caller's locals

	push {a1 - a4}	@ Transfer scratch regs to...
	pop  {v1 - v4}	@ local variable regs
.endm

.macro mFunctionBreakdown argumentCount
	pop {v1 - v7}	@ restore caller's locals
	pop {lr}	@ restore return address

	mov sp, fp	@ restore caller's stack frame
	pop {fp}

	add sp, #\argumentCount * 4
.endm

.macro mTerminalCommand operation
	mov a1, \operation
	bl terminalCommand
.endm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ newline
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data
msgNewline: .asciz "\n"

.section .text
newline:
	push {lr}
	ldr r0, =msgNewline
	bl printf
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ terminalCommand
@
@	a1 the command to send
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L25_cmdClearScreen:	.asciz "\033[2J\033[H"
.L25_msgCursorUp:	.asciz "\033[A"
.L25_msgClearToEOL:	.asciz "\033[K"
.L25_colorsError:	.asciz "\033[37;41m"
.L25_colorsNormal:	.asciz "\033[37;40m"

.L25_commands:
	.word .L25_cmdClearScreen, .L25_msgCursorUp, .L25_msgClearToEOL
	.word .L25_colorsError, .L25_colorsNormal

.section .text

terminalCommand:
	push {lr}
	ldr r1, =.L25_commands
	ldr a1, [r1, a1, lsl #2]	@ the command to send
	bl printf
	pop {lr}
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ displaySheet()
@
@ stack:
@	 +4 presentation mode
@	 +8 formula
@	 +12 overflow accumulator
@
@ registers:
@	a1 ops function
@	a2 spreadsheet data
@	a3 number of cells to display
@	a4 data width
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L1_msgSpreadsheetHeader:	.asciz "Pigsheet\n\n"
.L1_cellNumber:			.asciz "%9d. "

.section .text
.align 3

	rOperationsFunction	.req v1
	rSpreadsheetAddress	.req v2
	rNumberOfCellsToDisplay	.req v3
	rDataWidthInBytes	.req v4
	rLoopCounter		.req v5

displaySheet:
	mFunctionSetup	@ Setup stack frame and local variables

	ldr a1, =.L1_msgSpreadsheetHeader
	bl printf

.L1_loopInit:
	mov rLoopCounter, #0

.L1_loopTop:
	cmp rLoopCounter, rNumberOfCellsToDisplay
	bhs .L1_loopExit

	ldr a1, =.L1_cellNumber
	add a2, rLoopCounter, #1
	bl printf

	ldr a1, [fp, #4]		@ a1 = presentation indicator
	mov a2, rSpreadsheetAddress	@ spreadsheet
	mov a3, rLoopCounter		@ cell index
	mov a4, #operation_display
	blx rOperationsFunction		@ display current cell per data width 
	bl newline

.L1_loopBottom:
	add rLoopCounter, rLoopCounter, #1
	b .L1_loopTop

.L1_loopExit:
	bl newline

	mFunctionBreakdown 3	@ restore caller's locals and stack frame
	bx lr

	.unreq rOperationsFunction
	.unreq rSpreadsheetAddress
	.unreq rNumberOfCellsToDisplay
	.unreq rDataWidthInBytes
	.unreq rLoopCounter

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getCellToEdit
@
@ stack: 
@	+4 testMode
@
@ registers:
@	a1 lowest acceptable cell number
@	a2 highest acceptable cell number
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L12_msgInstructions:
	.asciz "Directions (enter 'Q' to quit, 'R' to return to the main menu):\n"
.L12_msgSeparator:
	.asciz "---------------------------------------------------------------\n"

.L12_msgSelectCell:
	.asciz "Select the cell to edit [%d, %d]\n"

.section .text
.align 3

	rMinimumCellNumber	.req v1
	rMaximumCellNumber	.req v2

getCellToEdit:
	mFunctionSetup	@ Setup stack frame and local variables

	ldr r0, =.L12_msgInstructions
	bl printf
	ldr r0, =.L12_msgSeparator
	bl printf

	ldr a1, =.L12_msgSelectCell
	mov a2, rMinimumCellNumber
	mov a3, rMaximumCellNumber
	bl printf

	bl promptForSelection

	ldr r0, [fp, #4]		@ test mode
	push {r0}
	mov a1, rMinimumCellNumber
	mov a2, rMaximumCellNumber
	mov a3, #q_accept		@ accept 'q' for quit
	mov a4, #r_accept		@ accept 'r' to go up a menu
	bl getMenuSelection

	mFunctionBreakdown 1	@ restore caller's locals and stack frame
	bx lr

	.unreq rMinimumCellNumber
	.unreq rMaximumCellNumber

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getCellValueDec
@
@ stack:
@	+4 test mode
@
@ registers:
@	a1 operations function
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

.section .data

.L19_getsBuffer:	.skip inputBufferSize
.L19_scanf:		.asciz "%d"
.L19_scanfResult:	.word 0

.section .text
.align 3

	rOperationsFunction	.req v1
	rFirstPass		.req v2
	rTestMode		.req v3

getCellValueDec:
	mFunctionSetup	@ Setup stack frame and local variables

	ldr rTestMode, [fp, #4]

	mov rFirstPass, #1	@ remember we're on the first pass

.L19_tryAgain:
	ldr a1, =.L19_getsBuffer
	bl gets

	ldr r0, =.L19_getsBuffer
	ldrh r0, [r0]		@ get only 2 bytes to check for "q\0" or "r\0"
	orr r0, #0x20		@ make sure it's lowercase

	mov r1, #inputStatus_acceptedControlCharacter
	cmp r0, #'q'
	beq .L19_epilogue
	cmp r0, #'r'
	beq .L19_epilogue

	and r0, #0xFF		@ if in test mode, allow // comments in input
	cmp r0, #'/'
	bne .L19_inputFirstStep
	cmp rTestMode, #1
	beq .L19_tryAgain

.L19_inputFirstStep:
	ldr a1, =.L19_getsBuffer
	ldr a2, =.L19_scanf
	ldr a3, =.L19_scanfResult
	bl sscanf

	ldr a1, =.L19_getsBuffer

.L19_skippingWhitespace:
	ldrb r1, [a1]
	cmp r1, #' '
	bhi .L19_foundNonWhitespace
	cmp r1, #0	@ null terminator--end of input
	beq .L19_yuck	@ nothing but whitespace? yuck!
	add a1, #1
	b .L19_skippingWhitespace

.L19_foundNonWhitespace:
	@ a1 -> first usable char in gets buffer
	ldr a2, =.L19_scanf
	ldr a3, =.L19_scanfResult
	ldr a3, [a3]
	bl matchInputToResult
	cmp r1, #inputStatus_inputNotOk
	beq .L19_yuck

	ldr a1, =.L19_scanfResult
	ldr a1, [a1]
	mov a4, #operation_validateRange
	blx rOperationsFunction	@ returns input status in r1

	cmp r1, #inputStatus_inputOk
	bne .L19_yuck
	ldr r0, =.L19_scanfResult
	ldr r0, [r0]
	b .L19_epilogue

.L19_yuck:
	ldr a1, =.L19_getsBuffer
	mov a2, #0
	mov a3, rFirstPass
	bl sayYuck

	mov rFirstPass, #0
	b .L19_tryAgain

.L19_epilogue:
	mFunctionBreakdown 1	@ restore caller's locals and stack frame
	bx lr

	.unreq rFirstPass
	.unreq rOperationsFunction
	.unreq rTestMode
	
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getNewValueForCell
@
@ stack: 
@	+4 testMode
@
@ registers:
@	a1 operations function
@	a2 cell index
@	a3 data width in bytes
@	a4 data presentation mode
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L13_jumpTable:
	.word 0, 0	@ in case I want to bring binary back
	.word menuGetCellValueDec, getCellValueDec
	.word 0, 0	@ in case I want to bring hex back

.section .text
.align 3

	rOperationsFunction	.req v1
	rCellIndex		.req v2
	rDataWidthInBytes	.req v3
	rPresentationMode	.req v4
	rMenuFunction		.req v5
	rInputFunction		.req v6

getNewValueForCell:
	mFunctionSetup	@ Setup stack frame and local variables

	ldr r0, =.L13_jumpTable
	add r0, rPresentationMode, lsl #3
	ldr rMenuFunction, [r0]
	ldr rInputFunction, [r0, #4]

	ldr r0, [fp, #4]
	push {r0}			@ test mode
	mov a1, rCellIndex
	mov a2, rDataWidthInBytes
	mov a3, rOperationsFunction
	blx rMenuFunction

	ldr r0, [fp, #4]
	push {r0}			@ test mode
	mov a1, rOperationsFunction
	mov a2, rDataWidthInBytes
	blx rInputFunction

	mFunctionBreakdown 1	@ restore caller's locals and stack frame
	bx lr

	.unreq rOperationsFunction
	.unreq rCellIndex
	.unreq rDataWidthInBytes
	.unreq rPresentationMode
	.unreq rMenuFunction
	.unreq rInputFunction

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getMainSelection
@
@ stack: 
@	+4 testMode
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L5_msgInstructions:	.asciz "Options (enter 'Q' to quit):\n"
.L5_msgSeparator:	.asciz "----------------------------\n"

mo_editCell:		.asciz "Edit cell"
mo_resetSpreadsheet:	.asciz "Reset"
mo_randomValues:	.asciz "Fill cells with random values"

menuOptions: .word mo_editCell, mo_resetSpreadsheet, mo_randomValues

.equ menuOptionsCount, 3

.section .text
.align 3

getMainSelection:
	mFunctionSetup

	ldr r0, [fp, #4]
	mov r1, #q_accept
	mov r2, #r_reject
	push {r0 - r2}
	ldr a1, =.L5_msgInstructions
	ldr a2, =.L5_msgSeparator
	ldr a3, =menuOptions
	mov a4, #menuOptionsCount
	bl runMenu

	mFunctionBreakdown 1
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getMenuSelection
@
@ stack:
@	+4 test mode
@
@ registers:
@	a1 minimum acceptable input
@	a2 maximum acceptable input
@	a3 accept/reject 'q'
@	a4 accept/reject 'r'
@
@ returns:
@	r0 user input
@	r1 input status
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L2_getsBuffer:		.skip inputBufferSize
.L2_scanf:		.asciz "%d"
.L2_scanfResult:	.word 0

.section .text
.align 3

	rMinimum	.req v1
	rMaximum	.req v2
	rQControl	.req v3
	rRControl	.req v4
	rTestMode	.req v5
	rFirstPass	.req v6

getMenuSelection:
	mFunctionSetup	@ Setup stack frame and local variables

	ldr rTestMode, [fp, #4]

	mov rFirstPass, #1

.L2_tryAgain:
	ldr a1, =.L2_getsBuffer
	bl gets

	ldr r0, =.L2_getsBuffer
	ldrh r0, [r0]		@ get only 2 bytes to check for "q\0" or "r\0"
	orr r0, #0x20		@ make sure it's lowercase

	cmp r0, #'q'
	bne .L2_checkR

	cmp rQControl, #q_accept
	bne .L2_yuck	
	b .L2_acceptControlCharacter

.L2_checkR:
	cmp r0, #'r'
	bne .L2_notQnotR

	cmp rRControl, #r_accept
	bne .L2_yuck
	b .L2_acceptControlCharacter

.L2_notQnotR:
	and r0, #0xFF		@ if in test mode, allow // comments in input
	cmp r0, #'/'
	bne .L2_inputFirstStep
	cmp rTestMode, #1
	beq .L2_tryAgain

.L2_inputFirstStep:
	ldr a1, =.L2_getsBuffer
	ldr a2, =.L2_scanf
	ldr a3, =.L2_scanfResult
	bl sscanf

	ldr a1, =.L2_getsBuffer

.L2_skippingWhitespace:
	ldrb r1, [a1]
	cmp r1, #' '
	bhi .L2_foundNonWhitespace
	cmp r1, #0	@ null terminator--end of input
	beq .L2_yuck	@ nothing but whitespace? yuck!
	add a1, #1
	b .L2_skippingWhitespace

.L2_foundNonWhitespace:
	@ a1 -> first usable char in gets buffer
	ldr a2, =.L2_scanf
	ldr a3, =.L2_scanfResult
	ldr a3, [a3]
	bl matchInputToResult

	cmp r1, #inputStatus_inputOk
	bne .L2_yuck

	ldr r0, =.L2_scanfResult
	ldr r0, [r0]
	cmp r0, rMinimum	@ Check against min
	blo .L2_yuck

	cmp r0, rMaximum	@ Check against max
	bhi .L2_yuck

	mov r1, #inputStatus_inputOk
	b .L2_epilogue

.L2_yuck:
	ldr a1, =.L2_getsBuffer
	mov a2, #0		@ no prompt suffix for decimal input
	mov a3, rFirstPass	@ first pass indicator
	bl sayYuck
	mov rFirstPass, #0
	b .L2_tryAgain
 
.L2_acceptControlCharacter:
	mov r1, #inputStatus_acceptedControlCharacter

.L2_epilogue:
	mFunctionBreakdown 1	@ restore caller's locals and stack frame
	bx lr

	.unreq rMinimum
	.unreq rMaximum
	.unreq rQControl
	.unreq rRControl
	.unreq rTestMode
	.unreq rFirstPass

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ matchInputToResult
@
@	a1 what the user entered
@	a2 format string used on the user input
@	a3 the value that resulted from the scanf
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L24_sprintfBuffer: .skip inputBufferSize

.section .text
.align 3

	rOriginalUserInput	.req v1
	rFormatString		.req v2
	rScanfResult		.req v3

matchInputToResult:
	mFunctionSetup	@ Setup stack frame and local variables

	ldr a1, =.L24_sprintfBuffer
	mov a2, rFormatString
	mov a3, rScanfResult
	bl sprintf

	mov r0, rOriginalUserInput

.L24_skipLeadingZeros:	@ caller already skipped whitespace
	ldrb r1, [r0]
	cmp r1, #'0'
	bne .L24_foundMeatOfUserInput

	ldrb r1, [r0, #1]		@ if following char is...
	cmp r1, #0			@ null terminator, accept final...
	beq .L24_foundMeatOfUserInput	@ char as whole input

	add r0, #1			@ leading zero--keep looking
	b .L24_skipLeadingZeros
	
.L24_foundMeatOfUserInput:
	mov a2, r0			@ first usable char of original input
	ldr a1, =.L24_sprintfBuffer	@ result of sprintf using that input
	bl strcmp

	mov r1, #inputStatus_inputOk
	cmp r0, #0
	movne r1, #inputStatus_inputNotOk
	b .L24_epilogue

.L24_epilogue:
	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rOriginalUserInput
	.unreq rFormatString
	.unreq rScanfResult

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ menuGetCellValueDec
@
@ stack:
@	+4 test mode
@
@ registers:
@	a1 cell index
@	a2 data width in bytes
@	a3 operations function
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L20_msgInstructionsTemplate:
	.asciz "Enter an integer from %d to %d\n"

.L20_msgInstructionsLength = . - .L20_msgInstructionsTemplate

@@@@@@@@@
@ Buffer to contain the instructions with actual number inserted
@ in the %d. I had to do it this way because the runMenu function
@ wants the full string. The 11 is to allow for the maximum
@ length of a 32-bit integer, digits plus sign
@@@@@@@@@
.L20_msgInstructions: .skip .L20_msgInstructionsLength + (2 * 11) 

.section .text
.align 3

	rCellIndex		.req v1
	rDataWidthInBytes	.req v2
	rOperationsFunction	.req v3

menuGetCellValueDec:
	mFunctionSetup	@ Setup stack frame and local variables

	mov a4, #operation_initAForMax
	blx rOperationsFunction
	mov v4, r0

	mov a4, #operation_initAForMin
	blx rOperationsFunction
	mov v5, r0

	ldr a1, =.L20_msgInstructions
	ldr a2, =.L20_msgInstructionsTemplate
	mov a3, v4	@ min
	mov a4, v5	@ max
	bl sprintf	@ r0 -> complete instructions string

	ldr a1, =.L20_msgInstructions
	mov a2, rCellIndex
	mov a3, #0	@ no prompt postfix for decimal
	bl runGetCellValueMenu

	mFunctionBreakdown 1	@ restore caller's locals and stack frame
	bx lr

	.unreq rCellIndex
	.unreq rDataWidthInBytes
	.unreq rOperationsFunction

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ operations8
@
@	a1 = accumulator/source
@		except for operation_display -- there it's presentation mode
@	a2 = sheet base address
@	a3 = multi-purpose --
@		usually index of target cell
@	a4 = operation
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.ops8_formatDec: .asciz "% 4d"
.ops8_formatHex: .asciz "$%02X"

.ops8_jumpTable:	.word .ops8_store, .ops8_display, .ops8_initAForMin
			.word .ops8_initAForMax, .ops8_min, .ops8_max
			.word .ops8_accumulate, .ops8_validateRange

.section .text
.align 3	@ in case there's an issue with jumping to this via register

	rOperationResult	.req r0
	rOverflowIndicator	.req r1
	rInputStatus		.req r1
	rCellContents		.req r1
	rOperand		.req v1
	rAccumulator		.req v1
	rPresentationMode	.req v1
	rSheetBaseAddress	.req v2
	rCellIndex		.req v3
	rOperation		.req v4

operations8:
	mFunctionSetup	@ Setup stack frame and local variables

	ldr r0, =.ops8_jumpTable
	ldr r0, [r0, rOperation, lsl #2]
	bx r0

.ops8_validateRange:
	mov rInputStatus, #inputStatus_inputNotOk
	mov r0, #0x80		@ minimum 8-bit value
	sxtb r0, r0		@ sign-extend
	cmp rOperand, r0
	blt .ops8_epilogue
	cmp rOperand, #0x7F	@ maximum 8-bit value
	movle rInputStatus, #inputStatus_inputOk
	b .ops8_epilogue

.ops8_accumulate:
	ldrsb rCellContents, [rSheetBaseAddress, rCellIndex]
	add rOperationResult, rAccumulator, rCellContents

	@@@
	@ notify caller of overflow status relative
	@ to bottom byte of the operation result
	@@@

	mov rOverflowIndicator, #0	@ default to no overflow
	and r2, rOperationResult, #0xFF	@ get bottom byte
	sxtb r2, r2			@ sign-extend r2
	cmp r2, rOperationResult
	movne rOverflowIndicator, #1	@ not equal means overflow

	b .ops8_epilogue

.ops8_display:
	ldrsb rCellContents, [rSheetBaseAddress, rCellIndex]

	ldr a1, =.ops8_formatDec	@ default to decimal
	bl printf
	b .ops8_epilogue

.ops8_initAForMax:
	mov rOperationResult, #0x80		@ lowest possible 8-bit signed value
	sxtb rOperationResult, rOperationResult	@ sign-extend
	b .ops8_epilogue

.ops8_initAForMin:
	mov rOperationResult, #0x7F		@ highest possible 8-bit signed value
	b .ops8_epilogue

.ops8_max:
	ldrsb rCellContents, [rSheetBaseAddress, rCellIndex]
	mov rOperationResult, rOperand		@ current max
	cmp rOperand, rCellContents
	movlt rOperationResult, rCellContents	@ new max if operand < cell value
	b .ops8_epilogue

.ops8_min:
	ldrsb rCellContents, [rSheetBaseAddress, rCellIndex]
	mov rOperationResult, rOperand		@ current min
	cmp rOperand, rCellContents
	movgt rOperationResult, rCellContents	@ new min if operand > cell value
	b .ops8_epilogue

.ops8_store:
	strb rOperand, [rSheetBaseAddress, rCellIndex]
	b .ops8_epilogue

.ops8_epilogue:
	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rOperationResult
	.unreq rOverflowIndicator
	.unreq rInputStatus
	.unreq rCellContents
	.unreq rOperand
	.unreq rAccumulator
	.unreq rPresentationMode
	.unreq rSheetBaseAddress
	.unreq rCellIndex
	.unreq rOperation

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ promptForSelection 
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

msgEnterSelection:	.asciz "Enter a selection\n"
msgPrompt:		.asciz "-> "

.section .text
.align 3

promptForSelection:
	push {lr}
	bl newline
	ldr a1, =msgEnterSelection
	bl printf
	ldr a1, =msgPrompt
	bl printf
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ randomFill
@
@	a1 = operations function
@	a2 = sheet base address
@	a3 = cell count
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	rOperationsFunction	.req v1
	rSheetAddress		.req v2
	rCellCount		.req v3
	rLoopCounter		.req v4

randomFill:
	mFunctionSetup	@ Setup stack frame and local variables

.L6_loopInit:
	mov rLoopCounter, #0

.L6_loopTop:
	cmp rLoopCounter, rCellCount
	bhs .L6_loopExit

	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	@ rand() seems to return a range of 0 - 2^31, which means that I'll
	@ never get negative values when working with 32 bits. So shift all
	@ values left by one, then back down with sign extension. That turns
	@ anything > 2^31 negative, which means that about half the values
	@ I get back will be negative, which is what I want.
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	bl rand				@ returns rand in a1 (r0)
	lsl a1, #1
	asr a1, #1
	mov a2, rSheetAddress
	mov a3, rLoopCounter		@ current cell index
	mov r3, #operation_store
	blx rOperationsFunction		@ store a1

.L6_loopBottom:
	add rLoopCounter, #1
	b .L6_loopTop

.L6_loopExit:
	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rOperationsFunction
	.unreq rSheetAddress
	.unreq rCellCount
	.unreq rLoopCounter

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ resetSheet
@
@	a1 = operations function
@	a2 = sheet base address
@	a3 = cell count
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .text

	rOperationsFunction	.req v1
	rSheetAddress		.req v2
	rCellCount		.req v3
	rLoopCounter		.req v4

resetSheet:
	mFunctionSetup	@ Setup stack frame and local variables

.L4_init:
	mov rLoopCounter, #0

.L4_top:
	cmp rLoopCounter, rCellCount
	bhs .L4_loopExit

	mov a1, #0		@ data to store
	mov a2, rSheetAddress	@ base address of array
	mov a3, rLoopCounter	@ index of target cell
	mov a4, #operation_store
	blx rOperationsFunction	@ store the zero

.L4_loopBottom:
	add rLoopCounter, #1
	b .L4_top

.L4_loopExit:
	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rOperationsFunction
	.unreq rSheetAddress
	.unreq rCellCount
	.unreq rLoopCounter

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ runGetCellValueMenu
@
@	a1 instructions
@	a2 cell index
@	a3 prompt postfix
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L15_msgDirections:
	.ascii "Directions (enter 'Q' to quit, 'R' to return "
	.asciz "to cell selection menu):\n"

.L15_msgSeparator:
	.ascii "---------------------------------------------"
	.asciz "------------------------\n"

.L15_msgNewValue: .asciz "\nNew value for cell %d\n-> "

.section .text
.align 3

	rInstructions	.req v1
	rCellIndex	.req v2
	rPromptPostfix	.req v3

runGetCellValueMenu:
	mFunctionSetup	@ Setup stack frame and local variables

	ldr a1, =.L15_msgDirections
	bl printf
	ldr a1, =.L15_msgSeparator
	bl printf

	mov a1, rInstructions
	bl printf

	ldr a1, =.L15_msgNewValue
	mov a2, rCellIndex
	bl printf

	mov a1, rPromptPostfix
	cmp a1, #0	@ decimal has no prompt postfix
	blne putchar	@ awesome arm conditional instruction

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rInstructions
	.unreq rCellIndex
	.unreq rPromptPostfix
	
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ runMenu
@
@ stack:
@	 +4 testMode
@	 +8 q accept/reject
@	+12 r accept/reject
@
@ registers:
@	a1 instructions message
@	a2 separator
@	a3 menu options table
@	a4 number of options in table
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	rInstructionsMessage	.req v1
	rSeparator		.req v2
	rMenuOptionsTable	.req v3
	rNumberOfMenuOptions	.req v4

runMenu:
	mFunctionSetup	@ Setup stack frame and local variables

	mov a1, rInstructionsMessage
	bl printf
	mov a1, rSeparator
	bl printf

	mov a1, rMenuOptionsTable
	mov a2, rNumberOfMenuOptions
	bl showList

	bl promptForSelection

	ldr r0, [fp, #4]		@ test mode
	push {r0}
	mov a1, #1			@ minimum
	mov a2, rNumberOfMenuOptions	@ maximum
	ldr a3, [fp, #8]		@ q accept/reject
	ldr a4, [fp, #12]		@ r accept/reject
	bl getMenuSelection

	mFunctionBreakdown 3	@ restore caller's locals and stack frame
	bx lr

	.unreq rInstructionsMessage
	.unreq rSeparator
	.unreq rMenuOptionsTable
	.unreq rNumberOfMenuOptions

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ sayYuck
@
@	a1 string with yucky value
@	a2 prompt suffix
@	a3 skip second cursor-up
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L18_yuckMessage:	.asciz "Uhh... %s? Yuck! Try again!\n-> "
.L18_msgWTF:		.asciz "weird characters"

.section .text
.align 3

	rYuckyValue		.req v1
	rPromptSuffix		.req v2
	rSkipSecondCursorUp	.req v3

sayYuck:
	mFunctionSetup	@ Setup stack frame and local variables

.L18_escapeLoopInit:
	mov r0, v1	@ get yucky value string

.L18_escapeLoopTop:
	ldrb r1, [r0]	@ get byte
	cmp r1, #0	@ end of string--all done
	beq .L18_yuckyStringPreprocessed

	cmp r1, #' '		@ check for anything less than space
	ldrlo v1, =.L18_msgWTF	@ replace user input completely
	beq .L18_yuckyStringPreprocessed

	add r0, #1
	b .L18_escapeLoopTop

.L18_yuckyStringPreprocessed:

	mTerminalCommand #terminalCommand_cursorUp
	mTerminalCommand #terminalCommand_clearToEOL

	cmp rSkipSecondCursorUp, #1
	beq .L18_cursingComplete

	mTerminalCommand #terminalCommand_cursorUp
	mTerminalCommand #terminalCommand_clearToEOL

.L18_cursingComplete:
	ldr a1, =.L18_yuckMessage
	mov a2, rYuckyValue
	bl printf

	mov a1, v2
	cmp v2, #0	@ dec mode doesn't have a prompt suffix
	blne putchar	@ awesome arm conditional instruction

.L18_epilogue:
	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rYuckyValue
	.unreq rPromptSuffix
	.unreq rSkipSecondCursorUp

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ showList
@
@	a1 list address
@	a2 number of elements in list
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

msgListElement: .asciz "%d. %s\n"

.section .text

	rListAddress		.req v1
	rNumberOfListElements	.req v2
	rLoopCounter		.req v3

showList:
	mFunctionSetup	@ Setup stack frame and local variables

.L3_loopInit:
	mov rLoopCounter, #0

.L3_loopTop:
	add rLoopCounter, rLoopCounter, #1
	ldr a1, =msgListElement
	mov a2, rLoopCounter
	ldr a3, [rListAddress]
	bl printf

	add rListAddress, #4
	subs rNumberOfListElements, #1
	bne .L3_loopTop

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rListAddress
	.unreq rNumberOfListElements
	.unreq rLoopCounter

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ main
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

.section .data

.equ presentation_dec, 1
.equ numberOfCells, 6
.equ cellWidthInBytes, 1

.L0_localVariables:

testMode	= .-.L0_localVariables; .word 0
cellToEdit	= .-.L0_localVariables; .word 0

msgGreeting:	.asciz "Greetings, experimental subject.\n\n"
msgByeNow:	.asciz "'Bye now!\n"

actionsJumpTable:
		.word actionEditCell
		.word actionResetSpreadsheet
		.word actionFillRandom

operationsJumpTable:	.word operations8

.equ menuMode_main,			0
.equ menuMode_getCellToEdit,		1
.equ menuMode_getNewValueForCell,	2

menuModeJumpTable:
		.word menuMain
		.word menuGetCellToEdit
		.word menuGetNewValueForCell

.section .text
.global main

	rMenuMode			.req v1
	rSpreadsheetAddress		.req v2
	rOperationsFunction		.req v3

main:
	ldr fp, =.L0_localVariables	@ setup local stack frame

	ldr r0, =operationsJumpTable
	ldr rOperationsFunction, [r0]

	mov r1, #1	@ default to test mode
	cmp r0, #1	@ number of cmdline args
	moveq r1, #0	@ if only one cmdline arg (prog name), not test mode
	str r1, [fp, #testMode]

	mov a1, #0
	bl time
	bl srand

	mTerminalCommand #terminalCommand_clearScreen

greet:
	ldr a1, =msgGreeting
	bl printf

	mov rMenuMode, #menuMode_main

	mov a1, #numberOfCells
	bl malloc
	mov rSpreadsheetAddress, r0

	mov a1, rOperationsFunction
	mov a2, rSpreadsheetAddress
	mov a3, #numberOfCells
	bl resetSheet

redisplaySheet:
	mTerminalCommand #terminalCommand_clearScreen

	mov a1, rOperationsFunction
	mov a2, rSpreadsheetAddress
	mov a3, #numberOfCells
	mov a4, #cellWidthInBytes
	bl displaySheet

	ldr r1, =menuModeJumpTable
	ldr r0, [r1, rMenuMode, lsl #2]
	bx r0	@ jump to handler for current menu mode

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Main Menu
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
menuMain:
	ldr r0, [fp, #testMode]
	push {r0}
	bl getMainSelection

	cmp r1, #inputStatus_acceptedControlCharacter
	beq actionQuit 
	b actionSwitch

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Get cell to edit menu
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
menuGetCellToEdit:
	ldr r0, [fp, #testMode]
	push {r0}
	mov a1, #1		@ lowest acceptable cell number
	mov a2, #numberOfCells	@ highest acceptable
	bl getCellToEdit

	cmp r1, #inputStatus_acceptedControlCharacter
	bne gotCellToEdit

	cmp r0, #'q'
	beq actionQuit
	b returnToMain	@ control char not q, must be r

gotCellToEdit:
	str r0, [fp, #cellToEdit]
	mov rMenuMode, #menuMode_getNewValueForCell
	b redisplaySheet

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Get new value for cell menu
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
menuGetNewValueForCell:
	ldr r0, [fp, #testMode]
	push {r0}
	mov a1, rOperationsFunction
	ldr a2, [fp, #cellToEdit]
	mov a3, #cellWidthInBytes
	mov a4, #presentation_dec
	bl getNewValueForCell

	cmp r1, #inputStatus_acceptedControlCharacter
	bne gotNewValueForCell

	cmp r0, #'q'
	beq actionQuit
	b actionEditCell @ control char not 'q', so 'r' -- return to cell select

gotNewValueForCell:	@ r0/a1 = new value for cell
	mov a2, rSpreadsheetAddress
	ldr a3, [fp, #cellToEdit]
	sub a3, #1	@ cell to edit, zero-based
	mov a4, #operation_store
	blx rOperationsFunction
	b returnToMain

actionSwitch:
	sub r0, #1			@ user menu selection to 0-based
	ldr r1, =actionsJumpTable
	add r0, r1, r0, lsl #2
	ldr r0, [r0]
	bx r0

actionEditCell:
	mov rMenuMode, #menuMode_getCellToEdit
	b redisplaySheet

actionResetSpreadsheet:
	mov a1, rSpreadsheetAddress
	bl free
	mTerminalCommand #terminalCommand_clearScreen
	b redisplaySheet

actionFillRandom:
	mov a1, rOperationsFunction
	mov a2, rSpreadsheetAddress
	mov a3, #numberOfCells
	bl randomFill
	b returnToMain

returnToMain:
	mov rMenuMode, #menuMode_main
	b redisplaySheet

actionQuit:
	ldr r0, =msgByeNow
	bl printf
	mov r0, #0
	bl fflush		@ make sure it's all out, for our test harness

	mov r7, $1		@ exit syscall
	svc 0			@ wake kernel

	.unreq rMenuMode
	.unreq rSpreadsheetAddress

	.end

