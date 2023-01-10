--[[
	vm16
	====

	Copyright (C) 2019-2023 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	VM16 SD Card
]]--

-- for lazy programmers
local M = minetest.get_meta

function vm16.sdcard.get_data(pos, list, idx)
	local inv = M(pos):get_inventory()
	local stack = inv:get_stack(list, idx)
	local name = stack:get_name()
	if name == "vm16:sdcard" then
		local data = stack:get_meta():to_table().fields
		return data.description, data.fname or "sdcard.txt", data.text or "<new>"
	end
end

function vm16.sdcard.set_data(pos, list, idx, descr, fname, text)
	local inv = M(pos):get_inventory()
	local stack = inv:get_stack(list, idx)
	local name = stack:get_name()
	if name == "vm16:sdcard" then
		local meta = stack:get_meta()
		if descr then
			meta:set_string("description", descr)
		end
		if fname then
			meta:set_string("fname", fname)
		end
		if text then
			meta:set_string("text", text)
		end
		inv:set_stack(list, idx, stack)
		return true
	end
end

minetest.register_craftitem("vm16:sdcard", {
	description = "VM16 SD Card",
	inventory_image = "vm16_sdcard.png",
	wield_image = "vm16_sdcard.png",
	groups = {cracky=1, book=1},
	on_use = function() end,
	on_place = function() end,
	node_placement_prediction = "",
})
