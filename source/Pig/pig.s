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
@ getWager
@
@ registers
@	a1 user prompt
@	a2 minimum wager
@	a3 maximum wager
@
@ returns
@	r0 file descriptor
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	.data
	.align 2

.L3_getsBuffer:		.skip inputBufferSize
.L3_scanf:		.asciz "%d"
.L3_scanfResult:	.word 0

	.text
	.align 2

getWager:
	mFunctionSetup	@ Setup stack frame and local variables

	bl printf	@ display the prompt that has been set up for us

	ldr	a1, =.L3_getsBuffer
	bl	gets

	ldr	a1, =.L3_getsBuffer
	ldr	a2, =.L3_scanf
	ldr	a3, =.L3_scanfResult
	bl	sscanf

	ldr	r1, =.L3_scanfResult
	ldr	r0, [r1]	@ return user's wager

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

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
	cmp	rLoopCounter, #17
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
	rLEDToLight	.req v4
	rIntensity	.req v5

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

	.comm	i,4,4
	.comm	j,4,4

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
@ getSlotForValue
@
@ registers:
@	a1 value
@
@ returns
@	r0 slot number
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	.data
	.align 2

.L7_limits:
.L7_redLimit:		.word 0			@ 0% of 2^32
.L7_orangeLimit:	.word 1288490188	@ 30%
.L7_yellowLimit:	.word 2362232012	@ 55%
.L7_greenLimit:		.word 3221225472	@ 75%
.L7_blueLimit:		.word 3865470566	@ 90%
.L7_whiteLimit:		.word 4294967295	@ 2^32 - 1

	.text
	.align 2

	rValue		.req v1
	rLoopCounter	.req v2
	rSlotLimit	.req v3
	rLimitsBase	.req v4

getSlotForValue:
	mFunctionSetup		@ Setup stack frame and local variables

.L7_loopInit:
	ldr	rLimitsBase, =.L7_limits
	mov	rLoopCounter, #1

