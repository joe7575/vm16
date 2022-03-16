--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Editor window for the debugger
]]--

vm16.edit = {}

local function fs_listing(pos, lText, err)
	local out = {}
	if err then
		out[#out + 1] = err
		out[#out + 1] = ""
	end
	for i, line in ipairs(lText) do
		local lineno = string.format("%3d: ", i)
		out[#out + 1] = lineno .. line
	end
	return table.concat(out, "\n")
end

function vm16.edit.init(pos, mem)
end

function vm16.edit.fs_editor(pos, mem, x, y, xsize, ysize, fontsize, file, text)
	local color = mem.running and "#AAA" or "#FFF"
	return "box[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";#000]" ..
		"style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. fontsize .. "]" ..
		"textarea[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";code;File: " .. file .. ";" ..
		minetest.formspec_escape(text) .. "]"
end

function vm16.edit.fs_listing(pos, mem, x, y, xsize, ysize, fontsize, file, lText, err)
	local color = mem.running and "#AAA" or "#FFF"
	return "box[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";#000]" ..
		"style_type[textarea;font=mono;textcolor=#FFF;border=false;font_size="  .. fontsize .. "]" ..
		"textarea[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";;Listing: " .. file .. ";" ..
		minetest.formspec_escape(fs_listing(pos, lText, err)) .. "]"
end
