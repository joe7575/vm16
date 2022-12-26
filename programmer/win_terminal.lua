--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Programmer terminal window
]]--

-- for lazy programmers
local M = minetest.get_meta
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = minetest.string_to_pos

vm16.term = {}
local term = vm16.term
local prog = vm16.prog

local NUM_LINES = 25
local MAX_STR_LEN = 60
local TERM_SIZE = "0.2,0.6;11.4, 9.6"

local function count_lines(str)
	return select(2, string.gsub(str, "\n", ""))
end

local function del_first_line(text)
	local first, _ = string.find(text, "\n", 1)
	return string.sub(text, first + 1)
end

local function limit_num_lines(text)
	local num = count_lines(text)
	while num >= NUM_LINES do
		text = del_first_line(text)
		num = num - 1
	end
	return text
end

local function fs_window(pos, mem, textsize)
	return "box[" .. TERM_SIZE .. ";#000]" ..
		"style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. textsize .. "]" ..
		"textarea[" .. TERM_SIZE .. ";;Terminal;" .. mem.term_text .. "]"
end

function vm16.term.formspec(pos, mem, textsize)
	vm16.menubar.add_button("close", "Close")
	mem.term_text = mem.term_text or ">"
	return fs_window(pos, mem, textsize)
end

local function bell(pos)
	minetest.sound_play("vm16_beep", {
		pos = pos,
		gain = 1,
		max_hear_distance = 5})
end

local function clear_screen(pos, mem)
	mem.term_text = ">"
	mem.last_line = ""
	if mem.ttl and mem.ttl > minetest.get_gametime() then
		M(pos):set_string("formspec", vm16.prog.formspec(pos, mem))
	end
end

local function new_line(pos, mem)
	if mem.term_text == ">" or mem.term_text == "" then
		mem.term_text = minetest.formspec_escape(mem.last_line)
	else
		mem.term_text = mem.term_text .. "\n" .. minetest.formspec_escape(mem.last_line)
	end
	mem.term_text = limit_num_lines(mem.term_text)
	mem.last_line = ""
	if mem.ttl and mem.ttl > minetest.get_gametime() then
		M(pos):set_string("formspec", vm16.prog.formspec(pos, mem))
	end
end

local function putchar(pos, mem, val)
	if val == 0 then
		return
	elseif val == 7 then  -- bell ('\a')
		bell(pos, mem)
	elseif val == 8 then  -- backspace ('\b')
		clear_screen(pos, mem)
	elseif val == 9 then  -- tab ('\t')
		local n = 8 - (#mem.last_line % 8)
		for i = 1,n do
			mem.last_line = mem.last_line .. " "
		end
	elseif val == 10 then  -- line feed ('\n')
		new_line(pos, mem)
	elseif #mem.last_line < MAX_STR_LEN then
		mem.last_line = mem.last_line .. prog.to_char(val)
	end
end

function vm16.term.putchar(pos, val)
	local mem = prog.get_mem(pos)
	mem.term_text = mem.term_text or ""
	mem.last_line = mem.last_line or ""

	if val > 255 then
		putchar(pos, mem, val / 256)
		putchar(pos, mem, val % 256)
	else
		putchar(pos, mem, val)
	end
end

function vm16.term.on_receive_fields(pos, fields, mem)
	if fields.close then
		mem.term_active = false
	end
end
