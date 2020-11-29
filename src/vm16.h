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

#ifndef vm16_h
#define vm16_h


#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <stddef.h>

#ifndef _UNIT_TEST_

#include "lua.h"

LUALIB_API int luaopen_vm16(lua_State *L);

#endif

#define IDENT           (0x36314D56)
#define VERSION         (2)
#define VM16_WORD_SIZE  (16)
#define MEM_BLOCK_SIZE  (4096)
#define MAX_MEM_BLOCKS  (16)     // = 64 KW

/*
** VM return values
*/

#define VM16_OK        (0)  // run to the end
#define VM16_IN        (1)  // input command
#define VM16_OUT       (2)  // output command
#define VM16_SYS       (3)  // system call
#define VM16_HALT      (4)  // CPU halt
#define VM16_ERROR     (5)  // invalid call

typedef struct {
    uint32_t ident;     // VM identifier
    uint16_t version;   // VM version
    uint16_t areg;      // A accu register
    uint16_t breg;      // B accu register
    uint16_t creg;      // C accu register
    uint16_t dreg;      // D accu register
    uint16_t xreg;      // X index register
    uint16_t yreg;      // Y index register
    uint16_t pcnt;      // program counter
    uint16_t sptr;      // stack pointer
    uint16_t l_addr;        // latched address (I/O, examine)
    uint16_t l_data;        // latched data (I/O, examine)
    uint16_t mem_size;      // RAM size in words
    uint16_t mem_mask;      // mask value (size - 1)
    uint16_t *p_in_dest;    // for IN command
    uint16_t memory[1];     // program/data memory (16 bit)
}vm16_t;

/*
** printf
*/
void vm16_disassemble(vm16_t *C, uint8_t opcode, uint8_t addr_mode1, uint8_t addr_mode2);

/*
** Determine the size in bytes for the VM
** Size is the memory size 2^'size'
*/
uint32_t vm16_calc_size(uint8_t size);

/*
** Return the size store in the VM
*/
uint32_t vm16_real_size(vm16_t *C);

/*
** Initialize the allocation VM memory.
*/
bool vm16_init(vm16_t *C, uint32_t mem_size);

/*
** Set PC to given memory address
*/
void vm16_set_pc(vm16_t *C, uint16_t addr);

/*
** Return PC value
*/
uint16_t vm16_get_pc(vm16_t *C);

/*
** Deposit 'value' to PC address and post-increment PC
** addr/data is available via C->io_addr/C->out_data
*/
void vm16_deposit(vm16_t *C, uint16_t value);

/*
** Read complete VM inclusive RAM for storage purposes.
** Number of read bytes is returned.
*/
uint32_t vm16_get_vm(vm16_t *C, uint32_t size_buffer, uint8_t *p_buffer);

/*
** Write (restore) the VM with then given binary string.
** Number of written bytes is returned.
*/
uint32_t vm16_set_vm(vm16_t *C, uint32_t size_buffer, uint8_t *p_buffer);

/*
** Read memory block for debugging purposes / external drives
*/
uint32_t vm16_read_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer);

/*
** Write memory block from external drives / storage mediums
*/
uint32_t vm16_write_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer);

/*
** Read value from VM memory
*/
uint16_t vm16_peek(vm16_t *C, uint16_t addr);

/*
** Write value to VM memory
*/
bool vm16_poke(vm16_t *C, uint16_t addr, uint16_t val);


/*
** Run the VM with the given number of machine cycles.
** The number of executed cycles is stored in 'ran'
** The reason for the abort is returned.
*/
int vm16_run(vm16_t *C, uint32_t num_cycles, uint32_t *run);

#endif
