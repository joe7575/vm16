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

-- Start example
local Code = [[
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

local function on_update(pos, resp)
	print("on_update", vm16.CallResults[resp])
	local mem = prog.get_mem(pos)
	vm16.debug.on_update(pos, mem)
	M(pos):set_string("formspec", prog.formspec(pos, mem))
end

local function on_input(pos, address) 
	print("on_input", address); 
	return address
end

local function on_output(pos, address, val1, val2)
	if address == 0 then
		local mem = prog.get_mem(pos)
		if val1 == 0 then
			mem.output = ""
		elseif mem.output and #mem.output < 80 then
			mem.output = mem.output .. prog.to_string(val1)
		end
	else
		print("output", address, val1, val2)
	end
end

local function on_system() end

local clbks = vm16.generate_callback_table(on_input, on_output, on_system, on_update)

local function on_timer(pos, elapsed)
	if vm16.is_loaded(pos) then
		local mem = prog.get_mem(pos)
		print("on_timer", P2S(pos), mem.running)
		if mem.running then
			return vm16.run(pos, nil, clbks, mem.breakpoints) < vm16.HALT
		end
	end
end

local function on_rightclick(pos)
	M(pos):set_string("formspec", vm16.prog.formspec(pos, prog.get_mem(pos)))
end

minetest.register_node("vm16:cpu2", {
	description = "VM16 Computer2",
	tiles = {
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu.png",
	},
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = M(pos)
		meta:set_string("formspec", vm16.prog.formspec(pos, prog.get_mem(pos)))
		meta:set_string("infotext", "VM16 Computer2")
		meta:set_string("code", Code)
	end,
	on_timer = on_timer,
	on_rightclick = on_rightclick,
	on_receive_fields = function(pos, formname, fields, player)
		vm16.prog.on_receive_fields(pos, formname, fields, player, clbks)
	end,
	after_dig_node = function(pos)
		vm16.destroy(pos)
	end,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,
})
