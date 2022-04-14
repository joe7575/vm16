--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Variables watch window for the debugger
]]--

vm16.watch = {}

local prog = vm16.prog
local CTYPE   = vm16.Asm.CTYPE
local LINENO  = vm16.Asm.LINENO
local CODESTR = vm16.Asm.CODESTR
local ADDRESS = vm16.Asm.ADDRESS
local OPCODES = vm16.Asm.OPCODES

local function var_address(cpu, offs, num_stack_var)
	-- Valid Base Pointer (before ret instruction)
	if cpu.SP <= cpu.BP or cpu.BP == 0 then
		return cpu.BP + offs
	else
		return cpu.SP + offs + num_stack_var
	end
end

local function get_string(data)
	local out = {}
	for i = 1, 8 do
		out[i] = prog.to_string(data[i] or 0)
	end
	return table.concat(out, "")
end

local function gen_varlist(pos, mem)
	local out = {}
	local cpu = vm16.get_cpu_reg(mem.cpu_pos)
	if cpu then
		-- Globals
		for _, item in ipairs(mem.lut:get_globals() or {}) do
			out[#out + 1] = item
		end
		for _, item in ipairs(mem.lut:get_file_locals(self.file_name) or {}) do
			out[#out + 1] = item
		end
		out[#out + 1] = {name = "", addr = 0}
		-- Locals
		local locals = mem.lut:get_locals(cpu.PC) or {}
		for var, offs in pairs(locals) do
			if var ~= "@nsv@" then
				local addr = var_address(cpu, offs, locals["@nsv@"])
				out[#out + 1] = {name = var, addr = addr, type = "local"}
			end
		end
	end
	return out
end

local function format_watch(pos, mem)
	local out = {}
	mem.watch_varlist = gen_varlist(pos, mem)
	for idx, item in ipairs(mem.watch_varlist) do
		if item.name == "" then
			out[#out + 1] = "----------------:----------"
		else
			local val = vm16.peek(mem.cpu_pos, item.addr)
			local s = minetest.formspec_escape(string.format("%-16s: %04X %d", item.name, val, val))
			out[#out + 1] = s
		end
	end
	return table.concat(out, ",")
end

local function memory_bar(pos, mem, x, y, xsize, ysize)
	local mem_size = vm16.mem_size(mem.cpu_pos)
	local cpu = vm16.get_cpu_reg(mem.cpu_pos)
	if mem_size and cpu and mem.lut then
		local x1 = x + xsize * (mem.lut:get_program_size() / mem_size)
		local x2 = x + xsize * ((cpu.TOS % mem_size) / mem_size)
		local x3 = x + xsize * 1.0
		return "label[" .. x .. "," .. (y + 0.4) .. ";Memory (" .. mem_size .. ")]" ..
			"box[" .. x  .. "," .. (y + 0.6) .. ";" .. (x1 - x)  .. "," .. 0.4 .. ";#00B]" ..
			"box[" .. x1 .. "," .. (y + 0.6) .. ";" .. (x2 - x1) .. "," .. 0.4 .. ";#AAA]" ..
			"box[" .. x2 .. "," .. (y + 0.6) .. ";" .. (x3 - x2) .. "," .. 0.4 .. ";#0B0]"
	end
	return ""
end

local function mem_dump(pos, mem, x, y, xsize, ysize, fontsize)
	mem.startaddr = mem.startaddr or 0
	local data = vm16.read_mem(mem.cpu_pos, mem.startaddr, 16)
	local item = mem.watch_varlist[mem.last_watch_idx]
	local str = get_string(data)
	local var
	if data and item and str then
		if mem.pointaddr then
			var = minetest.formspec_escape(string.format("'%s' => %04X = \"%s\"",  item.name, mem.pointaddr, str))
		else
			var = minetest.formspec_escape(string.format("'%s' at %04X = \"%s\"",  item.name, item.addr, str))
		end
		local lines = {"container[" .. x .. "," .. y .. "]" ..
			"style_type[textarea;font=mono;font_size="  .. fontsize .. "]" ..
			"image_button[4.9,0.1;0.5,0.5;vm16_arrow.png;watch_dec;]" ..
			"image_button[5.5,0.1;0.5,0.5;vm16_arrow.png^[transformR180;watch_inc;]" ..
			"label[0,0.4;" .. var .. "]" ..
			"box[0,0.6;" .. xsize .. "," .. (ysize - 0.6) .. ";#006]" ..
			"textarea[0,0.6;" .. (xsize + 0.4) .. "," .. (ysize - 0.6) .. ";;;"}

		if data then
			for i = 0,3 do
				local offs = i * 4
				table.insert(lines, string.format("%04X: %04X %04X %04X %04X",
					mem.startaddr + offs, data[1+offs], data[2+offs], data[3+offs], data[4+offs]))
				if i < 3 then
					table.insert(lines, "\n")
				end
			end
		else
			table.insert(lines, "Error")
		end
		table.insert(lines, "]")
		table.insert(lines, "container_end[]")
		return table.concat(lines, "")
	end
	return ""
end

function vm16.watch.init(pos, mem, obj)
end

function vm16.watch.fs_window(pos, mem, x, y, xsize, ysize, fontsize)
	local color = mem.running and "#AAA" or "#FFF"
	local y1, y2, y3, ysize1, ysize2, ysize3, dump
	if mem.last_watch_idx then
		ysize1 = ysize - 3.6
		ysize2 = 2.4
		ysize3 = 1
		y1 = y
		y2 = y + ysize - 3.4
		y3 = y + ysize - 1
		dump = mem_dump(pos, mem, x, y2, xsize, ysize2, fontsize)
	else
		ysize1 = ysize - 1
		ysize3 = 1
		y1 = y
		y3 = y + ysize - 1
		dump = ""
	end
	return "label[" .. x .. "," .. (y - 0.2) .. ";Variables]" ..
		"style_type[table;font=mono;font_size="  .. fontsize .. "]" ..
		"tableoptions[color=" ..color .. ";background=#033003;highlight_text=" ..color .. ";highlight=#036707]" ..
		"table[" .. x .. "," .. y1 .. ";" .. xsize .. "," .. ysize1 .. ";watch;" ..
		format_watch(pos, mem) .. ";]" ..
		dump ..
		memory_bar(pos, mem, x, y3, xsize, ysize3)
end

function vm16.watch.on_receive_fields(pos, fields, mem)
	if fields.watch then
		local evt = minetest.explode_table_event(fields.watch)
		if evt.type == "DCL" then
			local idx = tonumber(evt.row)
			local item = mem.watch_varlist[idx]
			if item then
				local addr = vm16.peek(mem.cpu_pos, item.addr)
				mem.last_watch_idx = idx
				mem.startaddr = addr
				mem.pointaddr = addr
			else
				mem.last_watch_idx = nil
				mem.startaddr = nil
			end
		elseif evt.type == "CHG" then
			local idx = tonumber(evt.row)
			local item = mem.watch_varlist[idx]
			if item and item.type == "global" and idx ~= mem.last_watch_idx then
				mem.last_watch_idx = idx
				mem.startaddr = item.addr
				mem.pointaddr = nil
			else
				mem.last_watch_idx = nil
				mem.startaddr = nil
			end
		end
	elseif fields.watch_inc then
		mem.startaddr = math.min(mem.startaddr + 8, (mem.mem_size or 64) - 8)
	elseif fields.watch_dec then
		mem.startaddr = math.max(mem.startaddr - 8, 0)
	end
end
