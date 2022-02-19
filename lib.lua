--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
]]--

-- Returns the number of operands (0,1) based on the given opcode
function vm16.num_operands(opcode)
	if opcode then 
		local idx1 = math.floor(opcode / 1024)
		local rest = opcode - (idx1 * 1024)
		local idx2 = math.floor(rest / 32)
		local idx3 = rest % 32
		return math.min((idx2 >= 16 and 1 or 0) + (idx3 >= 16 and 1 or 0), 1)
	end
	return 0
end

function vm16.hex2number(s)
	local addr = string.match (s or "0", "^([0-9a-fA-F]+)$")
	if not addr or addr == "" then addr = "0" end
	return (tonumber(addr, 16) % 0x10000) or 0
end

function vm16.set_breakpoint(pos, addr, num)
	local code = vm16.peek(pos, addr)
	vm16.poke(pos, addr, 0x0400 + num)
	return code
end
	
function vm16.breakpoint_step1(pos, addr, code)
	local val = vm16.peek(pos, addr)
	vm16.poke(pos, addr, code)
	vm16.set_pc(pos, addr)
	return val
end

function vm16.breakpoint_step2(pos, addr, val)
	vm16.run(pos, 1)
	vm16.poke(pos, addr, val)
end

function vm16.reset_breakpoint(pos, addr, code)
	vm16.poke(pos, addr, code)
end

