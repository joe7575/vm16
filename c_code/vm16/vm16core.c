/*
VM16
Copyright (C) 2019 Joe <iauit@gmx.de>

This file is part of VM16.

VM16 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

VM16 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with VM16.  If not, see <https://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "vm16.h"

/*
**      MSB          LSB
** +-----------+------+------+
** |  op-code  | opd1 | opd2 |
** +-----------+------+------+
**
*/

/*
* Addressing modes
*/

// registers
#define  AREG  (0x00)
#define  BREG  (0x01)
#define  CREG  (0x02)
#define  DREG  (0x03)
#define  XREG  (0x04)
#define  YREG  (0x05)
#define  PCNT  (0x06)
#define  SPTR  (0x07)

// addressing
#define  XIND  (0x08)     // x-indirect: move a, [x]
#define  YIND  (0x09)     // y-indirect: move [y], b
#define  XINC  (0x0A)     // x-indirect, post-increment: move a, [x++]
#define  YINC  (0x0B)     // y-indirect, post-increment: move [y++], b
#define  REG0  (0x0C)     // #0 register
#define  REG1  (0x0D)     // #1 register

#define  CNST  (0x10)     // constant: move a, #1234; jump 0
#define  ABS   (0x11)     // absolute: move a, 100
#define  REL   (0x12)     // relative: jump -10
#define  SREL  (0x13)     // stack relative: inc [SP+1]


/* OP codes */
#define  NOP    (0x00)
#define  HALT   (0x01)
#define  CALL   (0x02)
#define  RETN   (0x03)

#define  MOVE   (0x04)
#define  JUMP   (0x05)
#define  INC    (0x06)
#define  DEC    (0x07)

#define  ADD    (0x08)
#define  SUB    (0x09)
#define  MUL    (0x0A)
#define  DIV    (0x0B)

#define  AND    (0x0C)
#define  OR     (0x0D)
#define  XOR    (0x0E)
#define  NOT    (0x0F)

#define  BNZE   (0x10)
#define  BZE    (0x11)
#define  BPOS   (0x12)
#define  BNEG   (0x13)

#define  IN     (0x14)
#define  OUT    (0x15)
#define  PUSH   (0x16)
#define  POP    (0x17)

#define  SWAP   (0x18)
#define  DBNZ   (0x19)
#define  SHL    (0x1A)
#define  SHR    (0x1B)

#define  DLY    (0x1C)
#define  SYS    (0x1D)

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))

#define VMA(C, addr)            (((uint16_t)(addr)) & (C)->mem_mask)  // valid memory address
#define MEM_READ(C, addr)       ((C)->memory[VMA(C, addr)])  // read a value
#define MEM_WRITE(C, add, val)  (MEM_READ(C, add) = val)
#define MEM_ADDR(C, addr)       &MEM_READ(C, addr)  // provide address
#define INC_PC(C)               ((C)->pcnt = VMA(C, (C)->pcnt + 1))
#define INC_ADDR(C, addr)       ((addr) = VMA(C, (addr) + 1))
#define VM_SIZE(size)           (sizeof(vm16_t) + (sizeof(uint16_t) * (size - 1)))
#define MEM_SIZE(vm_size)       ((vm_size - sizeof(vm16_t) + sizeof(uint16_t)) / sizeof(uint16_t))
#define VM_VALID(C)             ((C != 0) && (C->ident == IDENT) && (C->version == VERSION))


/*
** Determine the operand destination address (register/memory)
*/
static uint16_t *getaddr(vm16_t *C, uint8_t addr_mod) {
  switch(addr_mod) {
    case AREG: return &C->areg;
    case BREG: return &C->breg;
    case CREG: return &C->creg;
    case DREG: return &C->dreg;
    case XREG: return &C->xreg;
    case YREG: return &C->yreg;
    case PCNT: return &C->pcnt;
    case SPTR: return &C->sptr;
    case XIND: return MEM_ADDR(C, C->xreg);
    case YIND: return MEM_ADDR(C, C->yreg);
    case XINC: {
        uint16_t *p_res = MEM_ADDR(C, C->xreg);
        INC_ADDR(C, C->xreg);
        return p_res;
    }
    case YINC: {
        uint16_t *p_res = MEM_ADDR(C, C->yreg);
        INC_ADDR(C, C->yreg);
        return p_res;
    }
    case CNST: return MEM_ADDR(C, 0); // invalid
    case ABS: {
        uint16_t addr = MEM_READ(C, C->pcnt);
        INC_PC(C);
        return MEM_ADDR(C, addr);
    }
    case REL: return MEM_ADDR(C, 0); // invalid
    case SREL: {
        uint16_t offs = MEM_READ(C, C->pcnt);
        INC_PC(C);
        return MEM_ADDR(C, C->sptr + offs);
    }
    default: return MEM_ADDR(C, 0);
  }
}

