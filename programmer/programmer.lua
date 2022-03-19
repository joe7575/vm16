--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	VM16 Programming Station
]]--

-- for lazy programmers
local M = minetest.get_meta
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end
local prog = vm16.prog

local function cpu_server_pos(pos, mem)
	mem.cpu_pos = mem.cpu_pos or S2P(M(pos):get_string("cpu_pos"))
	mem.server_pos = mem.server_pos or S2P(M(pos):get_string("server_pos"))
	return mem.cpu_pos and mem.server_pos
end

local function preserve_cpu_server_pos(pos, itemstack)
	local imeta = itemstack:get_meta()
	if imeta then
		local meta = M(pos)
		meta:set_string("cpu_pos", imeta:get_string("cpu_pos"))
		meta:set_string("server_pos", imeta:get_string("server_pos"))
	end
end

local function init(pos, mem)
	local def = prog.get_cpu_def(mem.cpu_pos)
	vm16.server.init(mem.server_pos)
	vm16.files.init(pos, mem)
	def.on_init(mem.cpu_pos, pos)
end

minetest.register_node("vm16:programmer", {
	description = "VM16 Programmer",
	drawtype = "nodebox",
	paramtype2 = "facedir",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 5,
	glow = 12,
	use_texture_alpha = "clip",
	node_box = {
		type = "fixed",
		fixed = {
			{-12/32, -16/32,  -8/32,  12/32, -14/32, 12/32},
			{-12/32, -14/32,  12/32,  12/32,   6/32, 14/32},
		},
	},
	tiles = {
		-- up, down, right, left, back, front
		'vm16_programmer_top.png',
		'vm16_programmer_bottom.png',
		'vm16_programmer_side.png',
		'vm16_programmer_side.png',
		'vm16_programmer_bottom.png^vm16_logo.png',
		"vm16_programmer_front.png",
	},
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local mem = prog.get_mem(pos)
		preserve_cpu_server_pos(pos, itemstack)
		local meta = M(pos)
		meta:set_string("formspec", prog.fs_connect(mem))
		meta:set_string("infotext", "VM16 Programmer")
		if cpu_server_pos(pos, mem) then
			init(pos, mem)
		end
	end,
	on_rightclick = function(pos)
		local mem = prog.get_mem(pos)
		if cpu_server_pos(pos, mem) and mem.running then
			M(pos):set_string("formspec", vm16.prog.formspec(pos, mem))
		end
	end,
	on_receive_fields = function(pos, formname, fields, player)
		local mem = prog.get_mem(pos)
		if cpu_server_pos(pos, mem) then
			local def = prog.get_cpu_def(mem.cpu_pos)
			vm16.prog.on_receive_fields(pos, formname, fields, player, def.callbacks)
		end
	end,
	after_dig_node = function(pos)
		local mem = prog.get_mem(pos)
		if cpu_server_pos(pos, mem) then
			vm16.destroy(mem.cpu_pos)
		end
	end,
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type == "node" then
			local name = user and user:get_player_name()
			local pos = pointed_thing.under
			if not user or minetest.is_protected(pos, user:get_player_name()) then
				minetest.chat_send_player(name, "[vm16] Error: Protected position!")
				return
			end
			local node = minetest.get_node(pos)
			if prog.get_cpu_def(pos) then
				local meta = itemstack:get_meta()
				meta:set_string("cpu_pos", P2S(pos))
				minetest.chat_send_player(name, "[vm16] Connected to CPU")
			elseif node.name == "vm16:server" then
				local meta = itemstack:get_meta()
				meta:set_string("server_pos", P2S(pos))
				minetest.chat_send_player(name, "[vm16] Connected to Server")
			end
		end
		return itemstack
	end,
	preserve_metadata = function(pos, oldnode, oldmetadata, drops)
		local meta = drops[1]:get_meta()
		meta:set_string("cpu_pos", oldmetadata.cpu_pos)
		meta:set_string("server_pos", oldmetadata.server_pos)
	end,
	stack_max = 1,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,
})

minetest.register_lbm({
	label = "vm16 Programmer",
	name = "vm16:programmer",
	nodenames = {"vm16:programmer"},
	run_at_every_load = true,
	action = function(pos, node)
		local mem = prog.get_mem(pos)
		if cpu_server_pos(pos, mem) then
			init(pos, mem)
			M(pos):set_string("formspec", vm16.prog.formspec(pos, mem))
		end
	end
})

function vm16.add_ro_file(pos, filename, text)
	local mem = prog.get_mem(pos)
	if cpu_server_pos(pos, mem) then
		vm16.server.add_ro_file(mem.server_pos, filename, text)
	end
end

function vm16.update_programmer(cpu_pos, pos, resp)
	print("on_update", vm16.CallResults[resp])
	local mem = prog.get_mem(pos)
	vm16.debug.on_update(pos, mem)
	M(pos):set_string("formspec", prog.formspec(pos, mem))
end

function vm16.putchar(pos, val)
	local mem = prog.get_mem(pos)
	if val1 == 0 then
		mem.output = ""
	elseif mem.output and #mem.output < 80 then
		mem.output = mem.output .. prog.to_string(val)
	end
end