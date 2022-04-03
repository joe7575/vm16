--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Programmer helper functions
]]--

-- for lazy programmers
local M = minetest.get_meta

local Cache = {}    -- [hash] = {}

vm16.prog = {}

function vm16.prog.get_mem(pos)
	local hash = minetest.hash_node_position(pos)
	Cache[hash] = Cache[hash] or {}
	return Cache[hash]
end

function vm16.prog.del_mem(pos)
	local hash = minetest.hash_node_position(pos)
	Cache[hash] = nil
end

function vm16.prog.get_linenum(lToken, addr)
	for idx = #lToken, 1, -1 do
		local tok = lToken[idx]
		if tok.address == addr then
			return tok.lineno
		end
	end
	return 0
end

function vm16.prog.to_char(val)
	if val >= 32 and val <= 127 then
		return string.char(val)
	end
	return "."
end

function vm16.prog.to_string(val)
	if val > 255 then
		return vm16.prog.to_char(val / 256) .. vm16.prog.to_char(val % 256)
	else
		return vm16.prog.to_char(val)
	end
end

function vm16.prog.get_cpu_def(cpu_pos)
	local node = minetest.get_node(cpu_pos)
	local ndef = minetest.registered_nodes[node.name]
	if ndef and ndef.vm16_cpu then
		return ndef.vm16_cpu
	end
end

function vm16.dump_obj_code_listing(obj)
	local mydump = function(tbl)
		local t = {}
		for _,e in ipairs(tbl or {}) do
			if type(e) == "number" then
				table.insert(t, string.format("%04X", e))
			else
				table.insert(t, "'"..e.."'")
			end
		end
		return table.concat(t, " ")
	end

	local out = {"##### VM16 Object Code #####"}
	if obj and obj.lCode then
		for _,item in ipairs(obj.lCode) do
			local ctype, lineno, scode, address, opcodes = unpack(item)
			table.insert(out, string.format("%5s %3d %04X: %-15s %s", ctype, lineno, address or 0, scode, mydump(opcodes)))
		end
	end
	return table.concat(out, "\n")
end
