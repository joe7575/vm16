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

--local function format_asm_code(mem, lCode)
--	local addr = vm16.get_pc(pos)
--	local code = {}
--	for i, line in ipairs(strsplit(M(pos):get_string("code"))) do
--		code[#code + 1] = line
--	end
--	if mem.lToken and addr then
--		local lineno = not mem.running and get_linenum(mem.lToken, addr) or 0
--		local start, stop = get_window(mem, lineno, #mem.lToken)
--		local lines = {}
--		for idx = start, stop do
--			local tok = mem.lToken[idx]
--			if tok and tok.address and tok.lineno then
--				local tag = "  "
--				if tok.breakpoint then
--					tag = "* "
--				end
--				if idx == lineno and not mem.scroll_lineno then
--					lines[#lines + 1] = minetest.formspec_escape(">>" .. code[tok.lineno] or "oops")
--				else
--					lines[#lines + 1] = minetest.formspec_escape(tag .. (code[tok.lineno] or "oops"))
--				end
--			elseif tok and tok.lineno then
--				lines[#lines + 1] = minetest.formspec_escape("  " .. (code[tok.lineno] or "oops"))
--			end
--		end
--		--return table.concat(lines, "\n")
--		return table.concat(lines, ",")
--	end
--	return ""
--end

local function format_src_code(mem, text)
	local lines = {}
	mem.breakpoint_lines = mem.breakpoint_lines or {}

	for lineno, line in ipairs(prog.strsplit(text)) do
		local tag = "  "
		if lineno == mem.curr_lineno and mem.breakpoint_lines[lineno] then
			tag = "*>"
		elseif lineno == mem.curr_lineno then
			tag = ">>"
		elseif mem.breakpoint_lines[lineno] then
			tag = "* "
		end
		lines[#lines + 1] = minetest.formspec_escape(tag .. line)
	end
	return table.concat(lines, ",")
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
	local lineno = mem.tLineno[addr] or 1
	for no = lineno + 1, mem.last_lineno do
		if mem.tAddress[no] then
			return no
		end
	end
	return lineno
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

function vm16.debug.init(pos, mem, result)
	mem.breakpoints = {}
	mem.breakpoint_lines = {}
	mem.tAddress = {}
	mem.tLineno = {}
	mem.last_lineno = 1  -- source file size in lines
	mem.cursorline = 1   -- highlighted line
	mem.curr_lineno = 1  -- PC position
	mem.last_code_addr = 0
	mem.output = ""
	
	for _, tok in ipairs(result.output) do
		if tok.lineno and tok.address then
			mem.tAddress[tok.lineno] = tok.address
			mem.tLineno[tok.address] = tok.lineno
			mem.last_lineno = tok.lineno
		end
	end

	local def = prog.get_cpu_def(mem.cpu_pos)
	mem.cpu_def = def.cpu_def
	local mem_size = def and def.on_mem_size(mem.cpu_pos) or 3
	vm16.create(mem.cpu_pos, mem_size)
	for _,tok in ipairs(result.output) do
		for i, opc in pairs(tok.opcodes or {}) do
			vm16.poke(mem.cpu_pos, tok.address + i - 1, opc)
			mem.last_code_addr = math.max(mem.last_code_addr, tok.address + i - 1)
		end
	end
	vm16.set_pc(mem.cpu_pos, 0)
end

function vm16.debug.on_update(pos, mem)
	mem.running = false
	local addr = vm16.get_pc(mem.cpu_pos)
	mem.cursorline = mem.tLineno[addr] or 1
	mem.curr_lineno = mem.cursorline
	reset_temp_breakpoint(pos, mem)
end

local function fs_window(pos, mem, x, y, xsize, ysize, fontsize, lCode)
	local color = mem.running and "#AAA" or "#FFF"
	return "label[" .. x .. "," .. (y - 0.2) .. ";Code]" ..
		"style_type[table;font=mono;font_size="  .. fontsize .. "]" ..
		"tableoptions[color=" ..color .. ";highlight_text=" ..color .. ";highlight=#000589]" ..
		"table[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";code;" .. 
		format_src_code(mem, lCode) .. ";" .. (mem.cursorline or 1) .. "]"
end

function vm16.debug.formspec(pos, mem, textsize)
		if mem.running then
			vm16.menubar.add_button("stop", "Stop")
		else
			vm16.menubar.add_button("edit", "Edit")
			vm16.menubar.add_button("step", "Step")
			vm16.menubar.add_button("runto", "Run to C")
			vm16.menubar.add_button("run", "Run")
			vm16.menubar.add_button("reset", "Reset")
		end
		mem.status = mem.running and "Running..." or minetest.formspec_escape("Debug  |  Out[0]: " .. (mem.output or ""))
		return fs_window(pos, mem, 0.2, 0.6, 11.4, 9.6, textsize, mem.text or "") ..
			vm16.watch.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
end

function vm16.debug.on_receive_fields(pos, fields, mem)
	if fields.edit then
		minetest.get_node_timer(mem.cpu_pos):stop()
		vm16.destroy(mem.cpu_pos)
		mem.error = nil
		mem.asm_code = nil
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
			local lineno = get_next_lineno(pos, mem)
			set_temp_breakpoint(pos, mem, lineno)
			mem.running = true
			minetest.get_node_timer(mem.cpu_pos):start(mem.cpu_def.cycle_time)
			vm16.run(mem.cpu_pos, mem.cpu_def, mem.breakpoints)
		end
	elseif fields.runto then
		if vm16.is_loaded(mem.cpu_pos) then
			set_temp_breakpoint(pos, mem, mem.cursorline or 1)
			mem.running = true
			minetest.get_node_timer(mem.cpu_pos):start(mem.cpu_def.cycle_time)
			vm16.run(mem.cpu_pos, mem.cpu_def, mem.breakpoints)
		end
	elseif fields.run then
		if vm16.is_loaded(mem.cpu_pos) then
			mem.running = true
			minetest.get_node_timer(mem.cpu_pos):start(mem.cpu_def.cycle_time)
			vm16.run(mem.cpu_pos, mem.cpu_def, mem.breakpoints)
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
			minetest.get_node_timer(mem.cpu_pos):stop()
			mem.running = false
		end
	end
end
