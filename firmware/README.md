# AVR firmware

The ATtiny4313 was used for the project because of its size of the contained EEPROM (256B) in which the bootstrap code is stored. If this functionality is not used, it can use the more readily available ATtiny2313, which will be used to distribute the clock and pre-set the “Bus Timing and Initialisation Register”.

NOTE: The project is not complete, although fully functional. The Z280 bootstrap firmware upgrade routines are missing, both from the microcontroller and application side. Currently, the upgrade requires removing the AVR from the PCB and programming it in an external programmer.

Requirements:

- AVR programmer ([AVRDude](https://github.com/avrdudes/avrdude), Arduino or any commercial one supporting ATTiny4313);
- AVR assembler ([AVRASM2](https://github.com/GreatCowBASIC/AVRASM2)).
  
  

Example of microcontroller programming process including bit fuse setting using AVRDude and the USBASP programmer. Section flash:w:main.hex contains the AVR firmware code and section eeprom:w:bootstap.hex contains the Z280 bootstrap code.

`avrdude -c usbasp -p t4313 -u -U flash:w:main.hex -U eeprom:w:bootstrap.hex -U lfuse:w:0xbe:m -U hfuse:w:0xdb:m -U efuse:w:0xff:m`