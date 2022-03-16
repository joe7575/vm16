--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Variables watch window for the debugger
]]--

vm16.files = {}

local function format_files(pos, mem, files)
	local lines = {}

	lines[#lines + 1] = string.format("%-16s 20:23      ro", "command.h")
	for _, file in ipairs(files or {}) do
		local s = string.format(      "%-16s 2022-03-12 rw", file)
		lines[#lines + 1] = s
	end
	return table.concat(lines, ",")
end


function vm16.files.init(pos, mem)
	mem.lVars = {}
	for k,v in pairs(mem.tGlobals or {}) do
		mem.lVars[#mem.lVars + 1] = k
	end
	table.sort(mem.lVars)
end

function vm16.files.fs_window(pos, mem, x, y, xsize, ysize, fontsize, files)
	local color = mem.running and "#AAA" or "#FFF"
	return "label[" .. x .. "," .. (y - 0.2) .. ";Files]" ..
		"style_type[table;font=mono;font_size="  .. fontsize .. "]" ..
		"tableoptions[color=" ..color .. ";highlight_text=" ..color .. ";highlight=#63007E]" ..
		"table[" .. x .. "," .. y .. ";" .. xsize .. "," .. ysize .. ";watch;" .. 
		format_files(pos, mem, files) .. ";]"
end
