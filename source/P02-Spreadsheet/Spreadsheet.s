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

.equ operation_store, 0
.equ operation_display, 1
.equ operation_initAForMin, 2
.equ operation_initAForMax, 3
.equ operation_min, 4
.equ operation_max, 5
.equ operation_accumulate, 6
.equ operation_checkOverflow, 7

.equ longestCalculationString, 9

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ calcSheetMinMax
@
@ stack:
@	+4: unused but required so
@		main can call minmax
@		and sumavg with the
@		same mechanism
@
@ registers:
@	a/v1: operations function
@	a/v2: spreadsheet address
@	a/v3: number of cells in sheet
@	a/v4: operation - min or max
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .text

calcSheetMinMax:
	push {fp}	@ setup local stack frame
	mov fp, sp

	push {lr}	@ preserve return address
	push {v1 - v6}	@ always preserve caller's locals

	push {a1 - a4}	@ Transfer scratch regs to...
	pop  {v1 - v4}	@ local variable regs

	cmp v4, #formula_minimum
	beq .L7_initForMin

	mov a4, #operation_initAForMax
	blx v1		@ init A for max

	mov a4, #operation_max
	b .L7_loopInit

.L7_initForMin:
	mov a1, #operation_initAForMin
	blx v1		@ init A for min

	mov a4, #operation_min

.L7_loopInit:
	mov v6, #0
	mov v5, r0	@ init from the initA result

.L7_loopTop:
	cmp v6, v3
	bhs .L7_loopExit

	mov a1, v5	@ current min/max
	mov a2, v2	@ sheet address
	mov a3, v6	@ cell index
	blx v1		@ get min/max between curr and a1
	mov v5, r0	@ save comparison result

.L7_loopBottom:
	add v6, #1
	b .L7_loopTop

.L7_loopExit:
	mov a1, v5	@ result
	mov a2, v2	@ sheet
	mov a3, v6	@ cell "index" -- result cell
	mov a4, #operation_store
	blx v1		@ store result

	pop {v1 - v6}	@ restore caller's locals
	pop {lr}	@ restore return address

	mov sp, fp	@ restore caller's stack frame
	pop {fp}

	add sp, #4	@ clear caller's stack parameters
	bx lr		@ return
	
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ calcSheetSumAverage
@
@ stack:
@	+4 POINTER TO overflow flag
@
@ registers:
@	a/v1 operations function
@	a/v2 spreadsheet base address
@	a/v3 number of cells in sheet
@	a/v4 min/max indicator
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .text

calcSheetSumAverage:
	push {fp}	@ setup local stack frame
	mov fp, sp

	push {lr}	@ preserve return address
	push {v1 - v7}	@ always preserve caller's locals

	push {a1 - a4}	@ Transfer scratch regs to...
	pop  {v1 - v4}	@ local variable regs

.L11_loopInit:
	mov v5, #0	@ accumulator
	mov v6, #0	@ cell index

.L11_loopTop:
	cmp v6, v3	@ end of loop?
	bhs .L11_loopExit

	mov a1, v5	@ accumulator
	mov a2, v2	@ sheet base address
	mov a3, v6	@ cell index
	mov a4, #operation_accumulate
	blx v1		@ accumulate sum 
	mov v5, r0	@ track accumulator

	mov a4, #operation_checkOverflow
	blx v1
	cmp r0, #1	@ overflow?
	bne .L11_loopBottom

	add r1, fp, #4	@ r1 -> overflow flag pointer
	ldr r1, [r1]	@ r1 -> caller's overflow flag
	str r0, [r1]	@ notify caller of overflow

.L11_loopBottom:
	add v6, #1
	b .L11_loopTop

.L11_loopExit:
	mov a1, v5	@ sum
	cmp v4, #formula_sum
	beq .L11_storeResult

	mov a2, v3	@ denominator for average
	bl divide	@ result in r0

