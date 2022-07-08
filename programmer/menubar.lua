--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Menu bar for the debugger
]]--

vm16.menubar = {}

local t = {}

function vm16.menubar.init(x, y, size)
	t.x = x
	t.y = y
	t.size = size
	t.out = {}
	t.on_button = {}
end

function vm16.menubar.add_button(name, label, size)
	size = size or t.size
	table.insert(t.out, "button[" .. t.x .. "," .. t.y .. ";" .. size .. ",0.8;" .. name .. ";" .. label .. "]")
	t.x = t.x + size + 0.1
end

function vm16.menubar.add_separator()
	table.insert(t.out, "box[" .. t.x .. "," .. t.y .. ";" .. "0.05" .. ",0.8;#FFF]")
	t.x = t.x + 0.2
end

function vm16.menubar.add_textfield(name, label, text, size)
	table.insert(t.out, "field[" .. t.x .. "," .. (t.y + 0.1) .. ";" .. size .. ",0.6;" .. name .. ";" .. label .. ";" .. text .. "]")
	t.x = t.x + size + 0.1
end

function vm16.menubar.finalize()
	return table.concat(t.out, "")
end
