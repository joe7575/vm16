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
#define VERSION         (2)    // VM compatibility
#define SVERSION        "2.7.3"
#define VM16_WORD_SIZE  (16)

/*
** VM return values
*/

#define VM16_OK        (0)  // run to the end
#define VM16_NOP       (1)  // nop command
#define VM16_IN        (2)  // input command
#define VM16_OUT       (3)  // output command
#define VM16_SYS       (4)  // system call
#define VM16_HALT      (5)  // CPU halt
#define VM16_BREAK     (6)  // breakpoint reached
#define VM16_ERROR     (7)  // invalid opcode

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
    uint16_t bptr;      // stack base pointer
    uint16_t tptr;      // Top of stack
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
** Return the size to store the VM as ASCII string
*/
uint32_t vm16_get_string_size(vm16_t *C);

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
** Return complete VM inclusive RAM as ASCII string for storage purposes.
*/
char *vm16_get_vm_as_str(vm16_t *C, uint32_t size_buffer, char *p_buffer);

/*
** Write (restore) the VM with then given ASCII string.
** Number of written bytes is returned.
*/
uint32_t vm16_set_vm_as_str(vm16_t *C, uint32_t size_buffer, char *p_buffer);

/*
** Read memory block for debugging purposes / external drives
*/
uint32_t vm16_read_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer);

/*
** Write memory block from external drives / storage mediums
*/
uint32_t vm16_write_mem(vm16_t *C, uint16_t addr, uint16_t num, uint16_t *p_buffer);

/*
** Read memory block as ASCII string for storage purposes.
** `num` is the memory block size in words.
*/
uint32_t vm16_read_mem_as_str(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer);

/*
** Write memory block from ASCII string.
** `num` is the memory block size in words.
*/
uint32_t vm16_write_mem_as_str(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer);

/*
** Read memory block and convert the data to ASCII characters (screen memory)
*/
uint16_t vm16_read_ascii(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer);

/*
** Write ASCII string to VM memory (with char to word conversion)
*/
uint32_t vm16_write_ascii(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer);

/*
** Write ASCII string to VM memory (with two chars to one word (compact string)
*/
uint32_t vm16_write_ascii_16(vm16_t *C, uint16_t addr, uint16_t num, char *p_buffer);
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

/*
** Write H16 string to the VM memory.
*/
bool vm16_write_h16(vm16_t *C, char *s);

/*
** Return H16 string from VM memory data
** start_addr and size must be a multiple of 8!
*/
uint32_t vm16_read_h16(vm16_t *C, char *dest_buff, uint16_t start_addr, uint32_t size);

/*
** Return needed buffer size for the H16 string.
*/
uint32_t vm16_get_h16_buffer_size(vm16_t *C);

#endif
