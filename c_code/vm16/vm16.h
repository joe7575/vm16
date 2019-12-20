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

#ifndef vm16_h
#define vm16_h


#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <stddef.h>

#ifndef _UNIT_TEST_

#include "lua.h"

#define LUA_VM16LIBNAME "vm16lib"
LUALIB_API int luaopen_vm16(lua_State *L);

#endif

#define IDENT           (0x36314D56)
#define VERSION         (1)
#define VM16_WORD_SIZE  (16)
#define MEM_BLOCK_SIZE  (4096)
#define MAX_MEM_BLOCKS  (16)     // 16 x MEM_BLOCK_SIZE

/*
** VM return values
*/

#define VM16_OK        (0)  // run to the end
#define VM16_DELAY     (1)  // one cycle pause
#define VM16_IN        (2)  // input command
#define VM16_OUT       (3)  // output command
#define VM16_SYS       (4)  // system call
#define VM16_HALT      (5)  // CPU halt
#define VM16_ERROR     (6)  // invalid call

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
    uint16_t l_addr;    // latched addr (I/O, examine)
    uint16_t l_data;    // latched data (I/O, examine)
    uint32_t mem_size;
    uint16_t *p_in_dest;    // for IN command
    uint16_t *p_dst[16];    // RAM memory mapping
    uint16_t *p_src[16];    // ROM memory mapping
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
** Mark given block number as write protected.
*/
bool vm16_mark_block_as_rom(vm16_t *C, uint8_t block);

/*
** Clear registers and memory (set to zero)
*/
void vm16_clear(vm16_t *C);

/*
** Set PC to given memory address
*/
void vm16_loadaddr(vm16_t *C, uint16_t addr);

/*
** Deposit 'value' to PC address and post-increment PC
** addr/data is available via C->io_addr/C->out_data
*/
void vm16_deposit(vm16_t *C, uint16_t value);

/*
** Read 'value' from PC address and post-increment PC
** addr/data is available via C->io_addr/C->out_data
*/
void vm16_examine(vm16_t *C);

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
** Run the VM with the given number of machine cycles.
** The number of executed cycles is stored in 'ran'
** The reason for the abort is returned.
*/
int vm16_run(vm16_t *C, uint32_t num_cycles, uint32_t *run);

#endif
