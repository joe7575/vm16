--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Simple CPU for testing purposes
]]--

-- for lazy programmers
local M = minetest.get_meta
local prog = vm16.prog


function vm16.prog.formspec(pos, mem)
	local textsize = M(pos):get_int("textsize")
	if textsize >= 0 then
		textsize = "+" .. textsize
	else
		textsize = tostring(textsize)
	end

	vm16.button.init(0.2, 10.4, 2.5)

	local windows
	if vm16.is_loaded(pos) then
		mem.status = "Debug"
		windows = vm16.debug.formspec(pos, mem, textsize)
	else
		mem.status = "Edit"
		windows = vm16.edit.formspec(pos, mem, textsize)
	end
	
	return "formspec_version[4]" ..
		"size[18,12]" ..
		"button[16.6,0;0.6,0.6;larger;+]" ..
		"button[17.2,0;0.6,0.6;smaller;-]" ..
		windows ..
		vm16.button.fs_buttons() ..
		"box[0.2,11.3;17.6,0.05;#FFF]" ..
		"style_type[label;font=normal;textcolor=#FFF;font_size=+0]" ..
		"label[0.3,11.7;Mode: " .. mem.status .. "]"
end

function prog.on_receive_fields(pos, formname, fields, player, clbks)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return
	end

	local mem = prog.get_mem(pos)
	if fields.larger then
		M(pos):set_int("textsize", math.min(M(pos):get_int("textsize") + 1, 8))
	elseif fields.smaller then
		M(pos):set_int("textsize", math.max(M(pos):get_int("textsize") - 1, -8))
	elseif vm16.is_loaded(pos) then
		vm16.debug.on_receive_fields(pos, fields, mem, clbks)
	else
		mem.running = nil
		vm16.edit.on_receive_fields(pos, fields, mem)
	end
	M(pos):set_string("formspec", vm16.prog.formspec(pos, mem))
end
