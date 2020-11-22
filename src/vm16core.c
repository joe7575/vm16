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
#define  DLY    (0x01)
#define  SYS    (0x02)
#define  INT    (0x03)

#define  JUMP   (0x04)
#define  CALL   (0x05)
#define  RETN   (0x06)
#define  HALT   (0x07)


#define  MOVE   (0x08)
#define  XCHG   (0x09)
#define  INC    (0x0A)
#define  DEC    (0x0B)

#define  ADD    (0x0C)
#define  SUB    (0x0D)
#define  MUL    (0x0E)
#define  DIV    (0x0F)

#define  AND    (0x10)
#define  OR     (0x11)
#define  XOR    (0x12)
#define  NOT    (0x13)

#define  BNZE   (0x14)
#define  BZE    (0x15)
#define  BPOS   (0x16)
#define  BNEG   (0x17)

#define  IN     (0x18)
#define  OUT    (0x19)
#define  PUSH   (0x1A)
#define  POP    (0x1B)

#define  SWAP   (0x1C)
#define  DBNZ   (0x1D)
#define  MOD    (0x1E)

#define  SHL    (0x1F)
#define  SHR    (0x20)
#define  ADDC   (0x21)
#define  MULC   (0x22)

#define  SKNE   (0x23)
#define  SKEQ   (0x24)
#define  SKLT   (0x25)
#define  SKGT   (0x26)


#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))


#define VMA(C, addr)            (((uint16_t)(addr)) & (C)->mem_mask)  // valid memory address
#define ADDR_SRC(C, addr)       (&(C)->memory[VMA(C, addr)])
#define ADDR_DST(C, addr)       (&(C)->memory[VMA(C, addr)])


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
    case XIND: return ADDR_DST(C, C->xreg);
    case YIND: return ADDR_DST(C, C->yreg);
    case XINC: {
        uint16_t *p_res = ADDR_DST(C, C->xreg);
        C->xreg++;
        return p_res;
    }
    case YINC: {
        uint16_t *p_res = ADDR_DST(C, C->yreg);
        C->yreg++;
        return p_res;
    }
    case CNST: return ADDR_DST(C, 0); // invalid
    case ABS: {
        uint16_t addr = *ADDR_SRC(C, C->pcnt);
        C->pcnt++;
        return ADDR_DST(C, addr);
    }
    case REL: return ADDR_DST(C, 0); // invalid
    case SREL: {
        uint16_t offs = *ADDR_SRC(C, C->pcnt);
        C->pcnt++;
        return ADDR_DST(C, C->sptr + offs);
    }
    default: return ADDR_DST(C, 0);
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
    case XIND: return *ADDR_SRC(C, C->xreg);
    case YIND: return *ADDR_SRC(C, C->yreg);
    case XINC: {
        uint16_t val = *ADDR_SRC(C, C->xreg);
        C->xreg++;
        return val;
    }
    case YINC: {
        uint16_t val = *ADDR_SRC(C, C->yreg);
        C->yreg++;
        return val;
    }
    case REG0: return 0;
    case REG1: return 1;
    case CNST: {
        uint16_t val = *ADDR_SRC(C, C->pcnt);
        C->pcnt++;
        return val;
    }
    case ABS: {
        uint16_t addr = *ADDR_SRC(C, C->pcnt);
        C->pcnt++;
        return *ADDR_SRC(C, addr);
    }
    case REL: {
        uint16_t offs = *ADDR_SRC(C, C->pcnt);
        C->pcnt++;
        return C->pcnt + offs;
    }
    case SREL: {
        uint16_t offs = *ADDR_SRC(C, C->pcnt);
        C->pcnt++;
        return C->sptr + offs;
    }
    default: return 0;
  }
}

// size in number of 4K blocks
uint32_t vm16_calc_size(uint8_t size) {
    uint32_t mem_size = MIN(size, MAX_MEM_BLOCKS) * MEM_BLOCK_SIZE;
    return VM_SIZE(mem_size);
}

uint32_t vm16_real_size(vm16_t *C) {
    return VM_SIZE(C->mem_size);
}

bool vm16_init(vm16_t *C, uint32_t vm_size) {
    if(C != NULL) {
        memset(C, 0, vm_size);
        C->ident = IDENT;
        C->version = VERSION;
        C->mem_size = MEM_SIZE(vm_size);
        C->mem_mask = C->mem_size - 1;
        return true;
    }
    return false;
}

void vm16_loadaddr(vm16_t *C, uint16_t addr) {
    if(VM_VALID(C)) {
        C->pcnt = addr;
    }
}

void vm16_deposit(vm16_t *C, uint16_t value) {
    if(VM_VALID(C)) {
        *ADDR_DST(C, C->pcnt) = value;
        C->l_addr = C->pcnt;
        C->l_data = value;
        C->pcnt++;
    }
}

void vm16_examine(vm16_t *C) {
    if(VM_VALID(C)) {
        C->l_addr = C->pcnt;
        C->l_data = *ADDR_SRC(C, C->pcnt);
        C->pcnt++;
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
            uint32_t mem_size = C->mem_size;
            memcpy(C, p_buffer, size);
            // restore the header again
            C->ident = IDENT;
            C->version = VERSION;
            C->mem_size = mem_size;

            return size;
        }
    }
    return 0;
}

