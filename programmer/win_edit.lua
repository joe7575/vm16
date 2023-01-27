--[[
	vm16
	====

	Copyright (C) 2019-2023 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Editor window for the debugger
]]--

local version = "1.4"

-- for lazy programmers
local M = minetest.get_meta
local prog = vm16.prog
local server = vm16.server
local file_ext = vm16.file_ext
local file_base = vm16.file_base

local EDIT_SIZE = "0.2,0.6;11.4, 9.6"

local Splashscreen = string.format([[

                 VM16 Programmer
                 ===============

A programming station with compiler, assembler,
editor, debugger, file server and more.

 - Debugger v%s
 - Compiler v%s
 - Assembler v%s
 - vm16 API v%s

Instructions:
 - First click on "Init" to initialize the computer
 - Double-click on a file on the right to open the editor
 - Click "Execute" to directly start the program
 - or click "Debug" to single-step the program
 - or click "Build" to generate a h16-file for a SD Card
 - Use "+", "-" buttons to change the font size
 - Enter a file name and click "New" to generate a new file
 - Copy/paste code from given (read-only) examples

Have fun!
]], version, vm16.Comp.version, vm16.Asm.version, vm16.version)

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


local function fs_editor(pos, mem, fontsize, file, text, background_color)
	local textcolor = server.is_ro_file(mem.server_pos, mem.file_name) and "#AAA" or "#FFF"
	background_color = background_color or "#000"
	-- Also the list-only window needs "editing rights" to be able to copy text
	return "box[" .. EDIT_SIZE .. ";" .. background_color .. "]" ..
		"style_type[textarea;font=mono;textcolor=" .. textcolor .. ";border=false;font_size="  .. fontsize .. "]" ..
		"textarea[" .. EDIT_SIZE .. ";code;File: " .. file .. ";" ..
		minetest.formspec_escape(text) .. "]"
end

local function fs_listing(pos, mem, fontsize, file, text, err)
	return "box[" .. EDIT_SIZE .. ";#000]" ..
		"style_type[textarea;font=mono;textcolor=#AAA;border=false;font_size="  .. fontsize .. "]" ..
		"textarea[" .. EDIT_SIZE .. ";;Listing: " .. file .. ";" ..
		minetest.formspec_escape(add_lineno(pos, text, err)) .. "]"
end

function vm16.edit.formspec(pos, mem, textsize)
	if mem.file_name and mem.file_text and mem.server_pos then
		local background_color = "#000"
		if mem.error then
			-- Output listing + error
			mem.status = "Error !!!"
			vm16.menubar.add_button("edit", "Edit")
			return fs_listing(pos, mem, textsize, "out.lst", mem.file_text , mem.error) ..
				vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
		elseif mem.file_name == "info.txt" then
			vm16.menubar.add_button("cancel", "Close File", 2.2)
			background_color = "#141"
		elseif mem.file_ext == "asm" then
			mem.status = "Edit"
			vm16.menubar.add_button("cancel", "Close File", 2.2)
			if not server.is_ro_file(mem.server_pos, mem.file_name) then
				vm16.menubar.add_button("save", "Save", 1.6)
			end
			vm16.menubar.add_button("build", "Build", 1.6)
			vm16.menubar.add_button("execute", "Execute")
			vm16.menubar.add_button("asmdbg", "Debug")
		elseif mem.file_ext == "c" then
			mem.status = "Edit"
			vm16.menubar.add_button("cancel", "Close File", 2.2)
			if not server.is_ro_file(mem.server_pos, mem.file_name) then
				vm16.menubar.add_button("save", "Save", 1.6)
			end
			vm16.menubar.add_button("compile", "Compile")
			vm16.menubar.add_button("build", "Build", 1.6)
			vm16.menubar.add_button("execute", "Execute")
			vm16.menubar.add_button("debug", "Debug")
		elseif mem.file_ext == "h16" then
			mem.status = "Edit"
			vm16.menubar.add_button("cancel", "Close File", 2.2)
			if not server.is_ro_file(mem.server_pos, mem.file_name) then
				vm16.menubar.add_button("save", "Save", 1.6)
			end
			vm16.menubar.add_button("exe_h16", "Execute")
		else
			vm16.menubar.add_button("cancel", "Close File", 2.2)
			if not server.is_ro_file(mem.server_pos, mem.file_name) then
				vm16.menubar.add_button("save", "Save", 1.6)
			end
		end
		return fs_editor(pos, mem, textsize, mem.file_name, mem.file_text, background_color) ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	else
		vm16.menubar.add_button("init", "Init")
		vm16.menubar.add_button("sdcard", "SD Card")
		return fs_editor(pos, mem, textsize, "-", Splashscreen, "#145") ..
			vm16.files.fs_window(pos, mem, 11.8, 0.6, 6, 9.6, textsize)
	end
end

function vm16.edit.on_load_file(mem, name, text)
	mem.file_name = name
	mem.file_text = text
	mem.file_ext = file_ext(mem.file_name)
	mem.error = nil
end

