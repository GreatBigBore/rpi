/*
 * piglow.c:
 *	Very simple demonstration of the PiGlow board.
 *	This uses the SN3218 directly - soon there will be a new PiGlow
 *	devLib device which will handle the PiGlow board on a more easy
 *	to use manner...
 *
 * Copyright (c) 2013 Gordon Henderson.
 ***********************************************************************
 * This file is part of wiringPi:
 *	https://projects.drogon.net/raspberry-pi/wiringpi/
 *
 *    wiringPi is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU Lesser General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    wiringPi is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU Lesser General Public License for more details.
 *
 *    You should have received a copy of the GNU Lesser General Public License
 *    along with wiringPi.  If not, see <http://www.gnu.org/licenses/>.
 ***********************************************************************
 */
#include <stdio.h>
#include <wiringPi.h>
#include <wiringPiI2C.h>

#include "sn3218.h"

#include <wiringPi.h>
#include <sn3218.h>

#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <ctype.h>
#include <poll.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <fcntl.h>
#include <pthread.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/ioctl.h>

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifndef	TRUE
#  define TRUE  (1==1)
#  define FALSE (!TRUE)
#endif

#include <wiringPi.h>
#include <piGlow.h>

#define	LED_BASE	533
#define	PIGLOW_BASE	577

// I2C definitions

#define I2C_SLAVE	0x0703
#define I2C_SMBUS	0x0720	/* SMBus-level access */

#define I2C_SMBUS_READ	1
#define I2C_SMBUS_WRITE	0

// SMBus transaction types

#define I2C_SMBUS_QUICK		    0
#define I2C_SMBUS_BYTE		    1
#define I2C_SMBUS_BYTE_DATA	    2 
#define I2C_SMBUS_WORD_DATA	    3
#define I2C_SMBUS_PROC_CALL	    4
#define I2C_SMBUS_BLOCK_DATA	    5
#define I2C_SMBUS_I2C_BLOCK_BROKEN  6
#define I2C_SMBUS_BLOCK_PROC_CALL   7		/* SMBus 2.0 */
#define I2C_SMBUS_I2C_BLOCK_DATA    8

// SMBus messages

#define I2C_SMBUS_BLOCK_MAX	32	/* As specified in SMBus standard */	
#define I2C_SMBUS_I2C_BLOCK_MAX	32	/* Not specified but we use same structure */

// Structures used in the ioctl() calls

union i2c_smbus_data
{
  uint8_t  byte ;
  uint16_t word ;
  uint8_t  block [I2C_SMBUS_BLOCK_MAX + 2] ;	// block [0] is used for length + one more for PEC
} ;

struct i2c_smbus_ioctl_data
{
  char read_write ;
  uint8_t command ;
  int size ;
  union i2c_smbus_data *data ;
} ;

//static int leg0 [6] = {  6,  7,  8,  5,  4,  9 } ;
//static int leg1 [6] = { 17, 16, 15, 13, 11, 10 } ;
//static int leg2 [6] = {  0,  1,  2,  3, 14, 12 } ;

static int wiringPiDebug; 
static int wiringPiReturnCodes;
static int *pinToGpio ;

static int pinToGpioR1 [64] =
{
  17, 18, 21, 22, 23, 24, 25, 4,	// From the Original Wiki - GPIO 0 through 7:	wpi  0 -  7
   0,  1,				// I2C  - SDA0, SCL0				wpi  8 -  9
   8,  7,				// SPI  - CE1, CE0				wpi 10 - 11
  10,  9, 11, 				// SPI  - MOSI, MISO, SCLK			wpi 12 - 14
  14, 15,				// UART - Tx, Rx				wpi 15 - 16

// Padding:

      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 31
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 47
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 63
} ;

static int pinToGpioR2 [64] =
{
  17, 18, 27, 22, 23, 24, 25, 4,	// From the Original Wiki - GPIO 0 through 7:	wpi  0 -  7
   2,  3,				// I2C  - SDA0, SCL0				wpi  8 -  9
   8,  7,				// SPI  - CE1, CE0				wpi 10 - 11
  10,  9, 11, 				// SPI  - MOSI, MISO, SCLK			wpi 12 - 14
  14, 15,				// UART - Tx, Rx				wpi 15 - 16
  28, 29, 30, 31,			// New GPIOs 8 though 11			wpi 17 - 20

// Padding:

                      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 31
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 47
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 63
} ;


// physToGpio:
//	Take a physical pin (1 through 26) and re-map it to the BCM_GPIO pin
//	Cope for 2 different board revisions here.

static int *physToGpio ;

static int physToGpioR1 [64] =
{
  -1,		// 0
  -1, -1,	// 1, 2
   0, -1,
   1, -1,
   4, 14,
  -1, 15,
  17, 18,
  21, -1,
  22, 23,
  -1, 24,
  10, -1,
   9, 25,
  11,  8,
  -1,  7,	// 25, 26

// Padding:

                                              -1, -1, -1, -1, -1,	// ... 31
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 47
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 63
} ;

