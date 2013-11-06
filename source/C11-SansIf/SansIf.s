/*
 * SansIf
 *
 * written by			Rob Bishop
 * created on			05 November 2013
 * last modified on		05 November 2013
 *
 * Write, compile, and execute a complete [MIPS] program that does the following:
 *
 * 1. uses only low-level decisions
 * 2. contains a static int8 variable named number8
 * 3. contains a static int16 variable named number16
 * 4. contains a static int32 variable named number32
 *
 * 5. has a robust getInt8 procedure that takes a string parameter representing the
 *		user prompt, min and max parameters; guarantees a user input value in the
 *		range min to max inclusive; returns the input value in al; @forward declare the procedure
 *
 * 6. has a robust getInt16 procedure that takes a string parameter representing the
 *		user prompt, min and max parameters; guarantees a user input value in the
 *		range min to max inclusive; returns the input value in ax; @forward declare the procedure
 *
 * 7. has a robust getInt32 procedure that takes a string parameter representing the
 *		user prompt, min and max parameters; guarantees a user input value in the
 *		range min to max inclusive; returns the input value in eax; @forward declare the procedure
 *
 * 8. has a procedure displayValue that takes a dword parameter (a memory address) and an uns8
 *		parameter (possible values: 1 (int8), 2 (int16), 3 (int32)) representing the data type of
 *		the memory associated with the address; displayValue will:
 *	a. display the address
 *	b. display the value at the address
 *	c. display the data type
 *	d. sample output: $0FF01234 = 99 (int8)
 *
 * 9. main loop (give the user the option to repeat):
 *	a. use getInt8 to get a user input -- store the input in number8
 *	b. use getInt16 to get a user input -- store the input in number16
 *	c. use getInt32 to get a user input -- store the input in number32
 *	d. pass the address of number8 into displayValue
 *	e. pass the address of number16 into displayValue
 *	f. pass the address of number32 into displayValue
 */

	.global main
	.func main
	
main:
	stmfd SP!, {lr}
	ldr r0, =string
	bl printf
	ldmfd sp!, {pc}
	
_exit:
	mov pc, lr
	
.data

string: .asciz "Hello, World\n";

@ Not sure yet what this stuff is about
values: .byte 1, 2, 3, 4, 5, 6, 7, 8, 9
endvalues: