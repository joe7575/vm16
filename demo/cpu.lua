--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Simple CPU for demo purposes
]]--

-- for lazy programmers
local M = minetest.get_meta
local H = minetest.hash_node_position
local MP = minetest.get_modpath("vm16")
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end

local Files = dofile(MP .. "/demo/files.lua")
local RADIUS = 3    -- for I/O nodes

local Inputs = {}   -- [hash] = {addr = value}
local Outputs = {}  -- [hash] = {addr = pos}
local IONodes = {}  -- Known I/O nodes

-- Will be added to the programmer file system as read-only TXT-file.
-- Can be used as CPU description.
local Info = [[
       VM16 Demo Computer
       ==================

VM16 Demo Computer is a demo CPU
with 1024 words of RAM and two additional blocks
for input and output examples.

Learn more about vm16 on:
https://github.com/joe7575/vm16/wiki

The CPU is connected to:
]]

local function find_io_nodes(cpu_pos)
	local pos1 = {x = cpu_pos.x - RADIUS, y = cpu_pos.y - RADIUS, z = cpu_pos.z - RADIUS}
	local pos2 = {x = cpu_pos.x + RADIUS, y = cpu_pos.y + RADIUS, z = cpu_pos.z + RADIUS}
	local posses = minetest.find_nodes_in_area(pos1, pos2, IONodes)
	local out = {}
	for _,pos in ipairs(posses) do
		local node = minetest.get_node(pos)
		local ndef = minetest.registered_nodes[node.name]
		if ndef and ndef.on_vm16_start_cpu then
			ndef.on_vm16_start_cpu(pos, cpu_pos)
			table.insert(out, string.format(" - %s at %s added", node.name, P2S(pos)))
		end
	end
	return table.concat(out, "\n")
end

-- CPU definition
local cpu_def = {
	cycle_time = 0.1, -- timer cycle time
	instr_per_cycle = 10000,
	input_costs = 1000,  -- number of instructions
	output_costs = 5000, -- number of instructions
	system_costs = 2000, -- number of instructions
	-- Called for each 'input' instruction.
	on_input = function(pos, address)
		local hash = H(pos)
		local item = Inputs[hash] and Inputs[hash][address]
		if item then
			return item.input(item.pos, address) or 0
		end
	end,
	-- Called for each 'output' instruction.
	on_output = function(pos, address, val1, val2)
		if address == 0 then
			local prog_pos = S2P(M(pos):get_string("prog_pos"))
			vm16.putchar(prog_pos, val1)
			return 500  -- number of instructions for putchar
		else
			local hash = H(pos)
			local item = Outputs[hash] and Outputs[hash][address]
			if item then
				item.output(item.pos, address, val1, val2)
			end
		end
	end,
	-- Called for each 'system' instruction.
	on_system = function(pos, address, val1, val2)
		print("on_system")
	end,
	-- Called when CPU stops.
	on_update = function(pos, resp)
		local prog_pos = S2P(M(pos):get_string("prog_pos"))
		vm16.update_programmer(pos, prog_pos, resp)
	end,
	-- Called when the programmers info/splash screen is displayed
	on_init = function(pos, prog_pos)
		M(pos):set_string("prog_pos", P2S(prog_pos))
		local s = find_io_nodes(pos)
		vm16.add_ro_file(prog_pos, "example1.c",   Files.example1_c)
		vm16.add_ro_file(prog_pos, "example2.c",   Files.example2_c)
		vm16.add_ro_file(prog_pos, "example3.c",   Files.example3_c)
		vm16.add_ro_file(prog_pos, "example4.c",   Files.example4_c)
		vm16.add_ro_file(prog_pos, "example1.asm", Files.example1_asm)
		vm16.add_ro_file(prog_pos, "stdio.asm",    Files.stdio_asm)
		vm16.add_ro_file(prog_pos, "mem.asm",      Files.mem_asm)
		vm16.add_ro_file(prog_pos, "info.txt",     Info .. s)
	end,
	on_mem_size = function(pos)
		return 4  -- 1024 words
	end,
	on_start = function(pos)
		M(pos):set_string("infotext", "VM16 Demo Computer (running)")
		M(pos):set_int("running", 1)
	end,
	on_stop = function(pos)
		M(pos):set_string("infotext", "VM16 Demo Computer (stopped)")
		M(pos):set_int("running", 0)
	end,
	on_check_connection = function(pos)
		return S2P(M(pos):get_string("prog_pos"))
	end,
	on_infotext = function(pos)
		return Info
	end,
}

minetest.register_node("vm16:cpu", {
	description = "VM16 Demo Computer",
	tiles = {
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu.png",
	},
	vm16_cpu = cpu_def,
	after_place_node = function(pos, placer)
		M(pos):set_string("infotext", "VM16 Demo Computer")
	end,
	on_timer = function(pos, elapsed)
		local prog_pos = S2P(M(pos):get_string("prog_pos"))
		return vm16.keep_running(pos, prog_pos, cpu_def)
	end,
	after_dig_node = function(pos)
		local prog_pos = S2P(M(pos):get_string("prog_pos"))
		vm16.unload_cpu(pos, prog_pos)
	end,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,
})

minetest.register_lbm({
	label = "vm16 Load CPU",
	name = "vm16:load_cpu",
	nodenames = {"vm16:cpu"},
	run_at_every_load = true,
	action = function(pos, node)
		find_io_nodes(pos)
		local prog_pos = S2P(M(pos):get_string("prog_pos"))
		if M(pos):get_int("running") == 1 then
			vm16.load_cpu(pos, prog_pos, cpu_def)
		end
	end
})

minetest.register_craft({
	output = "vm16:cpu",
	recipe = {
		{"", "", ""},
		{"default:steelblock", "basic_materials:gold_wire", "default:steelblock"},
		{"basic_materials:ic", "basic_materials:ic", "basic_materials:ic"},
	},
})

-------------------------------------------------------------------------------
-- API for I/O nodes
-------------------------------------------------------------------------------
function vm16.register_io_nodes(names)
	for _, name in ipairs(names) do
		table.insert(IONodes, name)
	end
end

function vm16.register_input_address(pos, cpu_pos, address, on_input)
	assert(pos and cpu_pos and address and on_input)
	local hash = H(cpu_pos)
	Inputs[hash] = Inputs[hash] or {}
	Inputs[hash][address] = {pos = pos, input = on_input}
end

function vm16.register_output_address(pos, cpu_pos, address, on_output)
	assert(pos and cpu_pos and address and on_output)
	local hash = H(cpu_pos)
	Outputs[hash] = Outputs[hash] or {}
	Outputs[hash][address] = {pos = pos, output = on_output}
end
