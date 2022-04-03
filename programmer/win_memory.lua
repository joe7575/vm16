--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Memory, register, and stack dump windows for the debugger
]]--

-- for lazy programmers
local M = minetest.get_meta

vm16.memory = {}

local function new_table(size)
	local out = {}
	for i = 1, size do
		out[i] = 0
	end
	return out
end

local function mem_dump(pos, mem, x, y)
	mem.startaddr = mem.startaddr or 0
	local data = vm16.read_mem(mem.cpu_pos, mem.startaddr, 128) or new_table(128)
	local lines = {"container[" .. x .. "," .. y .. "]" ..
		"label[0,0.5;Memory]" ..
		"button[2,0.1;1,0.6;dec;" .. minetest.formspec_escape("<") .. "]" ..
		"button[3,0.1;1,0.6;inc;" .. minetest.formspec_escape(">") .. "]" ..
		"box[0,0.7;9,6.6;#006]" ..
		"textarea[0,0.7;9.6,7;;;"}

	if data then
		for i = 0,15 do
			local offs = i * 8
			table.insert(lines, string.format("%04X: %04X %04X %04X %04X %04X %04X %04X %04X\n",
				mem.startaddr+offs, data[1+offs], data[2+offs], data[3+offs], data[4+offs],
				data[5+offs], data[6+offs], data[7+offs], data[8+offs]))
		end
	else
		table.insert(lines, "Error")
	end
	table.insert(lines, "]")
	table.insert(lines, "container_end[]")
	return table.concat(lines, "")
end

local function stack_dump(pos, mem, x, y)
	local stack_addr = (mem.mem_size or 64) - 8
	local data = vm16.read_mem(mem.cpu_pos, stack_addr, 8) or new_table(8)
	local lines = {"container[" .. x .. "," .. y .. "]" ..
		"box[0,0;9,0.4;#606]" ..
		"textarea[0,0;9.6,1;;Stack Area;"}

	if data then
		table.insert(lines, string.format("%04X: %04X %04X %04X %04X %04X %04X %04X %04X\n",
			stack_addr, data[1], data[2], data[3], data[4], data[5], data[6], data[7], data[8]))
	else
		table.insert(lines, "Error")
	end
	table.insert(lines, "]")
	table.insert(lines, "container_end[]")
	return table.concat(lines, "")
end

local function reg_dump(pos, mem, x, y)
	local cpu = vm16.get_cpu_reg(mem.cpu_pos) or {A=0, B=0, C=0, D=0, X=0, Y=0, SP=0, PC=0, BP=0}
	return "box[8.8,0.6;9,0.8;#060]" ..
		"label[8.8,0.4;Registers]" ..
		"textarea[8.8,0.6;9.6,0.8;;;" ..
		" A    B    C    D     X    Y    PC   SP\n" ..
		string.format("%04X %04X %04X %04X", cpu.A, cpu.B, cpu.C, cpu.D) .. "  " ..
		string.format("%04X %04X %04X %04X", cpu.X, cpu.Y, cpu.PC, cpu.SP) .. "]"
end

function vm16.memory.init(pos, mem)

end

function vm16.memory.fs_window(pos, mem, x, y, xsize, ysize, fontsize)
	local color = mem.running and "#AAA" or "#FFF"
	return "style_type[textarea;font=mono;textcolor=" .. color .. ";border=false;font_size="  .. fontsize .. "]" ..
		reg_dump(pos, mem, x, 0.6) ..
		mem_dump(pos, mem, x, 1.7) ..
		stack_dump(pos, mem, x, 9.8)
end
