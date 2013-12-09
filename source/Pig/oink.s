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

	.align	2
	.global	writeI2CRegister
	.type	writeI2CRegister, %function
writeI2CRegister:
	@ args = 0, pretend = 0, frame = 16
	@ frame_needed = 1, uses_anonymous_args = 0
	stmfd	sp!, {fp, lr}
	add	fp, sp, #4
	sub	sp, sp, #16
	str	r0, [fp, #-8]
	str	r1, [fp, #-12]
	str	r2, [fp, #-16]
	ldr	r3, [fp, #-16]
	uxtb	r2, r3
	ldr	r3, .L36
	strb	r2, [r3, #0]
	ldr	r3, .L36+4
	mov	r2, #0
	strb	r2, [r3, #0]
	ldr	r3, [fp, #-12]
	uxtb	r2, r3
	ldr	r3, .L36+4
	strb	r2, [r3, #1]
	ldr	r3, .L36+4
	mov	r2, #2
	str	r2, [r3, #4]
	ldr	r3, .L36+4
	ldr	r2, .L36
	str	r2, [r3, #8]
	ldr	r0, [fp, #-8]
	mov	r1, #1824
	ldr	r2, .L36+4
	bl	ioctl
	mov	r3, r0
	mov	r0, r3
	sub	sp, fp, #4
	ldmfd	sp!, {fp, pc}
.L37:
	.align	2
.L36:
	.word	theData
	.word	args
	.size	writeI2CRegister, .-writeI2CRegister
	.align	2
	.type	lightPigLED, %function
lightPigLED:
	@ args = 0, pretend = 0, frame = 16
	@ frame_needed = 1, uses_anonymous_args = 0
	stmfd	sp!, {fp, lr}
	add	fp, sp, #4
	sub	sp, sp, #16
	str	r0, [fp, #-8]
	str	r1, [fp, #-12]
	str	r2, [fp, #-16]
	ldr	r3, [fp, #-12]
	add	r2, r3, #1
	ldr	r3, [fp, #-16]
	uxtb	r3, r3
	ldr	r0, [fp, #-8]
	mov	r1, r2
	mov	r2, r3
	bl	writeI2CRegister
	ldr	r0, [fp, #-8]
	mov	r1, #22
	mov	r2, #0
	bl	writeI2CRegister
	sub	sp, fp, #4
	ldmfd	sp!, {fp, pc}
	.size	lightPigLED, .-lightPigLED
	.comm	i,4,4
	.comm	j,4,4
	.align	2
	.global	pigSetup
	.type	pigSetup, %function
pigSetup:
	@ args = 0, pretend = 0, frame = 0
	@ frame_needed = 1, uses_anonymous_args = 0
	stmfd	sp!, {fp, lr}
	add	fp, sp, #4
	mov	r0, #84
	bl	I2CSetup
	mov	r2, r0
	ldr	r3, .L42
	str	r2, [r3, #0]
	ldr	r3, .L42
	ldr	r3, [r3, #0]
	cmp	r3, #0
	bge	.L40
	ldr	r3, .L42
	ldr	r3, [r3, #0]
	b	.L41
.L40:
	ldr	r3, .L42
	ldr	r3, [r3, #0]
	mov	r0, r3
	mov	r1, #0
	mov	r2, #1
	bl	writeI2CRegister
	ldr	r3, .L42
	ldr	r3, [r3, #0]
	mov	r0, r3
	mov	r1, #19
	mov	r2, #63
	bl	writeI2CRegister
	ldr	r3, .L42
	ldr	r3, [r3, #0]
	mov	r0, r3
	mov	r1, #20
	mov	r2, #63
	bl	writeI2CRegister
	ldr	r3, .L42
	ldr	r3, [r3, #0]
	mov	r0, r3
	mov	r1, #21
	mov	r2, #63
	bl	writeI2CRegister
	ldr	r3, .L42
	ldr	r3, [r3, #0]
	mov	r0, r3
	mov	r1, #22
	mov	r2, #0
	bl	writeI2CRegister
	ldr	r3, .L42
	ldr	r3, [r3, #0]
.L41:
	mov	r0, r3
	ldmfd	sp!, {fp, pc}
.L43:
	.align	2
.L42:
	.word	fd
	.size	pigSetup, .-pigSetup
	.align	2
	.global	main
	.type	main, %function
main:
	@ args = 0, pretend = 0, frame = 0
	@ frame_needed = 1, uses_anonymous_args = 0
	stmfd	sp!, {fp, lr}
	add	fp, sp, #4
	bl	pigSetup
	mov	r2, r0
	ldr	r3, .L53
	str	r2, [r3, #0]
	ldr	r3, .L53+4
	mov	r2, #0
	str	r2, [r3, #0]
	b	.L45
.L48:
	ldr	r3, .L53+8
	mov	r2, #0
	str	r2, [r3, #0]
	b	.L46
.L47:
	ldr	r3, .L53
	ldr	r1, [r3, #0]
	ldr	r3, .L53+8
	ldr	r2, [r3, #0]
	ldr	r3, .L53+4
	ldr	r3, [r3, #0]
	mov	r0, r1
	mov	r1, r2
	mov	r2, r3
	bl	lightPigLED
	ldr	r3, .L53+8
	ldr	r3, [r3, #0]
	add	r2, r3, #1
	ldr	r3, .L53+8
	str	r2, [r3, #0]
.L46:
	ldr	r3, .L53+8
	ldr	r3, [r3, #0]
	cmp	r3, #17
	ble	.L47
	ldr	r3, .L53+4
	ldr	r3, [r3, #0]
	add	r2, r3, #1
	ldr	r3, .L53+4
	str	r2, [r3, #0]
.L45:
	ldr	r3, .L53+4
	ldr	r3, [r3, #0]
	cmp	r3, #9
	ble	.L48
	ldr	r3, .L53+4
	mov	r2, #10
	str	r2, [r3, #0]
	b	.L49
.L52:
	ldr	r3, .L53+8
	mov	r2, #0
	str	r2, [r3, #0]
	b	.L50
.L51:
	ldr	r3, .L53
	ldr	r1, [r3, #0]
	ldr	r3, .L53+8
	ldr	r2, [r3, #0]
	ldr	r3, .L53+4
	ldr	r3, [r3, #0]
	mov	r0, r1
	mov	r1, r2
	mov	r2, r3
	bl	lightPigLED
	ldr	r3, .L53+8
	ldr	r3, [r3, #0]
	add	r2, r3, #1
	ldr	r3, .L53+8
	str	r2, [r3, #0]
.L50:
	ldr	r3, .L53+8
	ldr	r3, [r3, #0]
	cmp	r3, #17
	ble	.L51
	ldr	r3, .L53+4
	ldr	r3, [r3, #0]
	sub	r2, r3, #1
	ldr	r3, .L53+4
	str	r2, [r3, #0]
.L49:
	ldr	r3, .L53+4
	ldr	r3, [r3, #0]
	cmp	r3, #0
	bge	.L52
	mov	r3, #0
	mov	r0, r3
	ldmfd	sp!, {fp, pc}
.L54:
	.align	2
.L53:
	.word	fd
	.word	i
	.word	j
	.size	main, .-main
	.ident	"GCC: (Debian 4.6.3-14+rpi1) 4.6.3"
	.section	.note.GNU-stack,"",%progbits
