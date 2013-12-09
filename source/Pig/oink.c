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

struct i2c_smbus_ioctl_data
{
  char read_write ;
  uint8_t command ;
  int size ;
  char *data;
} ;

int rpiBoardRev (void);

/*
 * I2CSetup:
 *	Open the I2C device, and regsiter the target device
 *********************************************************************************
 */

  int fd ;
  int rev ;
  const char *device ;

int I2CSetup (const int devId)
{
  rev = rpiBoardRev () ;

  if (rev == 1)
    device = "/dev/i2c-0" ;
  else
    device = "/dev/i2c-1" ;

  if ((fd = open (device, O_RDWR)) < 0) {
    printf( "Unable to open I2C device: %s\n", strerror (errno)) ;
	exit(-1);
	}

  if (ioctl (fd, I2C_SLAVE, devId) < 0) {
    printf("Unable to select I2C device: %s\n", strerror (errno)) ;
	exit(-1);
	}

  return fd;
}

static void rpiBoardRevOops (const char *why)
{
  fprintf (stderr, "piBoardRev: Unable to determine board revision from /proc/cpuinfo\n") ;
  fprintf (stderr, " -> %s\n", why) ;
  fprintf (stderr, " ->  You may want to check:\n") ;
  fprintf (stderr, " ->  http://www.raspberrypi.org/phpBB3/viewtopic.php?p=184410#p184410\n") ;
  exit (EXIT_FAILURE) ;
}

  FILE *cpuFd ;
  char line [120] ;
  char *c, lastChar ;
  int  boardRev = -1 ;

int rpiBoardRev (void)
{
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
  
    printf ("piboardRev: Revision string: %s\n", line) ;

  for (c = line ; *c ; ++c)
    if (isdigit (*c))
      break ;

  if (!isdigit (*c))
    rpiBoardRevOops ("No numeric revision string") ;

// If you have overvolted the Pi, then it appears that the revision
//	has 100000 added to it!

    if (strlen (c) != 4)
      printf ("piboardRev: This Pi has/is overvolted!\n") ;

  lastChar = line [strlen (line) - 1] ;

    printf ("piboardRev: lastChar is: '%c' (%d, 0x%02X)\n", lastChar, lastChar, lastChar) ;

  /**/ if ((lastChar == '2') || (lastChar == '3'))
    boardRev = 1 ;
  else
    boardRev = 2 ;

    printf ("piBoardRev: Returning revision: %d\n", boardRev) ;

  return boardRev ;
}

/*
 * wiringPiI2CWriteReg8: wiringPiI2CWriteReg16:
 *	Write an 8 or 16-bit value to the given register
 *********************************************************************************
 */

  char theData;
  struct i2c_smbus_ioctl_data args ;

int writeI2CRegister (int fd, int reg, int value)
{
	theData = value;
  args.read_write = I2C_SMBUS_WRITE;
  args.command    = reg ;
  args.size       = I2C_SMBUS_BYTE_DATA ;
  args.data       = &theData ;

  return ioctl (fd, I2C_SMBUS, &args) ;
}

static void lightPigLED (int fd, int pin, int value)
{
  writeI2CRegister (fd, (pin + 1), value & 0xFF) ;	// Value
  writeI2CRegister (fd, 0x16, 0x00) ;		// Update
}

/*
 * sn3218Setup:
 *	Create a new wiringPi device node for an sn3218 on the Pi's
 *	SPI interface.
 *********************************************************************************
 */

int i, j;

int pigSetup ()
{
  if ((fd = I2CSetup (0x54)) < 0)
    return fd ;

// Setup the chip - initialise all 18 LEDs to off

//wiringPiI2CWriteReg8 (fd, 0x17, 0) ;		// Reset
  writeI2CRegister (fd, 0x00, 1) ;		// Not Shutdown
  writeI2CRegister (fd, 0x13, 0x3F) ;	// Enable LEDs  0- 5
  writeI2CRegister (fd, 0x14, 0x3F) ;	// Enable LEDs  6-11
  writeI2CRegister (fd, 0x15, 0x3F) ;	// Enable LEDs 12-17
  writeI2CRegister (fd, 0x16, 0x00) ;	// Update

  return fd ;
}

int main (void)
{
  fd = pigSetup () ;

    for (i = 0 ; i < 10 ; ++i)
      for (j = 0 ; j < 18 ; ++j)
	lightPigLED (fd, j, i) ;

    for (i = 10 ; i >= 0 ; --i)
      for (j = 0 ; j < 18 ; ++j)
	lightPigLED (fd, j, i) ;

	return 0;
}
