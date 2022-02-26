--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Simple CPU for testing purposes
]]--

-- for lazy programmers
local M = minetest.get_meta
local H = minetest.hash_node_position
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end

local RADIUS = 3

local Inputs = {}   -- [hash] = {addr = value}
local Outputs = {}  -- [hash] = {addr = pos}
local IONodes = {}  -- Known I/O nodes

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

-------------------------------------------------------------------------------
-- API for the CPU
-------------------------------------------------------------------------------
function vm16.find_io_nodes(cpu_pos, radius)
	radius = radius or RADIUS
	local hash = H(cpu_pos)
	local pos1 = {x = cpu_pos.x - radius, y = cpu_pos.y - radius, z = cpu_pos.z - radius}
	local pos2 = {x = cpu_pos.x + radius, y = cpu_pos.y + radius, z = cpu_pos.z + radius}
	local posses = minetest.find_nodes_in_area(pos1, pos2, IONodes)
	for _,pos in ipairs(posses) do
		local node = minetest.get_node(pos)
		local ndef = minetest.registered_nodes[node.name]
		if ndef and ndef.on_vm16_start_cpu then
			ndef.on_vm16_start_cpu(pos, cpu_pos)
		end
	end
end

function vm16.on_output(pos, address, val1, val2)
	local hash = H(pos)
	local item = Outputs[hash] and Outputs[hash][address]
	if item then
		item.output(item.pos, address, val1, val2)
	end
end

function vm16.on_input(pos, address)
	local hash = H(pos)
	local item = Inputs[hash] and Inputs[hash][address]
	if item then
		return item.input(item.pos, address) or 0
	end
end
