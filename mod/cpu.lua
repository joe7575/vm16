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

local Cache = {}    -- [hash] = {}

-- Start example
local Code = [[
; ASCII output example

move A, #$41   ; load A with 'A'

loop:
  out #00, A   ; output char
  add  A, #01  ; increment char
  jump loop
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
	mem.running = resp < vm16.HALT
	mem.scroll_lineno = nil
	M(pos):set_string("formspec", vm16.cpu.formspec(pos, get_mem(pos)))
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

local clbks = vm16.generate_callback_table(vm16.on_input, on_output, nil, on_update)

local function assemble(code)
	local a = vm16.Asm:new({})
	code = code:gsub("\t", "  ")
	local lToken, err = a:scanner(code)
	if err then
		return nil, err
	end
	lToken, err = a:assembler(lToken)
	return lToken, err
end

local function init_cpu(pos, lToken)
	local mem = get_mem(pos)
	mem.breakpoints = {}
	vm16.find_io_nodes(pos)
	vm16.create(pos, 0)
	for _,tok in ipairs(lToken) do
		local _, _, _, _, address, opcodes = unpack(tok)
		for i, opc in pairs(opcodes) do
			vm16.poke(pos, address + i - 1, opc)
		end
	end
	vm16.set_pc(pos, 0)
end

local function mark_code_line(pos, mem, addr)
	if not addr or addr == 0 then return end
	for _,tok in ipairs(mem.lToken or {}) do
		if tok[vm16.Asm.ADDRESS] == addr then
			if tok.breakpoint then
				tok.breakpoint = nil
				vm16.reset_breakpoint(pos, addr, mem.breakpoints)
			else
				tok.breakpoint = true
				vm16.set_breakpoint(pos, addr, mem.breakpoints)
			end
			break
		end
	end
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
		elseif fields.inc then
			M(pos):set_int("startaddr", math.min(M(pos):get_int("startaddr") + 64, 0x180))
		elseif fields.dec then
			M(pos):set_int("startaddr", math.max(M(pos):get_int("startaddr") - 64, 0))
		elseif fields.assemble then
			if mem.error then
				mem.error = nil
			elseif not vm16.is_loaded(pos) then
				mem.lToken, mem.error = assemble(M(pos):get_string("code"))
				if mem.lToken then
					init_cpu(pos, mem.lToken)
					mem.output = ""
					mem.scroll_lineno = nil
					mem.start_idx = 1
				end
			end
		elseif fields.breakpoint then
			local addr = vm16.hex2number(fields.address or "")
			mark_code_line(pos, mem, addr)
		elseif fields.edit then
			if vm16.is_loaded(pos) then
				minetest.get_node_timer(pos):stop()
				vm16.destroy(pos)
			end
			mem.error = nil
		elseif fields.step then
			if vm16.is_loaded(pos) then
				vm16.run(pos, 1, clbks, mem.breakpoints)
				mem.scroll_lineno = nil
			end
		elseif fields.step10 then
			if vm16.is_loaded(pos) then
				minetest.get_node_timer(pos):start(0.4)
				mem.steps = 10
				vm16.run(pos, 1, clbks, mem.breakpoints)
				mem.scroll_lineno = nil
			end
		elseif fields.run then
			if vm16.is_loaded(pos) then
				mem.steps = nil
				vm16.run(pos, nil, clbks, mem.breakpoints)
				minetest.get_node_timer(pos):start(0.1)
				mem.running = true
				mem.scroll_lineno = nil
			end
		elseif fields.stop then
			if vm16.is_loaded(pos) then
				vm16.set_cpu_reg(pos, {A=0, B=0, C=0, D=0, X=0, Y=0, SP=0, PC=0})
				mem.output = ""
				mem.scroll_lineno = nil
			end
		elseif fields.down then
			if vm16.is_loaded(pos) and mem.lToken then
				mem.scroll_lineno = math.min((mem.scroll_lineno or 1) + 8, #mem.lToken - 8)
			end
		elseif fields.up then
			if vm16.is_loaded(pos) and mem.lToken then
				mem.scroll_lineno = math.max((mem.scroll_lineno or 1) - 8, 1)
			end
		end
	end
	if mem.running and fields.stop then
		minetest.get_node_timer(pos):stop()
		mem.running = false
	end
	meta:set_string("formspec", vm16.cpu.formspec(pos, mem))
end

local function on_timer(pos, elapsed)
	if vm16.is_loaded(pos) then
		local mem = get_mem(pos)
		if mem.steps then
			mem.steps = mem.steps - 1
			M(pos):set_string("formspec", vm16.cpu.formspec(pos, mem))
			return mem.steps > 0 and vm16.run(pos, 1, clbks, mem.breakpoints) < vm16.HALT
		elseif mem.running then
			return vm16.run(pos, nil, clbks, mem.breakpoints) < vm16.HALT
		end
	end
end

local function on_rightclick(pos)
	M(pos):set_string("formspec", vm16.cpu.formspec(pos, get_mem(pos)))
end

minetest.register_node("vm16:cpu", {
	description = "VM16 Computer",
	tiles = {
		"vm16_cpu_top.png",
		"vm16_cpu_top.png",
		"vm16_cpu.png",
	},
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = M(pos)
		meta:set_string("code", Code)
		meta:set_string("formspec", vm16.cpu.formspec(pos, get_mem(pos)))
		meta:set_string("infotext", "VM16 Computer")
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
	output = "vm16:cpu",
	recipe = {
		{"", "default:obsidian_glass", ""},
		{"default:steelblock", "basic_materials:gold_wire", "default:steelblock"},
		{"basic_materials:ic", "basic_materials:ic", "basic_materials:ic"},
	},
})