/*
* Determine the operand source value (register/memory)
*/
static uint16_t getoprnd(vm16_t *C, uint8_t addr_mod) {
  switch(addr_mod) {
    case AREG: return C->areg;
    case BREG: return C->breg;
    case CREG: return C->creg;
    case DREG: return C->dreg;
    case XREG: return C->xreg;
    case YREG: return C->yreg;
    case PCNT: return C->pcnt;
    case SPTR: return C->sptr;
    case XIND: return MEM_READ(C, C->xreg);
    case YIND: return MEM_READ(C, C->yreg);
    case XINC: {
        uint16_t val = MEM_READ(C, C->xreg);
        INC_ADDR(C, C->xreg);
        return val;
    }
    case YINC: {
        uint16_t val = MEM_READ(C, C->yreg);
        INC_ADDR(C, C->yreg);
        return val;
    }
    case REG0: return 0;
    case REG1: return 1;
    case CNST: {
        uint16_t val = MEM_READ(C, C->pcnt);
        INC_PC(C);
        return val;
    }
    case ABS: {
        uint16_t addr = MEM_READ(C, C->pcnt);
        INC_PC(C);
        return MEM_READ(C, addr);
    }
    case REL: {
        uint16_t offs = MEM_READ(C, C->pcnt);
        offs = VMA(C, C->pcnt + offs - 1);
        INC_PC(C);
        return offs;
    }
    case SREL: {
        uint16_t offs = MEM_READ(C, C->pcnt);
        INC_PC(C);
        return MEM_READ(C, C->sptr + offs);
    }
    default: return 0;
  }
}

void vm16_clear(vm16_t *C) {
    if(VM_VALID(C)) {
        memset(C->memory, 0, C->mem_size * 2);
        C->areg = 0;
        C->breg = 0;
        C->creg = 0;
        C->dreg = 0;
        C->xreg = 0;
        C->yreg = 0;
        C->pcnt = 0;
        C->sptr = 0;
    }
}

uint32_t vm16_calc_size(uint8_t size) {
    uint32_t mem_size = (1 << MIN(size, 16));
    return VM_SIZE(mem_size);
}

uint32_t vm16_real_size(vm16_t *C) {
    return VM_SIZE(C->mem_size);
}

bool vm16_init(vm16_t *C, uint32_t vm_size) {
    if(C != NULL) {
        C->ident = IDENT;
        C->version = VERSION;
        C->mem_size = MEM_SIZE(vm_size);
        C->mem_mask = MEM_SIZE(vm_size) - 1;
        vm16_clear(C);
        return true;
    }
    return false;
}

void vm16_loadaddr(vm16_t *C, uint16_t addr) {
    if(VM_VALID(C)) {
        C->pcnt = VMA(C, addr);
    }
}

void vm16_deposit(vm16_t *C, uint16_t value) {
    if(VM_VALID(C)) {
        MEM_WRITE(C, C->pcnt, value);
        C->l_addr = C->pcnt;
        C->l_data = value;
        INC_PC(C);
    }
}

void vm16_examine(vm16_t *C) {
    if(VM_VALID(C)) {
        C->l_addr = C->pcnt;
        C->l_data = MEM_READ(C, C->pcnt);
        INC_PC(C);
    }
}

uint32_t vm16_get_vm(vm16_t *C, uint32_t size_buffer, uint8_t *p_buffer) {
    if(VM_VALID(C)) {
        uint32_t size = MIN(VM_SIZE(C->mem_size), size_buffer);
        if((p_buffer != NULL) && (size_buffer >= size)) {
            memcpy(p_buffer, C, size);
            return size;
        }
    }
    return 0;
}

uint32_t vm16_set_vm(vm16_t *C, uint32_t size_buffer, uint8_t *p_buffer) {
    if(VM_VALID(C)) {
        uint32_t size = MIN(VM_SIZE(C->mem_size), size_buffer);
        if(p_buffer != NULL) {
            uint16_t mem_mask = C->mem_mask;
            uint32_t mem_size = C->mem_size;
            memcpy(C, p_buffer, size);
            // restore the header again
            C->ident = IDENT;
            C->version = VERSION;
            C->mem_mask = mem_mask;
            C->mem_size = mem_size;
            return size;
        }
    }
    return 0;
}

uint32_t vm16_read_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0)) {
            addr = VMA(C, addr);
            num = MIN(num, 0x80);
            num = MIN(num, C->mem_size - addr);
            memcpy(p_buffer, MEM_ADDR(C, addr), num * 2);
            return num;
        }
    }
    return 0;
}

