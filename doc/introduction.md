# VM16 Instruction Set (VM16 Assembler)

The VM16 is a 16-bit virtual machine implemented in C. It enables simulation of vintage computers in minetest and is capable of executing real binary code at a remarkable speed.

This document contains information on how to program the VM16 virtual machine in assembly language. 

All VM16 registers are 16-bits wide. The VM16 supports only 16-bit memory addressing, the memory is also organized in 16-bit words.
Valid memory configuration are 4, 8, 12, up to 64 KByte.

There are four data registers: A, B, C, D. These are intended to hold numbers that will have various mathematical and logical operations performed on them.

There are two address registers: X and Y. These are typically used as pointers (indirect addressing)

The last two registers are the Stack Pointer (SP) and the Program Counter (PC). 

The **Program Counter (PC)** points to the current instruction and is set after power on / reset to address zero. 

The **Stack Pointer (SP)** is set to zero, too. After a call or push instruction, the SP will first be decremented and then the value will be stored.

Lets say in register A is the value 0x55AA and the SP point to address 0x0000. 
After a `push A` operation, the SP points to address 0x0FFF (due to the 4K memory) and the value 0x55AA in stored in address 0x0FFF.


## Addressing Modes

VM16 instruction can have up to 2 operands. `add A, B` means `register A = register A + register B`.
There are also instructions with only one operand, like `inc A`  (increment the content of register A).
And there are also instruction without any operand, like `ret` (return from subroutine).

Almost all instructions support different types of addressing modes. Addressing modes are:

- **REG** (register addressing) All registers can be used: A, B, C, D, X, Y, SP ,PC. Ex: `inc A`
- **IMM** (immediate) In immediate addressing, the operand is located immediately after the opcode in the second word of the instruction. But not both operands can be of type IMM (no 3-words instructions). Ex: `sys #100`
- **DIR** (direct addressing) In direct addressing, the address of the operand is contained in the second word of the instruction. Direct addressing allows the user to directly address the memory. Ex: `inc 100`
- **IND** (indirect addressing) In indirect addressing, an index register (X or Y) is used to address memory. Ex: `dec [X]`
- **PINC** (indirect addressing with post-increment) Same as indirect addressing, but the index register will be incremented after the instruction is executed. Ex: `move [X]+, [Y]+` used for memory copying routines.
- **ABS** (absolute addressing). Used for all branch/jump instructions as absolute jump address. These are 2-word instructions. Ex: `jump 1000`
- **REL** (relative addressing). Used for all branch/jump instructions to be able to jump relative to the current address (relocatable code). These are 2-word instructions. Ex: `jump -8` or  `jump +4`
- **CNST** (constant addressing). VM16 has two pseudo register #0 and #1, which can be used as source operand. Ex: `move A, #0`


In addition to the Addressing Modes the table below uses the following two addressing groups:

- **DST**  (destination address capable) includes the following addressing modes: REG + DIR + IND + PINC 
- **SRC**  (source address/value capable) includes the following addressing modes: REG + DIR + IND + PINC  + IMM + CNST



## Special Signs

- the `$` sign is used for hexadecimal values, `$400` is equal to `1024`
- the `+`/`-` signs are used to signal relative jump addresses, like `jump +10`
- the `#` sign ist used to signal  immediate addressing, like `move A, #4`

`#` and `$` signs also can be combined: `jump #$1000`




## Instructions

For a table with all instructions, the addrressing modes and opcodes, see "opcodes.md"

### nop

No operation, the CPU does nothing, only consuming time (one VM16 time slot, typically 100 ms) and than jumping to the next instruction. One or several `nop` operations can therefore be used as delay.

### brk

Breaks/stops the program execution. Used to terminate the program for debugging purposes.

### sys

System call into the Lua environment. It allows to use some higher level of functionality,
implemented in Lua, without the need to write everything is assembler (cheating).
Valid numbers are 0 - 1023. Additional system call parameters a passed with registers A and B. 
The result is return in register A.
Ex: `sys #0`

### jump

Jump to the given address by setting the PC to the new value. The stack keeps untouched.
The instruction supports absolute and relative addressing
Ex: `jump $1234` or `jump +4` 

### call

Call a subroutine. The address for the next instruction is stored on the stack 
and the stack pointer is decremented.
The instruction supports absolute and relative addressing
Ex: `call $1234` or `call +4`

### ret

Return from subroutine. The used address is taken from the stack, the stack pointer is incremented.

### halt

Halts/stops the program execution to terminate the program.

### move

Move a constant or value from memory/register to memory/register. 
The VM16 assembler follows the Intel syntax: The destination operand is preceded by the source operand.
`move A, B` means move the content from B to A. The move instruction has a variable number of words, from
`move A, [X]` (one word) or `move X,#$1234` (to words). 3 words instructions are not allowed.

