--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Editor window for the debugger
]]--

-- for lazy programmers
local M = minetest.get_meta
local prog = vm16.prog

local EDIT_SIZE = "0.2,0.6;11.4, 9.6"

vm16.edit = {}

local function add_lineno(pos, text, err)
	local out = {}
	if err then
		out[#out + 1] = err
		out[#out + 1] = ""
	end
	for i, line in ipairs(prog.strsplit(text)) do
		local lineno = string.format("%3d: ", i)
		out[#out + 1] = lineno .. line
	end
	return table.concat(out, "\n")
end

local function fs_editor(pos, mem, fontsize, file, text)
	return "box[" .. EDIT_SIZE .. ";#000]" ..
		"style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. fontsize .. "]" ..
		"textarea[" .. EDIT_SIZE .. ";code;File: " .. file .. ";" ..
		minetest.formspec_escape(text) .. "]"
end

local function fs_listing(pos, mem, fontsize, file, text, err)
	return "box[" .. EDIT_SIZE .. ";#000]" ..
		"style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. fontsize .. "]" ..
		"textarea[" .. EDIT_SIZE .. ";;Listing: " .. file .. ";" ..
		minetest.formspec_escape(add_lineno(pos, text, err)) .. "]"
end

local function fs_asm_code(pos, mem, fontsize, file, text)
	return "box[" .. EDIT_SIZE .. ";#000]" ..
		"style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. fontsize .. "]" ..
		"textarea[" .. EDIT_SIZE .. ";;ASM Code: " .. file .. ";" ..
		minetest.formspec_escape(text) .. "]"
end

function vm16.edit.formspec(pos, mem, textsize)
	if mem.error then
		-- Output listing + error
		vm16.button.add("edit", "Edit")
		mem.status = "Error !!!"
		local text = M(pos):get_string("code")
		return fs_listing(pos, mem, textsize, "main.c", text, mem.error) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize, {"main.c", "test1.c"})
	elseif mem.asm_code then
		-- Edit asm code
		vm16.button.add("edit", "Edit")
		--vm16.button.add("assemble", "Assemble")
		vm16.button.add("debug", "Debug")
		mem.status = "Edit"
		mem.asm_code = mem.asm_code or ""
		return fs_asm_code(pos, mem, textsize, "main.asm", mem.asm_code) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize, {"main.asm", "test1.c"})
	else
		-- Edit source code
		vm16.button.add("save", "Save")
		vm16.button.add("compile", "Compile")
		vm16.button.add("debug", "Debug")
		mem.status = "Edit"
		local text = M(pos):get_string("code")
		return fs_editor(pos, mem, textsize, "main.c", text) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize, {"main.c", "test1.c"})
	end
end

function vm16.edit.on_receive_fields(pos, fields, mem)
	if fields.code and (fields.save or fields.compile or fields.assemble or fields.debug) then
		M(pos):set_string("code", fields.code)
	end
	if fields.edit then
		mem.error = nil
		mem.asm_code = nil
	elseif fields.compile then
		mem.error = nil
		mem.asm_code = vm16.gen_asm_code(M(pos):get_string("code"))
		vm16.files.init(pos, mem)
	elseif fields.debug then
		mem.error = nil
		mem.asm_code = nil
		local result = vm16.gen_obj_code(M(pos):get_string("code"))
		if not result.errors then
			vm16.debug.init(pos, mem, result)
			vm16.watch.init(pos, mem, result)
		else
			mem.error = result.errors
		end
	end
end
