--[[
	vm16
	====

	Copyright (C) 2019-2023 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	File list window for the debugger
]]--

-- for lazy programmers
local M = minetest.get_meta
local prog = vm16.prog
local server = vm16.server

vm16.files = {}

local function open_file(mem, index)
	if mem.server_pos then
		mem.file_cursor = index
		local names = server.get_filelist(mem.server_pos)
		if names then
			local item = names[index] or names[1]
			if item then
				local text = server.read_file(mem.server_pos, item.name)
				vm16.edit.on_load_file(mem, item.name, text)
			end
		end
	end
end

local function get_file_name(mem, index)
	if mem.server_pos then
		mem.file_cursor = index
		local names = server.get_filelist(mem.server_pos)
		if names then
			local item = names[index] or names[1]
			if item then
				return item.name
			end
		end
	end
end
local function set_cursor(mem, index)
	mem.file_cursor = index
end

local function new_file(mem, name)
	if mem.server_pos then
		server.write_file(mem.server_pos, name, "<new>")
	end
end

local function format_files(pos, mem)
	if mem.server_pos then
		local names = server.get_filelist(mem.server_pos)
		local out = {}
		for _, item in ipairs(names or {}) do
			local s = string.format("%-20s %s", item.name, item.attr)
			out[#out + 1] = s
		end
		return table.concat(out, ",")
	end
	return ""
end

-------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------
function vm16.files.init(pos, mem)
end

function vm16.files.create_file(mem, name, text)
	if mem.server_pos then
		server.write_file(mem.server_pos, name, text)
	end
end

function vm16.files.read_file(mem, name)
	if mem.server_pos then
		return server.read_file(mem.server_pos, name)
	end
end

function vm16.files.write_file(mem, name, text)
	if mem.server_pos then
		server.write_file(mem.server_pos, name, text)
	end
end
function vm16.files.remove_file(mem, name)
	if mem.server_pos then
		server.write_file(mem.server_pos, name, "")
	end
end

function vm16.files.rename_file(mem, old_name, new_name)
	if mem.server_pos then
		server.rename_file(mem.server_pos, old_name, new_name)
	end
end

function vm16.files.fs_window(pos, mem, x, y, xsize, ysize, fontsize)
	local color = mem.running and "#AAA" or "#FFF"

	if not mem.sdcard_active then
		vm16.menubar.add_separator()
		vm16.menubar.add_textfield("name", "", "", 2.5)
		vm16.menubar.add_button("new", "New", 1.6)
	end

	return "label[" .. x .. "," .. (y - 0.2) .. ";Files]" ..
		"style_type[table;font=mono;font_size="  .. fontsize .. "]" ..
		"tableoptions[color=" ..color .. ";highlight_text=" ..color .. ";highlight=#63007E]" ..
		"field_close_on_enter[name;false]" ..
		"table[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";files;" ..
		format_files(pos, mem) .. ";]"
end

function vm16.files.on_receive_fields(pos, fields, mem)
	if fields.files then
		local evt = minetest.explode_table_event(fields.files)
		if evt.type == "DCL" then
			open_file(mem, tonumber(evt.row))
			mem.selected_file = nil
			return true
		elseif evt.type == "CHG" then
			set_cursor(mem, tonumber(evt.row))
			mem.selected_file = get_file_name(mem, tonumber(evt.row))
			return true
		end
	elseif fields.name and fields.name ~= "" then
		mem.selected_file = nil
		if fields.new or fields.key_enter_field == "name" then
			new_file(mem, fields.name)
			return true
		end
	end
end