static int physToGpioR2 [64] =
{
  -1,		// 0
  -1, -1,	// 1, 2
   2, -1,
   3, -1,
   4, 14,
  -1, 15,
  17, 18,
  27, -1,
  22, 23,
  -1, 24,
  10, -1,
   9, 25,
  11,  8,
  -1,  7,	// 25, 26

// Padding:

                                              -1, -1, -1, -1, -1,	// ... 31
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 47
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,	// ... 63
} ;

static int sysFds [64] =
{
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
} ;
static int wiringPiMode;
//static uint64_t epochMilli, epochMicro ;
 
struct wiringPiNodeStruct theWiringPiNodeStruct;
struct wiringPiNodeStruct *robnode = &theWiringPiNodeStruct;

int rwiringPiI2CSetupInterface (const char *device, int devId)
{
  int fd ;

  if ((fd = open (device, O_RDWR)) < 0) {
    printf( "Unable to open I2C device: %s\n", strerror (errno)) ;
	exit(-1);
	}

  if (ioctl (fd, I2C_SLAVE, devId) < 0) {
    printf("Unable to select I2C device: %s\n", strerror (errno)) ;
	exit(-1);
	}

  return fd ;
}


/*
 * rwiringPiI2CSetup:
 *	Open the I2C device, and regsiter the target device
 *********************************************************************************
 */

int rwiringPiI2CSetup (const int devId)
{
  int rev ;
  const char *device ;

  rev = rpiBoardRev () ;

  if (rev == 1)
    device = "/dev/i2c-0" ;
  else
    device = "/dev/i2c-1" ;

  return rwiringPiI2CSetupInterface (device, devId) ;
}

/*
 * wiringPiNewNode:
 *	Create a new GPIO node into the wiringPi handling system
 *********************************************************************************
 */

static void pinModeDummy             (struct wiringPiNodeStruct *node, int pin, int mode)  { return ; }
static void pullUpDnControlDummy     (struct wiringPiNodeStruct *node, int pin, int pud)   { return ; }
static int  digitalReadDummy         (struct wiringPiNodeStruct *node, int pin)            { return LOW ; }
static void digitalWriteDummy        (struct wiringPiNodeStruct *node, int pin, int value) { return ; }
static void pwmWriteDummy            (struct wiringPiNodeStruct *node, int pin, int value) { return ; }
static int  analogReadDummy          (struct wiringPiNodeStruct *node, int pin)            { return 0 ; }
static void analogWriteDummy         (struct wiringPiNodeStruct *node, int pin, int value) { return ; }

static void rpiBoardRevOops (const char *why)
{
  fprintf (stderr, "piBoardRev: Unable to determine board revision from /proc/cpuinfo\n") ;
  fprintf (stderr, " -> %s\n", why) ;
  fprintf (stderr, " ->  You may want to check:\n") ;
  fprintf (stderr, " ->  http://www.raspberrypi.org/phpBB3/viewtopic.php?p=184410#p184410\n") ;
  exit (EXIT_FAILURE) ;
}

int rpiBoardRev (void)
{
  FILE *cpuFd ;
  char line [120] ;
  char *c, lastChar ;
  static int  boardRev = -1 ;

  if (boardRev != -1)	// No point checking twice
    return boardRev ;

  if ((cpuFd = fopen ("/proc/cpuinfo", "r")) == NULL)
    rpiBoardRevOops ("Unable to open /proc/cpuinfo") ;

  while (fgets (line, 120, cpuFd) != NULL)
    if (strncmp (line, "Revision", 8) == 0)
      break ;

  fclose (cpuFd) ;

  if (strncmp (line, "Revision", 8) != 0)
    rpiBoardRevOops ("No \"Revision\" line") ;

  for (c = &line [strlen (line) - 1] ; (*c == '\n') || (*c == '\r') ; --c)
    *c = 0 ;
  
  if (wiringPiDebug)
    printf ("piboardRev: Revision string: %s\n", line) ;

  for (c = line ; *c ; ++c)
    if (isdigit (*c))
      break ;

  if (!isdigit (*c))
    rpiBoardRevOops ("No numeric revision string") ;

// If you have overvolted the Pi, then it appears that the revision
//	has 100000 added to it!

  if (wiringPiDebug)
    if (strlen (c) != 4)
      printf ("piboardRev: This Pi has/is overvolted!\n") ;

  lastChar = line [strlen (line) - 1] ;

  if (wiringPiDebug)
    printf ("piboardRev: lastChar is: '%c' (%d, 0x%02X)\n", lastChar, lastChar, lastChar) ;

  /**/ if ((lastChar == '2') || (lastChar == '3'))
    boardRev = 1 ;
  else
    boardRev = 2 ;

  if (wiringPiDebug)
    printf ("piBoardRev: Returning revision: %d\n", boardRev) ;

  return boardRev ;
}

static inline int i2c_smbus_access (int fd, char rw, uint8_t command, int size, union i2c_smbus_data *data)
{
  struct i2c_smbus_ioctl_data args ;

	printf("B");
  args.read_write = rw ;
  args.command    = command ;
  args.size       = size ;
  args.data       = data ;
  return ioctl (fd, I2C_SMBUS, &args) ;
}