uint32_t vm16_read_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0) && (C->mem_size >= (addr + num))) {
            num = MIN(num, C->mem_size - addr);
            for(int i=0; i<num; i++) {
                *p_buffer++ = *ADDR_SRC(C, addr);
                addr++;
            }
            return num;
        }
    }
    return 0;
}

uint32_t vm16_write_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0) && (C->mem_size >= (addr + num))) {
            num = MIN(num, C->mem_size - addr);
            for(int i=0; i<num; i++) {
                *ADDR_DST(C, addr) = *p_buffer++;
                addr++;
            }
            return num;
        }
    }
    return 0;
}

uint16_t vm16_peek(vm16_t *C, uint16_t addr) {
    if(VM_VALID(C)) {
        return *ADDR_SRC(C, addr);
    }
    return 0xFFFF;
}

bool vm16_poke(vm16_t *C, uint16_t addr, uint16_t val) {
    if(VM_VALID(C)) {
        *ADDR_DST(C, addr) = val;
        return true;
    }
    return false;
}

int vm16_run(vm16_t *C, uint32_t num_cycles, uint32_t *ran) {
    if(!VM_VALID(C)) {
        *ran = 0;
        return VM16_ERROR;
    }
    uint32_t num = num_cycles;
    while(num-- > 0) {
        uint16_t code = *ADDR_SRC(C, C->pcnt);

        C->pcnt++;

        uint8_t opcode  = (uint8_t)((code >> 10) & 0x003f);
        uint8_t addr_mode1 = (uint8_t)((code >>  5) & 0x001f);
        uint8_t addr_mode2 = (uint8_t)((code >>  0) & 0x001f);

        switch(opcode) {
            case NOP: {
                break;
            }
           case DLY: {
                *ran = num_cycles - num;
                return VM16_DELAY;
            }
            case SYS: {
                C->p_in_dest = &C->areg;
                C->l_addr = code & 0x03FF;
                *ran = num_cycles - num;
                return VM16_SYS;
            }
            case INT: {
                uint16_t addr = (code & 0x03FF) * 4;
                C->sptr = C->sptr - 1;
                *ADDR_DST(C, C->sptr) = C->pcnt;
                C->pcnt = addr;
                break;
            }
            case JUMP: {
                C->pcnt = getoprnd(C, addr_mode1);
                break;
            }
            case CALL: {
                // addr = opd(), push PC, PC = addr
                uint16_t addr = getoprnd(C, addr_mode1);
                C->sptr = C->sptr - 1;
                *ADDR_DST(C, C->sptr) = C->pcnt;
                C->pcnt = addr;
                break;
            }
            case RETN: {
                // PC = pop()
                uint16_t addr = *ADDR_DST(C, C->sptr);
                C->sptr = C->sptr + 1;
                C->pcnt = addr;
                break;
            }
            case HALT: {
                *ran = num_cycles - num;
                return VM16_HALT;
            }
            case MOVE: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                *p_opd1 = opd2;
                break;
            }
            case XCHG: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t *p_opd2 = getaddr(C, addr_mode2);
                uint16_t temp = *p_opd1;
                *p_opd1 = *p_opd2;
                *p_opd2 = temp;
                break;
            }
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
                 *p_opd1 = ~*p_opd1;
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
                C->sptr = C->sptr - 1;
                *ADDR_DST(C, C->sptr) = opd1;
                break;
            }
            case POP: {
               uint16_t *p_opd1 = getaddr(C, addr_mode1);
                *p_opd1 = *ADDR_DST(C, C->sptr);
                C->sptr = C->sptr + 1;
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
            case MOD: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd2 > 0) {
                    *p_opd1 = *p_opd1 % opd2;
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
            case ADDC: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                uint32_t res = *p_opd1 + opd2;
                 *p_opd1 = (uint16_t)res;
                 C->breg = (uint16_t)(res >> 16);
                break;
            }
            case MULC: {
                uint16_t *p_opd1 = getaddr(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                uint32_t res = *p_opd1 * opd2;
                 *p_opd1 = (uint16_t)res;
                 C->breg = (uint16_t)(res >> 16);
                break;
            }
            case SKNE: {
                uint16_t opd1 = getoprnd(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd1 != opd2) {
                    C->pcnt += 2;
                }
                break;
            }
            case SKEQ: {
                uint16_t opd1 = getoprnd(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd1 == opd2) {
                    C->pcnt += 2;
                }
                break;
            }
            case SKLT: {
                uint16_t opd1 = getoprnd(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd1 < opd2) {
                    C->pcnt += 2;
                }
                break;
            }
            case SKGT: {
                uint16_t opd1 = getoprnd(C, addr_mode1);
                uint16_t opd2 = getoprnd(C, addr_mode2);
                if(opd1 > opd2) {
                    C->pcnt += 2;
                }
                break;
            }
            default: {
                break;
            }
        }
    }
    *ran = num_cycles - num;
    return VM16_OK;
}
