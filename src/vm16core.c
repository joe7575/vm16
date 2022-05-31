/*
VM16
Copyright (C) 2019-2020 Joe <iauit@gmx.de>

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
#define  REL   (0x12)     // relative: jump (deprecated)
#define  SREL  (0x13)     // stack relative: inc [SP+1]
#define  REL2  (0x14)     // relative: jump -10
#define  XREL  (0x15)     // X register relative [X+1]
#define  YREL  (0x16)     // Y register relative [Y+1]


/* OP codes */
#define  NOP    (0x00)
#define  BRK    (0x01)
#define  SYS    (0x02)
//#define  INT    (0x03)

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

// byte nibble vs ASCII char
#define NTOA(n)                 ((n) > 9   ? (n) + 55 : (n) + 48)
#define ATON(a)                 ((a) > '9' ? (a) - 55 : (a) - 48)

static inline char ascii(uint16_t val) {
    return ((val > 126 || val < 32) ? '.' : (char)val);
}

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
        case REL2: return ADDR_DST(C, 0); // invalid
        case XREL: {
            uint16_t offs = *ADDR_SRC(C, C->pcnt);
            C->pcnt++;
            return ADDR_DST(C, C->xreg + offs);
        }
        case YREL: {
            uint16_t offs = *ADDR_SRC(C, C->pcnt);
            C->pcnt++;
            return ADDR_DST(C, C->yreg + offs);
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
            return *ADDR_SRC(C, C->sptr + offs);
        }
        case REL2: {
            uint16_t offs = *ADDR_SRC(C, C->pcnt);
            C->pcnt++;
            return C->pcnt + offs - 2;
        }
        case XREL: {
            uint16_t offs = *ADDR_SRC(C, C->pcnt);
            C->pcnt++;
            return *ADDR_SRC(C, C->xreg + offs);
        }
        case YREL: {
            uint16_t offs = *ADDR_SRC(C, C->pcnt);
            C->pcnt++;
            return *ADDR_SRC(C, C->yreg + offs);
        }
        default: return 0;
    }
}

// size from 0 for 64 words, 1 for 128 words, up to 10 for 64 Kwords
uint32_t vm16_calc_size(uint8_t size) {
    uint32_t mem_size = 64 << MIN(size, 10);
    return VM_SIZE(mem_size);
}

uint32_t vm16_get_string_size(vm16_t *C) {
    return VM_SIZE(C->mem_size) * 2;
}

bool vm16_init(vm16_t *C, uint32_t vm_size) {
    if(C != NULL) {
        memset(C, 0, vm_size);
        C->ident = IDENT;
        C->version = VERSION;
        C->mem_size = MEM_SIZE(vm_size);
        C->mem_mask = C->mem_size - 1;
        C->p_in_dest = &C->areg;
        C->tptr = 0xFFFF;
        return true;
    }
    return false;
}

void vm16_set_pc(vm16_t *C, uint16_t addr) {
    if(VM_VALID(C)) {
        C->pcnt = addr;
    }
}

uint16_t vm16_get_pc(vm16_t *C) {
    if(VM_VALID(C)) {
        return C->pcnt;
    }
    return 0;
}

void vm16_deposit(vm16_t *C, uint16_t value) {
    if(VM_VALID(C)) {
        *ADDR_DST(C, C->pcnt) = value;
        C->l_addr = C->pcnt;
        C->l_data = value;
        C->pcnt++;
    }
}

char *vm16_get_vm_as_str(vm16_t *C, uint32_t size_buffer, char *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && ((VM_SIZE(C->mem_size) * 2) == size_buffer)) {
            char *p_src = (char*)C;
            char *p_dst = p_buffer;
             for(int i = 0; i < size_buffer/2; i++) {
                *p_dst++ = NTOA(*p_src >> 4);
                *p_dst++ = NTOA(*p_src & 0x0f);
                p_src++;
            }
            return p_buffer;
        }
    }
    return NULL;
}

uint32_t vm16_set_vm_as_str(vm16_t *C, uint32_t size_buffer, char *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && ((VM_SIZE(C->mem_size) * 2) == size_buffer)) {
            uint16_t mem_size = C->mem_size;
            char *p_src = p_buffer;
            char *p_dst = (char*)C;
            for(int i = 0; i < size_buffer/2; i++) {
                *p_dst++ = (ATON(p_src[0]) << 4) + ATON(p_src[1]);
                p_src += 2;
            }
            // restore the header again
            C->ident = IDENT;
            C->version = VERSION;
            C->mem_size = mem_size;
            C->p_in_dest = &C->areg;
            return size_buffer;
        }
    }
    return 0;
}

