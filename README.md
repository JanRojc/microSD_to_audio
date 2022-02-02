## Setup the project
These files are everything you need for the VHDL project to work (.vhd files go to design sources folder and .xdc file goes to design constraints folder). The only thing you need to do is set up the songs on the microSD card.

You can put the songs at the beginning of the microSD card (to sector 0, using HxD app) or put them anywhere else and find the sectors they are on, using HxD app. In any case you need HxD app (or some similar software), so you know where the songs are located. Once you've set up the songs and you know their addresses, you should read the code in SD_read.vhd (rows from 98 to 127, plus rows 33, 153) and change the addresses according to your songs. Currently the code works if 3 songs are written to the start of microSD one after the other (this can be changed if you modify mentioned rows).

Note: sector 0 is at address 0x2000, sector 1 is at 0x2001, sector 2 at 0x2002, etc. One sector has 512 Bytes.
