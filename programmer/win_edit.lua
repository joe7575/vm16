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
local server = vm16.server

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

local function file_ext(filename)
	local _, ext = unpack(string.split(filename, ".", true, 1))
	return ext
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
		vm16.menubar.add_button("edit", "Edit")
		mem.status = "Error !!!"
		mem.text = mem.text or ""
		return fs_listing(pos, mem, textsize, "out.lst", mem.text, mem.error) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	elseif mem.asm_code then
		-- Edit asm code
		vm16.menubar.add_button("edit", "Edit")
		vm16.menubar.add_button("asmdbg", "Debug")
		mem.status = "Edit"
		mem.text = nil
		return fs_asm_code(pos, mem, textsize, "out.asm", mem.asm_code) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	else
		-- Edit source code
		mem.status = "Edit"
		if not mem.filename or not mem.text then
			mem.filename = "-"
			mem.text = "<no file>"
		end
		vm16.menubar.add_button("cancel", "Cancel")
		vm16.menubar.add_button("save", "Save")
		if file_ext(mem.filename) == "c" then
			vm16.menubar.add_button("compile", "Compile")
			vm16.menubar.add_button("debug", "Debug")
		end
		return fs_editor(pos, mem, textsize, mem.filename, mem.text) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	end
end

function vm16.edit.on_load_file(mem, name, text)
	mem.filename = name
	mem.text = text
	mem.error = nil
	mem.asm_code = nil
end

function vm16.edit.on_receive_fields(pos, fields, mem)
	if fields.code and (fields.save or fields.compile or fields.assemble or fields.debug) then
		if mem.filename and mem.server_pos then
			mem.text = fields.code
			server.write_file(mem.server_pos, mem.filename, mem.text)
		end
	end
	if fields.cancel then
		mem.filename = nil
		mem.text = nil
		mem.error = nil
		mem.asm_code = nil
	elseif fields.edit then
		mem.error = nil
		mem.asm_code = nil
	elseif fields.compile then
		mem.error = nil
		mem.asm_code, mem.error = vm16.gen_asm_code(mem.filename or "", mem.text or "")
		vm16.files.init(pos, mem)
	elseif fields.debug then
		local def = prog.get_cpu_def(mem.cpu_pos)
		if def then
			local prog_pos = def.on_check_connection(mem.cpu_pos)
			if vector.equals(pos, prog_pos) then
				local result = vm16.gen_obj_code(mem.filename or "", mem.text or "")
				if not result.errors then
					vm16.debug.init(pos, mem, result)
					vm16.watch.init(pos, mem, result)
				else
					mem.error = result.errors
				end
				mem.error = nil
				mem.asm_code = nil
			end
		end
	elseif fields.asmdbg and mem.asm_code then
		local def = prog.get_cpu_def(mem.cpu_pos)
		if def then
			local prog_pos = def.on_check_connection(mem.cpu_pos)
			if vector.equals(pos, prog_pos) then
				local result = vm16.assemble(mem.filename or "out.asm", mem.asm_code)
				if not result.errors then
					vm16.debug.init(pos, mem, result)
					vm16.memory.init(pos, mem, result)
				else
					mem.error = result.errors
				end
				mem.error = nil
				mem.text = nil
			end
		end
	else
		vm16.files.on_receive_fields(pos, fields, mem)
	end
end
