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


#define ADDR_SRC(C, addr)       ((C)->p_src[(addr) >> 12] + ((addr) & 0x0fff))
#define ADDR_DST(C, addr)       ((C)->p_dst[(addr) >> 12] + ((addr) & 0x0fff))


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
        uint16_t addr = *ADDR_DST(C, C->pcnt);
        C->pcnt++;
        return ADDR_DST(C, addr);
    }
    case REL: return ADDR_DST(C, 0); // invalid
    case SREL: {
        uint16_t offs = *ADDR_DST(C, C->pcnt);
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
        offs = C->pcnt + offs - 1;
        C->pcnt++;
        return offs;
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
    uint32_t mem_size = MIN(size, MAX_MEM_BANKS) * MEM_BANK_SIZE;
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
        return true;
    }
    return false;
}

bool vm16_mark_rom_bank(vm16_t *C, uint8_t bank) {
    uint8_t num_banks = C->mem_size / MEM_BANK_SIZE;
    if(bank < num_banks) {
        C->p_dst[bank] = C->memory; // use first RAM bank instead
        return true;
    }
    return false;
}

void vm16_init_mem_banks(vm16_t *C) {
    if(VM_VALID(C)) {
        uint8_t num_blocks = C->mem_size / MEM_BANK_SIZE;
        for(int i=0; i<16; i++) {
            if(i < num_blocks) {
                if(C->rom_bank[i]) {
                    C->p_dst[i] = C->memory;
                } else {
                    C->p_dst[i] = &(C->memory)[i * MEM_BANK_SIZE];
                }
                C->p_src[i] = &(C->memory)[i * MEM_BANK_SIZE];
            } else {
                C->p_dst[i] = C->memory;
                C->p_src[i] = C->memory;
            }
        }
    }
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
            num = MIN(num, 0x80);
            num = MIN(num, C->mem_size - addr);
            memcpy(p_buffer, &(C->memory[addr]), num * 2);
            return num;
        }
    }
    return 0;
}

uint32_t vm16_write_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0) && (C->mem_size >= (addr + num))) {
            num = MIN(num, 0x80);
            num = MIN(num, C->mem_size - addr);
            memcpy(&(C->memory[addr]), p_buffer, num * 2);
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
        uint16_t code = *ADDR_SRC(C, C->pcnt);

        C->pcnt++;

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