/*
 * ranalogWrite:
 *	Write the analog value to the given Pin. 
 *	There is no on-board Pi analog hardware,
 *	so this needs to go to a new node.
 *********************************************************************************
 */

void ranalogWrite (int pin, int value)
{
  struct wiringPiNodeStruct *node = robnode;

	printf("A");
  node->analogWrite (node, pin, value) ;
}

/*
 * rinitialiseEpoch:
 *	Initialise our start-of-time variable to be the current unix
 *	time in milliseconds and microseconds.
 *********************************************************************************
 */
/*
static void rinitialiseEpoch (void)
{
  struct timeval tv ;

  gettimeofday (&tv, NULL) ;
  epochMilli = (uint64_t)tv.tv_sec * (uint64_t)1000    + (uint64_t)(tv.tv_usec / 1000) ;
  epochMicro = (uint64_t)tv.tv_sec * (uint64_t)1000000 + (uint64_t)(tv.tv_usec) ;
}
*/
/*
 * rwiringPiSetupSys:
 *	Must be called once at the start of your program execution.
 *
 * Initialisation (again), however this time we are using the /sys/class/gpio
 *	interface to the GPIO systems - slightly slower, but always usable as
 *	a non-root user, assuming the devices are already exported and setup correctly.
 */

int rwiringPiSetupSys (void)
{
  int boardRev ;
  int pin ;
  char fName [128] ;

    wiringPiDebug = TRUE ;

    wiringPiReturnCodes = TRUE ;

    printf ("wiringPi: wiringPiSetupSys called\n") ;

  boardRev = rpiBoardRev () ;

  if (boardRev == 1)
  {
     pinToGpio =  pinToGpioR1 ;
    physToGpio = physToGpioR1 ;
  }
  else
  {
     pinToGpio =  pinToGpioR2 ;
    physToGpio = physToGpioR2 ;
  }

// Open and scan the directory, looking for exported GPIOs, and pre-open
//	the 'value' interface to speed things up for later
  
  for (pin = 0 ; pin < 64 ; ++pin)
  {
    sprintf (fName, "/sys/class/gpio/gpio%d/value", pin) ;
    sysFds [pin] = open (fName, O_RDWR) ;
  }

  wiringPiMode = WPI_MODE_GPIO_SYS ;

  return 0 ;
}

/*
 * wiringPiI2CWriteReg8: wiringPiI2CWriteReg16:
 *	Write an 8 or 16-bit value to the given register
 *********************************************************************************
 */

int rwiringPiI2CWriteReg8 (int fd, int reg, int value)
{
  union i2c_smbus_data data ;

  data.byte = value ;
	printf("D"); 
  return i2c_smbus_access (fd, I2C_SMBUS_WRITE, reg, I2C_SMBUS_BYTE_DATA, &data) ;
}

static void rmyAnalogWrite (struct wiringPiNodeStruct *node, int pin, int value)
{
  int fd   = node->fd ;
  int chan = 0x01 + (pin - node->pinBase) ;

	printf("E"); 
  rwiringPiI2CWriteReg8 (fd, chan, value & 0xFF) ;	// Value
  rwiringPiI2CWriteReg8 (fd, 0x16, 0x00) ;		// Update
}

/*
 * sn3218Setup:
 *	Create a new wiringPi device node for an sn3218 on the Pi's
 *	SPI interface.
 *********************************************************************************
 */

int rsn3218Setup (const int pinBase)
{
  int fd ;
  struct wiringPiNodeStruct *node ;

  if ((fd = rwiringPiI2CSetup (0x54)) < 0)
    return fd ;

	printf("F");
// Setup the chip - initialise all 18 LEDs to off

//wiringPiI2CWriteReg8 (fd, 0x17, 0) ;		// Reset
  rwiringPiI2CWriteReg8 (fd, 0x00, 1) ;		// Not Shutdown
  rwiringPiI2CWriteReg8 (fd, 0x13, 0x3F) ;	// Enable LEDs  0- 5
  rwiringPiI2CWriteReg8 (fd, 0x14, 0x3F) ;	// Enable LEDs  6-11
  rwiringPiI2CWriteReg8 (fd, 0x15, 0x3F) ;	// Enable LEDs 12-17
  rwiringPiI2CWriteReg8 (fd, 0x16, 0x00) ;	// Update
  
  robnode->pinBase         = pinBase ;
  robnode->pinMax          = pinBase + 18 - 1 ;
  robnode->fd          = fd ;
  robnode->analogWrite = rmyAnalogWrite ;

  return 0 ;
}

int main (void)
{
  int i, j ;

  rwiringPiSetupSys () ;

  rsn3218Setup (LED_BASE) ;

    for (i = 0 ; i < 10 ; ++i)
      for (j = 0 ; j < 18 ; ++j)
	ranalogWrite (LED_BASE + j, i) ;

    for (i = 10 ; i >= 0 ; --i)
      for (j = 0 ; j < 18 ; ++j)
	ranalogWrite (LED_BASE + j, i) ;

	return 0;
}
