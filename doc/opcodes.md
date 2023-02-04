# VM16 V1.0

### Operand Types

- CONST = constant number in the range of 0..65535
- MEM = direct memory address in the range of 0..65535
- REL = relative memory address in the range of -32768..+32767 (jump/branch) or +0..+65535 (SP, X, Y)
- REG = A, B, C, D, X, Y, PC, SP, [X], [Y], [X]+, [Y]+

The Instruction Set table below uses mainly the following two addressing groups:

- **DST**  (destination address capable) includes the following operand types: MEM, REL, REG, [SP+n], [X+n], [Y+n]
- **SRC**  (source address/value capable) includes the following operand types: MEM, REL, REG, [SP+n], [X+n], [Y+n], #0, #1, CONST


### Instruction Set

| Instr. | Opnd 1 | Opnd 2 | Opcode                |
| ------ | ------ | ------ | --------------------- |
| nop    | --     | --     | 0000                  |
| brk    | const  | --     | 0400 + number (10bit) |
| sys    | const  | --     | 0800 + number (10bit) |
| --     | --     | --     | --                    |
| jump   | SRC    | --     | 1000 + Opnd1          |
| call   | SRC    | --     | 1400 + Opnd1          |
| ret    | --     | --     | 1800                  |
| halt   | --     | --     | 1C00                  |
| move   | DST    | SRC    | 2000 + Opnd1 + Opnd2  |
| xchg   | DST    | DST    | 2400 + Opnd1 + Opnd2  |
| inc    | DST    | --     | 2800 + Opnd1          |
| dec    | DST    | --     | 2C00 + Opnd1          |
| add    | DST    | SRC    | 3000 + Opnd1 + Opnd2  |
| sub    | DST    | SRC    | 3400 + Opnd1 + Opnd2  |
| mul    | DST    | SRC    | 3800 + Opnd1 + Opnd2  |
| div    | DST    | SRC    | 3C00 + Opnd1 + Opnd2  |
| and    | DST    | SRC    | 4000 + Opnd1 + Opnd2  |
| or     | DST    | SRC    | 4400 + Opnd1 + Opnd2  |
| xor    | DST    | SRC    | 4800 + Opnd1 + Opnd2  |
| not    | DST    | --     | 4C00 + Opnd1          |
| bnze   | SRC    | SRC    | 5000 + Opnd1 + Opnd2  |
| bze    | SRC    | SRC    | 5400 + Opnd1 + Opnd2  |
| bpos   | SRC    | SRC    | 5800 + Opnd1 + Opnd2  |
| bneg   | SRC    | SRC    | 5C00 + Opnd1 + Opnd2  |
| in     | DST    | SRC    | 6000 + Opnd1 + Opnd2  |
| out    | SRC    | SRC    | 6400 + Opnd1 + Opnd2  |
| push   | SRC    | --     | 6800 + Opnd1          |
| pop    | DST    | --     | 6C00 + Opnd1          |
| swap   | DST    | --     | 7000 + Opnd1          |
| dbnz   | DST    | SRC    | 7400 + Opnd1 + Opnd2  |
| mod    | DST    | SRC    | 7800 + Opnd1 + Opnd2  |
| shl    | DST    | SRC    | 7C00 + Opnd1 + Opnd2  |
| shr    | DST    | SRC    | 8000 + Opnd1 + Opnd2  |
| addc   | DST    | SRC    | 8400 + Opnd1 + Opnd2  |
| mulc   | DST    | SRC    | 8800 + Opnd1 + Opnd2  |
| skne   | SRC    | SRC    | 8C00 + Opnd1 + Opnd2  |
| skeq   | SRC    | SRC    | 9000 + Opnd1 + Opnd2  |
| sklt   | SRC    | SRC    | 9400 + Opnd1 + Opnd2  |
| skgt   | SRC    | SRC    | 9800 + Opnd1 + Opnd2  |
| msb    | DST    | SRC    | 9C00 + Opnd1 + Opnd2  |


### Opcodes

#### Instructions

| nop  | brk  | sys  | --   | jump | call | ret  | halt |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 0000 | 0400 | 0800 | 0C00 | 1000 | 1400 | 1800 | 1C00 |

| move | xchg | inc  | dec  | add  | sub  | mul  | div  |
|------|------|------|------|------|------|------|------|
| 2000 | 2400 | 2800 | 2C00 | 3000 | 3400 | 3800 | 3C00 |

