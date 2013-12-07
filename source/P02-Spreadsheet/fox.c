/*
 * piglow.c:
 *	Very simple demonstration of the PiGlow board.
 *	This uses the piGlow devLib.
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

static int leg0 [6] = {  6,  7,  8,  5,  4,  9 } ;
static int leg1 [6] = { 17, 16, 15, 13, 11, 10 } ;
static int leg2 [6] = {  0,  1,  2,  3, 14, 12 } ;

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
static uint64_t epochMilli, epochMicro ;

/*
 * rinitialiseEpoch:
 *	Initialise our start-of-time variable to be the current unix
 *	time in milliseconds and microseconds.
 *********************************************************************************
 */

static void rinitialiseEpoch (void)
{
  struct timeval tv ;

  gettimeofday (&tv, NULL) ;
  epochMilli = (uint64_t)tv.tv_sec * (uint64_t)1000    + (uint64_t)(tv.tv_usec / 1000) ;
  epochMicro = (uint64_t)tv.tv_sec * (uint64_t)1000000 + (uint64_t)(tv.tv_usec) ;
}

/*
 * swiringPiSetupSys:
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

  boardRev = piBoardRev () ;

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

  rinitialiseEpoch () ;

  wiringPiMode = WPI_MODE_GPIO_SYS ;

  return 0 ;
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
  struct wiringPiNodeStruct *node = wiringPiNodes ;

  if ((node = wiringPiFindNode (pin)) == NULL)
    return ;

	printf("wtf1\n");
  node->analogWrite (node, pin, value) ;
	printf("wtf2\n");
}

/*
 * rpiGlowRing:
 *	Light up 3 LEDs in a ring. Ring 0 is the outermost, 5 the innermost
 *********************************************************************************
 */

void rpiGlowRing (const int ring, const int intensity)
{
  if ((ring < 0) || (ring > 5))
    return ;

  ranalogWrite (PIGLOW_BASE + leg0 [ring], intensity) ;
  ranalogWrite (PIGLOW_BASE + leg1 [ring], intensity) ;
  ranalogWrite (PIGLOW_BASE + leg2 [ring], intensity) ;
}

static void failUsage (void)
{
  fprintf (stderr, "Usage examples:\n") ;
  fprintf (stderr, "  piglow off         # All off\n") ;
  fprintf (stderr, "  piglow red 50      # Light the 3 red LEDs to 50%%\n") ;
  fprintf (stderr, "     colours are: red, yellow, orange, green, blue and white\n") ;
  fprintf (stderr, "  piglow all 75      # Light all to 75%%\n") ;
  fprintf (stderr, "  piglow leg 0 25    # Light leg 0 to 25%%\n") ;
  fprintf (stderr, "  piglow ring 3 100  # Light ring 3 to 100%%\n") ;
  fprintf (stderr, "  piglow led 2 5 100 # Light the single LED on Leg 2, ring 5 to 100%%\n") ;

  exit (EXIT_FAILURE) ;
}

static int getPercent (char *typed)
{
  int percent ;

  percent = atoi (typed) ;
  if ((percent < 0) || (percent > 100))
  {
    fprintf (stderr, "piglow: percent value out of range\n") ;
    exit (EXIT_FAILURE) ;
  }
  return (percent * 255) / 100 ;
}


/*
 * main:
 *	Our little demo prgoram
 *********************************************************************************
 */

int main (int argc, char *argv [])
{
  int percent ;
  int ring, leg ;

// Always initialise wiringPi:
//	Use the Sys method if you don't need to run as root

  rwiringPiSetupSys () ;

// Initialise the piGlow devLib

  piGlowSetup (FALSE) ;

  if (argc == 1)
    failUsage () ;

  if ((argc == 2) && (strcasecmp (argv [1], "off") == 0))
  {
    for (leg = 0 ; leg < 3 ; ++leg)
      piGlowLeg (leg, 0) ;
    return 0 ;
  }

  if (argc == 3)
  {
    percent = getPercent (argv [2]) ;

    /**/ if (strcasecmp (argv [1], "red") == 0)
      rpiGlowRing (PIGLOW_RED, percent) ;
    else if (strcasecmp (argv [1], "yellow") == 0)
      rpiGlowRing (PIGLOW_YELLOW, percent) ;
    else if (strcasecmp (argv [1], "orange") == 0)
      rpiGlowRing (PIGLOW_ORANGE, percent) ;
    else if (strcasecmp (argv [1], "green") == 0)
      rpiGlowRing (PIGLOW_GREEN, percent) ;
    else if (strcasecmp (argv [1], "blue") == 0)
      rpiGlowRing (PIGLOW_BLUE, percent) ;
    else if (strcasecmp (argv [1], "white") == 0)
      rpiGlowRing (PIGLOW_WHITE, percent) ;
    else if (strcasecmp (argv [1], "all") == 0)
      for (ring = 0 ; ring < 6 ; ++ring)
	rpiGlowRing (ring, percent) ;
    else
    {
      fprintf (stderr, "piglow: invalid colour\n") ;
      exit (EXIT_FAILURE) ;
    }
    return 0 ;
  }

  if (argc == 4)
  {
    /**/ if (strcasecmp (argv [1], "leg") == 0)
    {
      leg = atoi (argv [2]) ;
      if ((leg < 0) || (leg > 2))
      {
	fprintf (stderr, "piglow: leg value out of range\n") ;
	exit (EXIT_FAILURE) ;
      }
      percent = getPercent (argv [3]) ;
      piGlowLeg (leg, percent) ;
    }
    else if (strcasecmp (argv [1], "ring") == 0)
    {
      ring = atoi (argv [2]) ;
      if ((ring < 0) || (ring > 5))
      {
	fprintf (stderr, "piglow: ring value out of range\n") ;
	exit (EXIT_FAILURE) ;
      }
      percent = getPercent (argv [3]) ;
      rpiGlowRing (ring, percent) ;
    }
    return 0 ;
  }

  if (argc == 5)
  {
    if (strcasecmp (argv [1], "led") != 0)
      failUsage () ;

    leg = atoi (argv [2]) ;
    if ((leg < 0) || (leg > 2))
    {
      fprintf (stderr, "piglow: leg value out of range\n") ;
      exit (EXIT_FAILURE) ;
    }
    ring = atoi (argv [3]) ;
    if ((ring < 0) || (ring > 5))
    {
      fprintf (stderr, "piglow: ring value out of range\n") ;
      exit (EXIT_FAILURE) ;
    }
    percent = getPercent (argv [4]) ;
    piGlow1 (leg, ring, percent) ;
    return 0 ;
  }

  failUsage () ;
  return 0 ; 
}


