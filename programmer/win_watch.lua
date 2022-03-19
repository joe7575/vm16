--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Variables watch window for the debugger
]]--

vm16.watch = {}

local function var_address(cpu, offs, num_stack_var)
	-- Valid Base Pointer (before ret instruction)
	if cpu.SP <= cpu.BP or cpu.BP == 0 then
		return cpu.BP + offs
	else
		return cpu.SP + offs + num_stack_var
	end
end

local function format_watch(pos, mem)
	local out = {}
	local cpu = vm16.get_cpu_reg(mem.cpu_pos)
	if cpu and mem.tFunctions and mem.tLocals then
		-- Globals
		for _, var in ipairs(mem.lVars or {}) do
			local s = string.format("%-16s: %d", var, vm16.peek(mem.cpu_pos, mem.tGlobals[var] or 0))
			out[#out + 1] = s
		end
		out[#out + 1] = "----------------:------"
		-- Locals
		local funcname = mem.tFunctions[mem.curr_lineno or 1] or ""
		local t = mem.tLocals[funcname] or {}
		for var, offs in pairs(t) do
			if var ~= "@nsv@" then
				local addr = var_address(cpu, offs, t["@nsv@"])
				local s = string.format("%-16s: %d", var, vm16.peek(mem.cpu_pos, addr))
				out[#out + 1] = s
			end
		end
	end
	return table.concat(out, ",")
end

local function memory_bar(pos, mem, x, y, xsize, ysize)
	local mem_size = vm16.mem_size(mem.cpu_pos)
	local cpu = vm16.get_cpu_reg(mem.cpu_pos)
	if mem_size and cpu and mem.last_used_mem_addr then
		local x1 = x + xsize * (mem.last_used_mem_addr / mem_size)
		local x2 = x + xsize * ((cpu.TOS % mem_size) / mem_size)
		local x3 = x + xsize * 1.0
		return "label[" .. x .. "," .. (y + 0.4) .. ";Memory (" .. mem_size .. ")]" ..
			"box[" .. x  .. "," .. (y + 0.6) .. ";" .. (x1 - x)  .. "," .. 0.4 .. ";#00B]" ..
			"box[" .. x1 .. "," .. (y + 0.6) .. ";" .. (x2 - x1) .. "," .. 0.4 .. ";#AAA]" ..
			"box[" .. x2 .. "," .. (y + 0.6) .. ";" .. (x3 - x2) .. "," .. 0.4 .. ";#0B0]"
	end
	return ""
end

function vm16.watch.init(pos, mem, result)
	mem.tGlobals = result.globals or {}
	mem.tLocals = result.locals or {}
	mem.tFunctions = result.functions or {}

	local last_used_mem_addr = mem.last_code_addr
	mem.lVars = {}
	for k,v in pairs(mem.tGlobals or {}) do
		mem.lVars[#mem.lVars + 1] = k
		last_used_mem_addr = math.max(last_used_mem_addr, v)
	end
	table.sort(mem.lVars)
	mem.last_used_mem_addr = last_used_mem_addr
end

function vm16.watch.fs_window(pos, mem, x, y, xsize, ysize, fontsize)
	local color = mem.running and "#AAA" or "#FFF"
	return "label[" .. x .. "," .. (y - 0.2) .. ";Variables]" ..
		"style_type[table;font=mono;font_size="  .. fontsize .. "]" ..
		"tableoptions[color=" ..color .. ";highlight_text=" ..color .. ";highlight=#036707]" ..
		"table[" .. x .. "," .. y .. ";" .. xsize .. "," .. (ysize - 1) .. ";watch;" ..
		format_watch(pos, mem) .. ";]" ..
		memory_bar(pos, mem, x, y + ysize - 1, xsize, 1)
end