| and  | or   | xor  | not  | bnze | bze  | bpos | bneg |
|------|------|------|------|------|------|------|------|
| 4000 | 4400 | 4800 | 4C00 | 5000 | 5400 | 5800 | 5C00 |

| in   | out  | push | pop  | swap | dbnz | mod  | shl  |
|------|------|------|------|------|------|------|------|
| 6000 | 6400 | 6800 | 6C00 | 7000 | 7400 | 7800 | 7C00 |

| shr  | addc | mulc | skne | skeq | sklt | skgt | msb  |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 8000 | 8400 | 8800 | 8C00 | 9000 | 9400 | 9800 | 9C00 |



#### Operand 1 (Opnd1)

| A    | B    | C    | D    | X    | Y    | PC   | SP   |
|------|------|------|------|------|------|------|------|
| 0000 | 0020 | 0040 | 0060 | 0080 | 00A0 | 00C0 | 00E0 |

| [X]  | [Y]  | [X]+ | [Y]+ | #0   | #1   | -    | -    |
|------|------|------|------|------|------|------|------|
| 0100 | 0120 | 0140 | 0160 | 0180 | 01A0 | 01C0 | 01E0 |

| CONST | MEM  | REL*) | [SP+n] | REL2 | [X+n] | [Y+n] | SP+n |
| ----- | ---- | ----- | ------ | ---- | ----- | ----- | ---- |
| 0200  | 0220 | 0240  | 0260   | 0280 | 02A0  | 02C0  | 02E0 |

#### Operand 2 (Opnd2)

| A    | B    | C    | D    | X    | Y    | PC   | SP   |
|------|------|------|------|------|------|------|------|
| 0000 | 0001 | 0002 | 0003 | 0004 | 0005 | 0006 | 0007 |

| [X]  | [Y]  | [X]+ | [Y]+ | #0   | #1   | -    | -    |
|------|------|------|------|------|------|------|------|
| 0008 | 0009 | 000A | 000B | 000C | 000D | 000E | 000F |

| CONST | MEM  | REL*) | [SP+n] | REL2 | [X+n] | [Y+n] | SP+n |
| ----- | ---- | ----- | ------ | ---- | ----- | ----- | ---- |
| 0010  | 0011 | 0012  | 0013   | 0014 | 0015  | 0016  | 0017 |

*) REL instructions are deprecated. Use REL2 instead!



### Important Subset for the first Steps

```
0000           nop
0802           sys  #2
1200, 0100     jump $100
1600, 0100     call $100
1800           ret
1C00           halt
2001           move A, B
2008           move A, [X]
2009           move A, [Y]
2010, 0123     move A, #$123
2011, 0123     move A, $123
2020           move B, A
2028           move B, [X]
2029           move B, [Y]
2030, 0123     move B, #$123
2031, 0123     move B, $123
2090, 0123     move X, #$123
2091, 0123     move X, $123
20B0, 0123     move Y, #$123
20B1, 0123     move Y, $123
2401           xchg A, B
2800           inc  A
2820           inc  B
2880           inc  X
28A0           inc  Y
2C00           dec  A
2C20           dec  B
2C80           dec  X
2CA0           dec  Y
3001           add  A, B
3010, 0002     add  A, #2
3011, 0100     add  A, $100
3020           add  B, A
3030, 0002     add  B, #2
3031, 0100     add  B, $100
3401           sub  A, B
3410, 0003     sub  A, #3
3411, 0100     sub  A, $100
3420           sub  B, A
3430, 0003     sub  B, #3
3431, 0100     sub  B, $100
3801           mul  A, B
3810, 0004     mul  A, #4
3C01           div  A, B
3C10, 0005     div  A, #5
4001           and  A, B
4010, 0006     and  A, #6
4011, 0100     and  A, $100
4401           or   A, B
4410, 0007     or   A, #7
4411, 0100     or   A, $100
4801           xor  A, B
4810, 0008     xor  A, #8
4811, 0100     xor  A, $100
4C00           not  A
5014, 0002     bnze A, +2
5010, 0100     bnze A, $100
5414, FFFE     bze  A, -2
5410, 0100     bze  A, $100
5814, FFFC     bpos A, -4
5810, 0100     bpos A, $100
5C14, FFFC     bneg A, -4
5C10, 0100     bneg A, $100
6010, 0002     in   A, #2
6600, 0003     out  #3, A
```