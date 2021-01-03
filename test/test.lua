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
	s = vm16lib.read_ascii(vm, 100, 16)
	assert(vm16lib.write_ascii(vm, 100, s) == true)
	local s2 = vm16lib.read_h16(vm, 0, vm16lib.mem_size(vm))
	vm16lib.write_h16(vm, s2)
	s2 = vm16lib.read_h16(vm, 0, vm16lib.mem_size(vm))
	
	local cpu = vm16lib.get_cpu_reg(vm)
	cpu.A = 0x1111
	cpu.B = 0x2222
	cpu.C = 0x3333
	cpu.D = 0x4444
	cpu.X = 0x5555
	cpu.Y = 0x6666
	cpu.PC = 0x7777
	cpu.SP = 0x8888
	vm16lib.set_cpu_reg(vm, cpu)
	cpu = vm16lib.get_cpu_reg(vm)
	assert(cpu.A == 0x1111)
	assert(cpu.B == 0x2222)
	assert(cpu.C == 0x3333)
	assert(cpu.D == 0x4444)
	assert(cpu.X == 0x5555)
	assert(cpu.Y == 0x6666)
	assert(cpu.PC == 0x7777)
	assert(cpu.SP == 0x8888)
	
-------------------------------------------------------------------------------
-- test word chars
-------------------------------------------------------------------------------

	vm16lib.poke(vm, 0x0100, 0x4861) -- 'Ha'
	vm16lib.poke(vm, 0x0101, 0x6C6C) -- 'll'
	vm16lib.poke(vm, 0x0102, 0x006F) -- 'o'
	vm16lib.poke(vm, 0x0103, 0x0000) -- '\0'
	print(vm16lib.read_ascii(vm, 0x0100, 6))
	print(vm16lib.read_ascii(vm, 0x0100, 5))
	print(vm16lib.read_ascii(vm, 0x0100, 4))

	vm = nil
	
	assert(vm16lib.testbit(0x1000, 0) == false)
	assert(vm16lib.testbit(0x1000, 11) == false)
	assert(vm16lib.testbit(0x1000, 12) == true)
	assert(vm16lib.testbit(0x1000, 13) == false)
	
	assert(vm16lib.is_ascii("Hallo joe") == true);
	assert(vm16lib.is_ascii("\0Hallo joe") == false);
	assert(vm16lib.is_ascii({}) == false);
	
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
	0x0800, 0x0802,  -- sys #0 / sys #2 (A=3)
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
	print("on_system", address, val1, val2)
	return 0x55
end	

vm16.create(pos, 1)
vm16.register_callbacks(on_input, on_output, on_system)
vm16.write_mem(pos, 0, Code)
print(vm16.CallResults[vm16.run(pos)])  -- 1. nop
print(vm16.CallResults[vm16.run(pos)])  -- 2. nop
print(vm16.CallResults[vm16.run(pos)])  -- in/out loop
print(vm16.CallResults[vm16.run(pos)])  -- in/out loop
print(vm16.CallResults[vm16.run(pos)])  -- sys loop

local s2 = vm16.read_h16(pos)
print(s2, vm16.write_h16(pos, s2))

-- illegal opcode
vm16.write_mem(pos, 0, {0xff00, 0xff00, 0xff00, 0xff00})
assert(vm16.set_pc(pos, 0) == true)
assert(vm16.run(pos) == vm16.ERROR)

-------------------------------------------------------------------------------
-- Breakpoint test
-------------------------------------------------------------------------------

Code = {
	0x1200, 0x0002,  -- jump, #2
	0x1200, 0x0004,  -- jump, #4
	0x1200, 0x0006,  -- jump, #6
	0x1200, 0x0000,  -- jump, #0
}

local function hexdump(tbl)
	local t = {}
	for i,val in ipairs(tbl) do
		t[i] = string.format("%04X", val)
	end
	print(table.concat(t, " "))
end
		
vm16.write_mem(pos, 0, Code)
local s = vm16.read_mem_bin(pos, 0, 8)
assert(#s == 16)
vm16.write_mem_bin(pos, 0, s)

assert(vm16.set_pc(pos, 0) == true)
assert(vm16.run(pos, 100) == vm16.OK)
hexdump(vm16.read_mem(pos, 0, 8))

local opc = vm16.set_breakpoint(pos, 4, 1)
assert(vm16.run(pos, 8) == vm16.BREAK)
assert(vm16.get_pc(pos) == 5)
local val = vm16.breakpoint_step1(pos, 4, opc)
assert(vm16.get_pc(pos) == 4)
vm16.breakpoint_step2(pos, 4, val)
hexdump(vm16.read_mem(pos, 0, 8))

vm16.reset_breakpoint(pos, 4, opc)
hexdump(vm16.read_mem(pos, 0, 8))
assert(vm16.run(pos, 100) == vm16.OK)



print("finished.")
