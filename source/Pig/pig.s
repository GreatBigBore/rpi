.equ inputStatus_inputOk,			0
.equ inputStatus_inputNotOk,			1
.equ inputStatus_acceptedControlCharacter,	2

.equ q_reject,	0
.equ q_accept,	1

.equ r_reject,	0
.equ r_accept,	1

.equ inputBufferSize, 100

.equ terminalCommand_clearScreen, 0
.equ terminalCommand_cursorUp, 1
.equ terminalCommand_clearToEOL, 2
.equ terminalCommand_colorsError, 3
.equ terminalCommand_colorsNormal, 4

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
@ Control stuff for the lightPig functions
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	.equ	leg0_red, 0
	.equ	leg0_orange, 1
	.equ	leg0_yellow, 2
	.equ	leg0_green, 3
	.equ	leg0_white, 12
	.equ	leg0_blue, 14

	.equ	leg1_blue, 4
	.equ	leg1_green, 5
	.equ	leg1_red, 6
	.equ	leg1_orange, 7
	.equ	leg1_yellow, 8
	.equ	leg1_white, 9

	.equ	leg2_white, 10
	.equ	leg2_blue, 11
	.equ	leg2_green, 13
	.equ	leg2_yellow, 15
	.equ	leg2_orange, 16
	.equ	leg2_red, 17

pigLegs:	.word pigLeg0, pigLeg1, pigLeg2
pigRings:	.word pigRingRed, pigRingOrange, pigRingYellow
		.word pigRingGreen, pigRingBlue, pigRingWhite

pigLeg0:	.word leg0_red, leg0_orange, leg0_yellow, leg0_green, leg0_blue, leg0_white
pigLeg1:	.word leg1_red, leg1_orange, leg1_yellow, leg1_green, leg1_blue, leg1_white
pigLeg2:	.word leg2_red, leg2_orange, leg2_yellow, leg2_green, leg2_blue, leg2_white

pigRing0:
pigRingRed:	.word leg0_red, leg1_red, leg2_red

pigRing1:
pigRingOrange:	.word leg0_orange, leg1_orange, leg2_orange

pigRing2:
pigRingYellow:	.word leg0_yellow, leg1_yellow, leg2_yellow

pigRing3:
pigRingGreen:	.word leg0_green, leg1_green, leg2_green

pigRing4:
pigRingBlue:	.word leg0_blue, leg1_blue, leg2_blue

pigRing5:
pigRingWhite:	.word leg0_white, leg1_white, leg2_white

	.arch armv6
	.eabi_attribute 27, 3
	.eabi_attribute 28, 1
	.fpu vfp
	.eabi_attribute 20, 1
	.eabi_attribute 21, 1
	.eabi_attribute 23, 3
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 2
	.eabi_attribute 30, 6
	.eabi_attribute 18, 4
	.file	"oink.c"
	.comm	fd,4,4
	.comm	rev,4,4
	.comm	device,4,4
	.section	.rodata
	.align	2

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ I2CSetup
@
@ returns
@	r0 file descriptor
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	.data
	.align 2

.L1_devicePath:		.ascii "/dev/i2c-"
.L1_deviceNumber:	.asciz "0"

.L1_msgUnableToOpen:	.asciz "Unable to open %s; error = %s\n"
.L1_msgUnableToSelect:	.asciz "Unable to select %s: error = %s\n"

	.text
	.align	2
	.global	I2CSetup

.L1_I2CSlaveID:		.word 0x703

	rFileDescriptor	.req v1
	rBoardRevision	.req v2

	.type	I2CSetup, %function
I2CSetup:

	mFunctionSetup	@ Setup stack frame and local variables

	bl	rpiBoardRev

	mov	rBoardRevision, r0
	ldr	r0, =.L1_deviceNumber
	add	r1, rBoardRevision, #'0' - 1	@ 0-based, plus make it ascii
	strb	r1, [r0]			@ device path ready to use

	ldr	a1, =.L1_devicePath
	mov	a2, #2				@ O_RDWR for open
	bl	open

	mov	rFileDescriptor, r0
	cmp	rFileDescriptor, #0
	bge	.L1_openOk

	bl	__errno_location
	ldr	a1, [r0]
	bl	strerror
	mov	a3, r0
	ldr	a2, =.L1_devicePath
	ldr	a1, =.L1_msgUnableToOpen
	bl	printf
	mvn	r0, #0
	bl	exit

