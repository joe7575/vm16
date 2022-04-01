--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Code window for the debugger
]]--

-- for lazy programmers
local M = minetest.get_meta
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end
local prog = vm16.prog

vm16.debug = {}

local function format_asm_code(mem, text)
	local out = {}
	mem.breakpoint_lines = mem.breakpoint_lines or {}
	local addr = vm16.get_pc(mem.cpu_pos)

	for lineno, line in ipairs(vm16.splitlines(text)) do
		local tag = "  "
		local saddr = ""
		local is_curr_line = false
		if mem.tAddress and mem.tAddress[lineno] then
			saddr = string.format("%04X: ", mem.tAddress[lineno])
			is_curr_line = mem.tAddress[lineno] == addr
		end
		if is_curr_line and mem.breakpoint_lines[lineno] then
			tag = "*>"
		elseif is_curr_line then
			tag = ">>"
		elseif mem.breakpoint_lines[lineno] then
			tag = "* "
		end
		out[#out + 1] = minetest.formspec_escape(saddr .. tag .. line)
	end
	return table.concat(out, ",")
end

local function format_src_code(mem, text)
	local out = {}
	mem.breakpoint_lines = mem.breakpoint_lines or {}

	for lineno, line in ipairs(vm16.splitlines(text)) do
		local tag = "  "
		if lineno == mem.curr_lineno and mem.breakpoint_lines[lineno] then
			tag = "*>"
		elseif lineno == mem.curr_lineno then
			tag = ">>"
		elseif mem.breakpoint_lines[lineno] then
			tag = "* "
		end
		out[#out + 1] = minetest.formspec_escape(tag .. line)
	end
	return table.concat(out, ",")
end

local function set_breakpoint(pos, mem, lineno, tAddress)
	local addr = tAddress[lineno] or 0

	if mem.breakpoint_lines[lineno] then
		vm16.reset_breakpoint(mem.cpu_pos, addr, mem.breakpoints)
		mem.breakpoint_lines[lineno] = nil
	else
		mem.breakpoint_lines[lineno] = true
		vm16.set_breakpoint(mem.cpu_pos, addr, mem.breakpoints)
	end
end

local function set_cursor(mem, lineno)
	mem.cursorline = lineno
end

local function get_next_lineno(pos, mem)
	local addr = vm16.get_pc(mem.cpu_pos)
	local lineno = math.max(mem.tLineno[addr] or 1, mem.curr_lineno)
	for no = lineno + 1, mem.last_lineno do
		if mem.tAddress[no] then
			return no
		end
	end
	return lineno
end

local function start_cpu(mem)
	local def = prog.get_cpu_def(mem.cpu_pos)
	def.on_start(mem.cpu_pos)
	mem.running = true
	minetest.get_node_timer(mem.cpu_pos):start(mem.cpu_def.cycle_time)
	vm16.run(mem.cpu_pos, mem.cpu_def, mem.breakpoints)
end

local function stop_cpu(mem)
	local def = prog.get_cpu_def(mem.cpu_pos)
	def.on_stop(mem.cpu_pos)
	mem.running = false
	minetest.get_node_timer(mem.cpu_pos):stop()
end

local function set_temp_breakpoint(pos, mem, lineno)
	local addr = mem.tAddress[lineno]
	if addr and not mem.breakpoint_lines[lineno] then
		vm16.set_breakpoint(mem.cpu_pos, addr, mem.breakpoints)
		mem.temp_breakpoint = addr
	end
end

local function reset_temp_breakpoint(pos, mem)
	if mem.temp_breakpoint then
		vm16.reset_breakpoint(mem.cpu_pos, mem.temp_breakpoint, mem.breakpoints)
		mem.temp_breakpoint = nil
	end
end

function vm16.debug.init(pos, mem, obj)
	mem.breakpoints = {}
	mem.breakpoint_lines = {}
	mem.tAddress = {}
	mem.tLineno = {}
	mem.step_in = {}
	mem.last_lineno = 1  -- source file size in lines
	mem.curr_lineno = 1  -- PC position
	mem.last_code_addr = 0
	mem.output = ""

	mem.cpu_def = prog.get_cpu_def(mem.cpu_pos)
	local mem_size = mem.cpu_def and mem.cpu_def.on_mem_size(mem.cpu_pos) or 3
	vm16.create(mem.cpu_pos, mem_size)
	
	for _, item in ipairs(obj.lCode) do
		local ctype, lineno, scode, address, opcodes = unpack(item)
		if ctype == "code" and #opcodes > 0 then
			mem.tAddress[lineno] = mem.tAddress[lineno] or address
			mem.tLineno[address] = lineno
			mem.last_lineno = lineno
		elseif ctype == "call" then
			mem.step_in[lineno] = address
		end
		for i, opc in pairs(opcodes or {}) do
			vm16.poke(mem.cpu_pos, address + i - 1, opc)
			mem.last_code_addr = math.max(mem.last_code_addr, address + i - 1)
		end
	end

	vm16.set_pc(mem.cpu_pos, 0)
	mem.mem_size = vm16.mem_size(mem.cpu_pos)
	mem.startaddr = 0
	mem.cursorline = mem.tLineno[0] or 1
end

function vm16.debug.on_update(pos, mem)
	if mem.cpu_pos and mem.tLineno then
		stop_cpu(mem)
		local addr = vm16.get_pc(mem.cpu_pos)
		mem.cursorline = mem.tLineno[addr] or 1
		mem.curr_lineno = mem.cursorline
		reset_temp_breakpoint(pos, mem)
	end
end

local function fs_window(pos, mem, x, y, xsize, ysize, fontsize, text)
	local color = mem.running and "#AAA" or "#FFF"
	local code
	if mem.file_ext == "asm" then
		code = format_asm_code(mem, text) .. ";" .. (mem.cursorline or 1) .. "]"
	elseif mem.file_ext == "c" then
		code = format_src_code(mem, text) .. ";" .. (mem.cursorline or 1) .. "]"
	end

	return "label[" .. x .. "," .. (y - 0.2) .. ";Code]" ..
		"style_type[table;font=mono;font_size="  .. fontsize .. "]" ..
		"tableoptions[color=" ..color .. ";background=#030330;highlight_text=" ..color .. ";highlight=#000589]" ..
		"table[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";code;" ..
		code
end

function vm16.debug.formspec(pos, mem, textsize)
	if mem.running then
		vm16.menubar.add_button("stop", "Stop")
	else
		vm16.menubar.add_button("edit", "Edit")
		vm16.menubar.add_button("step", "Step")
		if mem.file_ext == "c" then
			vm16.menubar.add_button("stepin", "Step in")
		end
		vm16.menubar.add_button("runto", "Run to C")
		vm16.menubar.add_button("run", "Run")
		vm16.menubar.add_button("reset", "Reset")
	end
	mem.status = mem.running and "Running..." or minetest.formspec_escape("Debug  |  Out[0]: " .. (mem.output or ""))
	if mem.file_text then
		if mem.file_ext == "asm" then
			return fs_window(pos, mem, 0.2, 0.6, 8.4, 9.6, textsize, mem.file_text) ..
				vm16.memory.fs_window(pos, mem, 8.8, 0.6, 6, 9.6, textsize)
		elseif mem.file_ext == "c" then
			return fs_window(pos, mem, 0.2, 0.6, 11.4, 9.6, textsize, mem.file_text) ..
				vm16.watch.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
		end
	end
end

function vm16.debug.on_receive_fields(pos, fields, mem)
	if fields.edit then
		minetest.get_node_timer(mem.cpu_pos):stop()
		vm16.destroy(mem.cpu_pos)
		mem.error = nil
	elseif fields.code then
		local evt = minetest.explode_table_event(fields.code)
		if evt.type == "DCL" then
			set_breakpoint(pos, mem, tonumber(evt.row), mem.tAddress)
			return true  -- repaint formspec
		elseif evt.type == "CHG" then
			set_cursor(mem, tonumber(evt.row), mem.tAddress)
			return true  -- repaint formspec
		end
	elseif fields.step then
		if vm16.is_loaded(mem.cpu_pos) then
			if mem.file_ext == "asm" then
				vm16.run(mem.cpu_pos, mem.cpu_def, mem.breakpoints, 1)
				local addr = vm16.get_pc(mem.cpu_pos)
				mem.cursorline = mem.tLineno[addr] or 1
				mem.curr_lineno = mem.cursorline
			elseif mem.file_ext == "c" then
				local lineno = get_next_lineno(pos, mem)
				set_temp_breakpoint(pos, mem, lineno)
				start_cpu(mem)
			end
		end
	elseif fields.stepin then
		if vm16.is_loaded(mem.cpu_pos) then
			if mem.file_ext == "c" then
				local lineno = mem.step_in[mem.curr_lineno]
				if lineno then
					set_temp_breakpoint(pos, mem, lineno)
					start_cpu(mem)
				end
			end
		end
	elseif fields.runto then
		if vm16.is_loaded(mem.cpu_pos) then
			set_temp_breakpoint(pos, mem, mem.cursorline or 1)
			start_cpu(mem)
		end
	elseif fields.run then
		if vm16.is_loaded(mem.cpu_pos) then
			start_cpu(mem)
		end
	elseif fields.reset then
		if vm16.is_loaded(mem.cpu_pos) then
			vm16.set_cpu_reg(mem.cpu_pos, {A=0, B=0, C=0, D=0, X=0, Y=0, SP=0, PC=0})
			mem.output = ""
			mem.cursorline = 1
			mem.curr_lineno = 1
		end
	elseif fields.stop then
		if mem.running then
			stop_cpu(mem)
		end
	elseif fields.inc then
		mem.startaddr = math.min(mem.startaddr + 64, (mem.mem_size or 64) - 64)
	elseif fields.dec then
		mem.startaddr = math.max(mem.startaddr - 64, 0)
	end
end
