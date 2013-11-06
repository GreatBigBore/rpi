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

.section .bss

.comm buffer, 48	     @ reserve 48 byte buffer

.section .data

msg:
	.ascii	"** Greeter **\nDammit, enter your name! -> "
	msgLen = . - msg

msg2:
	.ascii	"Hello "
	msg2Len = . - msg2

.section .text

.globl _start
_start:

mov r0, $1		    @ print program's opening message	
ldr r1, =msg
ldr r2, =msgLen
mov r7, $4
svc $0

mov r7, $3		    @ read syscall
mov r0, $1		
ldr r1, =buffer
mov r2, $0x30
svc $0

mov r0, $1		    @ print msg2
ldr r1, =msg2
ldr r2, =msg2Len
mov r7, $4
svc $0

mov r0, $1		    @ now print the user input
ldr r1, =buffer
mov r2, $0x30
mov r7, $4
svc $0

mov r7, $1	            @ exit syscall
svc $0		            @ wake kernel
.end
