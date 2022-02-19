--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	VM16 On/Off Switch
]]--

-- for lazy programmers
local M = minetest.get_meta
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end

local DESCRIPTION = "VM16 On/Off Switch"

local function switch_on(pos, node, player, color)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	if player and M(pos):get_int("address") == 0 then
		return
	end
	if node.name == "vm16:switch_off" then
		node.name = "vm16:switch_on"
		minetest.swap_node(pos, node)
		local cpu_pos = S2P(M(pos):get_string("cpu_pos"))
		if cpu_pos then
			vm16.input_data(cpu_pos, M(pos):get_int("address"), 1)
		end
		minetest.sound_play("button", {
				pos = pos,
				gain = 0.5,
				max_hear_distance = 5,
			})
	end
end

local function switch_off(pos, node, player)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	if node.name == "vm16:switch_on" then
		node.name = "vm16:switch_off"
		minetest.swap_node(pos, node)
		local cpu_pos = S2P(M(pos):get_string("cpu_pos"))
		if cpu_pos then
			vm16.input_data(cpu_pos, M(pos):get_int("address"), 0)
		end
		minetest.sound_play("button", {
				pos = pos,
				gain = 0.5,
				max_hear_distance = 5,
			})
	end
end

local function on_vm16_start_cpu(pos, cpu_pos)
	M(pos):set_string("cpu_pos", P2S(cpu_pos))
	return M(pos):get_int("address")
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

minetest.register_node("vm16:switch_off", {
	description = DESCRIPTION,
	tiles = {
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_switch_off.png",
	},

	after_place_node = function(pos, placer)
		M(pos):set_string("infotext", DESCRIPTION)
		M(pos):set_string("formspec", formspec())
	end,

	on_rightclick = switch_on,
	on_receive_fields = on_receive_fields,
	on_vm16_start_cpu = on_vm16_start_cpu,

	paramtype2 = "facedir",
	groups = {choppy=2, cracky=2, crumbly=2},
	is_ground_content = false,
	sounds = default.node_sound_defaults(),
})


minetest.register_node("vm16:switch_on", {
	description = DESCRIPTION,
	tiles = {
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_switch_on.png",
	},

	on_rightclick = switch_off,
	on_receive_fields = on_receive_fields,
	on_vm16_start_cpu = on_vm16_start_cpu,

	paramtype = "light",
	sunlight_propagates = true,
	light_source = 8,
	paramtype2 = "facedir",
	groups = {choppy=2, cracky=2, crumbly=2, not_in_creative_inventory=1},
	is_ground_content = false,
	sounds = default.node_sound_defaults(),
	drop = "vm16:switch_off",
})

vm16.register_io_nodes({"vm16:switch_on", "vm16:switch_off"})

minetest.register_craft({
	output = "vm16:switch_off",
	recipe = {
		{"", "group:wood", ""},
		{"", "default:obsidian_glass", ""},
		{"", "basic_materials:ic", ""},
	},
})
