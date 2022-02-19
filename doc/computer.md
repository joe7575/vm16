# VM16 Computer

The vm16 mod comes with a computer, a lamp, and a switch block for training purposes. It can be used to get familiar with the assembler syntax and the CPU instructions. The VM16 CPU is a 16-bit CPU with 512 words memory. This should be sufficient to learn the programming basics. To work with this CPU, the following knowledge is useful:

- Calculating with HEX numbers (16 bit system)
- Basic knowledge of the structure of a CPU (register, memory addressing) and assembler programming




## Manual

- Craft the 3 blocks "VM16 Computer", "VM16 On/Off Switch" and "VM16 Color Lamp".
- Place all 3 blocks next to each other. The computer searches for I/O blocks in an area with a radius of 3 blocks.
- The switch is used as input block for the computer, the lamp as output block.
- Give lamp and switch an I/O address. For the following assembler examples, address '1' is used for both blocks.
- You can add further I/O blocks for you own programs with other addresses.




## VM16 Computer

The computer block is the core of the system. The block has a menu that shows the assembler code and the CPU internal registers and memory.

- Enter the edit mode with the "Edit" button. You can add you own code on the left side.
- Your code can be stored in the computer block with the "Save" button. If you remove the block, the program is lost.
- "Assemble" translates the code on the left into machine code and copies it into CPU memory on the right.
- Execute the code with "step" (single instruction), "Step 10", or "Run". The next instruction to be executed is highlighted on the left.
- A running CPU can be  stopped with the "Stop" button. 
- The program counter is set to zero using the "Reset" button (CPU must be stopped for this).
- With the '+' and '-' button the text size can be changed, which can be useful for smaller displays.

A newly placed computer comes with the following default program:

```asm
; ASCII output example

move A, #$41   ; load A with 'A'

loop:
  out #00, A   ; output char
  add  A, #01  ; increment char
  jump loop
```

This program outputs characters ("ABCDE...") as a text message in the computer menu. Execute this program step by step to see the output results and the changing register values.  The output address '0' is used internally for text output within the computer menu and cannot be used for external I/O blocks. 

### Performance

The CPU is able to execute up to 100,000 commands per second (0.1 MIPS). This applies as long as only internal CPU commands are executed. There are the following exceptions:

- The `sys`, the `in` and the `out` command interrupts the execution for 100 ms.
- The `nop` command, which can be used for pauses, also interrupts execution for 100 ms.

Otherwise the CPU runs "full speed", but only as long as the area of the world is loaded.



## VM16 On/Off Switch

The switch sends a '1' to the computer when it is turned on and a '0' when it is turned off. 

```assembly
loop:
  nop          ; 100 ms delay
  in   B, #1   ; read switch value
  bze  B, loop
  ...
```



## VM16 Color Lamp

This lamp block can light up in different colors. To do this, values from 1-64 must be sent to the block using the `out` instruction. The value 0 switches the lamp off.

```assembly
  move A, #00  ; color value in A
loop:
  nop          ; 100 ms delay
  and  A, #$3F ; values from 1 to 64
  add  A, #01
  out  #01, A  ; output color value
  jump loop
```