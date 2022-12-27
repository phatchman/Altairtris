# Altairtris
Tetris for Altair 8800.

This is a text-only version of tetris for the Altair, which will run on a vt-100 compatible terminal connected via Serial.
Serial port speed should be at least 9600bps. On the Altairduino, speeds above 38400bps tend to lose characters, so pick a Serial Port speed within that range.

You might like to try the new DAZZLER version. It's only been tested under an emulator, so please let me know if it works for you. The source code for this is in the dazzler branch. I do plan to merge this into the main code at some point.

## Executable Files

1. TETRIS.COM - CPM Version
2. TETRIS.HEX - Version to be loaded directly to the Altair. Does not rely on CPM
3. TETRISB.COM - CPM Version, but uses the # character for every shape
4. TETRISB.HEX - Non-CPM version that uses # character for evey shape
5. TETRISDZ.COM - CPM Version for the Cromemco DAZZLER graphics card. 

## Build Options
1. SET CPM = 1 to build for CPM
2. SET ALTSHAPECHARS = 1 to build a version when shapes are all # chars, rather than shape-specific characters.

Was developed using the ASL macro assembler http://john.ccac.rwth-aachen.de:8000/as/
But it can also be built using the CPM ASM assembler (tested using CPM v 2.2)

This is my first attempt at writing something in 8080 assembler for the Altair, so I welcome any feedback on how good or bad my code is.
