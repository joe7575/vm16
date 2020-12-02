local vm16lib = require("vm16lib")
print(vm16lib.version())

local function hex(word) return string.format("%04X", word) end

local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..']=' .. dump(v) .. ', '
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

local function equals(o1, o2, ignore_mt)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}

    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or equals(value1, value2, ignore_mt) == false then
            return false
        end
        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then return false end
    end
    return true
end

print("Do some tests...")

for i = 1,10000 do

	local vm = vm16lib.init(1)
	print("vm = "..dump(vm))
	
	assert("mem_size", vm16lib.mem_size(vm) == 4096)

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
	assert(equals(tbl, {1,2,3,4}) == true)
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

	
	local s2 = vm16lib.read_h16(vm)
	vm16lib.write_h16(vm, s2)
	s2 = vm16lib.read_h16(vm)
	
	vm = nil

end

print("finished.")
