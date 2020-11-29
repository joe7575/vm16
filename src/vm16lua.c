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

#include <stdlib.h>
#include "lua.h"
#include "lauxlib.h"

#include "vm16.h"

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))


static void setfield(lua_State *L, const char *reg, int value) {
    lua_pushstring(L, reg);
    lua_pushnumber(L, (double)value);
    lua_settable(L, -3);
}

static void setstrfield(lua_State *L, const char *reg, const char *s) {
    lua_pushstring(L, reg);
    lua_pushstring(L, s);
    lua_settable(L, -3);
}

static vm16_t *check_vm(lua_State *L) {
    void *ud = luaL_checkudata(L, 1, "vm16.cpu_dump");
    luaL_argcheck(L, ud != NULL, 1, "'vm16 object' expected");
    return (vm16_t*)ud;
}
static int init(lua_State *L) {
    lua_Integer size = luaL_checkinteger(L, 1);
    uint32_t nbytes = vm16_calc_size(size);
    vm16_t *C = (vm16_t *)lua_newuserdata(L, nbytes);
    if((C != NULL) && vm16_init(C, nbytes)) {
        luaL_getmetatable(L, "vm16.cpu_dump");
        lua_setmetatable(L, -2);
        return 1;
    }
    lua_pop(L, 1);
    return 0;
}

static int mem_size(lua_State *L) {
    vm16_t *C = check_vm(L);
    lua_pushinteger(L, C->mem_size);
    return 1;
}