.L11_storeResult:
	mov a2, v2	@ spreadsheet
	mov a3, v6	@ cell "index" -- just past main sheet is result cell
	mov a4, #operation_store
	blx v1		@ store result

.L11_epilogue:
	pop {v1 - v7}	@ restore caller's locals
	pop {lr}	@ restore return address

	mov sp, fp	@ restore caller's stack frame
	pop {fp}

	add sp, #4	@ clear caller's stack parameters
	bx lr		@ return

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ clearScreen()
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
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

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ divide - cribbed from http://www.tofla.iconbar.com/tofla/arm/arm02/
@	Hope it works!
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
divide:
	vmov s0, r0
	vmov s1, r1
	vcvt.f32.s32 s0, s0
	vcvt.f32.s32 s1, s1
	vdiv.f32 s0, s0, s1
	vcvt.s32.f32 s0, s0
	vmov r0, s0
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ displaySheet()
@
@ stack:
@	+12 presentation mode
@	 +8 formula
@	 +4 overflow accumulator
@
@	a/v1 - ops function
@	a/v2 - spreadsheet data
@	a/v3 - number of cells to display
@	a/v4 - data width
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L1_msgSpreadsheetHeader:	.asciz "Simple spreadsheet\r\n"
.L1_cellNumber:			.asciz "%9d. "

.L1_msgFormula:	.asciz "%9s: "
.L1_fSum:	.asciz "Sum"
.L1_fAverage:	.asciz "Average"
.L1_fMinimum:	.asciz "Minimum"
.L1_fMaximum:	.asciz "Maximum"
.L1_formulas:	.word .L1_fSum, .L1_fAverage, .L1_fMinimum, .L1_fMaximum

.L1_msgDataWidth:	.asciz "%d-bit signed integer mode\r\n\r\n"
.L1_msgOverflow:	.asciz "[ERROR]"

.section .text
.align 3

displaySheet:
	push {fp}
	mov fp, sp

	push {lr}
	push {v1 - v6}

	push {a1 - a4}	@ transfer argument registers...
	pop {v1 - v4}	@ to local variable registers

	ldr a1, =.L1_msgSpreadsheetHeader
	bl printf

	ldr a1, =.L1_msgDataWidth
	mov a2, v4, lsl #3	@ convert data width in bytes to width in bits
	bl printf

.L1_loopInit:
	mov v6, #0

.L1_loopTop:
	cmp v6, v3
	bhs .L1_loopExit

	ldr a1, =.L1_cellNumber
	add a2, v6, #1
	bl printf

	add a1, fp, #12	@ a1 -> presentation indicator
	ldr a1, [a1]	@ a1 = presentation indicator
	mov a2, v2	@ spreadsheet
	mov a3, v6	@ cell index
	mov a4, #operation_display
	blx v1		@ display current cell per data width 

.L1_loopBottom:
	add v6, v6, #1
	b .L1_loopTop

.L1_loopExit:
	bl newline

	add r1, fp, #8		@ r1 -> formula indicator
	ldr r1, [r1]		@ r1 = formula indicator
	ldr r0, =.L1_formulas
	add r0, r1, lsl #2	@ r0 -> formula message pointer
	ldr r1, [r0]		@ r1 -> formula message
	ldr r0, =.L1_msgFormula
	bl printf

	add a1, fp, #12	@ a1 -> presentation indicator
	ldr a1, [a1]	@ a1 = presentation indicator
	mov a2, v2	@ spreadsheet
	mov a3, v6	@ "index" of result cell 
	mov a4, #operation_display
	blx v1		@ display result cell per data width

	bl newline

	pop {v1 - v6}
	pop {lr}

	mov sp, fp
	pop {fp}
	add sp, #12
	bx lr
	
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getFormula
@	stack: 
@		testMode
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L8_msgInstructions:
	.asciz "Formula options (enter 'Q' to quit, 'R' to return to the main menu):\r\n"
