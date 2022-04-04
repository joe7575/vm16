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
local file_ext = vm16.file_ext
local file_base = vm16.file_base

local EDIT_SIZE = "0.2,0.6;11.4, 9.6"

vm16.edit = {}

local function add_lineno(pos, text, err)
	local out = {}
	if err then
		out[#out + 1] = err
		out[#out + 1] = ""
	end
	for i, line in ipairs(vm16.splitlines(text)) do
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

function vm16.edit.formspec(pos, mem, textsize)
	if mem.file_name and mem.file_text and mem.server_pos then
		if mem.error then
			-- Output listing + error
			mem.status = "Error !!!"
			vm16.menubar.add_button("edit", "Edit")
			return fs_listing(pos, mem, textsize, "out.lst", mem.file_text , mem.error) ..
				vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
		elseif mem.file_ext == "asm" then
			mem.status = "Edit"
			vm16.menubar.add_button("cancel", "Cancel")
			if not server.is_ro_file(mem.server_pos, mem.file_name) then
				vm16.menubar.add_button("save", "Save")
			end
			vm16.menubar.add_button("asmdbg", "Debug")
		elseif mem.file_ext == "c" then
			mem.status = "Edit"
			vm16.menubar.add_button("cancel", "Cancel")
			if not server.is_ro_file(mem.server_pos, mem.file_name) then
				vm16.menubar.add_button("save", "Save")
			end
			vm16.menubar.add_button("compile", "Compile")
			vm16.menubar.add_button("debug", "Debug")
		end
		return fs_editor(pos, mem, textsize, mem.file_name, mem.file_text) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	else
		return fs_editor(pos, mem, textsize, "-", "<no file>") ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	end
end

function vm16.edit.on_load_file(mem, name, text)
	mem.file_name = name
	mem.file_text = text
	mem.file_ext = file_ext(mem.file_name)
	mem.error = nil
end

function vm16.edit.on_receive_fields(pos, fields, mem)
	if fields.code and (fields.save or fields.compile or fields.assemble or fields.debug) then
		if mem.file_name and mem.server_pos then
			mem.file_text = fields.code
			server.write_file(mem.server_pos, mem.file_name, mem.file_text)
		end
	end
	if fields.cancel then
		mem.file_name = nil
		mem.file_text = nil
		mem.error = nil
	elseif fields.edit then
		mem.error = nil
	elseif mem.file_name and mem.file_text then
		if fields.compile then
			local sts, res = vm16.compile(mem.server_pos, mem.file_name, server.read_file, "asm")
			if sts then
				mem.file_text = res
				mem.file_name = "out.asm"
				mem.file_ext = "asm"
				server.write_file(mem.server_pos, mem.file_name, mem.file_text)
				vm16.files.init(pos, mem)
				mem.error = nil
			else
				mem.error = res
			end
		elseif fields.debug then
			local def = prog.get_cpu_def(mem.cpu_pos)
			if def then
				local prog_pos = def.on_check_connection(mem.cpu_pos)
				if vector.equals(pos, prog_pos) then
					local sts, res = vm16.compile(mem.server_pos, mem.file_name, server.read_file)
					if sts then
						vm16.debug.init(pos, mem, res)
						vm16.watch.init(pos, mem, res)
						mem.error = nil
					else
						mem.error = res
					end
				end
			end
		elseif fields.asmdbg then
			local def = prog.get_cpu_def(mem.cpu_pos)
			if def then
				local prog_pos = def.on_check_connection(mem.cpu_pos)
				if vector.equals(pos, prog_pos) then
					local sts, res = vm16.assemble(mem.server_pos, mem.file_name, server.read_file)
					if sts then
						vm16.debug.init(pos, mem, res)
						vm16.memory.init(pos, mem, res)
						mem.error = nil
					else
						mem.error = res
					end
				end
			end
		end
	end
	vm16.files.on_receive_fields(pos, fields, mem)
end
