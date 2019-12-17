--[[
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
]]--

-- for lazy programmers
local M = minetest.get_meta

vm16 = {}

local VM16_OK     = 0  -- run to the end
local VM16_DELAY  = 1  -- one cycle pause
local VM16_IN     = 2  -- input command
local VM16_OUT    = 3  -- output command
local VM16_SYS    = 4  -- system call
local VM16_HALT   = 5  -- CPU halt
local VM16_ERROR  = 6  -- invalid call

vm16.OK     = VM16_OK
vm16.DELAY  = VM16_DELAY
vm16.IN     = VM16_IN
vm16.OUT    = VM16_OUT
vm16.SYS    = VM16_SYS
vm16.HALT   = VM16_HALT
vm16.ERROR  = VM16_ERROR

local CREDIT = 100

-- ram_size is one of 12 (4K), 13 (8K), 14 (16K), 15 (32KB), or 16 (64KB)
function vm16.create(pos, ram_size)
	local meta = M(pos)
	meta:set_string("vm16", "")
	meta:set_int("vm16size", ram_size)
	meta:mark_as_private("vm16")
	return vm16lib.create(ram_size)
end

function vm16.destroy(vm, pos)
	vm = nil
	M(pos):set_string("vm16", "")
end

-- Reset registers and memory
-- returns true/false
function vm16.clear(vm)
	return vm16lib.clear(vm)
end	
	
-- Load PC of the VM with the given 16-bit address
-- returns true/false
function vm16.loadaddr(vm, addr)
	return vm16lib.loadaddr(vm, addr)
end	

-- Store the given value in the memory cell where the PC points to
-- and post-increment the PC.
-- returns true/false
function vm16.deposit(vm, value)
	return vm16lib.deposit(vm, value)
end	
	
-- Read the memory cell where the PC points to
-- and post-increment the PC.
-- returns the read value
function vm16.examine(vm)
	return vm16lib.examine(vm)
end	

-- Read 'num' memory values starting at the given 'addr'.
-- returns an table/array with the read values
function vm16.read_mem(vm, addr, num)
	return vm16lib.read_mem(vm, addr, num)
end	

-- Write the values of 'tbl' into the memory starting at the given 'addr'.
-- returns an array with the read values
function vm16.write_mem(vm, addr, tbl)
	return vm16lib.write_mem(vm, addr, tbl)
end	

-- Return the complete register set as table with the keys A, B, C, D, X, Y, PC, SP, 
-- plua 4 memory cells mem0 to mem3 (the PC points to mem0)
function vm16.get_cpu_reg(vm, addr, tbl)
	return vm16lib.get_cpu_reg(vm, addr, tbl)
end	

-- Test if the 'bit' number (0..15) is set in value
-- returns true/false
function vm16.testbit(value, bit)
	return vm16lib.testbit(value, bit)
end	

-- Call the VM 
-- cycles are machine cycles (e.g. 10000) per call
-- input  is a callback of type: u16_result, points = func(vm, pos, u16_addr)
-- output is a callback of type: u16_result, points = func(vm, pos, u16_addr, u16_value)
-- system is a callback of type: u16_result, points = func(vm, pos, u16_num, u16_value)
function vm16.run(vm, pos, cycles, input, output, system)
	local credit = CREDIT
	local resp, ran
	while credit > 0 and cycles > 0 do
		resp, ran = vm16lib.run(vm, cycles)
		if resp == VM16_IN then
			local evt = vm16lib.get_event(vm, resp)
			local result, points = input(vm, pos, evt.addr)
			vm16lib.event_response(vm, resp, result or 0xFFFF)
			credit = credit - (points or CREDIT)
		elseif resp == VM16_OUT then
			local evt = vm16lib.get_event(vm, resp)
			local result, points = output(vm, pos, evt.addr, evt.data)
			vm16lib.event_response(vm, resp, result or 0xFFFF)
			credit = credit - (points or CREDIT)
		elseif resp == VM16_SYS then
			local evt = vm16lib.get_event(vm, resp)
			local result, points = system(vm, pos, evt.addr, evt.data)
			vm16lib.event_response(vm, resp, result or 0xFFFF)
			credit = credit - (points or CREDIT)
		else
			return resp
		end
		cycles = cycles - ran
	end
	return resp
end

-- Store the complete VM as node meta data
function vm16.vm_store(vm, pos)
	local s = vm16lib.get_vm(vm)
	M(pos):set_string("vm16", s)
	M(pos):mark_as_private("vm16")
end

-- Restore the complete VM from the node meta data
function vm16.vm_restore(pos)
	local meta = M(pos)
	local s = meta:get_string("vm16")
	local size = meta:get_int("vm16size")
	if s ~= "" and size > 0 then
		local vm = vm16lib.create(size)
		if vm then
			vm16lib.set_vm(vm, s)
			return vm
		end
	end
end