.L1_openOk:
	mov	a1, rFileDescriptor
	ldr	a2, .L1_I2CSlaveID
	mov	a3, #0x54		@ magic number from wiringPi library
	bl	ioctl

	cmp	r0, #0
	bge	.L1_ioctlOk

	bl	__errno_location
	ldr	a1, [r0]
	bl	strerror
	mov	a3, r0
	ldr	a2, =.L1_devicePath
	ldr	a1, =.L1_msgUnableToSelect
	bl	printf
	mvn	r0, #0
	bl	exit

.L1_ioctlOk:
	mov	r0, rFileDescriptor

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rBoardRevision
	.unreq rFileDescriptor

kbhit:
	@ args = 0, pretend = 0, frame = 128
	@ frame_needed = 1, uses_anonymous_args = 0
	stmfd	sp!, {fp, lr}
	add	fp, sp, #4
	sub	sp, sp, #128
	sub	r3, fp, #72
	mov	r0, #0
	mov	r1, r3
	bl	tcgetattr
	sub	ip, fp, #132
	sub	lr, fp, #72
	ldmia	lr!, {r0, r1, r2, r3}
	stmia	ip!, {r0, r1, r2, r3}
	ldmia	lr!, {r0, r1, r2, r3}
	stmia	ip!, {r0, r1, r2, r3}
	ldmia	lr!, {r0, r1, r2, r3}
	stmia	ip!, {r0, r1, r2, r3}
	ldmia	lr, {r0, r1, r2}
	stmia	ip, {r0, r1, r2}
	ldr	r3, [fp, #-120]
	bic	r3, r3, #10
	str	r3, [fp, #-120]
	sub	r3, fp, #132
	mov	r0, #0
	mov	r1, #0
	mov	r2, r3
	bl	tcsetattr
	mov	r0, #0
	mov	r1, #3
	mov	r2, #0
	bl	fcntl
	str	r0, [fp, #-8]
	ldr	r3, [fp, #-8]
	orr	r3, r3, #2048
	mov	r0, #0
	mov	r1, #4
	mov	r2, r3
	bl	fcntl
	bl	getchar
	str	r0, [fp, #-12]
	sub	r3, fp, #72
	mov	r0, #0
	mov	r1, #0
	mov	r2, r3
	bl	tcsetattr
	mov	r0, #0
	mov	r1, #4
	ldr	r2, [fp, #-8]
	bl	fcntl
	ldr	r3, [fp, #-12]
	cmn	r3, #1
	beq	.L2
	ldr	r3, .L4
	ldr	r3, [r3, #0]
	ldr	r0, [fp, #-12]
	mov	r1, r3
	bl	ungetc
	mov	r3, #1
	b	.L3
.L2:
	mov	r3, #0
.L3:
	mov	r0, r3
	sub	sp, fp, #4
	ldmfd	sp!, {fp, pc}
.L5:
	.align	2
.L4:
	.word	stdin
	.size	kbhit, .-kbhit

	.align	2
	.section	.rodata
	.align	2
.LC4:
	.ascii	"piBoardRev: Unable to determine board revision from"
	.ascii	" /proc/cpuinfo\012\000"
	.align	2
.LC5:
	.ascii	" -> %s\012\000"
	.align	2
.LC6:
	.ascii	" ->  You may want to check:\012\000"
	.align	2
.LC7:
	.ascii	" ->  http://www.raspberrypi.org/phpBB3/viewtopic.ph"
	.ascii	"p?p=184410#p184410\012\000"
	.text
	.align	2
	.type	rpiBoardRevOops, %function
rpiBoardRevOops:
	@ args = 0, pretend = 0, frame = 8
	@ frame_needed = 1, uses_anonymous_args = 0
	stmfd	sp!, {fp, lr}
	add	fp, sp, #4
	sub	sp, sp, #8
	str	r0, [fp, #-8]
	ldr	r2, .L9
	ldr	r3, .L9+4
	ldr	r3, [r3, #0]
	mov	r0, r2
	mov	r1, #1
	mov	r2, #66
	bl	fwrite
	ldr	r3, .L9+4
	ldr	r3, [r3, #0]
	mov	r2, r3
	ldr	r3, .L9+8
	mov	r0, r2
	mov	r1, r3
	ldr	r2, [fp, #-8]
	bl	fprintf
	ldr	r2, .L9+12
	ldr	r3, .L9+4
	ldr	r3, [r3, #0]
	mov	r0, r2
	mov	r1, #1
	mov	r2, #28
	bl	fwrite
	ldr	r2, .L9+16
	ldr	r3, .L9+4
	ldr	r3, [r3, #0]
	mov	r0, r2
	mov	r1, #1
	mov	r2, #70
	bl	fwrite
	mov	r0, #1
	bl	exit
.L10:
	.align	2
.L9:
	.word	.LC4
	.word	stderr
	.word	.LC5
	.word	.LC6
	.word	.LC7
	.size	rpiBoardRevOops, .-rpiBoardRevOops
	.comm	cpuFd,4,4
	.comm	line,120,4
	.comm	c,4,4
	.comm	lastChar,1,1
	.global	boardRev
	.data
	.align	2
	.type	boardRev, %object
	.size	boardRev, 4
boardRev:
	.word	-1
	.section	.rodata
	.align	2
.LC8:
	.ascii	"/proc/cpuinfo\000"
	.align	2
.LC9:
	.ascii	"r\000"
	.align	2
.LC10:
	.ascii	"Unable to open /proc/cpuinfo\000"
	.align	2
.LC11:
	.ascii	"Revision\000"
	.align	2
.LC12:
	.ascii	"No \"Revision\" line\000"
	.align	2
.LC13:
	.ascii	"piboardRev: Revision string: %s\012\000"
	.align	2
.LC14:
	.ascii	"No numeric revision string\000"
	.align	2
.LC15:
	.ascii	"piboardRev: This Pi has/is overvolted!\000"
	.align	2
.LC16:
	.ascii	"piboardRev: lastChar is: '%c' (%d, 0x%02X)\012\000"
	.align	2
.LC17:
	.ascii	"piBoardRev: Returning revision: %d\012\000"
	.text
	.align	2
	.global	rpiBoardRev
	.type	rpiBoardRev, %function
rpiBoardRev:
	@ args = 0, pretend = 0, frame = 0
	@ frame_needed = 1, uses_anonymous_args = 0
	stmfd	sp!, {fp, lr}
	add	fp, sp, #4
	ldr	r3, .L33
	ldr	r3, [r3, #0]
	cmn	r3, #1
	beq	.L12
	ldr	r3, .L33
	ldr	r3, [r3, #0]
	b	.L13
.L12:
	ldr	r2, .L33+4
	ldr	r3, .L33+8
	mov	r0, r2
	mov	r1, r3
	bl	fopen
	mov	r2, r0
	ldr	r3, .L33+12
	str	r2, [r3, #0]
	ldr	r3, .L33+12
	ldr	r3, [r3, #0]
	cmp	r3, #0
	bne	.L30
	ldr	r0, .L33+16
	bl	rpiBoardRevOops
	b	.L30
.L17:
	ldr	r0, .L33+20
	ldr	r1, .L33+24
	mov	r2, #8
	bl	strncmp
	mov	r3, r0
	cmp	r3, #0
	beq	.L31
	b	.L15
.L30:
	mov	r0, r0	@ nop
.L15:
	ldr	r3, .L33+12
	ldr	r3, [r3, #0]
	ldr	r0, .L33+20
	mov	r1, #120
	mov	r2, r3
	bl	fgets
	mov	r3, r0
	cmp	r3, #0
	bne	.L17
	b	.L16
.L31:
	mov	r0, r0	@ nop
.L16:
	ldr	r3, .L33+12
	ldr	r3, [r3, #0]
	mov	r0, r3
	bl	fclose
	ldr	r0, .L33+20
	ldr	r1, .L33+24
	mov	r2, #8
	bl	strncmp
	mov	r3, r0
	cmp	r3, #0
	beq	.L18
	ldr	r0, .L33+28
	bl	rpiBoardRevOops
.L18:
	ldr	r0, .L33+20
	bl	strlen
	mov	r3, r0
	sub	r2, r3, #1
	ldr	r3, .L33+20
	add	r2, r2, r3
	ldr	r3, .L33+32
	str	r2, [r3, #0]
	b	.L19
.L20:
	ldr	r3, .L33+32
	ldr	r3, [r3, #0]
	mov	r2, #0
	strb	r2, [r3, #0]
	ldr	r3, .L33+32
	ldr	r3, [r3, #0]
	sub	r2, r3, #1
	ldr	r3, .L33+32
	str	r2, [r3, #0]
.L19:
	ldr	r3, .L33+32
	ldr	r3, [r3, #0]
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	cmp	r3, #10
	beq	.L20
	ldr	r3, .L33+32
	ldr	r3, [r3, #0]
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	cmp	r3, #13
	beq	.L20
	ldr	r3, .L33+36
	mov	r0, r3
	ldr	r1, .L33+20
	bl	printf
	ldr	r3, .L33+32
	ldr	r2, .L33+20
	str	r2, [r3, #0]
	b	.L21
.L24:
	bl	__ctype_b_loc
	mov	r3, r0
	ldr	r2, [r3, #0]
	ldr	r3, .L33+32
	ldr	r3, [r3, #0]
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	mov	r3, r3, asl #1
	add	r3, r2, r3
	ldrh	r3, [r3, #0]
	and	r3, r3, #2048
	cmp	r3, #0
	bne	.L32
.L22:
	ldr	r3, .L33+32
	ldr	r3, [r3, #0]
	add	r2, r3, #1
	ldr	r3, .L33+32
	str	r2, [r3, #0]
.L21:
	ldr	r3, .L33+32
	ldr	r3, [r3, #0]
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	cmp	r3, #0
	bne	.L24
	b	.L23
.L32:
	mov	r0, r0	@ nop
.L23:
	bl	__ctype_b_loc
	mov	r3, r0
	ldr	r2, [r3, #0]
	ldr	r3, .L33+32
	ldr	r3, [r3, #0]
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	mov	r3, r3, asl #1
	add	r3, r2, r3
	ldrh	r3, [r3, #0]
	and	r3, r3, #2048
	cmp	r3, #0
	bne	.L25
	ldr	r0, .L33+40
	bl	rpiBoardRevOops
.L25:
	ldr	r3, .L33+32
	ldr	r3, [r3, #0]
	mov	r0, r3
	bl	strlen
	mov	r3, r0
	cmp	r3, #4
	beq	.L26
	ldr	r0, .L33+44
	bl	puts
.L26:
	ldr	r0, .L33+20
	bl	strlen
	mov	r3, r0
	sub	r3, r3, #1
	ldr	r2, .L33+20
	ldrb	r2, [r2, r3]	@ zero_extendqisi2
	ldr	r3, .L33+48
	strb	r2, [r3, #0]
	ldr	r0, .L33+52
	ldr	r3, .L33+48
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	mov	r1, r3
	ldr	r3, .L33+48
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	mov	r2, r3
	ldr	r3, .L33+48
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	bl	printf
	ldr	r3, .L33+48
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	cmp	r3, #50
	beq	.L27
	ldr	r3, .L33+48
	ldrb	r3, [r3, #0]	@ zero_extendqisi2
	cmp	r3, #51
	bne	.L28
.L27:
	ldr	r3, .L33
	mov	r2, #1
	str	r2, [r3, #0]
	b	.L29
.L28:
	ldr	r3, .L33
	mov	r2, #2
	str	r2, [r3, #0]
.L29:
	ldr	r2, .L33+56
	ldr	r3, .L33
	ldr	r3, [r3, #0]
	mov	r0, r2
	mov	r1, r3
	bl	printf
	ldr	r3, .L33
	ldr	r3, [r3, #0]
.L13:
	mov	r0, r3
	ldmfd	sp!, {fp, pc}
.L34:
	.align	2
.L33:
	.word	boardRev
	.word	.LC8
	.word	.LC9
	.word	cpuFd
	.word	.LC10
	.word	line
	.word	.LC11
	.word	.LC12
	.word	c
	.word	.LC13
	.word	.LC14
	.word	.LC15
	.word	lastChar
	.word	.LC16
	.word	.LC17
	.size	rpiBoardRev, .-rpiBoardRev
	.comm	theData,1,1
	.comm	args,12,4

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ writeI2CRegister
@
@ registers:
@	a1 file descriptor
@	a2 register to write to
@	a3 value to write
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	.section .data
	.align 2

.L2_PigCommand:	.word 0
.L2_I2CCommand:	.word 0
		.word 0
		.word 0

	.section .text
	.align	2
	.global	writeI2CRegister
	.type	writeI2CRegister, %function

	rFileDescriptor		.req v1
	rTargetRegister		.req v2
	rValueToWrite		.req v3
	rPigCommand		.req v4
	rI2CCommand		.req v5

writeI2CRegister:
	mFunctionSetup	@ Setup stack frame and local variables

	ldr	rPigCommand, =.L2_PigCommand
	ldr	rI2CCommand, =.L2_I2CCommand

	strb	rValueToWrite, [rPigCommand]

	mov	r0, #0
	strb	r0, [rI2CCommand, #0]			@ i2cCommand.rw = I2C_SMBUS_WRITE
	strb	rTargetRegister, [rI2CCommand, #1]	@ i2cCommand.register = register
	mov	r0, #2
	str	r0, [rI2CCommand, #4]			@ i2cCommand. "size" = I2C_SMBUS_BYTE_DATA
	ldr	r0, =.L2_PigCommand
	str	r0, [rI2CCommand, #8]			@ i2cCommand.data = &theData

	mov	a1, rFileDescriptor	@ file descriptor
	mov	a2, #0x720		@ I2C_SMBUS
	mov	a3, rI2CCommand		@ a3 -> i2cCommand
	bl	ioctl
	mov	r3, r0
	mov	r0, r3

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor
	.unreq rTargetRegister
	.unreq rValueToWrite
	.unreq rPigCommand
	.unreq rI2CCommand

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ setPigLEDRegister
@
@ registers:
@	a1 file descriptor
@	a2 led to light 0 - 17
@	a3 intensity 0 - 255
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	rFileDescriptor	.req v1
	rPinToWrite	.req v2
	rValueToWrite	.req v3

	.align	2
	.type	setPigLEDRegister, %function
setPigLEDRegister:
	mFunctionSetup	@ Setup stack frame and local variables

	mov	a1, rFileDescriptor
	add	a2, rPinToWrite, #1
	and	a3, rValueToWrite, #0xFF
	bl	writeI2CRegister		@ write the value

	mov	a1, rFileDescriptor
	mov	a2, #0x16
	mov	a3, #0
	bl	writeI2CRegister		@ update? commit?

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor
	.unreq rPinToWrite
	.unreq rValueToWrite

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ lightPigAll
@
@ registers:
@	a1 file descriptor
@	a2 intensity 0 - 255
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	.text
	.align	2

	rFileDescriptor	.req v1
	rIntensity	.req v2
	rLoopCounter	.req v3

lightPigAll:
	mFunctionSetup		@ Setup stack frame and local variables

.L8_loopInit:
	mov	rLoopCounter, #0

.L8_loopTop:
	cmp	rLoopCounter, #18
	bhs	.L8_loopExit

	mov	a1, rFileDescriptor
	mov	a2, rLoopCounter
	mov	a3, rIntensity
	bl	setPigLEDRegister

.L8_loopBottom:
	add	rLoopCounter, #1
	b	.L8_loopTop

.L8_loopExit:
	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor
	.unreq rIntensity
	.unreq rLoopCounter

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ lightPigLeg
@
@ registers:
@	a1 file descriptor
@	a2 leg to light 0 - 3
@	a3 intensity 0 - 255
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	.text
	.align	2

lightPigLeg:
	mFunctionSetup	@ Setup stack frame and local variables


	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ lightPigLED
@
@ registers:
@	a1 file descriptor
@	a2 ring to light 0 - 5
@	a3 leg to lght 0 - 3
@	a4 intensity 0 - 255
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	.text
	.align	2

	rFileDescriptor	.req v1
	rRingToLight	.req v2
	rLegToLight	.req v3
	rIntensity	.req v4
	rLEDToLight	.req v5

lightPigLED:
	mFunctionSetup		@ Setup stack frame and local variables

	ldr	r0, =pigRings
	ldr	r0, [r0, rRingToLight, lsl #2]
	ldr	rLEDToLight, [r0, rLegToLight, lsl #2]

	mov	a1, rFileDescriptor
	mov	a2, rLEDToLight
	mov	a3, rIntensity
	bl	setPigLEDRegister

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor
	.unreq rRingToLight
	.unreq rLegToLight
	.unreq rLEDToLight
	.unreq rIntensity

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ lightPigRing
@
@ registers:
@	a1 file descriptor
@	a2 ring to light 0 - 5
@	a3 intensity 0 - 255
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	.text
	.align	2

	rFileDescriptor	.req v1
	rRingToLight	.req v2
	rIntensity	.req v3
	rThisRingBase	.req v4
	rLoopCounter	.req v5

lightPigRing:
	mFunctionSetup	@ Setup stack frame and local variables

.L6_loopInit:
	mov	rLoopCounter, #0
	ldr	r0, =pigRings
	ldr	rThisRingBase, [r0, rRingToLight, lsl #2]

.L6_loopTop:
	cmp	rLoopCounter, #3
	bhs	.L6_loopExit

	mov	a1, rFileDescriptor
	ldr	a2, [rThisRingBase, rLoopCounter, lsl #2]
	mov	a3, rIntensity
	bl	setPigLEDRegister

.L6_loopBottom:
	add	rLoopCounter, #1
	b	.L6_loopTop

.L6_loopExit:
	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor
	.unreq rRingToLight
	.unreq rIntensity
	.unreq rThisRingBase
	.unreq rLoopCounter

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ pigSetup
@
@ returns:
@	r0 file descriptor
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	.align	2
	.global	pigSetup
	.type	pigSetup, %function

	rFileDescriptor	.req v1

pigSetup:
	mFunctionSetup	@ Setup stack frame and local variables

	bl	I2CSetup
	mov	rFileDescriptor, r0
	cmp	rFileDescriptor, #0
	blo	.L41

	@ wiringPi lib says "not shutdown" -- reset?
	mov	a1, rFileDescriptor
	mov	a2, #0
	mov	a3, #1
	bl	writeI2CRegister

	@ enable LEDs 0 - 5
	mov	a1, rFileDescriptor
	mov	a2, #0x13
	mov	a3, #0x3F
	bl	writeI2CRegister

	@ enable LEDs 6 - 11
	mov	a1, rFileDescriptor
	mov	a2, #0x14
	mov	a3, #0x3F
	bl	writeI2CRegister

	@ enable LEDs 12 - 17
	mov	a1, rFileDescriptor
	mov	a2, #0x15
	mov	a3, #0x3F
	bl	writeI2CRegister

	@ update
	mov	a1, rFileDescriptor
	mov	a2, #0x16
	mov	a3, #0
	bl	writeI2CRegister

.L41:
	mov	r0, rFileDescriptor

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor

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
@ sayYuck
@
@	a1 string with yucky value
@	a2 prompt suffix
@	a3 skip second cursor-up
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L18_yuckMessage:	.asciz "Uhh... %s? Yuck! Try again!\n-> "

.section .text
.align 3

	rYuckyValue		.req v1
	rPromptSuffix		.req v2
	rSkipSecondCursorUp	.req v3

sayYuck:
	mFunctionSetup	@ Setup stack frame and local variables

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
@ getMainSelection
@
@ stack: 
@	+4 testMode
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.section .data

.L5_msgInstructions:	.asciz "Options (enter 'Q' to quit):\n"
.L5_msgSeparator:	.asciz "----------------------------\n"

.L5_inwardSpiral:	.asciz "Inward spiral"
.L5_tailChase:		.asciz "Tail chase"
.L5_blindMe:		.asciz "Blind me!"

.L5_menuOptions:	.word .L5_inwardSpiral, .L5_tailChase, .L5_blindMe

.equ .L5_menuOptionsCount, 3

	.text
	.align 2

getMainSelection:
	mFunctionSetup

	ldr r0, [fp, #4]
	mov r1, #q_accept
	mov r2, #r_reject
	push {r0 - r2}
	ldr a1, =.L5_msgInstructions
	ldr a2, =.L5_msgSeparator
	ldr a3, =.L5_menuOptions
	mov a4, #.L5_menuOptionsCount
	bl runMenu

	mFunctionBreakdown 1
	bx lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	
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
@ demoBlindMe
@
@	a1 file descriptor
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	.text
	.align 2

	rFileDescriptor	.req v1
	rIntensityLimit	.req v2
	rLoopCounter	.req v7

demoBlindMe:
	mFunctionSetup		@ Setup stack frame and local variables

.L10_restartFromZero:
	mov	rIntensityLimit, #1

.L10_upLoopInit:
	mov	rLoopCounter, #0

.L10_upLoopTop:
	cmp	rLoopCounter, rIntensityLimit
	bhs	.L10_upLoopExit

	mov	a1, rFileDescriptor
	mov	a2, rLoopCounter
	bl	lightPigAll
	
.L10_upLoopBottom:
	mov	a1, #0x3D
	lsl	a1, #8			@ get about 250k into a1
	bl	usleep			@ sleep for about .25 sec

	add	rLoopCounter, #10
	b	.L10_upLoopTop

.L10_upLoopExit:

.L10_downLoopInit:
	sub	rLoopCounter, rIntensityLimit, #1

.L10_downLoopTop:
	cmp	rLoopCounter, #0
	blt	.L10_downLoopExit

	mov	a1, rFileDescriptor
	mov	a2, rLoopCounter
	bl	lightPigAll

.L10_downLoopBottom:
	mov	a1, #0x3D
	lsl	a1, #8
	bl	usleep

	sub	rLoopCounter, #10
	b	.L10_downLoopTop

.L10_downLoopExit:
	bl	kbhit
	cmp	r0, #0
	bne	.L10_finished

	add	rIntensityLimit, #10
	cmp	rIntensityLimit, #250
	bhs	.L10_restartFromZero
	b	.L10_upLoopInit

.L10_finished:
	bl	getchar		@ eat the key

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor
	.unreq rIntensityLimit
	.unreq rLoopCounter

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ demoTailChase
@
@	a1 file descriptor
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	.text
	.align 2

	rFileDescriptor		.req v1
	rChaseLoopCounter	.req v2
	rPreviousLeg		.req v4
	rPreviousRing		.req v5
	rWhichLeg		.req v6
	rWhichRing		.req v7

demoTailChase:
	mFunctionSetup		@ Setup stack frame and local variables

	mov	a1, rFileDescriptor
	mov	a2, #0
	bl	lightPigAll	@ make sure everything is off to start with

.L11_ringLoopInit:
	mov	rWhichRing, #0

.L11_ringLoopTop:
	cmp	rWhichRing, #6
	bhs	.L11_ringLoopExit

.L11_chaseLoopInit:
	mov	rChaseLoopCounter, #0

.L11_chaseLoopTop:
	cmp	rChaseLoopCounter, #5
	bhs	.L11_chaseLoopExit

.L11_legLoopInit:
	mov	rWhichLeg, #2

.L11_legLoopTop:
	cmp	rWhichLeg, #0
	blt	.L11_legLoopExit

	mov	a1, rFileDescriptor
	mov	a2, rPreviousRing
	mov	a3, rPreviousLeg
	mov	a4, #0			@ intensity
	bl	lightPigLED		@ turn off the previous one

	mov	a1, rFileDescriptor
	mov	a2, rWhichRing
	mov	a3, rWhichLeg
	mov	a4, #5			@ intensity
	bl	lightPigLED

	mov	rPreviousRing, rWhichRing
	mov	rPreviousLeg, rWhichLeg

.L11_legLoopBottom:
	mov	a1, #0x10
	lsl	a1, #12
	bl	usleep

	sub	rWhichLeg, #1
	b	.L11_legLoopTop

.L11_legLoopExit:
.L11_chaseLoopBottom:
	add	rChaseLoopCounter, #1
	b	.L11_chaseLoopTop

.L11_chaseLoopExit:
.L11_ringLoopBottom:
	add	rWhichRing, #1
	b	.L11_ringLoopTop

.L11_ringLoopExit:
	mov	a1, rFileDescriptor
	mov	a2, #5			@ turn off the last ring
	mov	a3, #0			@ intensity
	bl	lightPigRing

	bl	kbhit
	cmp	r0, #0
	beq	.L11_ringLoopInit

	bl	getchar		@ eat the key

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor
	.unreq rChaseLoopCounter
	.unreq rPreviousLeg
	.unreq rPreviousRing
	.unreq rWhichLeg
	.unreq rWhichRing

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ demoInwardSpiral
@
@	a1 file descriptor
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	.text
	.align 2

	rFileDescriptor	.req v1
	rLoopCounter	.req v7

demoInwardSpiral:
	mFunctionSetup		@ Setup stack frame and local variables

.L9_loopInit:
	mov	a1, rFileDescriptor
	mov	a2, #0
	bl	lightPigAll	@ make sure everything is off to start with

	mov	rLoopCounter, #0

.L9_loopTop:
	cmp	rLoopCounter, #6
	bhs	.L9_loopExit

	mov	a1, rFileDescriptor
	mov	a2, rLoopCounter	@ ring to light
	mov	a3, #1			@ intensity
	bl	lightPigRing

	cmp	rLoopCounter, #0
	beq	.L9_loopBottom

	mov	a1, rFileDescriptor
	sub	a2, rLoopCounter, #1	@ ring to extinguish
	mov	a3, #0			@ intensity
	bl	lightPigRing

.L9_loopBottom:
	mov	a1, #0x3D
	lsl	a1, #12			@ get about 250k into a1
	bl	usleep			@ sleep for about .25 sec

	add	rLoopCounter, #1
	b	.L9_loopTop

.L9_loopExit:
	mov	a1, rFileDescriptor
	mov	a2, #5			@ turn off the last ring
	mov	a3, #0			@ intensity
	bl	lightPigRing

	bl	kbhit
	cmp	r0, #0
	beq	.L9_loopInit

	bl	getchar		@ eat the key

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor
	.unreq rLoopCounter

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	.section .data
	.align 2

.L0_localVariables:

testMode	= .-.L0_localVariables; .word 0

.L0_msgGreeting:	.asciz	"Greetings, experimental subject.\n\n"
.L0_msgByeNow:		.asciz "'Bye now!\n"

.L0_actionsJumpTable:
		.word .L0_inwardSpiral
		.word .L0_tailChase
		.word .L0_blindMe

	.global	main

	.section .text
	.align 2

	rFileDescriptor		.req v1

main:
	ldr	fp, =.L0_localVariables	@ setup local stack frame

	mov	r1, #1	@ default to test mode
	cmp	r0, #1	@ number of cmdline args
	moveq	r1, #0	@ if only one cmdline arg (prog name), not test mode
	str	r1, [fp, #testMode]

	mov	a1, #0
	bl	time
	bl	srand

	bl	pigSetup
	mov	rFileDescriptor, r0

.L0_mainMenu:
	mTerminalCommand #terminalCommand_clearScreen

	ldr	a1, =.L0_msgGreeting
	bl	printf

	ldr	r0, [fp, #testMode]
	push	{r0}
	bl	getMainSelection

	cmp	r1, #inputStatus_acceptedControlCharacter
	beq	.L0_actionQuit 

.L0_actionSwitch:
	sub	r0, #1			@ user menu selection to 0-based
	ldr	r1, =.L0_actionsJumpTable
	add	r0, r1, r0, lsl #2
	ldr	r0, [r0]
	bx	r0

.L0_inwardSpiral:
	mov	a1, rFileDescriptor
	bl	demoInwardSpiral
	b	.L0_mainMenu

.L0_blindMe:
	mov	a1, rFileDescriptor
	bl	demoBlindMe
	b	.L0_mainMenu

.L0_tailChase:
	mov	a1, rFileDescriptor
	bl	demoTailChase
	b	.L0_mainMenu

.L0_actionQuit:
	ldr	r0, =.L0_msgByeNow
	bl	printf
	mov	r0, #0
	bl	fflush		@ make sure it's all out, for our test harness
	mov	r0, #0
	bl	exit

