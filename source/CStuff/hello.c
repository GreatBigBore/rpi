#include "stdio.h"

void main() {
	char inputData[20];

	printf("Hello, world!\nEnter a number: ");
	fgets(inputData, 20, stdin);
	printf("You entered %s\n", inputData);
}