.L8_msgSeparator:
	.asciz "--------------------------------------------------------------------\r\n"

.L8_moSum:	.asciz "Sum"
.L8_moAverage:	.asciz "Average"
.L8_moMinimum:	.asciz "Minimum"
.L8_moMaximum:	.asciz "Maximum"

.L8_menuOptions: .word .L8_moSum, .L8_moAverage, .L8_moMinimum, .L8_moMaximum
.equ .L8_menuOptionsCount, 4
.section .text
.align 3

getFormula:
	push {fp}
	mov fp, sp

	push {lr}
	push {v1 - v6}

	add r0, fp, #4	@ test mode
	ldr r0, [r0]
	mov r1, #q_accept
	mov r2, #r_accept
	push {r0 - r2}
	ldr a1, =.L8_msgInstructions
	ldr a2, =.L8_msgSeparator
	ldr a3, =.L8_menuOptions
	mov a4, #.L8_menuOptionsCount
	bl runMenu

	pop {v1 - v6}
	pop {lr}
	mov sp, fp
	pop {fp}
	add sp, #4
	bx lr
	
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getPresentation
@	stack: 
@		testMode
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L9_msgInstructions:
	.asciz "Presentation options (enter 'Q' to quit, 'R' to return to the main menu):\r\n"
.L9_msgSeparator:
	.asciz "---------------------------------------------------------------------------\r\n"

.L9_moBinary:	.asciz "Binary"
.L9_moDecimal:	.asciz "Decimal"
.L9_moHex:	.asciz "Hex"

.L9_menuOptions: .word .L9_moBinary, .L9_moDecimal, .L9_moHex
.equ .L9_menuOptionsCount, 3
.section .text
.align 3

getPresentation:
	push {fp}
	mov fp, sp

	push {lr}
	push {v1 - v6}

	add r0, fp, #4	@ test mode
	ldr r0, [r0]
	mov r1, #q_accept
	mov r2, #r_accept
	push {r0 - r2}
	ldr a1, =.L9_msgInstructions
	ldr a2, =.L9_msgSeparator
	ldr a3, =.L9_menuOptions
	mov a4, #.L9_menuOptionsCount
	bl runMenu

	pop {v1 - v6}
	pop {lr}
	mov sp, fp
	pop {fp}
	add sp, #4
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getMainSelection
@	stack: 
@		testMode
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L5_msgInstructions:	.asciz "Options (enter 'Q' to quit):\r\n"
.L5_msgSeparator:	.asciz "----------------------------\r\n"

mo_editCell:		.asciz "Edit cell"
mo_changeFormula:	.asciz "Change formula"
mo_changeDataRep:	.asciz "Change data presentation"
mo_resetSpreadsheet:	.asciz "Reset sheet"
mo_randomValues:	.asciz "Fill cells with random values"

menuOptions: .word mo_editCell, mo_changeFormula, mo_changeDataRep
		.word mo_resetSpreadsheet, mo_randomValues

.equ menuOptionsCount, 5

.section .text
.align 3

getMainSelection:
	push {lr}
	ldr r0, =testMode
	ldr r0, [r0]
	mov r1, #q_accept
	mov r2, #r_reject
	push {r0 - r2}
	ldr a1, =.L5_msgInstructions
	ldr a2, =.L5_msgSeparator
	ldr a3, =menuOptions
	mov a4, #menuOptionsCount
	bl runMenu
	pop {lr}
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getMenuSelection
@
@ stack:
@	+4/v5 accept/reject 'r'
@
@ registers:
@	a/v1 test mode
@	a/v2 minimum acceptable input
@	a/v3 maximum acceptable input
@	a/v4 accept/reject 'q'
@
@ returns:
@	r0 user input
@	r1 input status
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

scanString:		.asciz "%2s"
scanResult:		.asciz "  "
msgYuck:		.asciz "%s? Yuck! Try again!\r\n-> "

.section .text

