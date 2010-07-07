#undef int()
#include <stdio.h>
#include <avr/interrupt.h>
#include <LiquidCrystal.h>


#define NUM_CHANNELS 4
#define NUM_MODES 4

#define TEMP_INCREMENT 1

#define DISPLAY_MODE_SINGLE_CHANNEL 0
#define DISPLAY_MODE_MULTI_CHANNEL 1

//pin definitions
#define SELECT_CHANNEL 10
#define SET_MODE_SWITCH 11
#define SELECT_UP 12
#define SELECT_DOWN 13

#define CONTROL_1 2
#define CONTROL_2 3
#define CONTROL_3 4
#define CONTROL_4 5


//pin interrupt definitions
#define ANALOG_INT_1  PCINT8  //port C = PCMSK1
#define ANALOG_INT_2  PCINT9
#define ANALOG_INT_3  PCINT10
#define ANALOG_INT_4  PCINT11

#define INT_SELECT_CHANNEL  PCINT2  //pin10  -- port b = PCMSK0
#define INT_SET_MODE_SWITCH PCINT3
#define INT_SELECT_UP       PCINT4
#define INT_SELECT_DOWN     PCINT5

#define MODE_HEAT   0
#define MODE_MCOOL  1
#define MODE_COOL   2
#define MODE_MHEAT  3

#define STATUS_OFF  0
#define STATUS_ON   1



char *line1 = "1XXXXXXXXXXXXXXX";
char *line2 = "2XXXXXXXXXXXXXXX";
char tempUnits = 'F';

LiquidCrystal lcd(0,1,6,7,8,9);

volatile int currentChannelNumber = 0;

// Assignments are for testing
volatile unsigned int temp[] = {45, 37, 32, 70};
volatile unsigned int lastTemp[] = {0,0,0,0};
volatile unsigned int set[] = {50, 51, 27, 68};
volatile int channelStatus[4] = {1, 0, 1, 0};

//volatile boolean setMode = false;
volatile boolean setModeLastInt = false;
volatile int displayMode = DISPLAY_MODE_MULTI_CHANNEL;

unsigned char buttonPorts = 0;


//display information
char modeString[4][6] = {"HEAT ","MCOOL","COOL ","MHEAT"};
char statusString[2][4] = {"OFF","ON "};
unsigned int displayX[] = {0, 12, 0, 12};
unsigned int displayY[] = {1, 1, 0, 0};
unsigned int singleChannelTempX = 6;
unsigned int singleChannelTempY = 1;
unsigned int singleChannelModeX = 9;
unsigned int singleChannelModeY = 1;
unsigned int singleChannelStatusX = 9;
unsigned int singleChannelStatusY = 0;
unsigned int setTempX = 5;
unsigned int setTempY = 1;
unsigned int setModeX = 9;
unsigned int setModeY = 1;

void clearScreen()
{
  lcd.clear();
}

boolean setMode()
{
  return(digitalRead(SET_MODE_SWITCH));
}

void selectChannel()
{
    if (! setMode())
    {
        if (displayMode == DISPLAY_MODE_MULTI_CHANNEL)
        {
            displayMode = DISPLAY_MODE_SINGLE_CHANNEL;
        }
        else
        {
            currentChannelNumber =  ++currentChannelNumber % NUM_CHANNELS;
            if (currentChannelNumber == 0) displayMode = DISPLAY_MODE_MULTI_CHANNEL; // if we roll over go to multi channel
        }
    }
    else
    {
        currentChannelNumber = (++currentChannelNumber % NUM_CHANNELS);
    }
 }

void selectUp()
{
    if (setMode)
    {
        set[currentChannelNumber] += TEMP_INCREMENT;
    }
}

void selectDown()
{
    if (setMode())
    {
        set[currentChannelNumber] -= TEMP_INCREMENT;
    }
}


void initializeDisplay()
{
  if (setMode())
  {
    initializeSetMode(currentChannelNumber);
  }
  else
  {
      if (displayMode == DISPLAY_MODE_MULTI_CHANNEL)
      {
        initializeMultichannelRunMode();
      }
      else
      {
        initializeSingleChannelRunMode(currentChannelNumber);
      }
    }
}

void initializeMultichannelRunMode()
{
    lcd.clear();
    sprintf(line1, " 1: %2u%1c  2: %2u%1c ", temp[0], tempUnits, temp[1], tempUnits);
    sprintf(line2, " 3: %2u%1c  4: %2u%1c ", temp[2], tempUnits, temp[3], tempUnits);
    lcd.print(line1);
    lcd.setCursor(0,0)
    lcd.print(line2);

}

void updateMultichannelRunMode(int channelToUpdate, int newTemperature)
{
  char *strTemp = "00";
  int cursorX = displayX[channelToUpdate]; //4 for 1, 3 12 for 2, 4
  int cursorY = displayY[channelToUpdate]; // 1 for 1,2 0 for 3, 4
  lcd.setCursor(cursorX,cursorY);
  sprintf(strTemp,"%2u",newTemperature);
  lcd.print(strTemp);
}