uint32_t vm16_read_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0) && (num <= C->mem_size)) {
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
        if((p_buffer != NULL) && (num > 0) && (num <= C->mem_size)) {
            for(int i=0; i<num; i++) {
                *ADDR_DST(C, addr) = *p_buffer++;
                addr++;
            }
            return num;
        }
    }
    return 0;
}

uint32_t vm16_read_mem_as_str(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0) && (num <= C->mem_size)) {
            for(int i=0; i<num; i++) {
                uint16_t val = *ADDR_SRC(C, addr);
                *p_buffer++ = NTOA((val >> 12) & 0x0f);
                *p_buffer++ = NTOA((val >>  8) & 0x0f);
                *p_buffer++ = NTOA((val >>  4) & 0x0f);
                *p_buffer++ = NTOA((val >>  0) & 0x0f);
                addr++;
            }
            return num;
        }
    }
    return 0;
}

uint32_t vm16_write_mem_as_str(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0) && (num <= C->mem_size)) {
            for(int i=0; i<num; i++) {
                char c1 = *p_buffer++;
                char c2 = *p_buffer++;
                char c3 = *p_buffer++;
                char c4 = *p_buffer++;
                *ADDR_DST(C, addr) = (ATON(c1) << 12) + (ATON(c2) <<  8) +
                                     (ATON(c3) <<  4) + ATON(c4);
                addr++;
            }
            return num;
        }
    }
    return 0;
}

uint16_t vm16_read_ascii(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0) && (num <= C->mem_size)) {
            uint16_t i = 0;
            while(i < num) {
                uint16_t val = *ADDR_SRC(C, addr);
                if(val == 0) {
                    return i;
                }
                if(val >= 256) {
                    *p_buffer++ = ascii(val >> 8);
                    i++;
                    if(i < num) {
                        *p_buffer++ = ascii(val & 0xFF);
                        i++;
                    }
                } else {
                    *p_buffer++ = ascii(val);
                    i++;
                }
                addr++;
            }
            return num;
        }
    }
    return 0;
}

uint32_t vm16_write_ascii(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0) && (num <= C->mem_size)) {
            for(int i=0; i<num; i++) {
                *ADDR_DST(C, addr) = *p_buffer++;
                addr++;
            }
            return num;
        }
    }
    return 0;
}

uint32_t vm16_write_ascii_16(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer) {
    if(VM_VALID(C)) {
        if((p_buffer != NULL) && (num > 0) && (num <= C->mem_size)) {
            for(int i = 0; i < (num + 1) / 2; i++) {
                if(p_buffer[1] == 0) {
                    *ADDR_DST(C, addr) = p_buffer[0];
                    p_buffer++;
                    addr++;
                } else {
                    *ADDR_DST(C, addr) = (p_buffer[0] << 8) + p_buffer[1];
                    p_buffer += 2;
                    addr++;
                }
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
                C->p_in_dest = &C->areg;
                *ran = num_cycles - num;
                return VM16_NOP;
            }
            case BRK: {
                C->p_in_dest = &C->areg;
                C->l_addr = code & 0x03FF;
                *ran = num_cycles - num;
                C->pcnt--;
                return VM16_BREAK;
            }
            case SYS: {
                C->p_in_dest = &C->areg;
                C->l_addr = code & 0x03FF;
                *ran = num_cycles - num;
                return VM16_SYS;
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
                C->bptr = C->sptr;
                C->tptr = MIN(C->tptr, C->sptr);
                break;
            }
            case RETN: {
                // PC = pop()
                uint16_t addr = *ADDR_DST(C, C->sptr);
                C->sptr = C->sptr + 1;
                C->pcnt = addr;
                C->bptr = C->sptr;
                break;
            }
            case HALT: {
                *ran = num_cycles - num;
                C->pcnt--;
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
                C->tptr = MIN(C->tptr, C->sptr);
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
                return VM16_ERROR;
            }
        }
    }
    *ran = num_cycles - num;
    return VM16_OK;
}
