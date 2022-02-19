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
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end

local RADIUS = 3

local Inputs = {}   -- [hash] = {addr = value}
local Outputs = {}  -- [hash] = {addr = pos}
local IONodes = {}  -- Known I/O nodes

function vm16.register_io_nodes(names)
	for _, name in ipairs(names) do
		table.insert(IONodes, name)
	end
end

-- Used by CPU
function vm16.on_start_cpu(cpu_pos)
	local hash = minetest.hash_node_position(cpu_pos)
	local pos1 = {x = cpu_pos.x - RADIUS, y = cpu_pos.y - RADIUS, z = cpu_pos.z - RADIUS}
	local pos2 = {x = cpu_pos.x + RADIUS, y = cpu_pos.y + RADIUS, z = cpu_pos.z + RADIUS}
	local posses = minetest.find_nodes_in_area(pos1, pos2, IONodes)
	for _,pos in ipairs(posses) do
		local node = minetest.get_node(pos)
		local ndef = minetest.registered_nodes[node.name]
		if ndef and ndef.on_vm16_start_cpu then
			if ndef.on_vm16_output then
				-- Output node
				local addr = ndef.on_vm16_start_cpu(pos, cpu_pos)
				if addr then
					Outputs[hash] = Outputs[hash] or {}
					Outputs[hash][addr] = {pos = pos, output = ndef.on_vm16_output}
				end
			else
				-- Input node
				local addr = ndef.on_vm16_start_cpu(pos, cpu_pos)
				if addr then
					Inputs[hash] = Inputs[hash] or {}
					Inputs[hash][addr] = 0
				end
			end
		end
	end
end

-- Used by 'input' nodes
function vm16.input_data(pos, addr, value)
	local hash = minetest.hash_node_position(pos)
	Inputs[hash] = Inputs[hash] or {}
	Inputs[hash][addr] = value
end

-- Used by CPU to output data
function vm16.on_output(pos, addr, val1, val2)
	local hash = minetest.hash_node_position(pos)
	local item = Outputs[hash] and Outputs[hash][addr]
	if item then
		item.output(item.pos, addr, val1, val2)
	end
end

-- Used by CPU to read input data
function vm16.on_input(pos, address)
	local hash = minetest.hash_node_position(pos)
	Inputs[hash] = Inputs[hash] or {}
	return Inputs[hash][address] or 0
end
