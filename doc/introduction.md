# VM16 Instruction Set (VM16 Assembler)

This document contains information on how to program the VM16 Computer/CPU in assembly language. 

All VM16 registers are 16-bits wide. 16 bit means, each register can store values between 0 and 65535. The VM16 supports only 16-bit memory addressing, the memory is also organized in 16-bit words.
Valid memory configuration are 0 for 64 words, 1 for 128 words, up to 10 for 64 Kwords.

There are four data registers: A, B, C, D. These are intended to hold numbers that will have various mathematical and logical operations performed on them.

There are two address registers: X and Y. These are typically used as pointers (indirect addressing).

The last two registers are the Stack Pointer (SP) and the Program Counter (PC). 

The **Program Counter (PC)** points to the current instruction and is set after power on / reset to address zero. 

The **Stack Pointer (SP)** is set to zero, too. After a call or push instruction, the SP will first be decremented and then the value will be stored.

Lets say in register A is the value 0x55AA and the SP point to address 0x0000. 
After a `push A` operation, the SP points to address 0xFFFF (or e.g. 0x0FFF in the case of 4K memory) and the value 0x55AA in stored in address 0xFFFF.




## Addressing Modes

VM16 instruction can have up to 2 operands. `add A, B` means `register A = register A + register B`.
There are also instructions with only one operand, like `inc A`  (increment the content of register A).
And there are also instruction without any operand, like `ret` (return from subroutine).

Almost all instructions support different types of operands. Operand types are:

```assembly
; Registers (REG): A, B, C, D, X, Y, SP, PC
move A, B

; Constants (CONST):  #0, #1, #1000, #$3AF
move A, #10     ; load A with decimal value
move A, #$3AF   ; load A with hexdecimal value

; Memory (MEM): memory addresses (0 to 65535)
move A, $100    ; load A with value from memory address 100h

; Indirect (IND): use X/Y register as address to the memory
move A, [X]     ; the value in X is used as address

; Post-increment (INC): use X/Y register as address to the memory
move A, [X]+    ; the value in X is incremented after the move instruction

; Stack-pointer-relative (SPREL): use SP register plus offset as address to the memory
; (valid offset range = +0..+65535)
move A, [SP+2]  ; variable value
move [SP+3], B  ; variable value
move A, SP+2    ; variable address

; X/Y register-relative (XREL/YREL): use X/Y register plus offset as address to the memory
; (valid offset range = +0..+65535)
move A, [X+2]
move [Y+3], B

; Absolute (ABS): Used for all branch/jump instructions as absolute jump address
jump 0

; Relative (REL): Used for all branch/jump instructions to be able to 
; jump relative to the current position (valid range = -32768..+32767)
jump -8 
jump +4
```

### Further Hints

- VM16 has two pseudo register #0 and #1, which can also be used as source operand. Ex: `move A, #0`.
- The constant operand can only be used as source operand (not as destination).


## Instructions

For a table with all instructions, the addressing modes and opcodes, see "opcodes.md"

### nop - No operation

No operation, the CPU does nothing, only consuming time (one VM16 time slot, typically 100 ms) and than jumping to the next instruction. One or several `nop` operations can therefore be used as delay.

```
nop
```

### brk - Break

Breaks/stops the program execution after this instruction. Used to terminate the program for debugging purposes.
Valid breakpoint numbers are 0 - 1023.

````
brk #0
brk #1
````

### sys - System call

System call. It allows to use some higher level of functionality autside the CPU. System calls are mod/computer dependent.
Valid numbers are 0 - 1023. Additional system call parameters can be passed via registers if necessary. 
The result is returned in register A.

```
sys #0
sys #10
```

### jump - Jump to address

Jump to the given address by setting the PC to the new value. The stack keeps untouched.
The instruction supports absolute and relative addressing.

```
jump $1234		; absolute
jump +4			; relative (skip next two-word instruction)
```

### call - Call a subroutin

Call a subroutine. The address for the next instruction is stored on the stack 
and the stack pointer is decremented. The instruction supports absolute and relative addressing.

```
call $1234		; absolute
call +4			; relative (skip next two-word instruction)
```