getMenuSelection:
	push {fp}
	mov fp, sp

	push {lr}
	push {v1 - v6}

	push {a1 - a4}	@ Transfer args to...
	pop  {v1 - v4}	@ local variable regs

	add v5, fp, #4	@ accept/reject 'r'
	ldr v5, [v5]

.L2_tryAgain:
	ldr r0, =scanString
	ldr r1, =scanResult
	bl scanf

	ldr r0, =scanResult
	ldrh r0, [r0]		@ get only 2 bytes to check for "q\0" or "r\0"
	orr r0, #0x20

	cmp r0, #'q'
	bne .L2_checkR

	cmp v4, #q_accept
	bne .L2_yuck	
	b .L2_acceptControlCharacter

.L2_checkR:
	cmp r0, #'r'
	bne .L2_notQnotR

	cmp v5, #r_accept
	bne .L2_yuck
	b .L2_acceptControlCharacter

.L2_notQnotR:
	ldr r0, =scanResult
	mov r1, #0
	mov r2, #10
	bl strtol

	cmp r0, v2	@ Check against min
	blo .L2_yuck

	cmp r0, v3	@ Check against max
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
	pop {v1 - v6}
	pop {lr}

	mov sp, fp
	pop {fp}
	add sp, #4
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ getSpreadsheetSpecs
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.equ minimumCellCount, 2
.equ maximumCellCount, 10

.section .data

msgEnterSpreadsheetSize:	.asciz "Enter the number of cells for the spreadsheet [2, 10] or 'Q' to quit\r\n"
msgDataWidthOptions:		.asciz "Data width options (enter 'Q' to quit):\r\n"
msgSeparator:			.asciz "---------------------------------------\r\n"
msgSelectDataWidth:		.asciz "Select data width:\r\n"

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
	ldr r0, =msgPrompt
	bl printf

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

	mov r0, #0
	mov r1, #inputStatus_inputOk

epilogue:
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ newline
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data
msgNewline: .asciz "\r\n"

.section .text
newline:
	push {lr}
	ldr r0, =msgNewline
	bl printf
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ operations8
@	a/v1 = accumulator/source
@		except for operation_display -- there it's presentation mode
@	a/v2 = sheet base address
@	a/v3 = multi-purpose --
@		usually index of target cell
@	a/v4 = operation
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.ops8_formatDec: .asciz "% 4d\r\n"
.ops8_formatHex: .asciz "$%02X\r\n"

.ops8_jumpTable:	.word .ops8_store, .ops8_display, .ops8_initAForMin
			.word .ops8_initAForMax, .ops8_min, .ops8_max
			.word .ops8_accumulate, .ops8_checkOverflow
.section .text
.align 3	@ in case there's an issue with jumping to this via register

operations8:
	push {lr}
	push {v1 - v6}

	push {a1 - a4}
	pop  {v1 - v4}

	ldr r0, =.ops8_jumpTable
	add r0, r0, v4, lsl #2	@ v4 = offset from beginning of jump table
	ldr r0, [r0]
	bx r0

.ops8_checkOverflow:
	mov r0, #0	@ default to no overflow
	mvn v2, #0xFF	@ v2 = 0xFFFFFF00
	tst v1, v2
	movne r0, #1	@ cool arm conditional instruction
	b .ops8_epilogue

.ops8_accumulate:
	add r1, v2, v3	@ r1 = address of cell
	ldrsb r1, [r1]	@ r1 = data from cell
	add r0, v1, r1	@ r0 = sum so far
	b .ops8_epilogue

.ops8_display:
	add a2, v2, v3	@ a2 = address of cell
	ldrsb a2, [a2]	@ a2 = data from cell

	cmp v1, #presentation_bin
	beq .ops8_displayBin

	ldr a1, =.ops8_formatDec	@ default to decimal
	cmp v1, #presentation_hex
	ldreq a1, =.ops8_formatHex	@ cool arm conditional execution
	andeq a2, #0xFF			@ also use only bottom byte if hex
	bl printf
	b .ops8_epilogue