void initializeSetMode(int channelToDisplay)
{
  lcd.clear();
  sprintf(line1, "CH%1u: %2u%1c %s ",channelToDisplay + 1, set[channelToDisplay],tempUnits, modeString[channelMode[channelToDisplay]]);
  lcd.println(line1);
}

void updateSetTempDisplay(int newTemp)
{
  char *buf = "00";
  lcd.setCursor(setTempX,setTempY);
  sprintf(buf,"u%2u",newTemp);
  lcd.print(buf);
}


void initializeSingleChannelRunMode(int channelToDisplay)
{
  sprintf(line1, "CH%1u: %2u%1c %s    ",channelToDisplay + 1, temp[channelToDisplay],tempUnits, statusString[channelStatus[channelToDisplay]]);
  sprintf(line2, "SET: %2u%1c %s  ", set[channelToDisplay],tempUnits, modeString[channelMode[channelToDisplay]]);
  lcd.clear();
  lcd.print(line1);
  lcd.setCursor(0,0);
  lcd.print(line2);
}

void updateSingleChannelRunTemp(int channelToUpdate)
{
    char *buf = "50";
    lcd.setCursor(singleChannelTempX,singleChannelTempY);
    sprintf(buf, %02u",temp[channelToUpdate]);
    Serial.print(buf);
}

void updateSingleChannelRunStatus(int channelToUpdate)
{
    char *buf = "OFF";
    lcd.setCursor(singleChannelStatusX,singleChannelStatusY);
    sprintf(buf, "%3s", statusString[channelStatus[channelToUpdate]]);
    lcd.print(buf);
}


int getTemp(int channelToRead)
{
  int reading = analogRead(channelToRead);
  int temp = reading / 100 ;   // Obviously there's going to be some different math here.
  return temp;
}

void setup()                    // run once, when the sketch starts
{

  pinMode(SELECT_CHANNEL, INPUT);
  pinMode(SET_MODE_SWITCH, INPUT);
  pinMode(SELECT_UP, INPUT);
  pinMode(SELECT_DOWN, INPUT);
  pinMode(SELECT_MODE, INPUT);


 lcd.begin(16,2);
 
 
 
  //Set up interrupts for analog pins (8=>0-13=>5)

  PCMSK1 |= 1 << ANALOG_INT_1;
  PCMSK1 |= 1 << ANALOG_INT_2;
  PCMSK1 |= 1 << ANALOG_INT_3;
  PCMSK1 |= 1 << ANALOG_INT_4;

//Set up interrupts for digital pins (0-7=>0-7 and 16-23)
  PCMSK0 |= 1 << INT_SELECT_CHANNEL;  //pin3  -- port D = PCMSK2
  PCMSK0 |= 1 << INT_SET_MODE_SWITCH;
  PCMSK0 |= 1 << INT_SELECT_UP;
  PCMSK2 |= 1 << INT_SELECT_DOWN;

//enable pin change interrupts

  PCICR |= (1 << PCIE1) | (1 << PCIE0);

}


ISR(PCINT1_vect) //analog (temp) change
{
  for (int i=0; i < 4; i++) // just check all four and update
  {
    temp[i] = getTemp(i);
    if (temp[i] != lastTemp[i])
    {
      lastTemp[i] = temp[i];
      think(i);
      processDisplay(i);
    }
  }
}

ISR(PCINT0_vect) //digital change (button poked)
{
  buttonPorts = PORTB;  //"latch" the button port in case we're not fast enough to read before the button gets let go.

  if (buttonPorts & 1 << INT_SELECT_CHANNEL)
  {
    // select channel switch
    selectChannel();
  }

  if (buttonPorts & 1 << INT_SET_MODE_SWITCH)
  {
    // set mode switch
  }

  if (buttonPorts & 1 << INT_SELECT_UP)
  {
    // up switch
    selectUp();
  }

  if (buttonPorts & 1 << INT_SELECT_DOWN)
  {
    // down switch
    selectDown();
  }


void processDisplay(int channel)
{
  //dispatch routine that holds all the logic for deciding what display update routine to call after pin change interrupt
}

void think(int channel)
{
  //routine that handles temperature changes.
  //switch (channelMode[i])

}

void loop()
{
}

//pin map from pins_arduino.c


// ATMEL ATMEGA8 & 168 / ARDUINO
//
//                  +-\/-+
//            PC6  1|    |28  PC5 (AI 5)
//      (D 0) PD0  2|    |27  PC4 (AI 4)
//      (D 1) PD1  3|    |26  PC3 (AI 3)
//      (D 2) PD2  4|    |25  PC2 (AI 2)
// PWM+ (D 3) PD3  5|    |24  PC1 (AI 1)
//      (D 4) PD4  6|    |23  PC0 (AI 0)
//            VCC  7|    |22  GND
//            GND  8|    |21  AREF
//            PB6  9|    |20  AVCC
//            PB7 10|    |19  PB5 (D 13)
// PWM+ (D 5) PD5 11|    |18  PB4 (D 12)
// PWM+ (D 6) PD6 12|    |17  PB3 (D 11) PWM
//      (D 7) PD7 13|    |16  PB2 (D 10) PWM
//      (D 8) PB0 14|    |15  PB1 (D 9) PWM
//                  +----+
//
// (PWM+ indicates the additional PWM pins on the ATmega168.)