### ret - Return from subroutine

Return from subroutine. The used address is taken from the stack, the stack pointer is incremented.

```
ret
```

### halt - Halt the program execution

Halts/stops the program execution to terminate the program.

```
halt
```

### move - Move value

Move a constant or value from memory/register to memory/register. 
The VM16 assembler follows the Intel syntax: The destination operand is preceded by the source operand.
`move A, B` means move the content from B to A. The move instruction has a variable number of words, from
`move A, [X]` (one word) or `move X,#$1234` (to words).

```
move A, #1
move SP, B
move C, #100
move [X], [Y]
```

### xchg - Exchange values

Exchange the values between one memory location/register and another memory location/register.

```
xchg A, B
xchg A, [X]
xchg A, $100
```

### inc - Increment

Increment the content of a register or memory address (val = val + 1).

```
inc A
inc $100
inc [X]
```

### dec - Decrement

Decrement the content of a register or memory address (val = val - 1).

```
dec A
dec $100
dec [X]
```

### add - Add

Add a constant or value of one memory/register to another memory/register.

```
add A, #1     ; result is stored in A
add $100, #1  ; result is stored in memory address 100h
add B, [X]    ; result is stored in B
```

### addc - Add with carry

Add a constant or value of one memory/register to another memory/register with carry.
The carry bit is stored in register B.

```
addc A, C  	    ; the result is stored in A, the carry in B
addc A, #$1234  ; the result is stored in A, the carry in B
```

### sub - Subtract

Subtract a constant or value of one memory/register from another memory/register.

```
sub A, #1     ; result is stored in A
sub $100, #1  ; result is stored in memory address 100h
sub B, [X]    ; result is stored in B
```

### mul - Multiply

Multiply contents/value of one memory/register with another memory/register

```
mul A, #1     ; result is stored in A
mul $100, #1  ; result is stored in memory address 100h
mul B, [X]    ; result is stored in B
```

### mulc - Multiply with carry

Multiply contents/value of one memory/register with another memory/register with carry.
The carry value is stored in register B.

```
mulc A, C  	    ; the result is stored in A, the carry in B
mulc A, #$1234  ; the result is stored in A, the carry in B
```

### div - Divide

Divide contents/value of one memory/register by another memory/register

```
div A, #1     ; result is stored in A
div $100, #1  ; result is stored in memory address 100h
div B, [X]    ; result is stored in B
```

### mod - Modulo operation

Modulo operation with contents/value from one memory/register with another memory/register.

```
mod A, #1     ; result is stored in A
mod $100, #1  ; result is stored in memory address 100h
mod B, [X]    ; result is stored in B
```

### and - Bitwise AND operation

AND operation with contents/value from one memory/register with another memory/register.

```
and A, #1     ; result is stored in A
and $100, #1  ; result is stored in memory address 100h
and B, [X]    ; result is stored in B
```

### or - Bitwise OR operation

OR operation with contents/value from one memory/register with another memory/register.

```
or A, #1     ; result is stored in A
or $100, #1  ; result is stored in memory address 100h
or B, [X]    ; result is stored in B
```

### xor - Bitwise XOR operation

XOR operation with contents/value from one memory/register with another memory/register.

```
xor A, #1     ; result is stored in A
xor $100, #1  ; result is stored in memory address 100h
xor B, [X]    ; result is stored in B
```

### not - Bitwise NOT operation

NOT operation with contents/value from one memory/register.

```
not A      ; result is stored in A
not $1001  ; result is stored in memory address 100h
not B      ; result is stored in B
```

### bnze - Branch if not zero

Branch to the operand2 address if operand1 is not zero.
operand2 can be any memory location/register, operand2 an absolute and relative address.

```
bnze  A, #$100   ; jump to absolute address
bnze  A, -2      ; jump to the prior address
bnze  [X], +4    ; skip next two-word instruction
```

### bze - Branch if zero

Branch to the operand2 address if operand1 is zero.
operand2 can be any memory location/register, operand2 an absolute and relative address.

```
bze  A, #$100   ; jump to absolute address
bze  A, -2      ; jump to the prior address
bze  [X], +4    ; skip next two-word instruction
```

