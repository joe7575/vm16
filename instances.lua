--[[
	vm16
	====

	Copyright (C) 2019-2020 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
	
	Wrapper to the C-lib and VM instance management
]]--

local vm16lib = ...
local VMList = {}
local storage = minetest.get_mod_storage()

local VM16_OK     = 0  -- run to the end
local VM16_NOP    = 1  -- nop command
local VM16_IN     = 2  -- input command
local VM16_OUT    = 3  -- output command
local VM16_SYS    = 4  -- system call
local VM16_HALT   = 5  -- CPU halt
local VM16_ERROR  = 6  -- invalid call

vm16.OK     = VM16_OK
vm16.NOP    = VM16_NOP
vm16.IN     = VM16_IN
vm16.OUT    = VM16_OUT
vm16.SYS    = VM16_SYS
vm16.HALT   = VM16_HALT
vm16.ERROR  = VM16_ERROR

vm16.CallResults = {[0]="OK", "NOP", "IN", "OUT", "SYS", "HALT", "ERROR"}

local CYCLES = 10000  -- max CPU cycles / 100 ms 

vm16.AsmHelp = [[## VM16 Instruction Set ##
0000            nop
1C00            halt
0800            sys  0
2010, 0123      move A, #$123
2030, 0123      move B, #$123
2090, 0123      move X, #$123
20B0, 0123      move Y, #$123
2011, 0123      move A, $123
2031, 0123      move B, $123
2091, 0123      move X, $123
20B1, 0123      move Y, $123
2001            move A, B
2001            move A, B
2008            move A, [X]
2009            move A, [Y]
2028            move B, [X]
2029            move B, [Y]
2401            xchg A, B
2880            inc  X
28A0            inc  Y
3001            add  A, B
3010, 0002      add  A, #2
3401            sub  A, B
3410, 0003      sub  A, #3
3801            mul  A, B
3810, 0004      mul  A, #4
3C01            div  A, B
3C10, 0005      div  A, #5
4001            and  A, B
4010, 0006      and  A, #6
4401            or   A, B
4410, 0007      or   A, #7
4801            xor  A, B
4810, 0008      xor  A, #8
1200, 0100      jump $100
1600, 0100      call $100
1800            ret
5010, 0100      bnze A, $100
5410, 0100      bze  A, $100
5810, 0100      bpos A, $100
5C10, 0100      bneg A, $100
6010, 0002      in   A, #2
6600, 0003      out  #3, A
]]

vm16.AsmHelp = vm16.AsmHelp:gsub(",", "\\,")
vm16.AsmHelp = vm16.AsmHelp:gsub("\n", ",")
vm16.AsmHelp = vm16.AsmHelp:gsub("%[", "\\%[")
vm16.AsmHelp = vm16.AsmHelp:gsub("%]", "\\%]")


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

function vm16.peek(pos, addr)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.peek(vm, addr)
end

function vm16.poke(pos, addr)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.poke(vm, addr)
end

function vm16.get_cpu_reg(pos, addr)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.get_cpu_reg(vm, addr)
end

function vm16.get_io_reg(pos, addr)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.get_io_reg(vm, addr)
end

function vm16.set_io_reg(pos, addr)
	local hash = minetest.hash_node_position(pos)
	local vm = VMList[hash]
	return vm and vm16lib.set_io_reg(vm, addr)
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
	
	if vm then
		resp = vm16lib.run(vm, math.min(cycles, CYCLES))

		if resp == VM16_IN then
			local io = vm16lib.get_io_reg(vm)
			io.data = vm16.on_input(pos, io.addr) or 0xFFFF
			vm16lib.set_io_reg(vm, io)
		elseif resp == VM16_OUT then
			local io = vm16lib.get_io_reg(vm)
			vm16.on_output(pos, io.addr, io.data)
		elseif resp == VM16_SYS then
			local io = vm16lib.get_io_reg(vm)
			io.A = vm16.on_system(pos, io.addr, io.A, io.B) or 0xFFFF
			vm16lib.set_io_reg(vm, io)
		elseif resp == VM16_HALT then
			local cpu = vm16lib.get_cpu_reg(vm) 
			vm16.on_update(pos, resp, cpu)
		end
	end
	return resp
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

minetest.after(10, debugging)