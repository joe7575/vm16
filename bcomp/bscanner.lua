--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Scanner/Tokenizer

  The Scanner is called recursive to handle import files.

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
local T_ASMCODE = 6
local T_NEWFILE = 7
local T_ENDFILE = 8

local lTypeString = {"ident", "number", "operand", "brace", "string", "asm code", "new file", "end file"}
local lToken = {}
local tScannedFiles = {}

local function file_ext(filename)
	local _, ext = unpack(string.split(filename, ".", true, 1))
	return ext
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
	self.tk_idx = 0
	self.tk_nxt = 0
	self.nested_calls = self.nested_calls or 0
	-- Reset global tables only once
	if self.nested_calls == 0 then
		lToken = {}
		tScannedFiles = {}
	end
end

function  BScan:import_file(filename)
	if tScannedFiles[filename] then
		return  -- already imported
	end
	tScannedFiles[filename] = true
	local is_asm_code = file_ext(filename) == "asm"
	local i = vm16.BScan:new({
		pos = self.pos,
		readfile = self.readfile,
		is_asm_code = is_asm_code,
		nested_calls = self.nested_calls + 1
	})
	i:bscan_init()
	local last_lineno = i:scanner(filename)
	table.insert(lToken, {type = T_NEWFILE, val = self.filename, lineno = self.lineno})
end

function BScan:tokenize(text)
	local idx = 1
	local size = #text

	while idx <= size do
		local ch = text:sub(idx, idx)
		if ch:match(SPACE) then
			local space = text:match(SPACE, idx)
			idx = idx + #space
		elseif ch:match(IDENT1) then
			local ident = text:match(IDENT2, idx)
			if ident == "import" then
				self.is_import_line = true
			elseif ident == "_asm_" then
				self.is_asm_code = true
				return
			else
				table.insert(lToken, {type = T_IDENT, val = ident, lineno = self.lineno})
			end
			idx = idx + #ident
		elseif ch == "0" and text:sub(idx + 1, idx + 1) == "x" then
			idx = idx + 2
			local number = text:match(HEXNUM, idx)
			table.insert(lToken, {type = T_NUMBER, val = tonumber(number, 16) or 0, lineno = self.lineno})
			idx = idx + #number
		elseif ch:match(NUMBER) then
			local number = text:match(NUMBER, idx)
			table.insert(lToken, {type = T_NUMBER, val = tonumber(number) or 0, lineno = self.lineno})
			idx = idx + #number
		elseif ch:match(OPERAND) then
			local operand = text:match(OPERAND, idx)
			if operand:sub(1, 2) == "//" then -- EOL comment
				break
			end
			table.insert(lToken, {type = T_OPERAND, val = operand, lineno = self.lineno})
			idx = idx + #operand
		elseif ch:match(BRACE) then
			table.insert(lToken, {type = T_BRACE, val = ch, lineno = self.lineno})
			idx = idx + 1
		elseif ch == "'" and text:match(CHAR, idx) then
			local char = text:match(CHAR, idx)
			local val = char_to_val(char)
			table.insert(lToken, {type = T_NUMBER, val = val, lineno = self.lineno})
			idx = idx + #char + 2
		elseif ch == '"' and text:match(STRING, idx) then
			local str = text:match(STRING, idx)
			if self.is_import_line then
				self.is_import_line = nil
				self:import_file(string.sub(str, 2, -2))
			else
				local str2 = string.sub(str, 1, -2) .. '\\0"'
				table.insert(lToken, {type = T_STRING, val = str2, lineno = self.lineno})
			end
			idx = idx + #str
		else
			self:error_msg(string.format("Invalid character '%s'", ch))
		end
	end
end

function BScan:scanner(filename)
	self.filename = filename
	self.lineno = 0
	if self.nested_calls > 10 then
		self:error_msg("Maximum number of nested imports exceeded")
	end
	table.insert(lToken, {type = T_NEWFILE, val = filename, lineno = 0})

	local text = self.readfile(self.pos, filename)
	if not text then
		self:error_msg(string.format("Can't open file '%s'", filename))
	end
	text = text:gsub("\\0", "\0")
	text = text:gsub("\\n", "\n")

	for lineno, line in ipairs(vm16.splitlines(text)) do
		self.lineno = lineno
		if self.is_asm_code then
			line = line:trim()
			if line == "}" then
				self.is_asm_code = false
			else
				table.insert(lToken, {type = T_ASMCODE, val = line, lineno = lineno})
			end
		else
			self:tokenize(line)
		end
	end

	table.insert(lToken, {type = T_ENDFILE, val = filename, lineno = self.lineno})
	
	if self.nested_calls == 0 then
		self.lTok = lToken
		lToken = {}
		self.tk_idx = 1
	end
	return self.lineno
end

function BScan:tk_match(ttype)
	local tok = self.lTok[self.tk_idx] or {}
	self.tk_idx = self.tk_idx + 1
	self.lineno = tok.lineno or 0
	if not ttype or ttype == tok.type or ttype == tok.val then
		return tok
	end

	local detected = tok.val:gsub("\\0", "")
	local expected = type(ttype) == "string" and ttype or lTypeString[ttype]
	self:error_msg(string.format("Syntax error: '%s' expected near '%s'", expected, detected))
end

function BScan:tk_peek()
	return self.lTok[self.tk_idx] or {}
end

function BScan:tk_next()
	return self.lTok[self.tk_idx + 1] or {}
end

function BScan:scan_dbg_dump()
	local out = {}

	for idx,tok in ipairs(self.lTok) do
		if tok.type == T_NEWFILE then
			out[idx] = string.format('%8s: #### "%s" ####', lTypeString[tok.type], tok.val)
		else
			out[idx] = string.format('%8s: (%d) "%s"', lTypeString[tok.type], tok.lineno, tok.val)
		end
	end

	return table.concat(out, "\n")
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
vm16.T_ASMCODE = T_ASMCODE
vm16.T_NEWFILE = T_NEWFILE
vm16.T_ENDFILE = T_ENDFILE