### bpos - Branch if positive

Branch to the operand2 address if operand1 is positive (value < $8000).
operand2 can be any memory location/register, operand2 an absolute and relative address.

```
bpos  A, #$100   ; jump to absolute address
bpos  A, -2      ; jump to the prior address
bpos  [X], +4    ; skip next two-word instruction
```

### bneg - Branch if negative

Branch to the operand2 address if operand1 is negative (value >= $8000).
operand2 can be any memory location/register, operand2 an absolute and relative address.

```
bneg  A, #$100   ; jump to absolute address
bneg  A, -2      ; jump to the prior address
bneg  [X], +4    ; skip next two-word instruction
```

### dbnz - Decrement and branch if not zero

Decrement operand1 and branch to the address operand2 until operand1 becomes zero.
operand1 can be any memory location/register, operand2 an absolute and relative address.

```
dbnz  A, #$100   ; jump to absolute address
dbnz  A, -2      ; jump to the prior address
dbnz  [X], +4    ; skip next two-word instruction
```

### in - IN operation

(I/O) operation to read an input value from an external device.
operand1 can be any register, operand2 is the port number (immediate/memory/register).
Valid port number values are application dependent (max: 0 - 65535).

```
in A, #1
in B, B
in C, $100
```

### out - OUT operation

(I/O) operation to write an output value to an external device.
operand1 is the port number (immediate/memory/register), operand2 can be any register.
Valid port number values are application dependent (max: 0 - 65535).

```
out #2, A
out B, B
out $100, C
```

Some `out` commands need a second parameter. In this case register `B` is used:

```
move   A, #1   ; load A
move   B, #5   ; load B
out    #2, A   ; perform out command
```

### push - Push onto the stack

Push a value onto the stack with a pre-decrement of the SP.

```
push #123
push A
push $100
push [X]
```

### pop - Pop from stack

op a value from the stack with a post-increment of the SP.

```
pop A
pop $100
pop [X]
```

### swap - Swap high/low-byte

Exchange high- and low-byte of the memory location/register.

```
swap A
swap $100
swap [X]
```

### shl - Shift left

Shift the bits of operand1 to the left, by the number of bits specified in operand2.

```
shl A, #1     ; result is stored in A
shl $100, #1  ; result is stored in memory address 100h
shl B, [X]    ; result is stored in B
```

### shr - Shift right

Shift the bits of operand1 to the right, by the number of bits specified in operand2.

```
shr A, #1     ; result is stored in A
shr $100, #1  ; result is stored in memory address 100h
shr B, [X]    ; result is stored in B
```

### skne - Compare and skip if not equal
Compare operand1 with operand2. If not equal, skip the next 2-word instructions (PC + 2).
Operand1 and operand2 can be any memory location/register or constant (immediate).

```
skne  A, #$100   	; skip the next 2 word instruction
skne  A, B      	; skip the next 2 word instruction
skne  [X], $100    	; skip the next 2 word instruction
```

### skeq - Compare and skip if equal

Compare operand1 with operand2. If equal, skip the next 2-word instructions (PC + 2).
Operand1 and operand2 can be any memory location/register or constant (immediate).

```
skeq  A, #$100   	; skip the next 2 word instruction
skeq  A, B      	; skip the next 2 word instruction
skeq  [X], $100    	; skip the next 2 word instruction
```

### sklt - Compare and skip if less than

Compare operand1 with operand2. If operand1 is less than operand2, skip the next 2-word instructions (PC + 2).
Operand1 and operand2 can be any memory location/register or constant (immediate).

```
sklt  A, #$100   	; skip the next 2 word instruction
sklt  A, B      	; skip the next 2 word instruction
sklt  [X], $100    	; skip the next 2 word instruction
```

### skgt - Compare and skip if greater than

Compare operand1 with operand2. If operand1 is greater than operand2, skip the next 2-word instructions (PC + 2).
Operand1 and operand2 can be any memory location/register or constant (immediate).

```
skgt  A, #$100   	; skip the next 2 word instruction
skgt  A, B      	; skip the next 2 word instruction
skgt  [X], $100    	; skip the next 2 word instruction
```