### xchg

Exchange the values between one memory location/register and another memory location/register.
Ex: `xchg A, [X]`

### inc

Increment the content of a register or memory address (val = val + 1).
Ex: `inc A`

### dec

Decrement the content of a register or memory address (val = val - 1).
Ex: `dec $3F`

### add

Add a constant or value of one memory/register to another memory/register.
Ex: `add A, B`  (the result is stored in A).

### addc

Add a constant or value of one memory/register to another memory/register with carry.
The carry bit is stored in register B.
Ex: `addc A, C`  (the result is stored in A, the carry in B).

### sub

Subtract a constant or value of one memory/register from another memory/register.
Ex: `sub A, B`  (the result is stored in A).

### mul

Multiply contents/value of one memory/register with another memory/register
Ex: `mul A, B`  (the result is stored in A).

### mulc

Multiply contents/value of one memory/register with another memory/register with carry.
The carry value is stored in register B.
Ex: `mulc A, #5`  (the result is stored in A, the carry in B).

### div

Divide contents/value of one memory/register by another memory/register
Ex: `div A, B`  (the result is stored in A).

### mod

Modulo operation with contents/value from one memory/register with another memory/register.
Ex: `mod A, B`  (the result is stored in A).

### and

AND operation with contents/value from one memory/register with another memory/register.
Ex: `and A, $78E`  (the result is stored in A).

### or

OR operation with contents/value from one memory/register with another memory/register.
Ex: `or A, $00FF`  (the result is stored in A).

### xor

XOR operation with contents/value from one memory/register with another memory/register.
Ex: `xor A, $00FF`  (the result is stored in A).

### not

NOT operation with contents/value from one memory/register.
Ex: `not A`

### bnze

Branch to the operand2 address if operand1 is not zero.
operand2 can be any memory location/register, operand2 an absolute and relative address.
Ex: `bnze [X], +2` (`+2` means: skip the next 2 word instruction)

The following examples are valid for all five branch instructions:

```
bnze	A, -4   ; jump to the prior address
bnze	A, -2   ; jump to the same address (endless loop)
bnze	A, +0   ; jump to the next address (nop)
```

### bze

Branch to the operand2 address if operand1 is zero.
operand2 can be any memory location/register, operand2 an absolute and relative address.
Ex: `bze [X], -8` 

### bpos

Branch to the operand2 address if operand1 is positive (value < $8000).
operand2 can be any memory location/register, operand2 an absolute and relative address.
Ex: `bpos [X], -8` 

### bneg

Branch to the operand2 address if operand1 is negative (value >= $8000).
operand2 can be any memory location/register, operand2 an absolute and relative address.
Ex: `bneg [X], -8` 

### dbnz

Decrement operand1 and branch to the address operand2 when operand1 becomes zero.
operand1 can be any memory location/register, operand2 an absolute and relative address.
Ex: `dbnz C, -8` 

### in

(I/O) operation to read an input value from an external device.
operand1 can be any memory location/register, operand2 is the port number (immediate).
Valid numbers for operand2 are application dependent.
Ex: `in A, #1` 

### out

(I/O) operation to write an output value to an external device.
operand1 is the port number (immediate), operand2 can be any memory location/register.
Valid numbers for operand1 are application dependent.
Ex: `out #2, A` 

Some `out` commands need a second parameter. In this case register `B` is used:

```
move   B, #5   ; load B
out    #2, A   ; perform out command
```


### push

Push a value onto the stack with a pre-decrement of the SP.
Ex: `push #123` 

### pop

op a value from the stack with a post-increment of the SP.
Ex: `pop D`

### swap

Exchange high- and low-byte of the memory location/register.
Ex: `swap A`

### shl

Shift the bits of operand1 to the left, by the number of bits specified in operand2.
Ex: `shl A, #8` 


### shr

Shift the bits of operand1 to the right, by the number of bits specified in operand2.
Ex: `shr [X], A` 

### skne
Compare operand1 with operand2. If not equal, skip the next 2-word instructions (PC + 2).
Operand1 and operand2 can be any memory location/register or constant (immediate).
Ex: `skne [X], A` 

### skeq

Compare operand1 with operand2. If equal, skip the next 2-word instructions (PC + 2).
Operand1 and operand2 can be any memory location/register or constant (immediate).
Ex: `skeq #10, A` 

### sklt

Compare operand1 with operand2. If operand1 is less than operand2, skip the next 2-word instructions (PC + 2).
Operand1 and operand2 can be any memory location/register or constant (immediate).
Ex: `sklt B, A` 

### skgt

Compare operand1 with operand2. If operand1 is greater than operand2, skip the next 2-word instructions (PC + 2).
Operand1 and operand2 can be any memory location/register or constant (immediate).
Ex: `skgt $800, A` 

