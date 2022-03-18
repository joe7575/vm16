--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Variables watch window for the debugger
]]--

-- for lazy programmers
local M = minetest.get_meta
local prog = vm16.prog

vm16.files = {}

-------------------------------------------------------------------------------
-- Primitives
-------------------------------------------------------------------------------
local function get_file_list(mem)
	if mem.server_pos then
		local meta = M(mem.server_pos)
		local s = M(mem.server_pos):get_string("files")
		local files = minetest.deserialize(s) or {}
		local t = {}
		for name, text in pairs(files) do
			t[#t + 1] = name
		end
		table.sort(t)
		return files, t
	end
	return {}, {}
end

local function write_file(mem, files, name, text)
	local meta = M(mem.server_pos)
	print(dump(text))
	if text ~= "" then
		files[name] = text
	else
		files[name] = nil
	end
	local s = minetest.serialize(files)
	meta:set_string("files", s)
end

local function rename_file(mem, files, old_name, new_name)
	local meta = M(mem.server_pos)
	files[new_name] = files[old_name]
	files[old_name] = nil
	local s = minetest.serialize(files)
	meta:set_string("files", s)
end

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------
local function open_file(mem, index)
	mem.file_cursor = index
	local files, names = get_file_list(mem)
	local name = names[index] or names[1]
	vm16.edit.on_load_file(mem, name, files[name] or "")
end

local function set_cursor(mem, index)
	mem.file_cursor = index
end

local function new_file(mem, name)
	local files, names = get_file_list(mem)
	print("new_file", dump(files), dump(names))
	write_file(mem, files, name, "<new>")
end

local function format_files(pos, mem)
	local _, names = get_file_list(mem)
	print("format_files", dump(names))
	local lines = {}
	for _, name in ipairs(names or {}) do
		local s = string.format("%-16s rw", name)
		lines[#lines + 1] = s
	end
	return table.concat(lines, ",")
end

-------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------
function vm16.files.store_file(mem, name, text)
	if name and text then
		local files, _ = get_file_list(mem)
		write_file(mem, files, name, text)
	end
end

function vm16.files.get_current_file(mem)
	local files, names = get_file_list(mem)
	local name = names[mem.file_cursor] or names[1] or ""
	return name, files[name] or ""
end

function vm16.files.init(pos, mem)
end

function vm16.files.fs_window(pos, mem, x, y, xsize, ysize, fontsize)
	local color = mem.running and "#AAA" or "#FFF"

	vm16.menubar.add_separator()
	vm16.menubar.add_textfield("name", "", "", 2.5)
	vm16.menubar.add_button("new", "New", 1.6)

	return "label[" .. x .. "," .. (y - 0.2) .. ";Files]" ..
		"style_type[table;font=mono;font_size="  .. fontsize .. "]" ..
		"tableoptions[color=" ..color .. ";highlight_text=" ..color .. ";highlight=#63007E]" ..
		"table[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";files;" .. 
		format_files(pos, mem) .. ";]"
end

function vm16.files.on_receive_fields(pos, fields, mem)
	print(dump(fields))
	if fields.files then
		local evt = minetest.explode_table_event(fields.files)
		if evt.type == "DCL" then
			open_file(mem, tonumber(evt.row))
			return true
		elseif evt.type == "CHG" then
			set_cursor(mem, tonumber(evt.row))
			return true
		end
	elseif fields.name and fields.name ~= "" then
		if fields.new then
			new_file(mem, fields.name)
			return true
		end
	end
end
