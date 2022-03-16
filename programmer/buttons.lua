--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Button row for the debugger
]]--

vm16.button = {}

local t = {}

function vm16.button.init(x, y, size)
	t.x = x
	t.y = y
	t.size = size
	t.out = {}
	t.on_button = {}
end

function vm16.button.add(name, label)
	table.insert(t.out, "button[" .. t.x .. "," .. t.y .. ";" .. t.size .. ",0.8;" .. name .. ";" .. label .. "]")
	t.x = t.x + t.size + 0.2
end

function vm16.button.fs_buttons()
	return table.concat(t.out, "")
end
