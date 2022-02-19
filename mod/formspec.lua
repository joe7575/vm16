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
		if tok[vm16.Asm.ADDRESS] == addr then
			return tok[vm16.Asm.LINENO]
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
	if mem.lToken and addr then
		local lineno = not mem.running and get_linenum(mem.lToken, addr) or 0
		local start, stop = get_window(mem, lineno, #mem.lToken)
		local lines = {}
		for idx = start, stop do
			local tok = mem.lToken[idx]
			local addr = string.format("%04X: ", tok[vm16.Asm.ADDRESS])
			if idx == lineno then
				lines[#lines + 1] = addr .. minetest.colorize("#0FF", tok[vm16.Asm.TXTLINE])
			else
				lines[#lines + 1] = addr .. tok[vm16.Asm.TXTLINE]
			end
		end
		return table.concat(lines, "\n")
	end
	return ""
end

local function fs_listing(pos, err)
	local out = {}
	for i, line in ipairs(strsplit(M(pos):get_string("code"))) do
		local lineno = string.format("%3d: ", i)
		out[i] = lineno .. line
	end
	out[#out + 1] = ""
	out[#out + 1] = err
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
	local cpu = vm16.get_cpu_reg(pos) or {A=0, B=0, C=0, D=0, X=0, Y=0, SP=0, PC=0}
	table.insert(lines, "box[0,0;9,0.8;#060]")
	table.insert(lines, "textarea[0,0;9,0.8;;Registers;")
	table.insert(lines, " A    B    C    D     X    Y    PC   SP\n")
	table.insert(lines, string.format("%04X %04X %04X %04X", cpu.A, cpu.B, cpu.C, cpu.D) .. "  " ..
		string.format("%04X %04X %04X %04X", cpu.X, cpu.Y, cpu.PC, cpu.SP))
	table.insert(lines, "]")
	table.insert(lines, "container_end[]")
	return table.concat(lines, "")
end

function vm16.cpu.formspec(pos, mem)
	local textsize = M(pos):get_int("textsize")
	if textsize >= 0 then
		textsize = "+" .. textsize
	else
		textsize = tostring(textsize)
	end
	
	local code, asm_bttn_text, stop_bttn_text, color, status
	if mem.error then
		-- Output listing + error
		asm_bttn_text = "Edit"
		stop_bttn_text = "Stop"
		color = "#AAA"
		status = "Edit"
		code = "style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. textsize .. "]" ..
			"textarea[0.2,0.6;8.5,9.6;;Code;" .. 
			minetest.formspec_escape(fs_listing(pos, mem.error)) .. "]"
	elseif not vm16.is_loaded(pos) then
		-- Edit code
		asm_bttn_text = "Assemble"
		stop_bttn_text = "Stop"
		color = "#AAA"
		status = "Edit"
		code = "style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. textsize .. "]" ..
			"textarea[0.2,0.6;8.5,9.6;code;Code;" .. 
			minetest.formspec_escape(M(pos):get_string("code")) .. "]"
	else
		-- Run code
		asm_bttn_text = "Edit"
		stop_bttn_text = mem.running and "Stop" or "Reset"
		color = mem.running and "#AAA" or "#FFF"
		status = mem.running and "Running..." or minetest.formspec_escape("Debug  |  Out[0]: " .. (mem.output or ""))
		code  = "label[0.2,0.4;Code]" ..
			"style_type[label;font=mono;textcolor=#AAA;font_size="  .. textsize .. "]" ..
			"label[0.2,0.8;" .. minetest.formspec_escape(fs_code(pos, mem)) .. "]"
	end
	
	return "formspec_version[4]" ..
		"size[18,12]" ..
		"style_type[textarea;font=mono;textcolor=" .. color .. ";border=false;font_size="  .. textsize .. "]" ..
		"box[0.2,0.6;8.0,9.6;#000]" ..
		reg_dump(pos, 8.8, 0.6) ..
		mem_dump(pos, 8.8, 1.7) ..
		stack_dump(pos, 8.8, 9.8) ..
		code ..
		"button[16.6,0;0.6,0.6;larger;+]" ..
		"button[17.2,0;0.6,0.6;smaller;-]" ..
		"button[1.3,10.4;3,0.8;save;Save]" ..
		"button[4.5,10.4;3,0.8;assemble;" .. asm_bttn_text .. "]" ..
		"button[8.8,10.4;2,0.8;step;Step]" ..
		"button[11.1,10.4;2,0.8;step10;Step 10]" ..
		"button[13.4,10.4;2,0.8;run;Run]" ..
		"button[15.7,10.4;2,0.8;stop;" .. stop_bttn_text .. "]" ..
		"box[0.2,11.3;17.6,0.05;#FFF]" ..
		"style_type[label;font=normal;textcolor=#FFF;font_size=+0]" ..
		"label[0.3,11.7;Mode: " .. status .. "]"
end