static int set_pc(lua_State *L) {
    vm16_t *C = check_vm(L);
    lua_Integer addr = luaL_checkinteger(L, 2);
    if(C != NULL) {
        vm16_set_pc(C, (uint16_t)addr);
        lua_pushboolean(L, 1);
        return 1;
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int get_pc(lua_State *L) {
    vm16_t *C = check_vm(L);
    uint16_t addr = vm16_get_pc(C);
    lua_pushinteger(L, addr);
    return 1;
}

static int deposit(lua_State *L) {
    vm16_t *C = check_vm(L);
    lua_Integer value = luaL_checkinteger(L, 2);
    if(C != NULL) {
        vm16_deposit(C, (uint16_t)value);
        lua_pushboolean(L, 1);
        return 1;
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int get_vm(lua_State *L) {
    vm16_t *C = check_vm(L);
    uint32_t size = vm16_real_size(C);
    if(size > 0) {
        void *p_data = malloc(size);
        if(p_data != NULL) {
            uint32_t bytes = vm16_get_vm(C, size, (uint8_t*)p_data);
            lua_pushlstring(L, (const char *)p_data, bytes);
            free(p_data);
            return 1;
        }
    }
    return 0;
}

static int set_vm(lua_State *L) {
    vm16_t *C = check_vm(L);
    if(lua_isstring(L, 2)) {
        size_t size;
        const void *p_data = lua_tolstring(L, 2, &size);
        uint32_t res = vm16_set_vm(C, size, (uint8_t*)p_data);
        lua_pop(L, 2);
        lua_pushboolean(L, size == res);
        return 1;
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int read_mem(lua_State *L) {
    vm16_t *C = check_vm(L);
    lua_Integer addr = luaL_checkinteger(L, 2);
    lua_Integer num = luaL_checkinteger(L, 3);
    uint16_t *p_data = (uint16_t*)malloc(num * 2);
    if((C != NULL) && (p_data != NULL) && (num > 0)) {
        uint16_t words = vm16_read_mem(C, addr, num, p_data);
        lua_newtable(L);
        for(int i = 0; i < words; i++) {
            lua_pushinteger(L, p_data[i]);
            lua_rawseti(L, -2, i+1);
        }
        free(p_data);
        return 1;
    }
    return 0;
}

static int write_mem(lua_State *L) {
    vm16_t *C = check_vm(L);
    uint16_t addr = (uint16_t)luaL_checkinteger(L, 2);
    if(lua_istable(L, 3)) {
        size_t num = lua_objlen(L, 3);
        uint16_t *p_data = (uint16_t*)malloc(num * 2);
        if((C != NULL) && (p_data != NULL)) {
            for(size_t i = 0; i < num; i++) {
                lua_rawgeti(L, -1, i+1);
                uint16_t value = luaL_checkinteger(L, -1);
                p_data[i] = value;
                lua_pop(L, 1);
            }
            uint16_t words = vm16_write_mem(C, addr, num, p_data);
            free(p_data);
            lua_pushinteger(L, words);
            return 1;
        }
    }
    return 0;
}

static int peek(lua_State *L) {
    vm16_t *C = check_vm(L);
    uint16_t addr = (uint16_t)luaL_checkinteger(L, 2);
    uint16_t val = vm16_peek(C, addr);
    lua_pushinteger(L, val);
    return 1;
}

static int poke(lua_State *L) {
    vm16_t *C = check_vm(L);
    uint16_t addr = (uint16_t)luaL_checkinteger(L, 2);
    uint16_t val = (uint16_t)luaL_checkinteger(L, 3);
    bool res = vm16_poke(C, addr, val);
    lua_pushboolean(L, res);
    return 1;
}

static int run(lua_State *L) {
    vm16_t *C = check_vm(L);
    lua_Integer cycles = luaL_checkinteger(L, 2);
    if(C != NULL) {
        uint32_t ran;
        int res = vm16_run(C, cycles, &ran);
        lua_pushinteger(L, res);
        lua_pushinteger(L, ran);
        return 2;
    }
    lua_pushinteger(L, -1);
    return 1;
}

static int get_cpu_reg(lua_State *L) {
    vm16_t *C = check_vm(L);
    if(C != NULL) {
        uint16_t mem[2];
        uint16_t words = vm16_read_mem(C, C->pcnt, 2, mem);
        if(words == 2) {
            lua_newtable(L);               /* creates a table */
            setfield(L, "A", C->areg);
            setfield(L, "B", C->breg);
            setfield(L, "C", C->creg);
            setfield(L, "D", C->dreg);
            setfield(L, "X", C->xreg);
            setfield(L, "Y", C->yreg);
            setfield(L, "PC", C->pcnt);
            setfield(L, "SP", C->sptr);
            setfield(L, "mem0", mem[0]);
            setfield(L, "mem1", mem[1]);
            return 1;
        }
    }
    return 0;
}

static int get_io_reg(lua_State *L) {
    vm16_t *C = check_vm(L);
    if(C != NULL) {
        lua_newtable(L);               /* creates a table */
        setfield(L, "A", C->areg);
        setfield(L, "B", C->breg);
        setfield(L, "addr", C->l_addr);
        setfield(L, "data", C->l_data);
        return 1;
    }
    return 0;
}

static int set_io_reg(lua_State *L) {
    vm16_t *C = check_vm(L);
    if(C != NULL) {
        lua_getfield(L, 2, "A");
        lua_getfield(L, 2, "B");
        lua_getfield(L, 2, "data");
        // stack now has following:
        //  2 = table
        // -3 = A
        // -2 = B
        // -1 = data
        C->areg = luaL_checkint(L, -3);
        C->breg = luaL_checkint(L, -2);
        *C->p_in_dest = luaL_checkint(L, -1);
        lua_settop(L, 0);
    }
    return 0;
}

/*
** Bit 0..15
*/
static int testbit(lua_State *L) {
    uint16_t val = (uint16_t)luaL_checkinteger(L, 1);
    uint16_t bit = (uint16_t)luaL_checkinteger(L, 2);

    lua_pushboolean(L, val & (1 << bit));
    return 1;
}

static const luaL_Reg R[] = {
    {"init",            init},
    {"mem_size",        mem_size},
    {"set_pc",          set_pc},
    {"get_pc",          get_pc},
    {"deposit",         deposit},
    {"get_vm",          get_vm},
    {"set_vm",          set_vm},
    {"read_mem",        read_mem},
    {"write_mem",       write_mem},
    {"peek",            peek},
    {"poke",            poke},
    {"get_cpu_reg",     get_cpu_reg},
    {"run",             run},
    {"get_io_reg",      get_io_reg},
    {"set_io_reg",      set_io_reg},
    {"testbit",         testbit},
    {NULL, NULL}
};

/* }====================================================== */



LUALIB_API int luaopen_vm16lib(lua_State *L) {
    luaL_newmetatable(L, "vm16.cpu_dump");
    luaL_register(L, NULL, R);
    return 1;
}
