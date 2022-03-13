--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Code window for the debugger
]]--

vm16.debug = {}

local function format_code(mem, lCode)
	local lines = {}
	mem.breakpoint_lines = mem.breakpoint_lines or {}

	for lineno, line in ipairs(lCode or {}) do
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
		vm16.reset_breakpoint(pos, addr, mem.breakpoints)
		mem.breakpoint_lines[lineno] = nil
	else
		mem.breakpoint_lines[lineno] = true
		vm16.set_breakpoint(pos, addr, mem.breakpoints)
	end
end

local function set_cursor(mem, lineno)
	mem.cursorline = lineno
end

local function get_next_lineno(pos, mem)
	local addr = vm16.get_pc(pos)
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
		vm16.set_breakpoint(pos, addr, mem.breakpoints)
		mem.temp_breakpoint = addr
	end
end

local function reset_temp_breakpoint(pos, mem)
	if mem.temp_breakpoint then
		vm16.reset_breakpoint(pos, mem.temp_breakpoint, mem.breakpoints)
		mem.temp_breakpoint = nil
	end
end

function vm16.debug.init(pos, mem)
	mem.breakpoints = {}
	mem.breakpoint_lines = {}
	mem.tAddress = {}
	mem.tLineno = {}
	mem.last_lineno = 1  -- source file size in lines
	mem.cursorline = 1   -- highlighted line
	mem.curr_lineno = 1  -- PC position
	
	for _, tok in ipairs(mem.lToken) do
		if tok.lineno and tok.address then
			mem.tAddress[tok.lineno] = tok.address
			mem.tLineno[tok.address] = tok.lineno
			mem.last_lineno = tok.lineno
		end
	end
end

function vm16.debug.on_update(pos, mem)
	mem.running = false
	local addr = vm16.get_pc(pos)
	mem.cursorline = mem.tLineno[addr] or 1
	mem.curr_lineno = mem.cursorline
	reset_temp_breakpoint(pos, mem)
end

function vm16.debug.fs_window(pos, mem, x, y, xsize, ysize, fontsize, lCode)
	local color = mem.running and "#AAA" or "#FFF"
	return "label[" .. x .. "," .. (y - 0.2) .. ";Code]" ..
		"style_type[table;font=mono;font_size="  .. fontsize .. "]" ..
		"tableoptions[color=" ..color .. ";highlight_text=" ..color .. ";highlight=#000589]" ..
		"table[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";code;" .. 
		format_code(mem, lCode) .. ";" .. (mem.cursorline or 1) .. "]"
end

function vm16.debug.on_receive_fields(pos, mem, fields, clbks)
	if not mem.running then
		if fields.code then
			local evt = minetest.explode_table_event(fields.code)
			if evt.type == "DCL" then
				set_breakpoint(pos, mem, tonumber(evt.row), mem.tAddress)
				return true  -- repaint formspec
			elseif evt.type == "CHG" then
				set_cursor(mem, tonumber(evt.row), mem.tAddress)
				return true  -- repaint formspec
			end
		elseif fields.step then
			if vm16.is_loaded(pos) then
				local lineno = get_next_lineno(pos, mem)
				set_temp_breakpoint(pos, mem, lineno)
				vm16.run(pos, nil, clbks, mem.breakpoints)
			end
		elseif fields.runto then
			if vm16.is_loaded(pos) then
				minetest.get_node_timer(pos):start(0.1)
				set_temp_breakpoint(pos, mem, mem.cursorline or 1)
				vm16.run(pos, nil, clbks, mem.breakpoints)
			end
		elseif fields.run then
			if vm16.is_loaded(pos) then
				minetest.get_node_timer(pos):start(0.1)
				mem.running = true
				vm16.run(pos, nil, clbks, mem.breakpoints)
			end
		elseif fields.stop then  -- reset
			if vm16.is_loaded(pos) then
				vm16.set_cpu_reg(pos, {A=0, B=0, C=0, D=0, X=0, Y=0, SP=0, PC=0, BP=0})
				mem.output = ""
				mem.cursorline = 1
				mem.curr_lineno = 1
			end
		end
	else
		if fields.stop then
			minetest.get_node_timer(pos):stop()
			mem.running = false
		end
	end
end

