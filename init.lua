--[[
	vm16
	====

	Copyright (C) 2019-2020 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
]]--

vm16 = {}
vm16.version = 1.2   -- see history in readme.md

local IE = minetest.request_insecure_environment()

if not IE then
	error("Please add vm16 to the list of 'secure.trusted_mods' in minetest.conf!")
end

local vm16lib = IE.require("vm16lib")

if not vm16lib then
	error("Please install vm16 via 'luarocks install vm16'")
end

local MP = minetest.get_modpath("vm16")

assert(loadfile(MP.."/instances.lua"))(vm16lib)
dofile(MP.."/events.lua")

IE = nil
vm16lib = nil

-- for testing purposes
dofile(MP.."/test/cpu.lua")
dofile(MP.."/test/input.lua")
dofile(MP.."/test/output.lua")

