--[[
	vm16
	====

	Copyright (C) 2019-2020 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
	
	Wrapper to the C-lib and VM instance management
]]--

local vm16lib = ...
assert(vm16lib.version() == "2.2")

local VMList = {}
local storage = minetest.get_mod_storage()

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

vm16.CallResults = {[0]="OK", "NOP", "IN", "OUT", "SYS", "HALT", "BREAK", "ERROR"}

local SpecialCycles = {} -- for sys calls with reduced/increased cycles

local CYCLES = 10000  -- max CPU cycles / 100 ms 

vm16.version = vm16lib.version()
vm16.testbit = vm16lib.testbit

-- ram_size is from 1 (4K) to 16 (64KB)
function vm16.create(pos, ram_size)
	print("vm_create")
	local hash = minetest.hash_node_position(pos)
	VMList[hash] = vm16lib.init(ram_size)
	print(VMList[hash])
	
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
function vm16.read_h16(pos)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.read_h16(vm)
end

function vm16.run(pos, cycles)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	local resp = VM16_ERROR
	local ran
	
	cycles = math.min(cycles or CYCLES, CYCLES)
	
	while vm and cycles > 0 do
		resp, ran = vm16lib.run(vm, cycles)
		cycles = cycles - ran
		
		if resp == VM16_NOP then
			return VM16_NOP
		elseif resp == VM16_BREAK then
			local cpu = vm16lib.get_cpu_reg(vm) 
			vm16.on_update(pos, resp, cpu)
			return VM16_BREAK
		elseif resp == VM16_IN then
			local io = vm16lib.get_io_reg(vm)
			io.data = vm16.on_input(pos, io.addr) or 0xFFFF
			vm16lib.set_io_reg(vm, io)
			cycles = cycles - CYCLES/10
		elseif resp == VM16_OUT then
			local io = vm16lib.get_io_reg(vm)
			if vm16.on_output(pos, io.addr, io.data, io.B) then return resp end
			cycles = cycles - CYCLES/20
		elseif resp == VM16_SYS then
			local io = vm16lib.get_io_reg(vm)
			io.data = vm16.on_system(pos, io.addr, io.A, io.B) or 0xFFFF
			vm16lib.set_io_reg(vm, io)
			cycles = cycles - (SpecialCycles[io.addr] or CYCLES/10)
		elseif resp == VM16_HALT then
			local cpu = vm16lib.get_cpu_reg(vm) 
			vm16.on_update(pos, resp, cpu)
			return VM16_HALT
		elseif resp == VM16_ERROR then
			local cpu = vm16lib.get_cpu_reg(vm) 
			vm16.on_update(pos, resp, cpu)
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

local function remove_unloaded_vm()
	print("remove_unloaded_vms")
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
			vm16.on_unload(pos)
		end
	end
	print(cnt.." CPUs active")
	minetest.after(60, remove_unloaded_vm)
end	

minetest.after(60, remove_unloaded_vm)


local function debugging()
	for hash, _ in pairs(VMList) do
		local pos = minetest.get_position_from_hash(hash)
		print("CPU active at "..minetest.pos_to_string(pos))
	end
	minetest.after(10, debugging)
end	

--minetest.after(10, debugging)
