# VM16 Assembler Manual



## Introduction

The VM16 Assembler is used to translate assembler instructions (text) into machine code (numbers), which can be directly executed on the VM16 CPU. Example "7segment.asm":

```assembly
; ASCII output example

move A, #$41   ; load A with 'A'

loop:
  out #00, A   ; output char
  add  A, #01  ; increment char
  jump loop
```



## Assembler Syntax

The assembler differentiates between upper and lower case, all instructions have to be in lower case, CPU register (A - Y) always in upper case. Each instruction has to be placed in a separate line. Leading blanks are accepted.

```assembly
  move  A B
  add   A, #10
  jump #$1000
```

The assembler allows blank and/or a comma separators between the first and the second operator.

The `#` sign in `move A, #10` signals an absolute value (constants). This value is loaded into the register. In contrast to `move A, 0`, where the value from memory address `0` is loaded into the register.

The `$` sign signals a hexadecimal value. `$400` is equal to `1024`.

`#` and `$` signs also can be combined, like in `jump #$1000`



## Comments

Comments are used for addition documentation, or to disable some lines of code. Every character behind the `;` sign is a comment and is ignored by the assembler:

```assembly
; this is a comment
    move    A, 0    ; this is also a comment
```

Due to Minetest limitations, only the ASCII character set shall be used



## Labels

Labels allow to implement a jump/call/branch to a dedicated position without knowing the correct memory address. 
In the example above the instruction `out  #8, A` will be executed after the instruction `jump loop`.  

For labels  the characters 'A' - 'Z', 'a' - 'z',  '_' and '0' - '9' are allowed ('0' - '9' not as first character) following by the ':' sign.

Labels can be used in two different ways:

- `jump  loop` is translated into an instruction with an absolute memory address
- `jump +loop` is translated into an instruction with a relative address (+/- some addresses), so that the code can be relocated to a different memory address

### Namespaces with local and global labels

The complete assembler program represents a namespace in which all labels are known. However, to divide the program into separate namespaces, the keyword `namespace` can be used. Labels now are `namespace` section local. To make a label globally available again, the keyword `global` is used.

The following example should explain the usage:

```asm
global func1
global func2

; Function 1 with a local `loop` label
func1:
  ...
loop:
  ....
  djnz A, loop
  ret
  
namespace ;--------------------------------------------------

; Function 2 with the same local `loop` label
func2:
  ...
loop:
  ....
  djnz A, loop
  ret
```



## Assembler Directives

Assembler directives are used to distinguish between code, data, and text sections, or to specify a memory address for following code section.

Here a (not useful) example:

```assembly
    .org $100
    .code
start: 
    move    A, #text1
    sys     #0
    halt
        
    .data
var1: 100
var2: $2123

    .org $200
    .text
text1: "Hello World\0"
```

- `.org` defines the memory start address for the locater. In the example above, the code will start at address 100 (hex).
- `.code` marks the start of a code section and is optional at the beginning of a program (code is default).
- `.data` marks the start of a data/variables section.  Variables have a name and a start value. Variables have always the size of one word.
- `.text` marks the start of a text section with "..." strings. `\0` is equal to the value zero and has always be used to terminate the string.
- `.ctext` marks the start of a compressed text section (two characters in one word). This is not used in the example above but allows a better packaging of constant strings. It depends on your output device, if  compressed strings are supported.



## Symbols

To make you program better readable, the assembler supports constant or symbol definitions.

```assembly
INP_BUFF = $40      ; 64 chars
OUT_BUFF = $80      ; 64 chars

START:  move    X, #INP_BUFF
        move    Y, #OUT_BUFF
```

For symbols  the characters 'A' - 'Z', 'a' - 'z',  '_' and '0' - '9' are allowed ('0' - '9' not as first character).

Of course, symbols must be defined before they can be used.

