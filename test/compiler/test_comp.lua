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

local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = function(s) return minetest.string_to_pos(s) end


local startup_code = {
	-- Reserved area 0002 - 0007:
	"jump 8",
	".org 8",
	"call @init",
	"call init",
	"@loop:",
	"call loop",
	"nop",
	"jump @loop",
}

local function read_file(pos, filename)
	--print("read_file", pos, fname)
	local text
	local file = io.open("/home/joachim/Projekte/minetest/Compiler/" .. filename, "rt")
	if file then
		text = file:read("*all")
		file:close()
	end
	return text
end

local function write_file(pos, filename, text)
-- Opens a file in append mode
	local file = io.open("/home/joachim/Projekte/minetest/Compiler/" .. filename, "wt")
	if file then
		file:write(text)
		file:close()
	end
end

local function dump_parser_output(output)
	local out = {}

	out[#out + 1] = "#### Code ####"
	for idx,tok in ipairs(output.lCode) do
		local ctype, lineno, code = tok[1], tok[2], tok[3]
		out[#out + 1] = string.format('%5s: (%3d) "%s"', ctype, lineno, code)
	end

	out[#out + 1] = "#### Debug ####"
	for idx,tok in ipairs(output.lDebug) do
		local ctype, lineno, address, ident, info = tok[1], tok[2], tok[3], tok[4], tok[5]
		info = info and (', "' .. info .. '"') or ""
		out[#out + 1] = string.format('%5s %3d %s %s %s', ctype, lineno, address or -1000, ident or "oops", info)
	end

	return table.concat(out, "\n")
end

local function test_lookup(filename)
	local pos = {x=0, y=0, z=0}
	
	local sts, res = vm16.compile(pos, filename, read_file)
	if sts then
		print("######################### LST ############################")
		print(res)
	else
		print(res)
		return
	end

	sts, res = vm16.compile(pos, filename, read_file)
	if sts then
		local lut = vm16.Lut:new()
		lut:init(res)
		for _,item in ipairs(lut.items) do
			print(string.format("%-20s:  %04X/%04X", item.file .. ":" .. item.func, 
					item.addresses[1], item.addresses[2]))
		end
	else
		print(res)
	end
end

local function assemble(filename)
	local pos = {x=0, y=0, z=0}
	local sts, res = vm16.assemble(pos, filename, read_file, true)
	print("######################### DBG ############################")
	print(res)
	sts, res = vm16.assemble(pos, filename, read_file)
	print("######################### BIN ############################")
	print(#res.lCode, res.locals)
end

local function compile_and_assemble(filename)
	local pos = {x=0, y=0, z=0}
	local sts, res = vm16.compile(pos, filename, read_file, {gen_asm_code = true})
	if sts then
		write_file(pos, "out.asm", res)
		sts, res = vm16.assemble(pos, "out.asm", read_file, true)
		if sts then
			print("######################### BIN ############################")
			print(vm16.dump_compiler_output(res))
		else
			print(res)
		end
	else
		print(res)
	end
end

local function compile(filename)
	local pos = {x=0, y=0, z=0}
	local sts, res = vm16.compile(pos, filename, read_file, {gen_token_list = true})
	if sts then
		print("######################### Scanner ############################")
		print(res)
	else
		print(res)
		return
	end
	
	sts, res = vm16.compile(pos, filename, read_file, {gen_parser_output = true})
	if sts then
		print("######################### Parser ############################")
		print(dump_parser_output(res))
	else
		print(res)
		return
	end

	sts, res = vm16.compile(pos, filename, read_file, {gen_asm_code = true})
	if sts then
		print("######################### ASM ############################")
		print(res)
	else
		print(res)
		return
	end
	
	sts, res = vm16.compile(pos, filename, read_file)
	if sts then
		print("######################### BIN ############################")
		print(vm16.dump_compiler_output(res))
	else
		print(res)
		return
	end
end

local function beduino_compile(filename)
	local pos = {x=0, y=0, z=0}
	local sts, res = vm16.compile(pos, filename, read_file, {startup_code = startup_code, gen_parser_output = true})
	if sts then
		print("######################### Parser ############################")
		print(dump_parser_output(res))
	else
		print(res)
		return
	end

	sts, res = vm16.compile(pos, filename, read_file, {startup_code = startup_code, gen_asm_code = true})
	if sts then
		print("######################### ASM ############################")
		print(res)
	else
		print(res)
		return
	end

	local sts, res = vm16.compile(pos, filename, read_file, {startup_code = startup_code})
	if sts then
		print("######################### BIN ############################")
		print(vm16.dump_compiler_output(res))
	else
		print(res)
		return
	end
end

--test_scanner("test8.c")
--assemble("test1.asm")
--compile("comm.c")
--compile("test13.c")
--test_lookup("test8.c")
--compile_and_assemble("test13.c")
--beduino_compile("test14.c")
--test_lookup("test14.c")
--beduino_compile("test15.c")



for i = 0,100 do
	local pos = {x = i, y = i, z = i}
	local s = vm16lib.hash_node_position(pos)
	print(P2S(pos), s, P2S(get_position_from_hash(s)))
end

for i = -30000,30000,10000 do
	local pos = {x = i, y = i, z = i}
	local s = vm16lib.hash_node_position(pos)
	print(P2S(pos), s, P2S(get_position_from_hash(s)))
end


print(vm16lib.hash_node_position({x = 35000, y = -35000, z = 0}))