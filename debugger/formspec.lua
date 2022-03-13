--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Simple CPU for testing purposes
]]--

-- for lazy programmers
local M = minetest.get_meta

vm16.prog = {}

local function new_table(size)
	local out = {}
	for i = 1, size do
		out[i] = 0
	end
	return out
end

local function get_linenum(lToken, addr)
	for idx = #lToken, 1, -1 do
		local tok = lToken[idx]
		if tok.address == addr then
			return tok.lineno
		end
	end
	return 0
end

local strfind = string.find
local strsub = string.sub
local tinsert = table.insert

local function strsplit(text)
   local list = {}
   local pos = 1

   while true do
      local first, last = strfind(text, "\n", pos)
      if first then -- found?
         tinsert(list, strsub(text, pos, first-1))
         pos = last+1
      else
         tinsert(list, strsub(text, pos))
         break
      end
   end
   return list
end

local function get_window(mem, lineno, size)
	if mem.scroll_lineno then
		return mem.scroll_lineno, mem.scroll_lineno + 16
	end
	mem.start_idx = mem.start_idx or 1
	if lineno > mem.start_idx + 12 then
		mem.start_idx = lineno - 12
	elseif lineno > 3 and lineno < mem.start_idx + 3 then
		mem.start_idx = lineno - 3
	end
	return mem.start_idx, math.min(mem.start_idx + 16, size)
end

local function fs_code(pos, mem)
	local addr = vm16.get_pc(pos)
	local code = {}
	for i, line in ipairs(strsplit(M(pos):get_string("code"))) do
		code[#code + 1] = line
	end
	if mem.lToken and addr then
		local lineno = not mem.running and get_linenum(mem.lToken, addr) or 0
		local start, stop = get_window(mem, lineno, #mem.lToken)
		local lines = {}
		for idx = start, stop do
			local tok = mem.lToken[idx]
			if tok and tok.address and tok.lineno then
				local tag = "  "
				if tok.breakpoint then
					tag = "* "
				end
				if idx == lineno and not mem.scroll_lineno then
					lines[#lines + 1] = minetest.formspec_escape(">>" .. code[tok.lineno] or "oops")
				else
					lines[#lines + 1] = minetest.formspec_escape(tag .. (code[tok.lineno] or "oops"))
				end
			elseif tok and tok.lineno then
				lines[#lines + 1] = minetest.formspec_escape("  " .. (code[tok.lineno] or "oops"))
			end
		end
		--return table.concat(lines, "\n")
		return table.concat(lines, ",")
	end
	return ""
end

local function fs_listing(pos, err)
	local out = {}
	if err then
		out[#out + 1] = err
		out[#out + 1] = ""
	end
	for i, line in ipairs(strsplit(M(pos):get_string("code"))) do
		local lineno = string.format("%3d: ", i)
		out[#out + 1] = lineno .. line
	end
	return table.concat(out, "\n")
end

local function mem_dump(pos, x, y)
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

local function stack_dump(pos, x, y)
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

local function reg_dump(pos, x, y)
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

function vm16.prog.formspec(pos, mem)
	local textsize = M(pos):get_int("textsize")
	if textsize >= 0 then
		textsize = "+" .. textsize
	else
		textsize = tostring(textsize)
	end

	local code, save_breakpoint_bttn, asm_edit_bttn, stop_bttn_text, color, status
	if mem.error then
		-- Output listing + error
		asm_edit_bttn = "button[5.5,10.4;2,0.8;edit;Edit]"
		save_breakpoint_bttn = ""
		stop_bttn_text = "Stop"
		color = "#AAA"
		status = "Error !!!"
		code = "style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. textsize .. "]" ..
			"textarea[0.2,0.6;8.5,9.6;;Code;" ..
			minetest.formspec_escape(fs_listing(pos, mem.error)) .. "]"
	elseif not vm16.is_loaded(pos) then
		-- Edit code
		asm_edit_bttn = "button[4.5,10.4;3,0.8;assemble;Assemble]"
		save_breakpoint_bttn = "button[1.3,10.4;3,0.8;save;Save]"
		stop_bttn_text = "Stop"
		color = "#AAA"
		status = "Edit"
		local text = M(pos):get_string("code")
		code = vm16.edit.fs_window(pos, mem,0.2, 0.6, 11.4, 9.6, textsize, "main.c", text) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize, {"main.c", "test1.c"})
	else
		-- Run code
		asm_edit_bttn = "button[5.5,10.4;2,0.8;edit;Edit]"
		save_breakpoint_bttn = ""
		stop_bttn_text = mem.running and "Stop" or "Reset"
		color = mem.running and "#AAA" or "#FFF"
		status = mem.running and "Running..." or minetest.formspec_escape("Debug  |  Out[0]: " .. (mem.output or ""))
		code  = vm16.debug.fs_window(pos, mem, 0.2, 0.6, 11.4, 9.6, textsize, strsplit(M(pos):get_string("code"))) ..
			vm16.watch.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	end

	return "formspec_version[4]" ..
		"size[18,12]" ..
		"style_type[textarea;font=mono;textcolor=" .. color .. ";border=false;font_size="  .. textsize .. "]" ..
		--reg_dump(pos, 8.8, 0.6) ..
		--stack_dump(pos, 8.8, 9.8) ..
		code ..
		"button[16.6,0;0.6,0.6;larger;+]" ..
		"button[17.2,0;0.6,0.6;smaller;-]" ..
		save_breakpoint_bttn ..
		asm_edit_bttn ..
		"button[8.8,10.4;2,0.8;step;Step]" ..
		"button[11.1,10.4;2,0.8;runto;Run to C]" ..
		"button[13.4,10.4;2,0.8;run;Run]" ..
		"button[15.7,10.4;2,0.8;stop;" .. stop_bttn_text .. "]" ..
		"box[0.2,11.3;17.6,0.05;#FFF]" ..
		"style_type[label;font=normal;textcolor=#FFF;font_size=+0]" ..
		"label[0.3,11.7;Mode: " .. status .. "]"
end
