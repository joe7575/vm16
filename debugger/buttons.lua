--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Button row for the debugger
]]--

local t = {}
vm16.button = t

function vm16.button.init(x, y, size)
	t.x = x
	t.y = y
	t.size = size
	t.out = {}
	t.on_button = {}
end

function vm16.button.on_receive_fields(pos, mem, fields, clbks)
	for k,v in pairs(fields) do
		if t.on_button[k] then
			t.on_button[k](pos, mem, fields, clbks)
			return true
		end
	end
end

function vm16.button.add(name, label, on_button)
	table.insert(t.out, "button[" .. t.x .. "," .. t.y .. ";" .. t.size .. ",0.8;" .. name .. ";" .. label .. "]")
	t.x = t.x + t.size + 0.2
	t.on_button[name] = on_button
end

function vm16.button.fs_buttons()
	return table.concat(t.out, "")
end
