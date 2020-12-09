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

#define is_eol(c)             (((c) == '\n') || ((c) == '\r'))
#define is_hex(c)             ((((c) >= 'a') && ((c) <= 'f')) || (((c) >= 'A') && ((c) <= 'F')))
#define is_digit(c)           (((c) >= '0') && ((c) <= '9'))

#define LINELENGTH1           (2+4+2+8*4+2)
#define ENDOFFILE             ":00000FF\0"
#define LINELENGTH2           (strlen(ENDOFFILE) + 1)

/*
* Read `num_char` characters from the string `source_ptr` and return
* the uint16_t via `p_value`.
*/
static char *get_hex_value(char *source_ptr, uint16_t *p_value, int num_char)
{
    uint16_t val = 0;

    for(int i = 0; i < num_char; i++) {
        if(is_digit(source_ptr[i])) {
            val = (val * 16) + source_ptr[i] - (uint16_t)'0';
        }
        else if(is_hex(source_ptr[i])) {
            val = (val * 16) + (source_ptr[i] | 0x20) - (uint16_t)'a' + 10U;
        }
        else {
            val = 0xffff;
            break;
        }
    }

    *p_value = val;
    return &source_ptr[num_char];
}

/*
* Copy one line from `source_ptr` to `dest_buff`
*/
static char *get_next_line(char *source_ptr, char *dest_buff, int buff_size) {
    // read all characters until a newline is reached
    while(!is_eol(*source_ptr) && (*source_ptr != '\0') && (buff_size > 1)) {
        *dest_buff++ = *source_ptr++;
        buff_size--;
    }
    *dest_buff = 0;

    while(is_eol(*source_ptr)) {
        source_ptr++;
    }
    return source_ptr;
}

/*
* :n addr ty 1..8 words (4 chars each)
* -- ---- -- ------------------------------
* :4 aaaa 00 1111222233334444
* :8 aaaa 00 1nn12nn23nn34nn45nn56nn67nn78nn8
* :2 aaaa 00 n1n1n2n2
* :0 0000 FF
*
* n.. number of words (1..8)
* ty...type: 00=16-bit words in hex, FF=end of file
*/
static int parse_h16_line(vm16_t *C, char *s) {
    uint16_t num;
    uint16_t addr;
    uint16_t type;
    uint16_t buff[8];
    char *p = s;

    if(*p == ':') {
        p++;
        p = get_hex_value(p, &num, 1);
        p = get_hex_value(p, &addr, 4);
        p = get_hex_value(p, &type, 2);

        if(strlen(s) != (8 + num * 4)) {
            return -1; // error
        }
        if((type == 0) && (num > 0) && (num < 9) && (addr < 65636)) {
            for(int i = 0; i < num; i++) {
                p = get_hex_value(p, &buff[i], 4);
            }
            vm16_write_mem(C, addr, num, buff);
            return 1; // ok
        }
        else if((type == 0xff) && (num == 0) && (addr == 0)) {
            return 0; // eof
        }
    }
    return -1; // error
}

bool vm16_write_h16(vm16_t *C, char *s) {

  char buffer[50];
  char *p = s;
  int resp;

  do {
      p = get_next_line(p, buffer, 50);
      resp = parse_h16_line(C, buffer);
  } while((resp == 1) && (*p != '\0'));

  return resp == 0;
}

uint32_t vm16_read_h16(vm16_t *C, char *dest_buff, int buff_size) {
    bool is_zero;
    char *p = dest_buff;
    int num;

    for(uint16_t addr = 0; addr < C->mem_size; addr = addr + 8) {
        is_zero = true;
        for(uint16_t offs = 0; offs < 8; offs++) {
            if(C->memory[addr + offs] != 0) {
                is_zero = false;
            }
        }
        if(!is_zero && (buff_size > (LINELENGTH1 + LINELENGTH2))) {
            num = sprintf(p, ":8%04X00", addr);
            p = p + num;
            for(uint16_t offs = 0; offs < 8; offs++) {
                num = sprintf(p, "%04X", C->memory[addr + offs]);
                p = p + num;
            }
            *p++ = '\n';
            buff_size = buff_size - LINELENGTH1;
        }
    }
    strcpy(p, ENDOFFILE);
    p = p + LINELENGTH2;
    *p = '\0';
    return strlen(dest_buff);
}

uint32_t vm16_get_h16_buffer_size(vm16_t *C) {
    return (((uint32_t)(C->mem_size) / 8) * LINELENGTH1) + LINELENGTH2;
}

