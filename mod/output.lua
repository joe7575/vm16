--[[
	vm16
	====

	Copyright (C) 2019-2020 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
	
	Output block for numeric values
]]--

-- for lazy programmers
local M = minetest.get_meta

local function register(src_pos, dest_pos, addr)
	dest_pos = minetest.string_to_pos(dest_pos)
	if dest_pos then
		local node = minetest.get_node(dest_pos)
		if node.name == "vm16:cpu" then
			local ndef = minetest.registered_nodes[node.name]
			ndef.reg_output(dest_pos, addr, src_pos)
		else
			print("[VM16] No CPU position")
		end
	else
		print("[VM16] Invalid position")
	end
end
	
local function formspec(spos, addr, value)
	return "size[6,6.5]"..
		"label[0,0;Output]"..
		"field[1,1.5;5,1;spos;CPU pos: (-1,2,3);"..spos.."]"..
		"field[1,3.0;5,1;addr;I/O port: 0..3;"..addr.."]"..
		"label[1,4.5;Output: "..value.."]"..
		"button_exit[1.5,5.5;3,1;exit;Register]"
end

local function on_receive_fields(pos, formname, fields, player)
	if fields.exit and fields.addr and fields.addr ~= "" and
			fields.spos and fields.spos ~= "" then
		local meta = minetest.get_meta(pos)
		local addr = math.min(tonumber(fields.addr) or 0, 3)
		meta:set_string("spos", fields.spos)
		meta:set_int("addr", addr)
		register(pos, fields.spos, addr)
		meta:set_string("formspec", formspec(fields.spos, addr, "-"))
	end
end

minetest.register_node("vm16:output", {
	description = "VM16 Test Output",
	tiles = {
		"vm16_output.png",
	},
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		M(pos):set_string("formspec", formspec("(0,0,0)", "0", "-"))
	end,
	on_receive_fields = on_receive_fields,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,

	hand_over = function(pos, addr, value)
		print("hand_over", addr, value)
		local meta = minetest.get_meta(pos)
		local spos = meta:get_string("spos")
		meta:set_string("formspec", formspec(spos, addr, value))
		meta:set_string("infotext", "value = "..value)
	end,
})
