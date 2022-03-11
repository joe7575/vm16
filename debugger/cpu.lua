--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	VM16 Computer
]]--

-- for lazy programmers
local M = minetest.get_meta
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end

local Cache = {}    -- [hash] = {}

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

local function to_char(val)
	if val >= 32 and val <= 127 then
		return string.char(val)
	end
	return "."
end

local function to_string(val)
	if val > 255 then
		return to_char(val / 256) .. to_char(val % 256)
	else
		return to_char(val)
	end
end

local function get_mem(pos)
	local hash = minetest.hash_node_position(pos)
	Cache[hash] = Cache[hash] or {}
	return Cache[hash]
end

local function on_update(pos, resp)
	local mem = get_mem(pos)
	vm16.dbg.on_update(pos, mem)
	M(pos):set_string("formspec", vm16.prog.formspec(pos, mem))
end

local function on_output(pos, address, val1, val2)
	if address == 0 then
		local mem = get_mem(pos)
		if val1 == 0 then
			mem.output = ""
		elseif mem.output and #mem.output < 80 then
			mem.output = mem.output .. to_string(val1)
		end
	else
		vm16.on_output(pos, address, val1, val2)
	end
end

local function on_system() end

local clbks = vm16.generate_callback_table(vm16.on_input, on_output, on_system, on_update)

local function compile(code)
	local result = vm16.BCompiler(code, false)
	if result.errors then
		print("compile2 " .. result.errors)
		return nil, result.errors
	end
	return result.output
end

local function init_cpu(pos, lToken)
	local mem = get_mem(pos)
	mem.breakpoints = {}
	vm16.find_io_nodes(pos)
	vm16.create(pos, 3)
	for _,tok in ipairs(lToken) do
		for i, opc in pairs(tok.opcodes or {}) do
			vm16.poke(pos, tok.address + i - 1, opc)
		end
	end
	vm16.set_pc(pos, 0)
end

local function on_receive_fields(pos, formname, fields, player)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return
	end

	local mem = get_mem(pos)
	local meta = minetest.get_meta(pos)
	local lines = {"Error"}

	if not mem.running then
		if fields.code and (fields.save or fields.assemble) then
			M(pos):set_string("code", fields.code)
		end
		if fields.larger then
			M(pos):set_int("textsize", math.min(M(pos):get_int("textsize") + 1, 8))
		elseif fields.smaller then
			M(pos):set_int("textsize", math.max(M(pos):get_int("textsize") - 1, -8))
		elseif fields.assemble then
			if mem.error then
				mem.error = nil
			elseif not vm16.is_loaded(pos) then
				mem.lToken, mem.error = compile(M(pos):get_string("code"))
				if mem.lToken then
					init_cpu(pos, mem.lToken)
					mem.output = ""
					mem.scroll_lineno = nil
					mem.start_idx = 1
					vm16.dbg.init(pos, mem)
				end
			end
		elseif fields.edit then
			if vm16.is_loaded(pos) then
				minetest.get_node_timer(pos):stop()
				vm16.destroy(pos)
			end
			mem.error = nil
		else
			vm16.dbg.on_receive_fields(pos, mem, fields, clbks)
		end
	end
	if mem.running and fields.stop then
		minetest.get_node_timer(pos):stop()
		mem.running = false
	end
	meta:set_string("formspec", vm16.prog.formspec(pos, mem))
end

local function on_timer(pos, elapsed)
	if vm16.is_loaded(pos) then
		local mem = get_mem(pos)
		print("on_timer", P2S(pos), mem.running)
		if mem.running then
			return vm16.run(pos, nil, clbks, mem.breakpoints) < vm16.HALT
		end
	end
end

local function on_rightclick(pos)
	M(pos):set_string("formspec", vm16.prog.formspec(pos, get_mem(pos)))
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
		meta:set_string("code", Code)
		meta:set_string("formspec", vm16.prog.formspec(pos, get_mem(pos)))
		meta:set_string("infotext", "VM16 Computer2")
	end,
	on_timer = on_timer,
	on_rightclick = on_rightclick,
	on_receive_fields = on_receive_fields,
	after_dig_node = function(pos)
		vm16.destroy(pos)
	end,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,
})

minetest.register_craft({
	output = "vm16:cpu2",
	recipe = {
		{"default:steelblock", "basic_materials:gold_wire", "default:steelblock"},
		{"basic_materials:ic", "basic_materials:ic", "basic_materials:ic"},
		{"", "default:obsidian_glass", ""},
	},
})
