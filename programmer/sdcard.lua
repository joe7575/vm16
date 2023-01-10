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
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end

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


local function on_place(itemstack, placer, pointed_thing)
	if pointed_thing.type == "node" then
		local pos = pointed_thing.under
		local playername = placer:get_player_name()
		if placer:get_player_control().sneak then
			local node = minetest.get_node(pos)
			local inv = M(pos):get_inventory()
			if inv:get_size("vm16_sdcard") == 1 and inv:is_empty("vm16_sdcard") then
				itemstack:set_count(0)
				inv:add_item("vm16_sdcard", ItemStack("vm16:sdcard"))
				return itemstack
			end
		end
	end
end

minetest.register_tool("vm16:sdcard", {
	description = "VM16 SD Card",
	inventory_image = "vm16_sdcard.png",
	wield_image = "vm16_sdcard.png",
	groups = {cracky=1, book=1},
	on_use = function() end,
	on_place = function() end,
	node_placement_prediction = "",
	stack_max = 1,
})
