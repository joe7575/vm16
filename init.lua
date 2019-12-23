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

vm16 = vm16lib		-- rename the lib


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

-- ram_size is from 1 (4K) to 16 (64KB)
function vm16.create(pos, ram_size)
	local meta = M(pos)
	meta:set_string("vm16", "")
	meta:set_int("vm16size", ram_size)
	meta:mark_as_private("vm16")
	return vm16.init(ram_size)
end

function vm16.destroy(vm, pos)
	vm = nil
	M(pos):set_string("vm16", "")
end


function vm16.call(vm, pos, cycles, input, output, system)
	local credit = CREDIT
	local resp, ran
	while credit > 0 and cycles > 0 do
		resp, ran = vm16.run(vm, cycles)
		if resp == VM16_IN then
			local evt = vm16.get_event(vm, resp)
			local result, points = input(vm, pos, evt.addr)
			vm16.event_response(vm, resp, result or 0xFFFF)
			credit = credit - (points or CREDIT)
		elseif resp == VM16_OUT then
			local evt = vm16.get_event(vm, resp)
			local result, points = output(vm, pos, evt.addr, evt.data)
			vm16.event_response(vm, resp, result or 0xFFFF)
			credit = credit - (points or CREDIT)
		elseif resp == VM16_SYS then
			local evt = vm16.get_event(vm, resp)
			print("VM16_SYS", dump(evt))
			local resA, resB, points = system(vm, pos, evt.addr, evt.A, evt.B)
			vm16.event_response(vm, resp, resA or 0xFFFF, resB or evt.B)
			credit = credit - (points or CREDIT)
		else
			return resp
		end
		cycles = cycles - ran
	end
	return resp
end

function vm16.vm_store(vm, pos)
	local s = vm16.get_vm(vm)
	M(pos):set_string("vm16", s)
	M(pos):mark_as_private("vm16")
end

function vm16.vm_restore(pos)
	local meta = M(pos)
	local s = meta:get_string("vm16")
	local size = meta:get_int("vm16size")
	if s ~= "" and size > 0 then
		local vm = vm16.init(size)
		if vm then
			vm16.set_vm(vm, s)
			vm16.init_mem_banks(vm)
			return vm
		end
	end
end