.L7_loopTop:
	cmp	rLoopCounter, #6
	bhs	.L7_loopExit

	ldr	rSlotLimit, [rLimitsBase, rLoopCounter, lsl #2]
	cmp	rValue, rSlotLimit	@ if rValue < rSlotLimit
	blo	.L7_loopExit		@ we have our slot number

.L7_loopBottom:
	add	rLoopCounter, #1
	b	.L7_loopTop

.L7_loopExit:
	mov	r0, rLoopCounter	@ return value is the slot number

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rValue
	.unreq rLoopCounter
	.unreq rSlotLimit
	.unreq rLimitsBase

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ spinWheels
@
@ registers:
@	a1 file descriptor
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	.data
	.align 2

.L4_colors:
		.word .L4_whiteName
		.word .L4_blueName
		.word .L4_greenName
		.word .L4_yellowName
		.word .L4_orangeName
		.word .L4_redName

.L4_whiteName:	.asciz "white"
.L4_blueName:	.asciz "blue"
.L4_greenName:	.asciz "green"
.L4_yellowName:	.asciz "yellow"
.L4_orangeName:	.asciz "orange"
.L4_redName:	.asciz "red"

.L4_msgYouLandedOn:	.asciz "You landed on %s\n"

	.text
	.align 2

	rFileDescriptor	.req v1
	rLoopCounter	.req v2
	rSlot1		.req v3
	rSlot2		.req v4
	rSlot0		.req v5

spinWheels:
	mFunctionSetup	@ Setup stack frame and local variables

	mov	a1, rFileDescriptor
	mov	a2, #0
	bl	lightPigAll	@ turn off all the LEDs

	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	@ Something strange happens with rand that causes me to get all
	@ positive values when working with 16-bit cells. The ror is there to
	@ mix things up a bit and hopefully give me both positive and negative
	@ values in a random, or at least apparently random distribution. 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	bl	rand		@ returns rand in r0
	ror	r0, #1		@ because I want a full range
	bl	getSlotForValue	@ convert value to slot, ie, ring #
	mov	rSlot0, r0

	bl	rand		@ returns rand in r0
	ror	r0, #1		@ because I want a full range
	bl	getSlotForValue	@ convert value to slot, ie, ring #
	mov	rSlot1, r0

	bl	rand		@ returns rand in r0
	ror	r0, #1		@ because I want a full range
	bl	getSlotForValue	@ convert value to slot, ie, ring #
	mov	rSlot2, r0

.L4_loopInit:
	mov	rLoopCounter, #0

.L4_loopTop:
	cmp	rLoopCounter, #6
	bhs	.L4_loopExit

	mov	a1, rFileDescriptor
	mov	a2, rLoopCounter	@ ring to light
	mov	a3, #1			@ intensity
	bl	lightPigRing

	cmp	rLoopCounter, #0
	beq	.L4_loopBottom

	mov	a1, rFileDescriptor
	sub	a2, rLoopCounter, #1	@ ring to extinguish
	mov	a3, #0			@ intensity
	bl	lightPigRing

.L4_loopBottom:
	mov	a1, #0x3D
	lsl	a1, #12			@ get about 250k into a1
	bl	usleep			@ sleep for about .25 sec

	add	rLoopCounter, #1
	b	.L4_loopTop

.L4_loopExit:
	mov	a1, rFileDescriptor
	mov	a2, #5			@ turn off the last ring
	mov	a3, #0			@ intensity
	bl	lightPigRing

	mov	a1, rFileDescriptor
	mov	a2, rSlot0	@ which ring
	mov	a3, #0		@ which leg
	mov	a4, #1		@ intensity
	bl	lightPigLED

	mov	a1, rFileDescriptor
	mov	a2, rSlot1	@ which ring
	mov	a3, #1		@ which leg
	mov	a4, #1		@ intensity
	bl	lightPigLED

	mov	a1, rFileDescriptor
	mov	a2, rSlot2	@ which ring
	mov	a3, #2		@ which leg
	mov	a4, #1		@ intensity
	bl	lightPigLED

	mFunctionBreakdown 0	@ restore caller's locals and stack frame
	bx lr

	.unreq rFileDescriptor
	.unreq rLoopCounter
	.unreq rSlot0
	.unreq rSlot1
	.unreq rSlot2

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

	.section .data
	.align 2

	.equ maximumWager, 3

.L0_localVariables:

testMode	= .-.L0_localVariables; .word 0
currentBankroll	= .-.L0_localVariables; .word 1000

.L0_msgGreeting:	.asciz	"Greetings, big spender\n"
.L0_msgByeNow:		.asciz "'Bye now!\n"
.L0_msgEnterYourWager:	.asciz "Enter your wager [%d, %d] -> "
.L0_msgYouHaveBet:	.asciz "You have bet $%d.\nSpinning..."

	.global	main

	.section .text
	.align 2

	rFileDescriptor		.req v1
	rLEDLevel		.req v2
	rWhichLED		.req v3
	rCurrentBankroll	.req v4
	rCurrentWager		.req v5
	rMaximumWager		.req v6

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

	mTerminalCommand #terminalCommand_clearScreen

	ldr	a1, =.L0_msgGreeting
	bl	printf

	ldr	rCurrentBankroll, [fp, #currentBankroll]

.L0_continuePlaying:
	mov	rMaximumWager, #maximumWager
	cmp	rCurrentBankroll, #maximumWager
	movlo	rMaximumWager, rCurrentBankroll

.L0_getWager:
	ldr	a1, =.L0_msgEnterYourWager
	mov	a2, #1
	mov	a3, rMaximumWager
	bl	getWager

	mov	rCurrentWager, r0
	ldr	a1, =.L0_msgYouHaveBet
	mov	a2, rCurrentWager
	bl	printf

	mov	a1, rFileDescriptor
	bl	spinWheels

	mov	r0, #0
	bl	exit

	.unreq rFileDescriptor
	.unreq rLEDLevel
	.unreq rWhichLED
	.unreq rCurrentBankroll
	.unreq rCurrentWager
	.unreq rMaximumWager
