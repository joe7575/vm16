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

function vm16.prog.formspec(pos, mem)
	local windows, buttons, status
	local textsize = M(pos):get_int("textsize")
	if textsize >= 0 then
		textsize = "+" .. textsize
	else
		textsize = tostring(textsize)
	end

	vm16.button.init(0.2, 10.4, 2.5)
	if mem.error then
		-- Output listing + error
		vm16.button.add("edit", "Edit")
		status = "Error !!!"
		local lText =  strsplit(M(pos):get_string("code"))
		windows = vm16.edit.fs_listing(pos, mem, 0.2, 0.6, 11.4, 9.6, textsize, "main.c", lText, mem.error) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize, {"main.c", "test1.c"})
	elseif not vm16.is_loaded(pos) then
		-- Edit code
		vm16.button.add("save", "Save")
		vm16.button.add("compile", "Compile")
		vm16.button.add("debug", "Debug")
		status = "Edit"
		local text =  M(pos):get_string("code")
		windows = vm16.edit.fs_editor(pos, mem, 0.2, 0.6, 11.4, 9.6, textsize, "main.c", text) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize, {"main.c", "test1.c"})
	else
		-- Run code
		if mem.running then
			vm16.button.add("stop", "Stop", vm16.debug.on_receive_fields)
		else
			vm16.button.add("step", "Step", vm16.debug.on_receive_fields)
			vm16.button.add("runto", "Run to C", vm16.debug.on_receive_fields)
			vm16.button.add("run", "Run", vm16.debug.on_receive_fields)
			vm16.button.add("reset", "Reset", vm16.debug.on_receive_fields)
		end
		status = mem.running and "Running..." or minetest.formspec_escape("Debug  |  Out[0]: " .. (mem.output or ""))
		local lText =  strsplit(M(pos):get_string("code"))
		windows  = vm16.debug.fs_window(pos, mem, 0.2, 0.6, 11.4, 9.6, textsize, lText) ..
			vm16.watch.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	end

	return "formspec_version[4]" ..
		"size[18,12]" ..
		windows ..
		vm16.button.fs_buttons() ..
		"button[16.6,0;0.6,0.6;larger;+]" ..
		"button[17.2,0;0.6,0.6;smaller;-]" ..
		"box[0.2,11.3;17.6,0.05;#FFF]" ..
		"style_type[label;font=normal;textcolor=#FFF;font_size=+0]" ..
		"label[0.3,11.7;Mode: " .. status .. "]"
end

local function on_receive_fields(pos, formname, fields, player)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return
	end

	local mem = get_mem(pos)
	local meta = minetest.get_meta(pos)
	local lines = {"Error"}

	if not mem.running then
		if fields.code and (fields.save or fields.assemble or fields.compile  or fields.debug) then
			M(pos):set_string("code", fields.code)
		elseif fields.larger then
			M(pos):set_int("textsize", math.min(M(pos):get_int("textsize") + 1, 8))
		elseif fields.smaller then
			M(pos):set_int("textsize", math.max(M(pos):get_int("textsize") - 1, -8))
		elseif fields.compile then
			if mem.error then
				mem.error = nil
			elseif not vm16.is_loaded(pos) then
				local result, err = vm16.comp.compile(mem, M(pos):get_string("code"))
				if not err then
					init_cpu(pos, mem.lToken)
					mem.output = ""
					mem.scroll_lineno = nil
					mem.start_idx = 1
					vm16.debug.init(pos, mem)
					vm16.watch.init(pos, mem)
					vm16.edit.init(pos, mem)
					vm16.files.init(pos, mem)
				end
			end
		elseif fields.debug then
			if mem.error then
				mem.error = nil
			elseif not vm16.is_loaded(pos) then
				local result, err = vm16.comp.compile(mem, M(pos):get_string("code"))
				if not err then
					init_cpu(pos, mem.lToken)
					mem.output = ""
					mem.scroll_lineno = nil
					mem.start_idx = 1
					vm16.debug.init(pos, mem)
					vm16.watch.init(pos, mem)
					vm16.edit.init(pos, mem)
					vm16.files.init(pos, mem)
				end
			end
		elseif fields.edit then
			if vm16.is_loaded(pos) then
				minetest.get_node_timer(pos):stop()
				vm16.destroy(pos)
			end
			mem.error = nil
		else
		end
	end
	if not vm16.button.on_receive_fields(pos, mem, fields, clbks) then
		vm16.debug.on_receive_fields(pos, mem, fields, clbks)
	end
	meta:set_string("formspec", vm16.prog.formspec(pos, mem))
end