uint32_t vm16_write_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0)) {
            addr = VMA(C, addr);
            num = MIN(num, 0x80);
            num = MIN(num, C->mem_size - addr);
            memcpy(MEM_ADDR(C, addr), p_buffer, num * 2);
            return num;
        }
    }
    return 0;
}

int vm16_run(vm16_t *C, uint32_t num_cycles, uint32_t *ran) {
    if(!VM_VALID(C)) {
        *ran = 0;
        return VM16_ERROR;
    }
    uint32_t num = num_cycles;
    while(num-- > 0) {
        uint16_t code = MEM_READ(C, C->pcnt);

        INC_PC(C);
        uint8_t opcode  = (uint8_t)((code >> 10) & 0x003f);
        uint8_t addr_mode1 = (uint8_t)((code >>  5) & 0x001f);
        uint8_t addr_mode2 = (uint8_t)((code >>  0) & 0x001f);

        switch(opcode) {
            case NOP: break;
            case HALT: {
                *ran = num_cycles - num;
                return VM16_HALT;
            }
            case CALL: {
                // addr = opd(), push PC, PC = addr
                uint16_t addr = getoprnd(C, addr_mode1);
                C->sptr = VMA(C, C->sptr - 1);
                *MEM_ADDR(C, C->sptr) = C->pcnt;
                C->pcnt = addr;
                break;
            }
            case RETN: {
                // PC = pop()
                uint16_t addr = *MEM_ADDR(C, C->sptr);
                C->sptr = VMA(C, C->sptr + 1);
                C->pcnt = addr;
                break;
            }
            case MOVE: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = opd2;
                break;
            }
            case JUMP: C->pcnt = getoprnd(C, addr_mode1); break;
            case INC: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                (*p_opd1)++;
                break;
            }
            case DEC: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                (*p_opd1)--;
                break;
            }
            case ADD: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = *p_opd1 + opd2;
                break;
            }
            case SUB: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = *p_opd1 - opd2;
                break;
            }
            case MUL: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = *p_opd1 * opd2;
                break;
            }
            case DIV: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd2 > 0) {
                    *p_opd1 = *p_opd1 / opd2;
                }
                break;
            }
            case AND: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = *p_opd1 & opd2;
                break;
            }
            case OR: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = *p_opd1 | opd2;
                break;
            }
            case XOR: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = *p_opd1 ^ opd2;
                break;
            }
            case NOT: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = ~opd2;
                break;
            }
            case BNZE: {
                uint16_t opd1 = getoprnd(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd1 != 0) {
                    C->pcnt = opd2;
                }
                break;
            }
            case BZE: {
                uint16_t opd1 = getoprnd(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd1 == 0) {
                    C->pcnt = opd2;
                }
                break;
            }
            case BPOS: {
                uint16_t opd1 = getoprnd(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd1 <= 0x7FFF) {
                    C->pcnt = opd2;
                }
                break;
            }
            case BNEG: {
                uint16_t opd1 = getoprnd(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd1 > 0x7FFF) {
                    C->pcnt = opd2;
                }
                break;
            }
            case IN: {
                C->p_in_dest = getaddr(C, addr_mode1);
                C->l_addr = getoprnd(C, addr_mode2);
                *ran = num_cycles - num;
                return VM16_IN;
            }
            case OUT: {
                C->l_addr = getoprnd(C, addr_mode1);
                C->l_data = getoprnd(C, addr_mode2);
                *ran = num_cycles - num;
                return VM16_OUT;
            }
            case PUSH: {
                uint16_t opd1 = getoprnd(C, addr_mode1);
                C->sptr = VMA(C, C->sptr - 1);
                *MEM_ADDR(C, C->sptr) = opd1;
                break;
            }
            case POP: {
               uint16_t *p_opd1 = getaddr(C, addr_mode1);
                *p_opd1 = *MEM_ADDR(C, C->sptr);
                C->sptr = VMA(C, C->sptr + 1);
                break;
            }
            case SWAP: {
              uint16_t *p_opd1 = getaddr(C, addr_mode1);
              *p_opd1 = ((uint16_t)(*p_opd1) >> 8) | ((uint16_t)(*p_opd1) << 8);
              break;
            }
            case DBNZ: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                (*p_opd1)--;
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(*p_opd1 != 0) {
                    C->pcnt = opd2;
                }
                break;
            }
            case SHL: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = *p_opd1 << opd2;
                break;
            }
            case SHR: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = *p_opd1 >> opd2;
                break;
            }
            case DLY: {
                *ran = num_cycles - num;
                return VM16_DELAY;
            }
            case SYS: {
                C->l_data = getoprnd(C, addr_mode1);
                *ran = num_cycles - num;
                return VM16_SYS;
            }
            default: {
                break;
            }
        }
    }
    *ran = num_cycles - num;
    return VM16_OK;
}