.ops8_displayBin:
	mov a1, a2	@ a1 = data to display
	mov a2, #1	@ a2 = number of bytes
	bl showNumberAsBin
	b .ops8_epilogue

.ops8_initAForMax:
	mov r0, #0x80		@ lowest possible 8-bit signed value
	b .ops8_epilogue

.ops8_initAForMin:
	mov r0, #0x7F		@ highest possible 8-bit signed value
	b .ops8_epilogue

.ops8_max:
	add r1, v2, v3	@ r1 = address of cell
	ldrsb r1, [r1]	@ r1 = data from cell
	cmp v1, r1
	movlt r0, r1 
	b .ops8_epilogue

.ops8_min:
	add r1, v2, v3	@ r1 = address of cell
	ldrsb r1, [r1]	@ r1 = data from cell
	cmp v1, r1
	movgt r0, r1
	b .ops8_epilogue

.ops8_store:
	add v2, v3
	strb v1, [v2]
	b .ops8_epilogue

.ops8_epilogue:
	pop {v1 - v6}
	pop {lr}
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ operations16
@	r0 = accumulator/source
@	r1 = sheet base address
@	r2 = multi-purpose;
@		usually index of target cell
@	r3 = operation
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.ops16_formatDec: .asciz "% 6d\r\n"
.ops16_jumpTable: .word .ops16_store, .ops16_display

.section .text
.align 3	@ in case there's an issue with jumping to this via register

operations16:
	push {lr}
	push {r4 - r7}

	push {r0 - r3}
	pop  {r4 - r7}

	ldr r3, =.ops16_jumpTable
	add r3, r3, r7, lsl #2	@ r7 = offset from beginning of jump table
	ldr r3, [r3]
	bx r3

.ops16_store:
	add r1, r2, lsl #1
	strh r0, [r1]
	b .ops16_epilogue

.ops16_display:
	ldr r0, =.ops16_formatDec
	add r1, r2, lsl #1	@ r1 = address of cell
	ldrsh r1, [r1]		@ r1 = data from cell
	bl printf

.ops16_epilogue:
	pop {r4 - r7}
	pop {lr}
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ operations32
@	r0 = accumulator/source
@	r1 = sheet base address
@	r2 = multi-purpose;
@		usually index of target cell
@	r3 = operation
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.ops32_formatDec: .asciz "% 11d\r\n"
.ops32_jumpTable: .word .ops32_store, .ops32_display

.section .text
.align 3	@ in case there's an issue with jumping to this via register

operations32:
	push {lr}
	push {r4 - r7}

	push {r0 - r3}
	pop  {r4 - r7}

	ldr r3, =.ops32_jumpTable
	add r3, r3, r7, lsl #2	@ r7 = offset from beginning of jump table
	ldr r3, [r3]
	bx r3

.ops32_store:
	add r1, r2, lsl #2
	str r0, [r1]
	b .ops32_epilogue

.ops32_display:
	ldr r0, =.ops32_formatDec
	add r1, r2, lsl #2	@ r1 = address of cell
	ldr r1, [r1]		@ r1 = data from cell
	bl printf

.ops32_epilogue:
	pop {r4 - r7}
	pop {lr}
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ promptForSelection 
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

msgEnterSelection:	.asciz "Enter a selection"
msgPrompt:		.asciz "-> "

.section .text
.align 3

promptForSelection:
	push {lr}
	bl newline
	ldr r0, =msgEnterSelection
	bl printf
	ldr r0, =msgPrompt
	bl printf
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ randomFill
@	a/v1 = operations function
@	a/v2 = sheet base address
@	a/v3 = cell count
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
randomFill:
	push {lr}
	push {v1 - v6}

	push {a1 - a3}	@ Transfer arguments to...
	pop  {v1 - v3}	@ local variables

