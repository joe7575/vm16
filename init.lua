--[[
	vm16
	====

	Copyright (C) 2019-2023 Joachim Stolberg

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

vm16.cpu = {}
dofile(MP.."/asm/asm.lua")
dofile(MP.."/bcomp/bgenerator.lua")
dofile(MP.."/bcomp/bscanner.lua")
dofile(MP.."/bcomp/bsymbols.lua")
dofile(MP.."/bcomp/bexpression.lua")
dofile(MP.."/bcomp/bconst_expr.lua")
dofile(MP.."/bcomp/bparser.lua")
dofile(MP.."/bcomp/bcompiler.lua")
dofile(MP.."/bcomp/libc.lua")

dofile(MP.."/programmer/lib.lua")
dofile(MP.."/programmer/lookup.lua")
dofile(MP.."/programmer/server.lua")
dofile(MP.."/programmer/menubar.lua")
dofile(MP.."/programmer/win_edit.lua")
dofile(MP.."/programmer/win_files.lua")
dofile(MP.."/programmer/win_debug.lua")
dofile(MP.."/programmer/win_watch.lua")
dofile(MP.."/programmer/win_memory.lua")
dofile(MP.."/programmer/win_terminal.lua")
dofile(MP.."/programmer/win_sdcard.lua")
dofile(MP.."/programmer/formspec.lua")
dofile(MP.."/programmer/programmer.lua")
dofile(MP.."/programmer/sdcard.lua")
dofile(MP.."/demo/files.lua")

-- for testing purposes
if minetest.settings:get_bool("vm16_testblocks_enabled") == true and
		minetest.global_exists("default") and
		minetest.global_exists("basic_materials") then
	dofile(MP.."/demo/cpu.lua")
	dofile(MP.."/demo/switch.lua")
	dofile(MP.."/demo/lamp.lua")
	dofile(MP.."/demo/recipes.lua")
end
