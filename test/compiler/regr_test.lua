local MP = '/home/joachim/Projekte/lua/minetest_unittest/lib'

core = {}

dofile(MP.."/chatcommands.lua")
dofile(MP.."/serialize.lua")
dofile(MP.."/misc_helpers.lua")
dofile(MP.."/vector.lua")
dofile(MP.."/item.lua")
dofile(MP.."/misc.lua")

minetest = core
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local MP = "/home/joachim/minetest5/mods/vm16"
vm16 = {}
local vm16lib = require("vm16lib")
print("vm16 version = " .. vm16lib.version())
assert(loadfile(MP.."/api.lua"))(vm16lib)
dofile(MP.."/lib.lua")
dofile(MP.."/asm/asm.lua")

dofile(MP.."/bcomp/bgenerator.lua")
dofile(MP.."/bcomp/bscanner.lua")
dofile(MP.."/bcomp/bsymbols.lua")
dofile(MP.."/bcomp/bexpression.lua")
dofile(MP.."/bcomp/bparser.lua")
dofile(MP.."/bcomp/bcompiler.lua")
dofile(MP.."/programmer/lib.lua")
dofile(MP.."/programmer/lookup.lua")

local startup_code1 = {
	"call main",
	"halt",
}

local startup_code2 = {
	"jump 8",
	".org 8",
	"call @init",
	"call init",
	"@loop:",
	"call loop",
	"nop",
	"jump @loop",
}


local function read_file(pos, fname)
	local text
	local f = io.open("/home/joachim/minetest5/mods/vm16/test/compiler/" .. fname, "rt")
	if f then
		text = f:read("*all")
		f:close()
	end
	return text
end

local function compile1(filename)
	print("\n #### Compile 'main': " .. filename .. " ####")
	local pos = {x=0, y=0, z=0}
	local sts, res = vm16.compile(pos, filename, read_file, {startup_code = startup_code1})
	if sts then
		print(vm16.dump_compiler_output(res))
	else
		print(res)
	end
end

local function compile2(filename)
	print("\n #### Compile 'loop': " .. filename .. " ####")
	local pos = {x=0, y=0, z=0}
	local sts, res = vm16.compile(pos, filename, read_file, {startup_code = startup_code2})
	if sts then
		print(vm16.dump_compiler_output(res))
	else
		print(res)
	end
end

compile1("test01.c")  -- functions and parameters, arithmetic
compile1("test02.c")  -- arithmetic
compile1("test03.c")  -- if, else, while
compile1("test04.c")  -- const, inline asm
compile1("test05.c")  -- arrays and strings
compile1("test06.c")  -- import files
compile1("test07.c")  -- static function and vars, pointers
compile1("test08.c")  -- boolean expressions
compile2("test09.c")  -- beduino init, loop
compile1("test10.c")  -- break, continue, goto
