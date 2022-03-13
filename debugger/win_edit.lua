--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Editor window for the debugger
]]--

vm16.edit = {}

function vm16.edit.init(pos, mem)
end

function vm16.edit.fs_window(pos, mem, x, y, xsize, ysize, fontsize, file, text)
	local color = mem.running and "#AAA" or "#FFF"
	return "box[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";#000]" ..
		"style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. fontsize .. "]" ..
		"textarea[0.2,0.6;8.5,9.6;code;File: " .. file .. ";" ..
		minetest.formspec_escape(text) .. "]"
end
