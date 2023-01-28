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
local debug = vm16.debug
local term = vm16.term

local CpuTime = 0
local RunTime = 0
local SCREENSAVER_TIME = 60 * 5

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

local function programmer_present(prog_pos)
	if prog_pos then
		local node = minetest.get_node(prog_pos)
		return node and (node.name == "vm16:programmer" or node.name == "vm16:programmer2")
	end
end

local function init(pos, mem)
	if mem.cpu_pos and mem.server_pos then
		mem.executing = M(pos):get_int("executing") == 1
		local def = prog.get_cpu_def(mem.cpu_pos)
		if def then
			vm16.server.init(mem.server_pos, def.cpu_type)
			vm16.files.init(pos, mem)
			def.on_init(mem.cpu_pos, pos, mem.server_pos)
		end
	end
end

local function after_place_node(pos, placer, itemstack, pointed_thing)
	local inv = M(pos):get_inventory()
	inv:set_size('vm16_sdcard', 1)
	local mem = prog.get_mem(pos)
	preserve_cpu_server_pos(pos, itemstack)
	local meta = M(pos)
	meta:set_string("infotext", "VM16 Programmer")
	if cpu_server_pos(pos, mem) then
		init(pos, mem)
		meta:set_string("formspec", prog.formspec(pos, mem))
	end
end

local function on_rightclick(pos)
	local mem = prog.get_mem(pos)
	mem.ttl = minetest.get_gametime() + SCREENSAVER_TIME
	M(pos):set_string("formspec", vm16.prog.formspec(pos, mem))
end

local function on_receive_fields(pos, formname, fields, player)
	local mem = prog.get_mem(pos)
	if cpu_server_pos(pos, mem) then
		mem.cpu_def = mem.cpu_def or prog.get_cpu_def(mem.cpu_pos)
		mem.ttl = minetest.get_gametime() + SCREENSAVER_TIME
		vm16.prog.on_receive_fields(pos, formname, fields, player)
	end
end

local function after_dig_node(pos)
	prog.del_mem(pos)
end

local function on_use(itemstack, user, pointed_thing)
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
		elseif node.name == "vm16:server" or node.name == "vm16:server2" then
			local meta = itemstack:get_meta()
			meta:set_string("server_pos", P2S(pos))
			minetest.chat_send_player(name, "[vm16] Connected to Server")
		end
	end
	return itemstack
end

local function preserve_metadata(pos, oldnode, oldmetadata, drops)
	local meta = drops[1]:get_meta()
	meta:set_string("cpu_pos", oldmetadata.cpu_pos)
	meta:set_string("server_pos", oldmetadata.server_pos)
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if stack:get_name() == "vm16:sdcard" then
		return 1
	end
	return 0
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
	after_place_node = after_place_node,
	on_rightclick = on_rightclick,
	on_receive_fields = on_receive_fields,
	after_dig_node = after_dig_node,
	on_init = init,
	on_use = on_use,
	preserve_metadata = preserve_metadata,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	stack_max = 1,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,
})

minetest.register_node("vm16:programmer2", {
	description = "VM16 Programmer",
	paramtype2 = "facedir",
	tiles = {
		-- up, down, right, left, back, front
		'vm16_programmer2_top.png',
		'vm16_programmer2_top.png',
		'vm16_programmer2_side.png',
		'vm16_programmer2_side.png',
		'vm16_programmer2_side.png',
		"vm16_programmer2_front.png",
	},
	after_place_node = after_place_node,
	on_rightclick = on_rightclick,
	on_receive_fields = on_receive_fields,
	after_dig_node = after_dig_node,
	on_use = on_use,
	preserve_metadata = preserve_metadata,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	stack_max = 1,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,
})


minetest.register_lbm({
	label = "vm16 Programmer",
	name = "vm16:programmer",
	nodenames = {"vm16:programmer", "vm16:programmer2"},
	run_at_every_load = true,
	action = function(pos, node)
		local mem = prog.get_mem(pos)
		if cpu_server_pos(pos, mem) then
			init(pos, mem)
			M(pos):set_string("formspec", vm16.prog.formspec(pos, mem))
		end
	end
})

-------------------------------------------------------------------------------
-- CPU API
-------------------------------------------------------------------------------
function vm16.load_cpu(cpu_pos, prog_pos, cpu_def)
	if cpu_pos then
		if programmer_present(prog_pos) then
			local mem = prog.get_mem(prog_pos)
			mem.cpu_def = cpu_def
		end
		vm16.on_load(cpu_pos)
	end
end

function vm16.register_ro_file(cpu_type, filename, text)
	vm16.server.register_ro_file(cpu_type, filename, text)
end

function vm16.write_file(pos, filename, text)
	if pos and filename and text then
		vm16.server.write_file(pos, filename, text)
	end
end

function vm16.keep_running(cpu_pos, prog_pos, cpu_def)
	local mem

	if programmer_present(prog_pos) then
		mem = prog.get_mem(prog_pos)
		mem.cpu_def = cpu_def
		mem.running = vm16.is_loaded(cpu_pos)
	else
		mem = {}
	end
	if vm16.is_loaded(cpu_pos) then
		local t = minetest.get_us_time()
		local resp = vm16.run(cpu_pos, cpu_def, mem.breakpoints)
		CpuTime = CpuTime + (minetest.get_us_time() - t)
		if RunTime < minetest.get_gametime() then
			minetest.log("action", "[vm16] Generated CPU load = " .. math.floor(CpuTime/1000000) .. "s/h")
			RunTime = minetest.get_gametime() + 3600
			CpuTime = 0
		end
		return resp < vm16.HALT
	end
end

function vm16.update_programmer(cpu_pos, prog_pos, resp)
	if programmer_present(prog_pos) then
		local mem = prog.get_mem(prog_pos)
		debug.on_update(prog_pos, mem, resp)
		M(prog_pos):set_string("formspec", prog.formspec(prog_pos, mem))
	end
end

function vm16.set_stdout(prog_pos, val)
	if programmer_present(prog_pos) then
		M(prog_pos):set_int("stdout", val)
	end
end

function vm16.putchar(prog_pos, val)
	if programmer_present(prog_pos) then
		local stdout = M(prog_pos):get_int("stdout")
		if stdout == 1 then
			return term.putchar(prog_pos, val)
		else
			local mem = prog.get_mem(prog_pos)
			if val == 0 then
				mem.output = ""
			elseif mem.output and #mem.output < 80 then
				mem.output = mem.output .. prog.to_string(val)
			end
		end
	end
end

function vm16.getchar(prog_pos)
	return 0  -- no char
end

function vm16.unload_cpu(cpu_pos, prog_pos)
	if cpu_pos then
		vm16.destroy(cpu_pos)
	end
end

function vm16.cpu_started(prog_pos, pos)
	-- CPU is started from extern => Reset programmer
	local mem = prog.get_mem(prog_pos)
	mem.executing = true
	M(pos):set_int("executing", 1)
	mem.term_active = false
	mem.sdcard_active = false
	mem.file_name = nil
	mem.file_text = nil
	mem.file_ext = nil
	mem.error = nil
end