local function start_cpu(pos, mem, obj)
	mem.cpu_def = prog.get_cpu_def(mem.cpu_pos)
	local mem_size = mem.cpu_def and mem.cpu_def.on_mem_size(mem.cpu_pos) or 3
	vm16.create(mem.cpu_pos, mem_size)
	if vm16.is_loaded(mem.cpu_pos) then
		if obj then
			for _, item in ipairs(obj.lCode) do
				local ctype, lineno, address, opcodes = unpack(item)
				if ctype == "code" then
					for i, opc in pairs(opcodes or {}) do
						vm16.poke(mem.cpu_pos, address + i - 1, opc)
					end
				end
			end
		elseif mem.file_text then
			vm16.write_h16(mem.cpu_pos, mem.file_text)
		end
		vm16.set_pc(mem.cpu_pos, 0)
		local def = prog.get_cpu_def(mem.cpu_pos)
		def.on_start(mem.cpu_pos)
		mem.executing = true
		M(pos):set_int("executing", 1)
		vm16.term.init(pos, mem)
		minetest.get_node_timer(mem.cpu_pos):start(mem.cpu_def.cycle_time)
		vm16.run(mem.cpu_pos, mem.cpu_def, mem.breakpoints)
	end
end

function vm16.edit.on_receive_fields(pos, fields, mem)
	if fields.code and (fields.save or fields.compile or fields.assemble or
				fields.debug or fields.larger or fields.smaller) then
		if mem.file_name and mem.server_pos then
			mem.file_text = fields.code
			server.write_file(mem.server_pos, mem.file_name, mem.file_text)
		end
	end
	if fields.cancel then
		mem.file_name = nil
		mem.file_text = nil
		mem.error = nil
	elseif fields.init then
		minetest.registered_nodes["vm16:programmer"].on_init(pos, mem)
		local text = (server.read_file(mem.server_pos, "info.txt") or "File error") .. "\n\nDone."
		vm16.edit.on_load_file(mem, "info.txt", text)
	elseif fields.sdcard then
		mem.sdcard_active = true
	elseif fields.edit then
		mem.error = nil
	elseif mem.file_name and mem.file_text then
		if fields.compile then
			local def = prog.get_cpu_def(mem.cpu_pos)
			if def then
				local prog_pos = def.on_check_connection(mem.cpu_pos)
				if prog_pos and vector.equals(pos, prog_pos) then
					local options = {
						gen_asm_code = true,
						startup_code = def.startup_code
					}
					local sts, res = vm16.compile(mem.server_pos, mem.file_name, server.read_file, options)
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
				end
			end
		elseif fields.debug then
			local def = prog.get_cpu_def(mem.cpu_pos)
			if def then
				local prog_pos = def.on_check_connection(mem.cpu_pos)
				if prog_pos and vector.equals(pos, prog_pos) then
					local options = {
						startup_code = def.startup_code
					}
					local sts, res = vm16.compile(mem.server_pos, mem.file_name, server.read_file, options)
					if sts then
						vm16.debug.init(pos, mem, res)
						vm16.watch.init(pos, mem, res)
						mem.error = nil
					else
						mem.error = res
					end
				end
			end
		elseif fields.execute then
			local def = prog.get_cpu_def(mem.cpu_pos)
			if def then
				local prog_pos = def.on_check_connection(mem.cpu_pos)
				if prog_pos and vector.equals(pos, prog_pos) then
					local options = {
						startup_code = def.startup_code
					}
					local sts, res
					if mem.file_ext == "asm" then
						sts, res = vm16.assemble(mem.server_pos, mem.file_name, server.read_file)
					else
						sts, res = vm16.compile(mem.server_pos, mem.file_name, server.read_file, options)
					end
					if sts then
						start_cpu(pos, mem, res)
						mem.error = nil
					else
						mem.error = res
					end
				end
			end
		elseif fields.exe_h16 then
			local def = prog.get_cpu_def(mem.cpu_pos)
			if def then
				local prog_pos = def.on_check_connection(mem.cpu_pos)
				if prog_pos and vector.equals(pos, prog_pos) then
					start_cpu(pos, mem)
					mem.error = nil
				end
			end
		elseif fields.build then
			local def = prog.get_cpu_def(mem.cpu_pos)
			if def then
				local prog_pos = def.on_check_connection(mem.cpu_pos)
				if prog_pos and vector.equals(pos, prog_pos) then
					local options = {
						startup_code = def.startup_code
					}
					local sts, res
					if mem.file_ext == "asm" then
						sts, res = vm16.assemble(mem.server_pos, mem.file_name, server.read_file)
					else
						sts, res = vm16.compile(mem.server_pos, mem.file_name, server.read_file, options)
					end
					if sts then
						local first, last, size, h16 = vm16.Asm.generate_h16(res.lCode)
						mem.file_text = h16
						mem.file_name = "out.h16"
						mem.file_ext = "h16"
						server.write_file(mem.server_pos, mem.file_name, mem.file_text)
						vm16.files.init(pos, mem)
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
				if prog_pos and vector.equals(pos, prog_pos) then
					local sts, res = vm16.assemble(mem.server_pos, mem.file_name, server.read_file, true)
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
