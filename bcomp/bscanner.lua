--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Scanner/Tokenizer

]]--

local IDENT1   = "[A-Za-z_]+"
local IDENT2   = "[A-Za-z_][A-Za-z_0-9]*"
local NUMBER   = "[0-9]+"
local HEXNUM   = "[0-9a-fA-F]+"
local OPERAND  = "[%+%-/%*%%=<>!;,&|!~%^][%+%-/=<>&|]*"
local BRACE    = "[{}%(%)%[%]]"
local SPACE    = "[%s]"
local CHAR     = "'([^'][^']?)'"
local STRING   = '"[^"]+"'

local T_IDENT   = 1
local T_NUMBER  = 2
local T_OPERAND = 3
local T_BRACE   = 4
local T_STRING  = 5

local strfind = string.find
local strsub  = string.sub
local tinsert = table.insert

local function split_into_lines(text)
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

local function char_to_val(char)
	if #char == 2 then
		return char:byte(1) * 256 + char:byte(2)
	else
		return char:byte(1)
	end
end


local BScan = vm16.BGen:new({})

function BScan:bscan_init()
	self.ltok = {}
	self.tk_idx = 1
	self.co = coroutine.create(self.line_produce)
end

function BScan:scanner(text)
	local idx = 1
	local size = #text
	-- If necessary, save the last value (needed for tk_next)
	self.ltok = {self.ltok[self.tk_idx]}
	self.tk_idx = 1

	while idx <= size do
		local ch = text:sub(idx, idx)
		if ch:match(SPACE) then
			local space = text:match(SPACE, idx)
			idx = idx + #space
		elseif ch:match(IDENT1) then
			local ident = text:match(IDENT2, idx)
			table.insert(self.ltok, {type = T_IDENT, val = ident})
			idx = idx + #ident
		elseif ch == "0" and text:sub(idx + 1, idx + 1) == "x" then
			idx = idx + 2
			local number = text:match(HEXNUM, idx)
			table.insert(self.ltok, {type = T_NUMBER, val = tonumber(number, 16) or 0})
			idx = idx + #number
		elseif ch:match(NUMBER) then
			local number = text:match(NUMBER, idx)
			table.insert(self.ltok, {type = T_NUMBER, val = tonumber(number) or 0})
			idx = idx + #number
		elseif ch:match(OPERAND) then
			local operand = text:match(OPERAND, idx)
			if operand:sub(1, 2) == "//" then -- EOL comment
				break
			end
			table.insert(self.ltok, {type = T_OPERAND, val = operand})
			idx = idx + #operand
		elseif ch:match(BRACE) then
			table.insert(self.ltok, {type = T_BRACE, val = ch})
			idx = idx + 1
		elseif ch == "'" and text:match(CHAR, idx) then
			local char = text:match(CHAR, idx)
			local val = char_to_val(char)
			table.insert(self.ltok, {type = T_NUMBER, val = val})
			idx = idx + #char + 2
		elseif ch == '"' and text:match(STRING, idx) then
			local str = text:match(STRING, idx)
			table.insert(self.ltok, {type = T_STRING, val = str})
			idx = idx + #str
		else
			error(string.format("Syntax error at '%s'", ch))
		end
	end
end

function BScan:line_produce()
	--require('mobdebug').on()
	for lineno, line in ipairs(split_into_lines(self.text)) do
		self.lineno = lineno
		if self.scanner_raw_mode then
			coroutine.yield(line)
		elseif line:trim() ~= "" then
			self:add_line(string.format(";%4d: %s", lineno, line))
			self:scanner(line)
			coroutine.yield(true)
		end
	end
end

function BScan:tk_match(ttype)
	while self.tk_idx > #self.ltok do
		local res = coroutine.resume(self.co, self)
		if not res then break end
	end
	local tok = self.ltok[self.tk_idx] or {}
	if tok.val == self.break_ident then
		print("Stop")
	end
	if not ttype or ttype == tok.type or ttype == tok.val then
		self.tk_idx = self.tk_idx + 1
		return tok
	end
	--print(string.format("Syntax error at '%s', '%s' expected", tok.val or "", ttype or ""))
	error(string.format("Syntax error at '%s', '%s' expected", tok.val or "", ttype or ""))
end

function BScan:tk_peek()
	while self.tk_idx > #self.ltok do
		local res = coroutine.resume(self.co, self)
		if not res then break end
	end
	return self.ltok[self.tk_idx] or {}
end

function BScan:tk_next()
	while self.tk_idx + 1 > #self.ltok do
		local res = coroutine.resume(self.co, self)
		if not res then break end
	end
	return self.ltok[self.tk_idx + 1] or {}
end

function BScan:tk_rawline()
	self.scanner_raw_mode = true
	local res, line = coroutine.resume(self.co, self)
	self.scanner_raw_mode = false
	return res and line
end

vm16.BScan = BScan

vm16.IDENT1  = IDENT1
vm16.IDENT2  = IDENT2
vm16.NUMBER  = NUMBER
vm16.OPERAND = OPERAND
vm16.BRACE   = BRACE
vm16.SPACE   = SPACE

vm16.T_IDENT   = T_IDENT
vm16.T_NUMBER  = T_NUMBER
vm16.T_OPERAND = T_OPERAND
vm16.T_BRACE   = T_BRACE
vm16.T_STRING  = T_STRING
