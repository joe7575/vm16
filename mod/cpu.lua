--[[
	vm16
	====

	Copyright (C) 2019-2020 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
	
	Simple CPU for testing purposes
]]--

-- for lazy programmers
local M = minetest.get_meta

local CpuInputs = {}   -- [addr] = value
local CpuOutputs = {}  -- [addr] = dest_pos


local PROG = ([[:8 0000 00 2010 0000 3010 0001 6010 0002 6600 0001
:2 0008 00 1200 0002
:00000FF]]):gsub(" ", "")

local function formspec(lines)
	return "size[10,7]"..
		"tabheader[0,0;tab;CPU,help;1;;true]"..
		"style_type[label,field;font=mono]"..
		"background[0.25,0.25;9.5,4.6;vm16_form_mask.png]"..
		"label[0.5,0.4;"..minetest.formspec_escape(lines[1] or "").."]"..
		"label[0.5,0.8;"..minetest.formspec_escape(lines[2] or "").."]"..
		"label[0.5,1.2;"..minetest.formspec_escape(lines[3] or "").."]"..
		"label[0.5,1.6;"..minetest.formspec_escape(lines[4] or "").."]"..
		"label[0.5,2.0;"..minetest.formspec_escape(lines[5] or "").."]"..
		"label[0.5,2.4;"..minetest.formspec_escape(lines[6] or "").."]"..
		"label[0.5,2.8;"..minetest.formspec_escape(lines[7] or "").."]"..
		"label[0.5,3.2;"..minetest.formspec_escape(lines[8] or "").."]"..
		"label[0.5,3.6;"..minetest.formspec_escape(lines[9] or "").."]"..
		"label[0.5,4.0;"..minetest.formspec_escape(lines[10] or "").."]"..
		"label[0.5,5.5;h = help]"..
		"field[0.7,6.4;7,0.8;command;;]"..
		"button[8.0,6.0;1.7,1;enter;enter]"..
		"field_close_on_enter[command;false]"
end

local function formspec_help()
	local s = vm16.AsmHelp
	return "size[10,7]"..
		"tabheader[0,0;tab;CPU,help;2;;true]"..
		"style_type[table;font=mono]"..
		"table[0.25,0.25;9.5,6.5;help;"..s..";1]"
end

local function mem_dump(pos, s)
	local addr = vm16.hex2number(s) or 0
	local mem = vm16.read_mem(pos, addr, 8*4)
	local lines = {}
	
	if mem then
		for i = 0,7 do
			local offs = i * 4
			lines[i+1] = string.format("%04X: %04X %04X %04X %04X", 
					addr+offs, mem[1+offs], mem[2+offs], mem[3+offs], mem[4+offs])
		end
	else
		lines[1] = "Error"
	end
	return lines
end

local function reg_dump(pos, resp)
	local cpu = vm16.get_cpu_reg(pos)
	local lines = {}
	
	if cpu then
		lines[1] = vm16.CallResults[resp]
		lines[2] = string.format("A:%04X B:%04X X:%04X Y:%04X", cpu.A, cpu.B, cpu.X, cpu.Y)
		local operand = ""
		if vm16.num_operands(cpu.mem0) == 1 then
			operand = string.format("%04X", cpu.mem1)
		end
		lines[3] = string.format(">%04X: %04X %s", cpu.PC, cpu.mem0, operand)
	else
		lines[1] = "Error"
	end
	return lines
end

local function enter_data(pos, s)
	local s1, s2 = unpack(string.split(s, " "))
	local lines
	
	if s2 then
		local val1 = vm16.hex2number(s1)
		local val2 = vm16.hex2number(s2)
		local addr = vm16.get_pc(pos) or 0
		lines = {string.format("%04X: %04X %04X", addr, val1, val2)}
		vm16.deposit(pos, val1)
		vm16.deposit(pos, val2)
	else
		local val = vm16.hex2number(s1)
		local addr = vm16.get_pc(pos) or 0
		lines = {string.format("%04X: %04X", addr, val)}
		vm16.deposit(pos, val)
	end
	return lines
end

local function help()
	return {
		"d <addr>        - memory dump",
		"a <addr>        - set PC to address",
		"s               - one CPU step",
		"e <opc> <opnd>  - enter code and ",
		"                  postincrement PC",
		"r               - run CPU",
		"t               - terminate CPU",
		"n               - turn power on",
		"f               - turn power off",
	}
end
	
