# VM16 Instruction Set (VM16 Assembler)

The VM16 is a 16-bit virtual machine implemented in C. It enables simulation of vintage computers in minetest and is capable of executing real binary code at a remarkable speed.

This document contains information on how to program the VM16 virtual machine in assembly language. 

All VM16 registers are 16-bits wide. The VM16 supports only 16-bit memory addressing, the memory is also organized in 16-bit words.
Valid memory configursation are 4, 8, 16, 32, and 64 KByte.

There are four data registers: A, B, C, D. These are intended to hold numbers that will have various mathematical and logical operations performed on them.

There are two address registers: X and Y. These are typically used as pointers (indirect addressing.

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
- **IMM** (immediate) In immediate addressing, the operand is located immediately after the opcode in the second word of the instruction. These are 2-word instructions, only one operand can be of type IMM. Ex: `move a, #100`
- **DIR** (direct addressing) In direct addressing, the address of the operand is contained in the second word of the instruction. Direct addressing allows the user to directly address the memory. These are 2-word instructions.  Ex: `move 800, A`
- **IND** (indirect addressing) In indirect addressing, an index register (X or Y) is used to address memory. EX: `dec [X]`
- **PINC** (indirect addressing with post-increment) Same as indirect addressing, but the index register will be incremented after the instruction is executed. Ex: `move [X]+, [Y]+` used for memory copying routines.
- **ABS** (absolute addressing). Used for all branch/jump instructions as absolute jump address. These are 2-word instructions. Ex: `jump 0`
- **REL** (relative addressing). Used for all branch/jump instructions to be able to jump relative to the current address (relocatable code). These are 2-word instructions. Ex: `jump -8`
- **CNST** (constant addressing). VM16 has two pseudo register #0 and #1, which can be used as source operand. Ex: `move A, #0`



The table below uses two groups of addressing modes:

- **DST**  (destination address capable) includes the following addressing modes: REG + DIR + IND + PINC 
- **SRC**  (source address/value capable) includes the following addressing modes: REG + DIR + IND + PINC  + IMM + CNST




## Instructions


Table of instructions with addressing modes:

| Instr. | Oprnd1 | Oprnd2  | Comment                                                      |
| ------ | ------ | ------- | ------------------------------------------------------------ |
| nop    | -      | -       | No operation, the CPU does nothing, only consuming time (one cycle) |
| halt   | -      | -       | Halts/stops the program execution                            |
| call   | -      | ABS,REL | Call a subroutine. The address for the next instruction is stored on the stack and the stack pointer is decremented |
| ret    | -      | -       | Return from subroutine. The used address is taken from the stack, the stack pointer is incremented |
| move   | DST    | SRC     | Move a value from memory or any register to memory or any register. `move A,B` means move the content from B to A |
| jump   | -      | ABS,REL | Jump to the given address by setting the PC to the new value. The stack is untouched |
| inc    | DST    | -       | Increment the content of a register or memory address (DST = DST + 1) |
| dec    | DST    | -       | Decrement the content of a register or memory address (DST = DST - 1) |
| add    | DST    | SRC     | Add contents/value of SRC to DST. The result is stored in DST |
| sub    | DST    | SRC     | Subtract contents/value of SRC from DST. The result is stored in DST |
| mul    | DST    | SRC     | Multiply contents/value of SRC with DST. The result is stored in DST |
| div    | DST    | SRC     | Divide contents/value of DST by SRC (`DST = DST / SRC`). The result is stored in DST |
| and    | DST    | SRC     | AND operation with SRC and DST. The result is stored in DST  |
| or     | DST    | SRC     | OR operation with SRC and DST. The result is stored in DST   |
| xor    | DST    | SRC     | XOR operation with SRC and DST. The result is stored in DST  |
| not    | DST    | -       | NOT operation with DST. The result is stored in DST          |
| bnze   | REG    | ABS,REL | Branch to the operand2 address  if REG is not zero.          |
| bze    | REG    | ABS,REL | Branch to the operand2 address  if REG is zero.              |
| bpos   | REG    | ABS,REL | Branch to the operand2 address  if REG is positive (bit 15 is 0). |
| bneg   | REG    | ABS,REL | Branch to the operand2 address  if REG is negative (bit 15 is 1). |
| in     | DST    | CNST    | (I/O) operation to read an input value from an external device |
| out    | CNST   | SRC     | (I/O) operation to write an output value to an external device |
| push   | SCR    | -       | Push a value onto the stack with a pre-decrement of the SP   |
| pop    | DST    | -       | Pop a value from the stack with a post-increment of the SP   |
| swap   | DST    | -       | Exchange high- and low-byte of DST                           |
| xchg   | DST    | DST     | Exchange contents/values one DST with the other DST          |
| dbnz   | REG    | ABS,REL | Decrement and branch to the operand2 address if REG has not become zero |
| mod    | DST    | SRC     | Modulo operation of DST with SRC (`DST = DST mod SRC`). The result is stored in DST |
| shl    | DST    | SRC     | Shift the bits of DST to the left, by the number of bits specified in SRC |
| shr    | DST    | SRC     | Shift the bits of DST to the right, by the number of bits specified in SRC |
| dly    | -      | -       | Perform a delay of one world cycle to slow down program execution |
| sys    | -      | CNST    | system call with number specified in CNST                    |




