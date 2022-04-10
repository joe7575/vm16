--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	vm16 API
]]--

local vm16lib = ...
if vm16lib.version() ~= "2.6.5" then
	minetest.log("error", "[vm16] Install Lua library v2.6.4 (see readme.md)!")
end

local M = minetest.get_meta
local VMList = {}
local storage = minetest.get_mod_storage()

-------------------------------------------------------------------------------
local VERSION     = 3.3  -- See readme.md
-------------------------------------------------------------------------------
local VM16_OK     = 0  -- run to the end
local VM16_NOP    = 1  -- nop command
local VM16_IN     = 2  -- input command
local VM16_OUT    = 3  -- output command
local VM16_SYS    = 4  -- system call
local VM16_HALT   = 5  -- CPU halt
local VM16_BREAK  = 6  -- breakpoint
local VM16_ERROR  = 7  -- invalid call

vm16.OK     = VM16_OK
vm16.NOP    = VM16_NOP
vm16.IN     = VM16_IN
vm16.OUT    = VM16_OUT
vm16.SYS    = VM16_SYS
vm16.HALT   = VM16_HALT
vm16.BREAK  = VM16_BREAK
vm16.ERROR  = VM16_ERROR
vm16.version  = VERSION
vm16.testbit  = vm16lib.testbit
vm16.is_ascii = vm16lib.is_ascii
vm16.CallResults = {[0]="OK", "NOP", "IN", "OUT", "SYS", "HALT", "BREAK", "ERROR"}

local SpecialCycles = {} -- for sys calls with reduced/increased cycles

local function store_breakpoint_addr(pos, vm, breakpoints)
	local addr = vm16lib.get_pc(vm)
	if breakpoints then
		breakpoints.address = addr
		if breakpoints[addr] then
			vm16lib.poke(vm, addr, breakpoints[addr])
		end
	end
end

local function skip_break_instr(pos, vm, cpu_def, breakpoints)
	local addr = vm16lib.get_pc(vm)
	if breakpoints then
		if breakpoints.address == addr then
			if breakpoints[addr] then
				vm16.run(pos, cpu_def, nil, 1)
				vm16lib.poke(vm, addr, 0x0400)
				breakpoints.address = nil
				return true
			else
				vm16lib.set_pc(vm, addr + 1)
				breakpoints.address = nil
				return true
			end
		end
		breakpoints.address = nil
	end
end

function vm16.set_breakpoint(pos, addr, breakpoints)
	if breakpoints then
		breakpoints[addr] = vm16.peek(pos, addr)
		vm16.poke(pos, addr, 0x0400)
	end
end

function vm16.reset_breakpoint(pos, addr, breakpoints)
	if breakpoints and breakpoints[addr] then
		breakpoints.address = nil
		vm16.poke(pos, addr, breakpoints[addr])
		return true
	end
end

-- ram_size is from 0 for 64 words, 1 for 128 words, up to 10 for 64 Kwords
function vm16.create(pos, ram_size)
	print("vm_create")
	local hash = minetest.hash_node_position(pos)
	VMList[hash] = vm16lib.init(ram_size)
	local meta = minetest.get_meta(pos)
	meta:set_string("vm16", "")
	meta:set_int("vm16size", ram_size)
	meta:mark_as_private("vm16")
	return VMList[hash] ~= nil
end

function vm16.destroy(pos)
	print("vm_destroy")
	minetest.get_meta(pos):set_string("vm16", "")
	local hash = minetest.hash_node_position(pos)
	VMList[hash] = nil
end

function vm16.is_loaded(pos)
	local hash = minetest.hash_node_position(pos)
	return VMList[hash] ~= nil
end

-- move VM from storage string to active
function vm16.vm_restore(pos)
	print("vm_restore")
	local meta = minetest.get_meta(pos)
	local hash = minetest.hash_node_position(pos)
	if not VMList[hash] then
		local s = storage:get_string(hash)
		local size = meta:get_int("vm16size")
		if s ~= "" and size > 0 then
			VMList[hash] = vm16lib.init(size)
			vm16lib.set_vm(VMList[hash], s)
		end
	end
end

-- move VM from active to storage string
local function vm_store(pos, vm)
	print("vm_store")
	local hash = minetest.hash_node_position(pos)
	local s = vm16lib.get_vm(vm)
	storage:set_string(hash, s)
end

function vm16.on_power_on(pos, ram_size)
	print("on_power_on")
	if not vm16.is_loaded(pos) then
		if vm16.create(pos, ram_size) then
			return true
		end
	end
end

function vm16.on_power_off(pos)
	print("on_power_off")
	if vm16.is_loaded(pos) then
		vm16.destroy(pos)
		return true
	end
end