local function on_receive_fields(pos, formname, fields, player)
	local meta = minetest.get_meta(pos)
	local lines = {"Error"}
	
	if fields.tab == "2" then
		meta:set_string("storeformspec", meta:get_string("formspec"))
		meta:set_string("formspec", formspec_help())
		return
	elseif fields.tab == "1" then
		meta:set_string("formspec", meta:get_string("storeformspec"))
		return
	elseif (fields.key_enter_field or fields.enter) and fields.command ~= "" then
		local cmd = string.sub(fields.command, 1, 1)
		local data = string.sub(fields.command, 3)
			
		if vm16.is_loaded(pos) then
			if minetest.get_node_timer(pos):is_started() then
				if cmd == "t" then
					minetest.get_node_timer(pos):stop()
					lines = {"stopped"}
				elseif cmd == "f" then
					minetest.get_node_timer(pos):stop()
					print(vm16.read_h16(pos))
					if vm16.on_power_off(pos) then
						lines = {"power off"}
					end
				else
					lines = help()
				end
			else -- stopped
				if cmd == "d" then
					lines = mem_dump(pos, data)
				elseif cmd == "a" then
					local addr = vm16.hex2number(data)
					vm16.set_pc(pos, addr)
					lines = {string.format("%04X:", addr)}
				elseif cmd == "s" then
					local resp = vm16.run(pos, 1)
					lines = reg_dump(pos, resp)
				elseif cmd == "e" then
					lines = enter_data(pos, data)
				elseif cmd == "r" then
					minetest.get_node_timer(pos):start(0.1)
					lines = {"started"}
				elseif cmd == "f" then
					print(vm16.read_h16(pos))
					if vm16.on_power_off(pos) then
						lines = {"power off"}
					end
				elseif cmd == "u" then
					minetest.get_node_timer(pos):stop()
					if vm16.vm_store(pos) then
						lines = {"unloaded"}
					end
				else
					lines = help()
				end
			end
		else
			if cmd == "n" then
				if vm16.on_power_on(pos, 1) then
					lines = {"power on"}
					vm16.write_h16(pos, PROG)
				end
			else
				lines = help()
			end
		end
	else
		lines = help()
	end
	meta:set_string("formspec", formspec(lines))
end

local function on_timer(pos, elapsed)
	print("timer")
	return vm16.run(pos, 10000) ~= vm16.HALT
end

minetest.register_node("vm16:cpu", {
	description = "VM16 Test CPU",
	tiles = {
		"vm16_cpu.png",
	},
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		M(pos):set_string("formspec", formspec({}))
	end,
	on_timer = on_timer,
	on_receive_fields = on_receive_fields,
	groups = {cracky=2, crumbly=2, choppy=2},
	is_ground_content = false,
	
	hand_over = function(pos, addr, value)
		print("hand_over", addr, value)
		local hash = minetest.hash_node_position(pos)
		CpuInputs[hash] = CpuInputs[hash] or {}
		CpuInputs[hash][addr] = value
	end,

	reg_output = function(pos, addr, dest_pos)
		local hash = minetest.hash_node_position(pos)
		CpuOutputs[hash] = CpuOutputs[hash] or {}
		CpuOutputs[hash][addr] = dest_pos
	end
})

minetest.register_lbm({
    label = "VM16 Load CPU",
    name = "vm16:load_cpu",
    nodenames = {"vm16:cpu"},
    run_at_every_load = true,
    action = function(pos, node)
		if vm16.on_load(pos) then
			M(pos):set_string("formspec", formspec({"powered"}))
		else
			M(pos):set_string("formspec", formspec({"unpowered"}))
		end
	end
})

local function on_input(pos, address)
	local hash = minetest.hash_node_position(pos)
	CpuInputs[hash] = CpuInputs[hash] or {}
	local value = CpuInputs[hash][address] or 0xFFFF
	print("on_input", address, value)
	return value
end
	
local function on_output(pos, address, value)	
	local hash = minetest.hash_node_position(pos)
	CpuOutputs[hash] = CpuOutputs[hash] or {}
	local dest_pos = CpuOutputs[hash][address]
	if dest_pos then
		local node = minetest.get_node(dest_pos)
		if node.name == "vm16:output" then
			local ndef = minetest.registered_nodes[node.name]
			ndef.hand_over(dest_pos, address, value)
		else
			print("[VM16] No output position")
		end
	else
		print("[VM16] Invalid position")
	end
end		

local function on_update(pos, resp, cpu)
	local lines = reg_dump(pos, resp)
	M(pos):set_string("formspec", formspec(lines))
end

vm16.register_callbacks(on_input, on_output, nil, on_update, nil)