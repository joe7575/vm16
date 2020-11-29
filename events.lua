--[[
	vm16
	====

	Copyright (C) 2019-2020 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
	
	User event functions
]]--

local VM16_NO_POWER  = 0  -- default state
local VM16_POWERED   = 1  -- VM instance available
local VM16_UNLOADED  = 2  -- area unloaded, VM stored as meta

vm16.States = {[0]="no power", "powered", "unloaded"}

function vm16.on_power_on(pos, ram_size)
	local meta = minetest.get_meta(pos)
	local state = meta:get_int("vm16state")
	print("on_power_on", state)
	if state == VM16_NO_POWER then
		if vm16.create(pos, ram_size) then
			meta:set_int("vm16state", VM16_POWERED)
			print("on_power_on2",  meta:get_int("vm16state"))
			return true
		end
	end
end

function vm16.on_power_off(pos)
	local meta = minetest.get_meta(pos)
	local state = meta:get_int("vm16state")
	print("on_power_off", state)
	if state ~= VM16_NO_POWER then
		vm16.destroy(pos)
		meta:set_int("vm16state", VM16_NO_POWER)
		print("on_power_off2",  meta:get_int("vm16state"))
		return true
	end
end

function vm16.on_load(pos)
	local meta = minetest.get_meta(pos)
	local state = meta:get_int("vm16state")
	print("on_load", state)
	if state == VM16_UNLOADED then
		vm16.vm_restore(pos)
		meta:set_int("vm16state", VM16_POWERED)
		print("on_load2",  meta:get_int("vm16state"))
		return true
	end
end

-- result = func_input(pos, address) 
-- func_output(pos, address, value) 
-- result = func_system(pos, address, val1, val2) 
-- func_update(pos, resp, cpu)
function vm16.register_callbacks(func_input, func_output, func_system, func_update)
	vm16.func_input  = func_input or vm16.func_input
	vm16.func_output = func_output or vm16.func_output
	vm16.func_system = func_system or vm16.func_system
	vm16.func_update = func_update or vm16.func_update
end

-- default callback handlers
vm16.func_input = function(pos, address)
	print("input", address)
	return address
end

vm16.func_output = function(pos, address, value)
	print("output", address, value)
end

vm16.func_system = function(pos, address, val1, val2) 
	print("system", address, val1, val2)
	return 1
end

vm16.func_update = function(pos, resp, cpu)
	print("update", vm16.CallResults[resp])
end