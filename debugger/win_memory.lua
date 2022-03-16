--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Memory, register, and stack dump windows for the debugger
]]--

vm16.memory = {}

local function new_table(size)
	local out = {}
	for i = 1, size do
		out[i] = 0
	end
	return out
end

function vm16.memory.mem_dump(pos, x, y)
	local addr = M(pos):get_int("startaddr")
	local mem = vm16.read_mem(pos, addr, 128) or new_table(128)
	local lines = {"container[" .. x .. "," .. y .. "]" ..
		"label[0,0.5;Memory]" ..
		"button[2,0.1;1,0.6;dec;" .. minetest.formspec_escape("<") .. "]" ..
		"button[3,0.1;1,0.6;inc;" .. minetest.formspec_escape(">") .. "]" ..
		"box[0,0.7;9,6.6;#006]" ..
		"textarea[0,0.7;9.6,7;;;"}

	if mem then
		for i = 0,15 do
			local offs = i * 8
			table.insert(lines, string.format("%04X: %04X %04X %04X %04X %04X %04X %04X %04X\n",
				addr+offs, mem[1+offs], mem[2+offs], mem[3+offs], mem[4+offs],
				mem[5+offs], mem[6+offs], mem[7+offs], mem[8+offs]))
		end
	else
		table.insert(lines, "Error")
	end
	table.insert(lines, "]")
	table.insert(lines, "container_end[]")
	return table.concat(lines, "")
end

function vm16.memory.stack_dump(pos, x, y)
	local mem = vm16.read_mem(pos, 0x1F8, 8) or new_table(8)
	local lines = {"container[" .. x .. "," .. y .. "]" ..
		"box[0,0;9,0.4;#606]" ..
		"textarea[0,0;9.6,1;;Stack Area;"}

	if mem then
		table.insert(lines, string.format("%04X: %04X %04X %04X %04X %04X %04X %04X %04X\n",
			0x1F8, mem[1], mem[2], mem[3], mem[4], mem[5], mem[6], mem[7], mem[8]))
	else
		table.insert(lines, "Error")
	end
	table.insert(lines, "]")
	table.insert(lines, "container_end[]")
	return table.concat(lines, "")
end

function vm16.memory.reg_dump(pos, x, y)
	local lines = {"container[" .. x .. "," .. y .. "]"}
	local cpu = vm16.get_cpu_reg(pos) or {A=0, B=0, C=0, D=0, X=0, Y=0, SP=0, PC=0, BP=0}
	table.insert(lines, "box[0,0;9,0.8;#060]")
	table.insert(lines, "textarea[0,0;9.6,0.8;;Registers;")
	table.insert(lines, " A    B    C    D     X    Y    PC   SP   BP\n")
	table.insert(lines, string.format("%04X %04X %04X %04X", cpu.A, cpu.B, cpu.C, cpu.D) .. "  " ..
		string.format("%04X %04X %04X %04X %04X", cpu.X, cpu.Y, cpu.PC, cpu.SP, cpu.BP))
	table.insert(lines, "]")
	table.insert(lines, "container_end[]")
	return table.concat(lines, "")
end

