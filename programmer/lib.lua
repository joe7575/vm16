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
local strfind = string.find
local strsub = string.sub
local tinsert = table.insert

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

function vm16.prog.strsplit(text)
   local list = {}
   local pos = 1

   while true do
      local first, last = strfind(text, "\n", pos)
      if first then -- found?
         tinsert(list, strsub(text, pos, first-1))
         pos = last+1
      else
         tinsert(list, strsub(text, pos))
         break
      end
   end
   return list
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

--local function get_window(mem, lineno, size)
--	if mem.scroll_lineno then
--		return mem.scroll_lineno, mem.scroll_lineno + 16
--	end
--	mem.start_idx = mem.start_idx or 1
--	if lineno > mem.start_idx + 12 then
--		mem.start_idx = lineno - 12
--	elseif lineno > 3 and lineno < mem.start_idx + 3 then
--		mem.start_idx = lineno - 3
--	end
--	return mem.start_idx, math.min(mem.start_idx + 16, size)
--end

function vm16.prog.get_cpu_def(cpu_pos)
	local node = minetest.get_node(cpu_pos)
	local ndef = minetest.registered_nodes[node.name]
	if ndef and ndef.vm16_cpu then
		return ndef.vm16_cpu
	end
end

