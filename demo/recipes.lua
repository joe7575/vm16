--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Missing recipes for programmer and server
]]--

minetest.register_craft({
	output = "vm16:programmer",
	recipe = {
		{"basic_materials:steel_strip", "default:obsidian_glass", ""},
		{"basic_materials:ic", "basic_materials:ic", "basic_materials:ic"},
		{"basic_materials:steel_strip", "basic_materials:gold_wire", "basic_materials:copper_wire"},
	},
})

minetest.register_craft({
	output = "vm16:server",
	recipe = {
		{"dye:black", "basic_materials:copper_wire", "dye:black"},
		{"basic_materials:ic", "basic_materials:ic", "basic_materials:ic"},
		{"default:steelblock", "basic_materials:gold_wire", "default:steelblock"},
	},
})

