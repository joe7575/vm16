--[[
	vm16
	====

	Copyright (C) 2019-2020 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
]]--

vm16 = {}

local IE = minetest.request_insecure_environment()

if not IE then
	error("Please add vm16 to the list of 'secure.trusted_mods' in minetest.conf!")
end

local vm16lib = IE.require("vm16lib")

if not vm16lib then
	error("Please install vm16 via 'luarocks install vm16'")
end

local MP = minetest.get_modpath("vm16")

assert(loadfile(MP.."/api.lua"))(vm16lib)
dofile(MP.."/lib.lua")

IE = nil
vm16lib = nil

-- for testing purposes
if minetest.settings:get_bool("vm16_testblocks_enabled") == true and
		minetest.global_exists("default") and
                minetest.global_exists("basic_materials") then
	vm16.cpu = {}
	dofile(MP.."/mod/asm.lua")
	dofile(MP.."/mod/io.lua")
	dofile(MP.."/mod/formspec.lua")
	dofile(MP.."/mod/cpu.lua")
	dofile(MP.."/mod/switch.lua")
	dofile(MP.."/mod/lamp.lua")
	dofile(MP.."/bcomp/bgenerator.lua")
	dofile(MP.."/bcomp/bscanner.lua")
	dofile(MP.."/bcomp/bsymbols.lua")
	dofile(MP.."/bcomp/bexpression.lua")
	dofile(MP.."/bcomp/bparser.lua")
	dofile(MP.."/bcomp/bcompiler.lua")
	dofile(MP.."/debugger/win_edit.lua")
	dofile(MP.."/debugger/win_files.lua")
	dofile(MP.."/debugger/win_debug.lua")
	dofile(MP.."/debugger/win_watch.lua")
	dofile(MP.."/debugger/formspec.lua")
	dofile(MP.."/debugger/cpu.lua")
end
