	.global _start
_start:
	@ read
	mov r7, #3
	mov r0, #0
	mov r2, #5
	ldr r1, =string
	svc 0
	
	@ write
	mov r7, #4
	mov r0, #1
	mov r2, #19
	ldr r1, =string
	svc 0
	
	@ exit
	mov r7, #1
	svc 0
	
.data
	string: .ascii "Hellow World String\n"
	