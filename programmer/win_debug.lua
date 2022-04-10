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
local server = vm16.server
local file_ext = vm16.file_ext
local file_base = vm16.file_base

vm16.debug = {}

local function format_asm_code(mem, text)
	local out = {}
	mem.breakpoint_lines = mem.breakpoint_lines or {}
	local addr = vm16.get_pc(mem.cpu_pos)

	for lineno, line in ipairs(vm16.splitlines(text)) do
		local tag = "  "
		local saddr = ""
		local is_curr_line = false
		local addr2 = mem.lut:get_address(mem.file_name, lineno)
		if addr2 then
			saddr = string.format("%04X: ", addr2)
		end
		is_curr_line = addr2 == addr
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

local function set_breakpoint(pos, mem, lineno)
	local addr = mem.lut:get_address(mem.file_name, lineno) or 0

	if mem.breakpoint_lines[lineno] then
		vm16.reset_breakpoint(mem.cpu_pos, addr, mem.breakpoints)
		mem.breakpoint_lines[lineno] = nil
	else
		mem.breakpoint_lines[lineno] = true
		vm16.set_breakpoint(mem.cpu_pos, addr, mem.breakpoints)
	end
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
	lineno = lineno or mem.curr_lineno or 1
	local addr = mem.lut:get_address(mem.file_name, lineno)
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

local function loadfile_by_address(mem, addr)
	local item = mem.lut:get_item(addr)
	if item then
		mem.file_name = item.file
		mem.file_ext = file_ext(mem.file_name)
		mem.file_text = server.read_file(mem.server_pos, mem.file_name)
	end
	return item
end


function vm16.debug.init(pos, mem, obj)
	mem.breakpoints = {}
	mem.breakpoint_lines = {}
	mem.output = ""
	mem.lut = vm16.Lut:new()
	mem.lut:init(obj)

	--print(vm16.dump_obj_code_listing(obj))
	mem.cpu_def = prog.get_cpu_def(mem.cpu_pos)
	local mem_size = mem.cpu_def and mem.cpu_def.on_mem_size(mem.cpu_pos) or 3
	vm16.create(mem.cpu_pos, mem_size)

	for _, item in ipairs(obj.lCode) do
		local ctype, lineno, scode, address, opcodes = unpack(item)
		for i, opc in pairs(opcodes or {}) do
			vm16.poke(mem.cpu_pos, address + i - 1, opc)
		end
	end

	vm16.set_pc(mem.cpu_pos, 0)
	mem.mem_size = vm16.mem_size(mem.cpu_pos)
	mem.startaddr = 0

	mem.main_filename = mem.file_name
	if mem.file_ext == "c" then
		local address = mem.lut:get_function_address("main")
		if address then
			local lineno = mem.lut:get_line(address)
			set_temp_breakpoint(pos, mem, lineno)
			start_cpu(mem)
		else
			local lineno = mem.lut:get_line(0)
			mem.cursorline = lineno
			mem.curr_lineno = lineno  -- PC position
		end
	elseif mem.file_ext == "asm" then
		local lineno = mem.lut:get_line(0)
		mem.cursorline = lineno
		mem.curr_lineno = lineno  -- PC position
	end
end

function vm16.debug.on_update(pos, mem, resp)
	if resp == vm16.HALT then
		mem.cursorline = 1
		mem.curr_lineno = 1
		stop_cpu(mem)
		reset_temp_breakpoint(pos, mem)
	elseif mem.cpu_pos then
		stop_cpu(mem)
		local addr = vm16.get_pc(mem.cpu_pos)
		mem.cursorline = mem.lut:get_line(addr) or 1
		mem.curr_lineno = mem.cursorline
		reset_temp_breakpoint(pos, mem)
	end
end

local function fs_window(pos, mem, x, y, xsize, ysize, fontsize, text)
	local color = mem.running and "#AAA" or "#FFF"
	local filename = mem.file_name or ""
	local code
	if mem.file_ext == "asm" then
		code = format_asm_code(mem, text) .. ";" .. (mem.cursorline or 1) .. "]"
	elseif mem.file_ext == "c" then
		code = format_src_code(mem, text) .. ";" .. (mem.cursorline or 1) .. "]"
	end

	return "label[" .. x .. "," .. (y - 0.2) .. ";File: " .. filename .. "]" ..
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
		if mem.lut then
			vm16.menubar.add_button("step", "Step")
			vm16.menubar.add_button("stepin", "Step in")
			vm16.menubar.add_button("stepout", "Step out")
			vm16.menubar.add_button("runto", "Run to C")
			vm16.menubar.add_button("run", "Run")
			vm16.menubar.add_button("reset", "Reset")
		end
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
	elseif fields.code and mem.lut then
		local evt = minetest.explode_table_event(fields.code)
		if evt.type == "DCL" then
			set_breakpoint(pos, mem, tonumber(evt.row))
			return true  -- repaint formspec
		elseif evt.type == "CHG" then
			mem.cursorline = tonumber(evt.row)
			return true  -- repaint formspec
		end
	elseif fields.step then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			if mem.file_ext == "asm" then
				vm16.run(mem.cpu_pos, mem.cpu_def, mem.breakpoints, 1)
				local addr = vm16.get_pc(mem.cpu_pos)
				mem.cursorline = mem.lut:get_line(addr) or 1
				mem.curr_lineno = mem.cursorline
			elseif mem.file_ext == "c" then
				local addr = vm16.get_pc(mem.cpu_pos)
				local lineno = mem.lut:get_next_line(addr)
				set_temp_breakpoint(pos, mem, lineno)
				start_cpu(mem)
			end
		end
	elseif fields.stepin then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			local addr = mem.lut:get_stepin_address(mem.file_name, mem.curr_lineno) or 0
			local item = loadfile_by_address(mem, addr)
			if item then
				local lineno = mem.lut:get_line(item.addresses[1])
				set_temp_breakpoint(pos, mem, lineno)
				start_cpu(mem)
			end
		end
	elseif fields.stepout then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			local cpu = vm16.get_cpu_reg(mem.cpu_pos)
			local addr = (vm16.peek(mem.cpu_pos, cpu.BP) or 2) - 2
			addr = mem.lut:find_next_address(addr)
			local item = loadfile_by_address(mem, addr)
			if item then
				local lineno = mem.lut:get_line(addr)
				set_temp_breakpoint(pos, mem, lineno)
				start_cpu(mem)
			end
		end
	elseif fields.runto then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			set_temp_breakpoint(pos, mem, mem.cursorline)
			start_cpu(mem)
		end
	elseif fields.run then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			start_cpu(mem)
		end
	elseif fields.reset then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			vm16.set_cpu_reg(mem.cpu_pos, {A=0, B=0, C=0, D=0, X=0, Y=0, SP=0, PC=0})
			mem.output = ""
			local address = mem.lut:get_function_address("main")
			if address then
				local item = loadfile_by_address(mem, address)
				if item then
					local lineno = mem.lut:get_line(address)
					reset_temp_breakpoint(pos, mem)
					set_temp_breakpoint(pos, mem, lineno)
					start_cpu(mem)
				end
			else
				local lineno = mem.lut:get_line(0)
				mem.cursorline = lineno
				mem.curr_lineno = lineno
			end
		end
	elseif fields.stop then
		if mem.running then
			stop_cpu(mem)
		end
		if not mem.lut then
			vm16.destroy(mem.cpu_pos)
		end
	elseif fields.inc then
		mem.startaddr = math.min(mem.startaddr + 64, (mem.mem_size or 64) - 64)
	elseif fields.dec then
		mem.startaddr = math.max(mem.startaddr - 64, 0)
	end
end
