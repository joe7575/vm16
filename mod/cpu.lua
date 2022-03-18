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
local prog = vm16.prog

local RADIUS = 3

local Inputs = {}   -- [hash] = {addr = value}
local Outputs = {}  -- [hash] = {addr = pos}
local IONodes = {}  -- Known I/O nodes

-- Start example
local StartCode = [[
var var1;
var var2 = 2;

func get_five() {
  return 5;
}

func foo(a,b) {
  var c = a;
  var d = b;
  return c * d;
}

func main() {
  var c = var1 + 1;
  var res;

  res = (c + var2) * 2;
  output(1, get_five(b));
  output(2, foo(var2, c));  
}
]]


local function find_io_nodes(cpu_pos)
	local pos1 = {x = cpu_pos.x - RADIUS, y = cpu_pos.y - RADIUS, z = cpu_pos.z - RADIUS}
	local pos2 = {x = cpu_pos.x + RADIUS, y = cpu_pos.y + RADIUS, z = cpu_pos.z + RADIUS}
	local posses = minetest.find_nodes_in_area(pos1, pos2, IONodes)
	for _,pos in ipairs(posses) do
		local node = minetest.get_node(pos)
		local ndef = minetest.registered_nodes[node.name]
		if ndef and ndef.on_vm16_start_cpu then
			ndef.on_vm16_start_cpu(pos, cpu_pos)
		end
	end
end

local function on_output(pos, address, val1, val2)
	local hash = H(pos)
	local item = Outputs[hash] and Outputs[hash][address]
	if item then
		item.output(item.pos, address, val1, val2)
	end
end

local function on_input(pos, address)
	local hash = H(pos)
	local item = Inputs[hash] and Inputs[hash][address]
	if item then
		return item.input(item.pos, address) or 0
	end
end

local function on_update(pos, resp)
	local prog_pos = S2P(M(pos):get_string("prog_pos"))
	vm16.prog.on_update(pos, prog_pos, resp)
end

local function on_system(pos, address, val1, val2)
	print("on_system")
end

local callbacks = vm16.generate_callback_table(on_input, on_output, on_system, on_update)

minetest.register_node("vm16:cpu", {
	description = "VM16 Computer",
	tiles = {
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu.png",
	},
	on_timer = function(pos, elapsed)
		local prog_pos = S2P(M(pos):get_string("prog_pos"))
		return vm16.prog.run(pos, prog_pos, 10000, callbacks)
	end,
	after_dig_node = function(pos)
		vm16.destroy(pos)
	end,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,

	vm16_cpu = {
		mem_size = 4,  -- 1024 bytes
		start_code = StartCode,
		callbacks = callbacks,
		on_start = function(pos, prog_pos)
			M(pos):set_string("prog_pos", P2S(prog_pos))
			find_io_nodes(pos)
		end,
		on_infotext = function(pos)
			return "No info"
		end,
	}
})

minetest.register_lbm({
	label = "vm16 Load CPU",
	name = "vm16:load_cpu",
	nodenames = {"vm16:cpu"},
	run_at_every_load = true,
	action = function(pos, node)
		find_io_nodes(pos)
		vm16.on_load(pos)
	end
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
