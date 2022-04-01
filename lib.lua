--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
]]--

local strfind = string.find
local strsub = string.sub
local tinsert = table.insert

-- Returns the number of operands (0,1,2) based on the given opcode
function vm16.num_operands(opcode)
	if opcode then
		local idx1 = math.floor(opcode / 1024)
		local rest = opcode - (idx1 * 1024)
		local idx2 = math.floor(rest / 32)
		local idx3 = rest % 32
		return (idx2 >= 16 and 1 or 0) + (idx3 >= 16 and 1 or 0)
	end
	return 0
end

function vm16.hex2number(s)
	local addr = string.match (s or "0", "^([0-9a-fA-F]+)$")
	if not addr or addr == "" then addr = "0" end
	return (tonumber(addr, 16) % 0x10000) or 0
end

-- Split a multi-line string into a list of lines
function vm16.splitlines(text)
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

function vm16.file_ext(filename)
	local _, ext = unpack(string.split(filename, ".", true, 1))
	return ext
end

function vm16.file_base(filename)
	local name, _ = unpack(string.split(filename, ".", true, 1))
	return name
end