function vm16.on_load(pos)
	print("on_load")
	if not vm16.is_loaded(pos) then
		vm16.vm_restore(pos)
		return true
	end
end

-- returns size in words
function vm16.mem_size(pos)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.mem_size(vm)
end

-- load PC with given address
function vm16.set_pc(pos, addr)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.set_pc(vm, addr)
end

function vm16.get_pc(pos)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.get_pc(vm)
end

function vm16.deposit(pos, value)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.deposit(vm, value)
end

function vm16.read_mem(pos, addr, num)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.read_mem(vm, addr, num)
end

function vm16.write_mem(pos, addr, tbl)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.write_mem(vm, addr, tbl)
end

function vm16.read_mem_bin(pos, addr, num)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.read_mem_bin(vm, addr, num)
end

function vm16.write_mem_bin(pos, addr, s)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.write_mem_bin(vm, addr, s)
end

function vm16.read_ascii(pos, addr, num)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.read_ascii(vm, addr, num)
end

function vm16.write_ascii(pos, addr, s)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.write_ascii(vm, addr, s)
end

function vm16.peek(pos, addr)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.peek(vm, addr)
end

function vm16.poke(pos, addr, val)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.poke(vm, addr, val)
end

function vm16.get_cpu_reg(pos)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.get_cpu_reg(vm)
end

function vm16.set_cpu_reg(pos, regs)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.set_cpu_reg(vm, regs)
end

function vm16.get_io_reg(pos)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.get_io_reg(vm)
end

function vm16.set_io_reg(pos, io)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.set_io_reg(vm, io)
end

-- Write H16 string to VM memory
function vm16.write_h16(pos, s)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.write_h16(vm, s)
end

-- Generate H16 string from VM memory
function vm16.read_h16(pos, start_addr, size)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	start_addr = start_addr or 0
	size = size or vm16lib.mem_size(vm)
	return vm and vm16lib.read_h16(vm, start_addr, size)
end

function vm16.run(pos, cpu_def, breakpoints, steps)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	local resp = VM16_ERROR
	local ran

	local cycles = steps or cpu_def.instr_per_cycle
	if skip_break_instr(pos, vm, cpu_def, breakpoints) then
		return VM16_OK
	end

	while vm and cycles > 0 do
		resp, ran = vm16lib.run(vm, cycles)
		cycles = cycles - ran

		if resp == VM16_NOP then
			return VM16_NOP
		elseif resp == VM16_BREAK then
			store_breakpoint_addr(pos, vm, breakpoints)
			local cpu = vm16lib.get_cpu_reg(vm)
			cpu_def.on_update(pos, resp, cpu)
			return VM16_BREAK
		elseif resp == VM16_IN then
			local io = vm16lib.get_io_reg(vm)
			io.data = cpu_def.on_input(pos, io.addr) or 0xFFFF
			vm16lib.set_io_reg(vm, io)
			cycles = cycles - cpu_def.input_costs
		elseif resp == VM16_OUT then
			local io = vm16lib.get_io_reg(vm)
			local costs = cpu_def.on_output(pos, io.addr, io.data, io.B)
			cycles = cycles - (costs or cpu_def.output_costs)
		elseif resp == VM16_SYS then
			local io = vm16lib.get_io_reg(vm)
			io.data = cpu_def.on_system(pos, io.addr, io.A, io.B) or 0xFFFF
			vm16lib.set_io_reg(vm, io)
			cycles = cycles - (SpecialCycles[io.addr] or cpu_def.system_costs)
		elseif resp == VM16_HALT then
			local cpu = vm16lib.get_cpu_reg(vm)
			cpu_def.on_update(pos, resp, cpu)
			return VM16_HALT
		elseif resp == VM16_ERROR then
			local cpu = vm16lib.get_cpu_reg(vm)
			cpu_def.on_update(pos, resp, cpu)
			return VM16_ERROR
		end
	end
	return resp
end

function vm16.register_sys_cycles(address, cycles)
	SpecialCycles[address] = cycles
end

minetest.register_on_shutdown(function()
	print("register_on_shutdown2")
	for hash, vm in pairs(VMList) do
		local pos = minetest.get_position_from_hash(hash)
		vm_store(pos, vm)
	end
	print("done")
end)

local function remove_unloaded_vms()
	local tbl = table.copy(VMList)
	local cnt = 0
	VMList = {}
	for hash, vm in pairs(tbl) do
		local pos = minetest.get_position_from_hash(hash)
		if minetest.get_node_or_nil(pos) then
			VMList[hash] = vm
			cnt = cnt + 1
		else
			vm_store(pos, vm)
		end
	end
	minetest.after(60, remove_unloaded_vms)
end

minetest.after(60, remove_unloaded_vms)
