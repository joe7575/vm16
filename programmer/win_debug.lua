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
local hex = function(val) return string.format("%04X", val) end
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
		mem.temp_breakpoint1 = addr
	end
end

local function set_branch_breakpoint(pos, mem, addr)
	if mem.lut then
		local lineno = mem.lut:get_line(addr)
		addr = mem.lut:get_branch_address(lineno)
		if addr then
			lineno = mem.lut:get_line(addr) or 1
			if not mem.breakpoint_lines[lineno] then
				vm16.set_breakpoint(mem.cpu_pos, addr, mem.breakpoints)
				mem.temp_breakpoint2 = addr
			end
		end
	end
end

local function reset_temp_breakpoint(pos, mem)
	if mem.temp_breakpoint1 then
		vm16.reset_breakpoint(mem.cpu_pos, mem.temp_breakpoint1, mem.breakpoints)
		mem.temp_breakpoint1 = nil
	end
	if mem.temp_breakpoint2 then
		vm16.reset_breakpoint(mem.cpu_pos, mem.temp_breakpoint2, mem.breakpoints)
		mem.temp_breakpoint2 = nil
	end
end

local function load_file(mem, filename)
	if filename then
		mem.file_name = filename
		mem.file_ext = file_ext(mem.file_name)
		mem.file_text = server.read_file(mem.server_pos, mem.file_name)
		return true
	end
end
local function loadfile_by_address(mem, addr)
	if mem.lut then
		local filename = (mem.lut:get_item(addr) or {}).file or mem.lut.main_file
		return load_file(mem, filename)
	end
end


local function walk_to_ret_address(mem)
	for i = 1, 20 do
		local pc = vm16.get_pc(mem.cpu_pos)
		if vm16.peek(mem.cpu_pos, pc) ~= 0x1800 then  -- ret instruction
			vm16.run(mem.cpu_pos, mem.cpu_def, mem.breakpoints, 1)
		end
	end
end

-- return from subroutine
local function step_out(pos, mem)
	walk_to_ret_address(mem)
	local cpu = vm16.get_cpu_reg(mem.cpu_pos)
	local addr = (vm16.peek(mem.cpu_pos, cpu.SP) or 2) - 2
	addr = mem.lut:find_next_address(addr)
	if loadfile_by_address(mem, addr) then
		local lineno = mem.lut:get_line(addr)
		set_temp_breakpoint(pos, mem, lineno)
		start_cpu(mem)
	end
end

function vm16.debug.init(pos, mem, obj)
	mem.breakpoints = {}
	mem.breakpoint_lines = {}
	mem.output = ""
	--print(vm16.dump_compiler_output(obj))
	mem.lut = vm16.Lut:new()
	mem.lut:init(obj)

	mem.cpu_def = prog.get_cpu_def(mem.cpu_pos)
	local mem_size = mem.cpu_def and mem.cpu_def.on_mem_size(mem.cpu_pos) or 3
	vm16.term.init(pos, mem)
	vm16.create(mem.cpu_pos, mem_size)

	for _, item in ipairs(obj.lCode) do
		local ctype, lineno, address, opcodes = unpack(item)
		if ctype == "code" then
			for i, opc in pairs(opcodes or {}) do
				vm16.poke(mem.cpu_pos, address + i - 1, opc)
			end
		end
	end

	vm16.set_pc(mem.cpu_pos, 0)
	mem.mem_size = vm16.mem_size(mem.cpu_pos)
	mem.startaddr = 0

	mem.main_filename = mem.file_name
	if mem.file_ext == "c" then
		local address = mem.lut:get_function_address("main") or mem.lut:get_function_address("init")
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
		mem.cursorline = mem.lut and mem.lut:get_line(addr) or 1
		mem.curr_lineno = mem.cursorline
		reset_temp_breakpoint(pos, mem)
	end
end