.L6_loopInit:
	mov v6, #0

.L6_loopTop:
	cmp v6, v3
	bhs .L6_loopExit

	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	@ Something strange happens with rand that causes me to get all
	@ positive values when working with 16-bit cells. The ror is there to
	@ mix things up a bit and hopefully give me both positive and negative
	@ values in a random, or at least apparently random distribution. 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	bl rand		@ returns rand in a1 (r0)
	ror a1, #1	@ because I want a full range
	mov a2, v2	@ sheet base address
	mov a3, v6	@ current cell index
	mov r3, #operation_store
	blx v1		@ store a1

.L6_loopBottom:
	add v6, #1
	b .L6_loopTop

.L6_loopExit:

	pop {v1 - v6}
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ resetSheet
@	r0/6 = operations function
@	r1/7 = sheet base address
@	r2/8 = cell count
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .text

resetSheet:
	push {lr}
	push {r4 - r8}

	@ Is there a better way to copy registers?
	push {r0 - r2}
	pop {r6 - r8}

.L4_init:
	mov r4, #0

.L4_top:
	cmp r4, r8
	bhs .L4_loopExit

	mov r0, #-27	@ data to store
	mov r1, r7	@ base address of array
	mov r2, r4	@ index of target cell
	mov r3, #operation_store
	blx r6		@ store the zero

.L4_loopBottom:
	add r4, #1
	b .L4_top

.L4_loopExit:
	pop {r4 - r8}
	pop {pc}
	
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ runMenu
@
@ stack:
@	testMode
@	q accept/reject
@	r accept/reject
@
@ registers:
@	r0/4 instructions message
@	r1/5 separator
@	r2/6 menu options table
@	r3/7 number of options in table
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
runMenu:
	push {fp}
	mov fp, sp

	push {lr}
	push {v1 - v6}

	push {a1 - a4}	@ transfer scratch regs...
	pop  {v1 - v4}	@ to variable regs

	mov r0, r4	@ instructions
	bl printf
	mov r0, r5	@ separator
	bl printf

	mov r0, r6	@ menu options
	mov r1, r7	@ number of options available
	bl showList

	bl promptForSelection

	add v6, fp, #4	@ r accept/reject
	ldr v6, [v6]
	push {v6}
	add v6, fp, #12	@ test mode
	ldr a1, [v6]
	mov a2, #1	@ minimum selection
	mov a3, v4	@ maximum selection
	add v6, fp, #8	@ q accept/reject
	ldr a4, [v6]
	bl getMenuSelection

	pop {v1 - v6}
	pop {lr}

	mov sp, fp
	pop {fp}
	add sp, #12
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ showList
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
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

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ showNumberAsBin 
@	a1 number to show
@	a2 number of bytes
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
showNumberAsBin:
	push {lr}
	push {v1 - v6}

	push {a1 - a4}	@ transfer scratch regs...
	pop  {v1 - v4}	@ to variable regs

.L10_loopInit:
	mov a1, #'%'
	bl putchar

	mov r0, #4
	sub v3, r0, v2	@ width in bytes - 4: 1, 2, 4 becomes 3, 2, 0
	lsl v3, #3	@ 3, 2, 0 becomes 24, 16, 0 to shift val to top of reg
	lsl v1, v3	@ shift value up to top of register

	mov v4, #4 - 1	@ for testing whether to show underscore
	mov v3, #1	@ remember we're on the first pass
	lsl v2, #3	@ width in bytes 1, 2, 4 -> width in bits 8, 16, 32

.L10_loopTop:
	cmp v2, #0
	beq .L10_loopExit

	tst v2, v4	@ time for underscore?
	bne .L10_showbit

	cmp v3, #1	@ no underscore on first pass through
	beq .L10_showbit

	mov a1, #'_'
	bl putchar

