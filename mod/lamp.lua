--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	VM16 Color Lamp
]]--

-- for lazy programmers
local M = minetest.get_meta
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end

local DESCRIPTION = "VM16 Color Lamp"

local function switch_on(pos, node, player, color)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	if player and M(pos):get_int("address") == 0 then
		return
	end
	if node.name == "vm16:lamp_off" or node.name == "vm16:lamp_on" then
		node.name = "vm16:lamp_on"
		node.param2 = (tonumber(color) or 0) % 64
		minetest.swap_node(pos, node)
	end
end

local function switch_off(pos, node, player)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	if node.name == "vm16:lamp_on" then
		node.name = "vm16:lamp_off"
		node.param2 = 50
		minetest.swap_node(pos, node)
	end
end

local function on_vm16_start_cpu(pos, cpu_pos)
	M(pos):set_string("cpu_pos", P2S(cpu_pos))
	return M(pos):get_int("address")
end

local function on_vm16_output(pos, addr, value)
	local node = minetest.get_node(pos)
	switch_on(pos, node, nil, value)
end

local function formspec()
	return "size[4,2]"..
		"field[0.2,0.8;3.8,1;addr;I/O port: (1 - 65535);]"..
		"button_exit[1.0,1.2;2,1;exit;Save]"
end

local function on_receive_fields(pos, formname, fields, player)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	if fields.exit and fields.addr then
		local address = tonumber(fields.addr) or 1
		local meta = M(pos)
		meta:set_int("address", address)
		meta:set_string("infotext", DESCRIPTION .. " #" .. address)
		meta:set_string("formspec", "")
	end
end

minetest.register_node("vm16:lamp_off", {
	description = DESCRIPTION,
	tiles = {"vm16_lamp.png"},

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		M(pos):set_string("infotext", DESCRIPTION)
		M(pos):set_string("formspec", formspec())
		local node = minetest.get_node(pos)
		node.param2 = 50
		minetest.swap_node(pos, node)
	end,

	on_rightclick = switch_on,
	on_receive_fields = on_receive_fields,
	on_vm16_start_cpu = on_vm16_start_cpu,
	on_vm16_output = on_vm16_output,

	paramtype = "light",
	paramtype2 = "color",
	palette = "vm16_palette64.png",
	sunlight_propagates = true,
	light_source = 0,
	drop = "vm16:lamp_off",
	groups = {choppy=2, cracky=2, crumbly=2},
	is_ground_content = false,
	sounds = default.node_sound_defaults(),
})


minetest.register_node("vm16:lamp_on", {
	description = DESCRIPTION,
	tiles = {"vm16_lamp.png"},

	on_rightclick = switch_off,
	on_receive_fields = on_receive_fields,
	on_vm16_start_cpu = on_vm16_start_cpu,
	on_vm16_output = on_vm16_output,

	paramtype = "light",
	paramtype2 = "color",
	palette = "vm16_palette64.png",
	sunlight_propagates = true,
	light_source = 10,
	groups = {choppy=2, cracky=2, crumbly=2, not_in_creative_inventory=1},
	is_ground_content = false,
	sounds = default.node_sound_defaults(),
	drop = "vm16:lamp_off",
})

vm16.register_io_nodes({"vm16:lamp_off", "vm16:lamp_on"})

minetest.register_craft({
	output = "vm16:lamp_off",
	recipe = {
		{"", "wool:white", ""},
		{"", "default:mese_post_light", ""},
		{"", "basic_materials:ic", ""},
	},
})
