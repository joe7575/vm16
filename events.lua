--[[
	vm16
	====

	Copyright (C) 2019-2020 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
	
	User event functions
]]--

function vm16.on_power_on(pos, ram_size)
	print("on_power_on")
	if not vm16.is_loaded(pos) then
		if vm16.create(pos, ram_size) then
			return true
		end
	end
end

function vm16.on_power_off(pos)
	print("on_power_off")
	if vm16.is_loaded(pos) then
		vm16.destroy(pos)
		return true
	end
end

function vm16.on_load(pos)
	print("on_load")
	if not vm16.is_loaded(pos) then
		vm16.vm_restore(pos)
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