--[[
	vm16
	====

	Copyright (C) 2019-2020 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
	
	Input block for numeric values
]]--

-- for lazy programmers
local M = minetest.get_meta

local function send(spos, addr, value)
	local pos = minetest.string_to_pos(spos)
	if pos then
		local node = minetest.get_node(pos)
		if node.name == "vm16:cpu" then
			local ndef = minetest.registered_nodes[node.name]
			ndef.hand_over(pos, addr, value)
		else
			print("[VM16] No CPU position")
		end
	else
		print("[VM16] Invalid position")
	end
end
	
local function formspec(spos, addr, value)
	return "size[6,6.5]"..
		"label[0,0;Input]"..
		"field[1,1.5;5,1;spos;Pos: (-1,2,3);"..spos.."]"..
		"field[1,3.0;5,1;addr;Address: 0..3;"..addr.."]"..
		"field[1,4.5;5,1;value;Value: 0..65535;"..value.."]"..
		"button_exit[2,5.5;2,1;exit;Send]"
end

local function on_receive_fields(pos, formname, fields, player)
	if fields.exit and fields.value and fields.value ~= "" and 
			fields.addr and fields.addr ~= "" and
			fields.spos and fields.spos ~= "" then
		local addr = math.min(tonumber(fields.addr) or 0, 3)
		local value = math.min(tonumber(fields.value) or 0, 65535)
		send(fields.spos, addr, value)
		M(pos):set_string("formspec", formspec(fields.spos, addr, value))
	end
end

minetest.register_node("vm16:input", {
	description = "VM16 Test Input",
	tiles = {
		"vm16_input.png",
	},
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		M(pos):set_string("formspec", formspec("(0,0,0)", "0", "1"))
	end,
	on_receive_fields = on_receive_fields,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,
})
