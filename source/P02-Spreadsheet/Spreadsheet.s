@/*
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
.section .bss

.comm buffer, 48	     @ reserve 48 byte buffer

.section .data

msgGreeting: .asciz "Greetings, data analyzer.\r\n"
msgSetupIntro: .asciz "To set up, enter spreadsheet size and data width.\r\n"

.section .text

	.global main

main:
	bl clearScreen

	ldr r0, =msgGreeting
	bl printf

	ldr r0, =msgSetupIntro
	bl printf

	mov r7, $1		@ exit syscall
	svc 0			@ wake kernel

.section .data

msgClearScreen: .ascii "\033[2J\033[H"
L_msgClearScreen = . - msgClearScreen

.section .text

clearScreen:
	mov r0, $1
	ldr r1, =msgClearScreen
	ldr r2, =L_msgClearScreen
	mov r7, $4
	svc 0
	mov pc, lr

	.end