local function fs_popup(pos, files)
	local s = table.concat(files, ",")
	--return "box[4,4;6,4;#000]" ..
	return "image[4,4;6,4;vm16_fs_win.png]" ..
		"label[4.6,4.76;Files:]" ..
		"dropdown[4.5,5.0;5.0;prj_file;" .. s .. ";1]" ..
		"button[7.5,6.8;2,0.8;load;Load]"
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
	local popup = ""
	-- CPU can be started by SD card (without debugging data)
	mem.lut = mem.lut or vm16.Lut:new()
	
	if mem.running then
		vm16.menubar.add_button("stop", "Stop")
		vm16.menubar.add_button("term", "Terminal", 2.4)
	else
		vm16.menubar.add_button("edit", "Edit")
		if mem.lut then
			vm16.menubar.add_button("step", "Step")
			if mem.file_ext ~= "asm" then
				vm16.menubar.add_button("stepin", "Step in")
				vm16.menubar.add_button("stepout", "Step out")
			end
			vm16.menubar.add_button("runto", "Run to C")
			vm16.menubar.add_button("run", "Run")
			vm16.menubar.add_button("file", "File")
			vm16.menubar.add_button("reset", "Reset")
			if mem.prj_files then
				popup = fs_popup(pos, mem.prj_files)
			end
		end
	end
	mem.status = mem.running and "Running..." or minetest.formspec_escape("Debug  |  Output: " .. (mem.output or ""))
	if mem.file_text then
		if mem.file_ext == "asm" then
			return fs_window(pos, mem, 0.2, 0.6, 8.4, 9.6, textsize, mem.file_text) ..
				vm16.memory.fs_window(pos, mem, 8.8, 0.6, 6, 9.6, textsize) ..
				popup
		elseif mem.file_ext == "c" then
			return fs_window(pos, mem, 0.2, 0.6, 11.4, 9.6, textsize, mem.file_text) ..
				vm16.watch.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize) ..
				popup
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
				if mem.lut:is_return_line(mem.file_name, addr) then
					step_out(pos, mem)
				else
					local lineno = mem.lut:get_next_line(addr)
					set_temp_breakpoint(pos, mem, lineno)
					set_branch_breakpoint(pos, mem, addr)
					start_cpu(mem)
				end
			end
		end
	elseif fields.stepin then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			local addr = mem.lut:get_stepin_address(mem.file_name, mem.curr_lineno) or 0
			if loadfile_by_address(mem, addr) then
				local lineno = mem.lut:get_line(addr)
				set_temp_breakpoint(pos, mem, lineno)
				start_cpu(mem)
			end
		end
	elseif fields.stepout then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			step_out(pos, mem)
		end
	elseif fields.runto then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			set_temp_breakpoint(pos, mem, mem.cursorline)
			start_cpu(mem)
		end
	elseif fields.file then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			mem.prj_files = mem.lut:get_files()
		end
	elseif fields.run then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			start_cpu(mem)
		end
	elseif fields.reset then
		if vm16.is_loaded(mem.cpu_pos) and mem.lut then
			vm16.set_cpu_reg(mem.cpu_pos, {A=0, B=0, C=0, D=0, X=0, Y=0, SP=0, PC=0})
			mem.output = ""
			local addr = mem.lut:get_function_address("main") or mem.lut:get_function_address("init")
			if addr then
				if loadfile_by_address(mem, addr) then
					local lineno = mem.lut:get_line(addr)
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
			local addr = vm16.get_pc(mem.cpu_pos)
			loadfile_by_address(mem, addr)
		end
		if not mem.lut then
			vm16.destroy(mem.cpu_pos)
		end
	elseif fields.load then
		load_file(mem, fields.prj_file)
		mem.cursorline = 1
		mem.prj_files = nil
	elseif fields.term then
		mem.term_active = true
	elseif fields.inc then
		mem.startaddr = math.min(mem.startaddr + 64, (mem.mem_size or 64) - 64)
	elseif fields.dec then
		mem.startaddr = math.max(mem.startaddr - 64, 0)
	end
end
