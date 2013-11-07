	.global main
	.func main
	
main:
	push {lr}

	ldr r0, =inputBuffer
	mov r1, #20
	mov r2, #0
	bl fgets
	
	ldr r0, =msgResult
	ldr r1, =inputBuffer
	bl printf
	
	pop {pc}
	
_exit:
	mov pc, lr	@ I'm almost certain this instruction is never reached

.data
	msgResult: .asciz "You entered %s.\n"
	inputBuffer: .skip 21