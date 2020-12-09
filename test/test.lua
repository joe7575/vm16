local MP = '/home/joachim/Projekte/lua/minetest_unittest/lib'

core = {}

dofile(MP.."/chatcommands.lua")
dofile(MP.."/serialize.lua")
dofile(MP.."/misc_helpers.lua")
dofile(MP.."/misc.lua")
dofile(MP.."/vector.lua")
dofile(MP.."/meta.lua")

minetest = core
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local MP = "/home/joachim/minetest5/mods/vm16"
vm16 = {}
local vm16lib = require("vm16lib")
print(vm16lib.version())
assert(loadfile(MP.."/instances.lua"))(vm16lib)
dofile(MP.."/events.lua")
dofile(MP.."/lib.lua")

print("Do some tests...")

for i = 1,10 do

	local vm = vm16lib.init(1)
	assert(vm16lib.mem_size(vm) == 4096)

	assert(vm16lib.set_pc(vm, 0x1234) == true)
	assert(vm16lib.get_pc(vm) == 0x1234)

	assert(vm16lib.set_pc(vm, 0) == true)
	assert(vm16lib.deposit(vm, 1) == true)
	assert(vm16lib.deposit(vm, 2) == true)
	assert(vm16lib.deposit(vm, 3) == true)
	assert(vm16lib.deposit(vm, 4) == true)
	assert(vm16lib.get_pc(vm) == 4)

	local s = vm16lib.get_vm(vm)
	assert(#s == (8*1024 + 46) * 2)
	assert(vm16lib.set_vm(vm, s) == true)

	local tbl = vm16lib.read_mem(vm, 0 ,4)
	assert(table.equals(tbl, {1,2,3,4}) == true)
	assert(#vm16lib.read_mem(vm, 0 ,0x2345) == 0)
	assert(#vm16lib.read_mem(vm, 0x2345 ,10) == 10)

	assert(vm16lib.write_mem(vm, 0, tbl) == 4)
	assert(vm16lib.write_mem(vm, 0x2345, tbl) == 4)
	assert(vm16lib.write_mem(vm, 0, {}) == 0)
	assert(vm16lib.write_mem(vm, 0, "1234") == nil)

	assert(vm16lib.peek(vm, 0) == 1)
	assert(vm16lib.peek(vm, 1) == 2)
	assert(vm16lib.peek(vm, 2) == 3)
	assert(vm16lib.peek(vm, 3) == 4)
	assert(vm16lib.peek(vm, 0x0345) == 1)
	assert(vm16lib.peek(vm, 0x0346) == 2)
	assert(vm16lib.peek(vm, 0x0347) == 3)
	assert(vm16lib.peek(vm, 0x0348) == 4)
	assert(vm16lib.peek(vm, 0x2345) == 1)
	assert(vm16lib.peek(vm, 0x2346) == 2)
	assert(vm16lib.peek(vm, 0x2347) == 3)
	assert(vm16lib.peek(vm, 0x2348) == 4)

	assert(vm16lib.poke(vm, 0x2345, 0x1234) == true)
	assert(vm16lib.poke(vm, 0x2346, 0x55AA) == true)
	assert(vm16lib.poke(vm, 0x2347, 0xFFFF) == true)
	assert(vm16lib.poke(vm, 0x2348, 0xAFFE) == true)
	assert(vm16lib.peek(vm, 0x2345) == 0x1234)
	assert(vm16lib.peek(vm, 0x2346) == 0x55AA)
	assert(vm16lib.peek(vm, 0x2347) == 0xFFFF)
	assert(vm16lib.peek(vm, 0x2348) == 0xAFFE)

	assert(vm16lib.poke(vm, 100, 0x40) == true)
	assert(vm16lib.poke(vm, 101, 0x41) == true)
	assert(vm16lib.poke(vm, 102, 0x42) == true)
	assert(vm16lib.poke(vm, 103, 0x43) == true)
	assert(vm16lib.poke(vm, 104, 0) == true)
	
	print(vm16lib.read_ascii(vm, 100, 16))
	local s2 = vm16lib.read_h16(vm)
	vm16lib.write_h16(vm, s2)
	s2 = vm16lib.read_h16(vm)
	
	vm = nil
	
	assert(vm16lib.testbit(0x1000, 0) == false)
	assert(vm16lib.testbit(0x1000, 11) == false)
	assert(vm16lib.testbit(0x1000, 12) == true)
	assert(vm16lib.testbit(0x1000, 13) == false)
	
end

-------------------------------------------------------------------------------
-- real VM test
-------------------------------------------------------------------------------

local Code = {
	0x0000, 0x0000,  -- nop / nop
	0x6010, 0x0001,  -- in A, #1
	0x6600, 0x0002,  -- out #2, A
	0x6010, 0x0003,  -- in A, #3
	0x6600, 0x0004,  -- out #4, A
	0x1200, 0x0002,  -- jump, #2
}

local pos = {x=0, y=0, z=0}
local cnt = 0

local function on_input(pos, address)
	cnt = cnt + 1
	print("input", cnt)
	return address
end	

local function on_output(pos, address, value)
	cnt = cnt + 1
	print("output", cnt)
	return true
	--return false
end	

local function on_system(pos, address, val1, val2)
	return val1
end	

vm16.create(pos, 1)
vm16.register_callbacks(on_input, on_output, on_system)
vm16.write_mem(pos, 0, Code)
print(vm16.CallResults[vm16.run(pos)])  -- 1. nop
print(vm16.CallResults[vm16.run(pos)])  -- 2. no0p
print(vm16.CallResults[vm16.run(pos)])  -- in/out loop

local s2 = vm16.read_h16(pos)
print(s2, vm16.write_h16(pos, s2))

print("finished.")