.L10_showbit:
	mov a1, #'0'	@ default to displaying zero
	lsls v1, #1	@ cool arm conditional instruction coming up
	movcs a1, #'1'	@ move 1 if carry set by above instruction -- cool 
	bl putchar

.L10_loopBottom:
	mov v3, #0	@ no longer on first pass
	sub v2, #1
	b .L10_loopTop

.L10_loopExit:
	bl newline
	pop {v1 - v6}
	pop {pc}

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ main
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.equ presentation_bin, 0
.equ presentation_dec, 1
.equ presentation_hex, 2

testMode:			.word 0
numberOfCellsInSpreadsheet:	.word 0
cellWidthInBytes:		.word 0

formula:			.word 0
presentation:			.word 0
menuMode:			.word 0
cellToEdit:			.word 0
overflowFlag:			.word 0

spreadsheetData:		.word 47, 48, 49, 50, 51, 19, 18, 17, 16, 15
spreadsheetDataBuffer:		.word 0

operationsFunction:		.word 0

.align 8

actionsJumpTable:
		.word actionEditCell
		.word actionChangeFormula
		.word actionChangePresentation
		.word actionResetSpreadsheet
		.word actionFillRandom

operationsJumpTable:	.word operations8, operations16, operations32

.equ menuMode_main,			0
.equ menuMode_changeFormula,		1
.equ menuMode_changePresentation,	2
.equ menuMode_getCellToEdit,		3
.equ menuMode_getNewValueForCell,	4

menuModeJumpTable:
		.word menuMain
		.word menuChangeFormula
		.word menuChangePresentation
		.word menuGetCellToEdit
		.word menuGetNewValueForCell

.equ formula_sum,	0
.equ formula_average,	1
.equ formula_minimum,	2
.equ formula_maximum,	3

formulaJumpTable:
		.word calcSheetSumAverage
		.word calcSheetSumAverage
		.word calcSheetMinMax
		.word calcSheetMinMax

msgGreeting:	.asciz "Greetings, data analyzer.\r\n\r\n"
msgSetupIntro:	.asciz "To set up, enter spreadsheet size and data width.\r\n"
msgByeNow:	.asciz "'Bye now!\r\n"

.section .text

	.global main

main:
	mov r0, #1
	ldr r1, =testMode
	str r0, [r1]

	mov r0, #0
	bl time
	bl srand

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

	mov r0, #presentation_dec
	ldr r1, =presentation
	str r0, [r1]

	ldr r0, =msgSetupIntro
	bl printf

	bl getSpreadsheetSpecs 

	cmp r1, #inputStatus_acceptedControlCharacter
	beq actionQuit 

	ldr r0, =operationsJumpTable
	ldr r2, =cellWidthInBytes
	ldr r2, [r2]
	lsr r2, #1		@ convert 1, 2, 4 to 0, 1, 2
	add r1, r0, r2, lsl #2	@ convert 0, 1, 2 to 0, 4, 8 for offset into jump table
	ldr r1, [r1]
	ldr r0, =operationsFunction
	str r1, [r0]

	ldr r0, =cellWidthInBytes
	ldr r0, [r0]
	ldr r1, =numberOfCellsInSpreadsheet
	add r1, #1	@ Make room for result cell
	mul r0, r1, r0
	bl malloc
	ldr r1, =spreadsheetDataBuffer
	str r0, [r1]

	ldr r0, =operationsFunction
	ldr r0, [r0]
	ldr r1, =spreadsheetDataBuffer
	ldr r1, [r1]
	ldr r2, =numberOfCellsInSpreadsheet
	ldr r2, [r2]
	bl resetSheet

recalculateSheet:
	ldr r0, =overflowFlag
	push {r0}
	ldr r0, =formula
	ldr r0, [r0]
	ldr r1, =formulaJumpTable
	add r0, r1, r0, lsl #2
	ldr v1, [r0]		@ v1 -> calculation function for formula 
	ldr a1, =operationsFunction
	ldr a1, [a1]
	ldr a2, =spreadsheetDataBuffer
	ldr a2, [a2]
	ldr a3, =numberOfCellsInSpreadsheet
	ldr a3, [a3]
	ldr a4, =formula
	ldr a4, [a4]
	blx v1			@ calculate sheet

