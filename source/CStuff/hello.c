#include "stdio.h"

void testFunction(i) {
	int j = 0x71;

barf:
	if(i == 12) {
		goto darf;
	}
carf:
	printf("this is a test function %d\n\r", i);
darf:
	printf("Another test\n\r");
}

void main() {
	printf("Hello, world!\n\r");
	testFunction(0x23);
}
