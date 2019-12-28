# VM16 [vm16]

VM16 is a 16-bit virtual machine to implement real working computers in Minetest.
It is not useful by itself, the mod pdp13 is an example how to use VM16.

The virtual machine is implemented in C and has a Lua API. In order to use the functionality
Minetest has to be recompiled.

 - The folder `c_code/` includes the C files and a readme how to use them
 - The folder `asm16/` includes an assembler written in Python 3
 - The folder `manual/` includes information to the VM16, the API, and the instruction set

### License
Copyright (C) 2019 Joe (iauit@gmx.de)  
Code: Licensed under the GNU GPL version 3 or later. See LICENSE.txt  


### Dependencies  
Required: none  


### History  
- 2019-12-03  v0.01  * First draft
- 2019-12-15  v0.02  * Code restructured
- 2019-12-28  v1.00  * First release

