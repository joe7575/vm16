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

-- result = on_input(pos, address) 
--          on_output(pos, address, value) 
-- result = on_system(pos, address, val1, val2) 
--          on_update(pos, resp, cpu)
--          on_unload(pos)
function vm16.register_callbacks(on_input, on_output, on_system, on_update, on_unload)
	vm16.on_input  = on_input or vm16.on_input
	vm16.on_output = on_output or vm16.on_output
	vm16.on_system = on_system or vm16.on_system
	vm16.on_update = on_update or vm16.on_update
	vm16.on_unload = on_unload or vm16.on_unload
end

-- default callback handlers
vm16.on_input = function(pos, address)
	print("on_input", address)
	return address
end

vm16.on_output = function(pos, address, value)
	print("on_output", address, value)
end

vm16.on_system = function(pos, address, val1, val2) 
	print("on_system", address, val1, val2)
	return 1
end

vm16.on_update = function(pos, resp, cpu)
	print("on_update", vm16.CallResults[resp])
end

vm16.on_unload = function(pos)
	print("on_unload")
end