# VM16 V1.0

### Instruction Set

| Instr. | Opnd 1 | Opnd 2 | Opcode               |
|--------|--------|--------|----------------------|
| nop    | --     | --     | 0000                 |
| halt   | --     | --     | 0400                 |
| call   | ADR    | --     | 0800 + Opnd1         |
| ret    | --     | --     | 0C00                 |
| move   | DST    | SRC    | 1000 + Opnd1 + Opnd2 |
| jump   | ADR    | --     | 1400 + Opnd1         |
| inc    | DST    | --     | 1800 + Opnd1         |
| dec    | DST    | --     | 1C00 + Opnd1         |
| add    | DST    | SRC    | 2000 + Opnd1 + Opnd2 |
| sub    | DST    | SRC    | 2400 + Opnd1 + Opnd2 |
| mul    | DST    | SRC    | 2800 + Opnd1 + Opnd2 |
| div    | DST    | SRC    | 2C00 + Opnd1 + Opnd2 |
| and    | DST    | SRC    | 3000 + Opnd1 + Opnd2 |
| or     | DST    | SRC    | 3400 + Opnd1 + Opnd2 |
| xor    | DST    | SRC    | 3800 + Opnd1 + Opnd2 |
| not    | DST    | --     | 3C00 + Opnd1         |
| bnze   | DST    | ADR    | 4000 + Opnd1 + Opnd2 |
| bze    | DST    | ADR    | 4400 + Opnd1 + Opnd2 |
| bpos   | DST    | ADR    | 4800 + Opnd1 + Opnd2 |
| bneg   | DST    | ADR    | 4C00 + Opnd1 + Opnd2 |
| in     | DST    | CNST   | 5000 + Opnd1 + Opnd2 |
| out    | CNST   | SRC    | 5400 + Opnd1 + Opnd2 |
| push   | SRC    | --     | 5800 + Opnd1         |
| pop    | DST    | --     | 5C00 + Opnd1         |
| swap   | DST    | --     | 6000 + Opnd1         |
| xchg   | DST    | DST    | 6400 + Opnd1 + Opnd2 |
| dbnz   | DST    | ADR    | 6800 + Opnd1 + Opnd2 |
| mod    | DST    | SRC    | 6C00 + Opnd1 + Opnd2 |
| shl    | DST    | SRC    | 7000 + Opnd1 + Opnd2 |
| shr    | DST    | SRC    | 7400 + Opnd1 + Opnd2 |
| dly    | --     | --     | 7800                 |
| sys    | CNST   | --     | 7C00 + Opnd1         |


### Addressing Modes

- REG = A, B, C, D, X, Y, PC, SP
- MEM = [X], [Y], [X]+, [Y]+, IND, [SP+n]
- ADR = IMM, REL
- CNST = #0, #1, IMM
- DST = A, B, C, D, X, Y, PC, SP, [X], [Y], [X]+, [Y]+, IND, [SP+n]
- SRC = A, B, C, D, X, Y, PC, SP, [X], [Y], [X]+, [Y]+, IND, [SP+n], #0, #1, IMM


### Opcodes

#### Instructions

| nop  | halt | call | ret  | move | jump | inc  | dec  |
|------|------|------|------|------|------|------|------|
| 0000 | 0400 | 0800 | 0C00 | 1000 | 1400 | 1800 | 1C00 |

| add  | sub  | mul  | div  | and  | or   | xor  | not  |
|------|------|------|------|------|------|------|------|
| 2000 | 2400 | 2800 | 2C00 | 3000 | 3400 | 3800 | 3C00 |

| bnze | bze  | bpos | bneg | in   | out  | push | pop  |
|------|------|------|------|------|------|------|------|
| 4000 | 4400 | 4800 | 4C00 | 5000 | 5400 | 5800 | 5C00 |

| swap | xchg | dbnz | mod  | shl  | shr  | dly  | sys  |
|------|------|------|------|------|------|------|------|
| 6000 | 6400 | 6800 | 6C00 | 7000 | 7400 | 7800 | 7C00 |

#### Operand 1 (Opnd1)

| A    | B    | C    | D    | X    | Y    | PC   | SP   |
|------|------|------|------|------|------|------|------|
| 0000 | 0020 | 0040 | 0060 | 0080 | 00A0 | 00C0 | 00E0 |

| [X]  | [Y]  | [X]+ | [Y]+ | #0   | #1   | -    | -    |
|------|------|------|------|------|------|------|------|
| 0100 | 0120 | 0140 | 0160 | 0180 | 01A0 | 01C0 | 01E0 |

| IMM  | IND  | REL  |[SP+n]|
|------|------|------|------|
| 0200 | 0220 | 0240 | 0260 |

#### Operand 2 (Opnd2)

| A    | B    | C    | D    | X    | Y    | PC   | SP   |
|------|------|------|------|------|------|------|------|
| 0000 | 0001 | 0002 | 0003 | 0004 | 0005 | 0006 | 0007 |

| [X]  | [Y]  | [X]+ | [Y]+ | #0   | #1   | -    | -    |
|------|------|------|------|------|------|------|------|
| 0008 | 0009 | 000A | 000B | 000C | 000D | 000E | 000F |

| IMM  | IND  | REL  |[SP+n]|
|------|------|------|------|
| 0010 | 0011 | 0012 | 0013 |


