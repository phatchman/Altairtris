# Altairtris
Tetris for Altair 8800.

This is a text-only version of tetris for the Altair, which will run on a vt-100 compatible terminal connected via Serial.
Serial port speed should be at least 9600bps. On the Altairduino, speeds above 38400bps tend to lose characters on output, 
so pick a serial port speed within that range.

You might like to try the new DAZZLER version. It's only been tested under an emulator, so please let me know if it works for you.
~~I guess I should really go and build the dazzler add-in card now that I've made some software for it.~~
I've created firmware for the Raspberry Pi Pico that can act as a low-cost Dazzler card for the Altair 8800 Simulator / Altair-Duino. 
See the [Pico Dazzler](https://github.com/phatchman/pico_dazzler) for more information.

## Executable Files

1. TETRIS.COM - CPM Version text version. Get this one if you are unsure and run it under CPM.
2. TETRIS.HEX - Non-CPM version to be loaded directly to the Altair.
3. TETRISB.COM - CPM Version, but uses the # character for every shape.
4. TETRISB.HEX - Non-CPM version that uses # character for every shape.
5. TETRISDZ.COM - CPM Version for the Cromemco DAZZLER graphics card. 
6. TETRISDZ.HEX - Non-CPM Dazzler version.

## Build Options
1. SET CPM = 1 to build for CPM
2. SET ALTSHAPECHARS = 1 to build a version when shapes are all # chars, rather than shape-specific characters.
3. SET DAZZLER = 1 to build the DAZZLER version.

Was developed using the ASL macro assembler http://john.ccac.rwth-aachen.de:8000/as/
But it can also be built using the CPM ASM assembler (tested using CPM v 2.2)

This is my first attempt at writing something in 8080 assembler for the Altair, so I welcome any feedback on how good or bad my code is.

## Screenshots

Serial/VT100                  | DAZZLER
:-------------------------:|:-------------------------:
![SIO-2/VT100](https://github.com/phatchman/Altairtris/blob/main/img/tetris_sio.png?raw=true)  |  ![DAZZLER](https://github.com/phatchman/Altairtris/blob/main/img/tetris_dazzler.png?raw=true)
