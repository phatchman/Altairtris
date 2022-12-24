# Altairtris
Tetris for Altair 8800.

This is a text-only version of tetris for the Altair, which will run on a vt-100 compatible terminal connected via Serial.
Serial port speed should be at least 9600bps. On the Altairduino, speeds above 38400bps tend to lose characters, so pick a Serial Port speed within that range.


## Executable Files

1. TETRIS.COM - CPM Version
2. TETRIS.HEX - Version to be loaded directly to the Altair. Does not rely on CPM

## Build Options
1. SET CPM = 1 to build for CPM
2. SET ALTSHAPECHARS = 1 to build a version when shapes are all # chars, rather than shape-specific characters.

Note there is currently some issue with the CPM version when you exit the game. Press Ctrl-C to soft-restart CPM after exiting, otherwise strange things could happen.

This is my first attempt at writing something in 8080 assembler for the Altair, so I welcome any feedback on how good or bad my code is.