redisplaySheet:
	bl clearScreen 

	ldr r0, =presentation
	ldr r0, [r0]
	push {r0}
	ldr r0, =formula
	ldr r0, [r0]
	push {r0}
	ldr r0, =overflowFlag
	ldr r0, [r0]
	push {r0}
	ldr r0, =operationsFunction
	ldr r0, [r0]
	ldr r1, =spreadsheetDataBuffer
	ldr r1, [r1]
	ldr r2, =numberOfCellsInSpreadsheet
	ldr r2, [r2]
	ldr r3, =cellWidthInBytes
	ldr r3, [r3]
	bl displaySheet

	ldr r0, =menuMode
	ldr r0, [r0]		@ r0 = menu mode
	ldr r1, =menuModeJumpTable
	add r1, r1, r0, lsl #2	@ r1 -> jump target for current menu
	ldr r0, [r1]		@ r0 = jump target
	bx r0

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Main Menu
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
menuMain:
	ldr r0, =testMode
	ldr r0, [r0]
	push {r0}
	bl getMainSelection

	cmp r1, #inputStatus_acceptedControlCharacter
	beq actionQuit 
	b actionSwitch

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Change Formula Menu
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
menuChangeFormula:
	ldr a1, =testMode
	ldr a1, [a1]
	push {a1}
	bl getFormula

	cmp r1, #inputStatus_acceptedControlCharacter
	bne setFormula

	cmp r0, #'q'
	beq actionQuit
	cmp r0, #'r'
	beq returnToMain

setFormula:
	sub r0, #1
	ldr r1, =formula
	str r0, [r1]
	b recalculateAndReturnToMain 

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Change data presentation menu
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
menuChangePresentation:
	ldr a1, =testMode
	ldr a1, [a1]
	push {a1}
	bl getPresentation

	cmp r1, #inputStatus_acceptedControlCharacter
	bne setPresentation

	cmp r0, #'q'
	beq actionQuit
	cmp r0, #'r'
	beq returnToMain

setPresentation:
	sub r0, #1
	ldr r1, =presentation
	str r0, [r1]
	b returnToMain

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Get cell to edit menu
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
menuGetCellToEdit:
	b returnToMain

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Get new value for cell menu
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
menuGetNewValueForCell:
	b returnToMain

actionSwitch:
	sub r0, #1			@ user menu selection to 0-based
	ldr r1, =actionsJumpTable
	add r0, r1, r0, lsl #2
	ldr r0, [r0]
	bx r0

actionEditCell:
	b returnToMain

actionChangeFormula:
	ldr r0, =menuMode
	mov r1, #menuMode_changeFormula
	str r1, [r0]
	b redisplaySheet

actionChangePresentation:
	ldr r0, =menuMode
	mov r1, #menuMode_changePresentation
	str r1, [r0]
	b redisplaySheet

actionResetSpreadsheet:
	b returnToMain

actionFillRandom:
	ldr a1, =operationsFunction
	ldr a1, [a1]
	ldr a2, =spreadsheetDataBuffer
	ldr a2, [a2]
	ldr a3, =numberOfCellsInSpreadsheet
	ldr a3, [a3]
	bl randomFill
	b recalculateSheet

recalculateAndReturnToMain:
	ldr r0, =menuMode
	mov r1, #menuMode_main
	str r1, [r0]
	b recalculateSheet

returnToMain:
	ldr r0, =menuMode
	mov r1, #menuMode_main
	str r1, [r0]
	b redisplaySheet

actionQuit:
	ldr r0, =msgByeNow
	bl printf

	mov r7, $1		@ exit syscall
	svc 0			@ wake kernel

	.end

