--[[

  VM16 Asm
  ========

  Copyright (C) 2019-2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  The Assembler accepts a list with following code items:
  
  {CTYPE,  LINENO,  CODESTR,      ADDRESS,  OPCODES}
  {"code",  2,     "move A, #1",   10,     {0x1020, 0x0001}}

]]--

local version = "2.2"

local CTYPE   = 1
local LINENO  = 2
local CODESTR = 3
local ADDRESS = 4
local OPCODES = 5

local tOpcodes = {}
local tOperands = {}
local IDENT  = "^[A-Za-z_][A-Za-z_0-9%.]+"
local RIPLBL = "^PC%+[A-Za-z_][A-Za-z_0-9%.]+"

--
-- OP-codes
--
local Opcodes = {[0] =
	"nop:-:-", "brk:CNST:-", "sys:CNST:-", "res2:CNST:-",
	"jump:ADR:-", "call:ADR:-", "ret:-:-", "halt:-:-",
	"move:DST:SRC", "xchg:DST:DST", "inc:DST:-", "dec:DST:-",
	"add:DST:SRC", "sub:DST:SRC", "mul:DST:SRC", "div:DST:SRC",
	"and:DST:SRC", "or:DST:SRC", "xor:DST:SRC", "not:DST:-",
	"bnze:DST:ADR", "bze:DST:ADR", "bpos:DST:ADR", "bneg:DST:ADR",
	"in:DST:CNST", "out:CNST:SRC", "push:SRC:-", "pop:DST:-",
	"swap:DST:-", "dbnz:DST:ADR", "mod:DST:SRC",
	"shl:DST:SRC", "shr:DST:SRC", "addc:DST:SRC", "mulc:DST:SRC",
	"skne:SRC:SRC", "skeq:SRC:SRC", "sklt:SRC:SRC", "skgt:SRC:SRC",
}

--
-- Operands
--
local Operands = {[0] =
	"A", "B", "C", "D", "X", "Y", "PC", "SP",
	"[X]", "[Y]", "[X]+", "[Y]+", "#0", "#1", "-", "-",
	"IMM", "IND", "REL", "[SP+n]", "REL2", "[X+n]", "[Y+n]"
}

--
-- Need special operand handling
--
local JumpInst = {
	["call"] = true, ["jump"] = true, ["bnze"] = true, ["bze"] = true,
	["bpos"] = true, ["bneg"] = true, ["dbnz"] = true
}

for idx,s in pairs(Opcodes) do
	local opc = string.split(s, ":")[1]
	tOpcodes[opc] = idx
end

for idx,s in pairs(Operands) do
	tOperands[s] = idx
end

local tSections = {
	[".data"]  = true,
	[".code"]  = true,
	[".text"]  = true,
	[".ctext"] = true,
}

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------
local function strsplit(s)
	local words = {}
	string.gsub(s, "([^%s,]+)", function(w)
		table.insert(words, w)
	end)
	return words
end

local function constant(s)
	if s and string.sub(s, 1, 1) == "#" then
		if string.sub(s, 2, 2) == "$" then
			return tonumber(string.sub(s, 3, -1), 16) or 0
		else
			return tonumber(string.sub(s, 2, -1), 10) or 0
		end
	else
		return 0
	end
end

local function value(s, is_hex)
	if s:match(IDENT) then
		return s
	end
	if s then
		if string.sub(s, 1, 1) == "$" then
			return tonumber(string.sub(s, 2, -1), 16) or 0
		elseif is_hex then
			return tonumber(s, 16) or 0
		else
			return tonumber(s, 10) or 0
		end
	else
		return 0
	end
end

local function pos_value(s, is_hex)
	if s:match(IDENT) then
		return "PC+" .. s
	end
	return value(s, is_hex)
end

local function neg_value(s, is_hex)
	if s:match(IDENT) then
		return "PC+" .. s
	end
	return 0x10000 - value(s, is_hex)
end

local function word_val(s, idx)
	if s:byte(idx) == 0 then
		return 0
	elseif idx == #s then
		return s:byte(idx)
	elseif s:byte(idx+1) == 0 then
		return s:byte(idx)
	else
		return (s:byte(idx) * 256) + s:byte(idx+1)
	end
end

local function append(into, from)
	if into and from then
		into[#into + 1] = from
	end
end

local function extend(into, from)
	if into and from then
		for _, t in ipairs(from or {}) do
			into[#into + 1] = t
		end
	end
end

-------------------------------------------------------------------------------
-- Assembler
-------------------------------------------------------------------------------
local Asm = {}

function Asm:new(o)
	o = o or {}
	o.address = o.address or 0
	o.support_namespaces = o.support_namespaces
	o.globals = {}
	o.all_symbols = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Asm:err_msg(err)
	--print(string.format("%s(%d): %s!", self.filename, self.lineno or 0, err))
	error(string.format("\001%s(%d): %s!", self.filename, self.lineno or 0, err))
end

function Asm:scanner(text, filename)
    local lOut = {}  -- {lineno, codestr, txtline}
	self.filename = filename
	self.lineno = 0

	if not vm16.is_ascii(text) then
		self:err_msg("Invalid ASCII file format!")
	end

	append(lOut, {"file", 0, filename})
	self.ctype = "code"

	for lineno, txtline in ipairs(vm16.splitlines(text)) do
		local _, _, codestr = txtline:find("(.+);")
		codestr = string.trim(codestr or txtline)
		if tSections[codestr] then
			self.ctype = string.sub(codestr, 2)
		elseif codestr ~= "" and string.byte(codestr, 1) ~= 59 then -- ';'
			append(lOut, {self.ctype, lineno, codestr})
		end
	end
	return lOut
end

function Asm:address_label(tok)
	local codestr = tok[CODESTR]
	local _, pos, label = codestr:find("^([A-Za-z_][A-Za-z_0-9]*):( *)")
	if label then
		if self.globals[label] == -1 then
			self.globals[label] = self.address
			-- Add 'func' line to the output stream
			if tok[CTYPE] == "code" then
				self.set_func = label
			end
		else
			if self.symbols[label] then
				self:err_msg("Redefinition of label " .. label)
			end
			self.symbols[label] = self.address
		end
		tok[CODESTR] = codestr:sub(pos+1, -1)
		self.label = label
	end
	return tok
end

function Asm:global_def(tok)
	local codestr = tok[CODESTR]
	local _, pos, label = codestr:find("^ *global +([A-Za-z_][A-Za-z_0-9]*)( *)")
	if label then
		if self.globals[label] then
			self:err_msg("Redefinition of global " .. label)
		end
		self.globals[label] = -1
		tok[CODESTR] = ""
	end
	return tok
end

function Asm:org_directive(tok)
	local codestr = tok[CODESTR]
	local _, _, addr = codestr:find("^%.org +([%$%x]+)$")
	if addr then
		self.address = value(addr)
		tok[CODESTR] = ""
	end
	return tok
end

function Asm:operand(s)
	if not s then return 0 end
	local s2 = string.upper(s)
	if tOperands[s2] then
		return tOperands[s2]
	end
	local c = string.sub(s, 1, 1)

	if c == "#" then return tOperands["IMM"], value(string.sub(s, 2, -1)) end
	if c == "$" then return tOperands["IND"], value(s) end
	-- value without '#' and '$'
	if string.byte(c) >= 48 and string.byte(c) <= 57 then return tOperands["IND"], value(s) end
	if c == "+" then return tOperands["REL2"], pos_value(string.sub(s, 2, -1)) end
	if c == "-" then return tOperands["REL2"], neg_value(string.sub(s, 2, -1)) end
	if string.sub(s, 1, 4) == "[SP+" then return tOperands["[SP+n]"], value(string.sub(s, 5, -2)) end
	if string.sub(s, 1, 3) == "[X+" then return tOperands["[X+n]"], value(string.sub(s, 4, -2)) end
	if string.sub(s, 1, 3) == "[Y+" then return tOperands["[Y+n]"], value(string.sub(s, 4, -2)) end
	-- valid label keyword
	if s:match(IDENT) then
		return tOperands["IND"], s
	end
	return
end

function Asm:decode_code(tok)
	local codestr = tok[CODESTR]
	local words = strsplit(codestr)
	-- Aliases
	if words[2] == "=" then
		if words[1]:match(IDENT) then
			local label = words[1]
			if self.symbols[label] then
				self:err_msg("Redefinition of symbol " .. label)
			end
			self.symbols[label] = value(words[3])
		else
			self:err_msg("Invalid left value")
		end
		return
	end

	-- Opcodes
	local opcode, opnd1, opnd2, val1, val2

	opcode = tOpcodes[words[1]]
	if not opcode then
		self:err_msg("Syntax error")
	end
	if #words == 2 and opcode < 4 then
		local num = constant(words[2]) % 1024
		opnd1 = math.floor(num / 32)
		opnd2 = num % 32
	else
		opnd1, val1 = self:operand(words[2])
		opnd2, val2 = self:operand(words[3])
	end
	-- some checks
	if not opnd1 and not opnd2 then
		self:err_msg("Syntax error")
	end
	-- code correction for all jump/branch opcodes: from '0' to '#0'
	if JumpInst[words[1]] then
		if opnd1 == tOperands["IND"] then opnd1 = tOperands["IMM"] end
		if opnd2 == tOperands["IND"] then opnd2 = tOperands["IMM"] end
	end
	-- calculate opcode
	local tbl = {(opcode * 1024) + ((opnd1 or 0) * 32) + (opnd2 or 0)}
	if val1 then tbl[#tbl+1] = val1 end
	if val2 then tbl[#tbl+1] = val2 end

	tok = {"code", tok[LINENO], tok[CODESTR], self.address, tbl}
	self.address = self.address + #tbl
	return tok
end

function Asm:decode_data(tok)
	local codestr = tok[CODESTR]
	local words = strsplit(codestr)
	local tbl = {}
	for _,word in ipairs(words) do
		if word then
			append(tbl, value(word))
		end
	end
	-- restore original label
	tok = {"data", tok[LINENO], self.label, self.address, tbl}
	self.address = self.address + #tbl
	return tok
end

function Asm:decode_text(tok)
	local codestr = tok[CODESTR]
	if codestr:byte(1) == 34 and codestr:byte(-1) == 34 then
		codestr = codestr:gsub("\\0", "\0")
		codestr = codestr:gsub("\\n", "\n")
		codestr = codestr:sub(2, -2)
		local ln = #codestr

		local out = {}
		for idx = 1, ln, 8 do
			local tbl = {}
			for i = idx, math.min(idx + 7, ln) do
				append(tbl, codestr:byte(i))
			end
			tok = {"text", tok[LINENO], codestr:sub(idx, idx + 7), self.address, tbl}
			self.address = self.address + #tbl
			append(out, tok)
		end
		return out
	else
		self:err_msg("Invalid string")
	end
end

function Asm:decode_ctext(tok)
	local codestr = tok[CODESTR]
	if codestr:byte(1) == 34 and codestr:byte(-1) == 34 then
		codestr = codestr:gsub("\\0", "\0\0")
		codestr = codestr:gsub("\\n", "\n")
		codestr = codestr:sub(2, -2)
		local ln = #codestr

		local out = {}
		for idx = 1, ln, 16 do
			local tbl = {}
			for i = idx, math.min(idx + 15, ln), 2 do
				append(tbl, word_val(codestr, i))
			end
			tok = {"ctext", tok[LINENO], codestr:sub(idx, idx + 7), self.address, tbl}
			self.address = self.address + #tbl
			append(out, tok)
		end
		return out
	else
		self:err_msg("Invalid string")
	end
end

function Asm:handle_rip_label(tok, i, opc)
	if opc:match(RIPLBL) then
		local label = string.sub(opc, 4, -1)
		if self.symbols[label] then
			tok[OPCODES][i] = self.symbols[label] - (tok[ADDRESS] or 0)
		elseif self.globals[label] then
			tok[OPCODES][i] = self.globals[label] - (tok[ADDRESS] or 0)
		else
			self:err_msg("Unknown label " .. label)
		end
		return true
	end
end

function Asm:handle_label(tok, i, label)
	if self.symbols[label] then
		tok[OPCODES][i] = self.symbols[label]
	elseif self.globals[label] then
		tok[OPCODES][i] = self.globals[label]
	else
		self:err_msg("Unknown label " .. label)
	end
end

function Asm:assembler(filename, lToken)
	local lOut = {}
	-- pass 1
	self.filename = filename
	self.all_symbols[self.filename] = {}
	self.symbols = self.all_symbols[self.filename]
	
	for _,tok in ipairs(lToken or {}) do
		self.lineno = tok[LINENO]
		tok = self:global_def(tok)
		tok = self:org_directive(tok)
		tok = self:address_label(tok)
		self.ctype = tok[CTYPE]

		if self.set_global then
			append(lOut, {"code", self.lineno, "global " .. self.set_global})
			self.set_global = nil
		end
		if self.set_func then
			append(lOut, {"func", self.lineno, self.set_func})
			self.set_func = nil
		end
		
		if tok[CODESTR] ~= "" then
			if self.ctype == "code" then
				append(lOut, self:decode_code(tok))
			elseif self.ctype == "data" then
				append(lOut, self:decode_data(tok))
			elseif self.ctype == "text" then
				extend(lOut, self:decode_text(tok))
			elseif self.ctype == "ctext" then
				extend(lOut, self:decode_ctext(tok))
			elseif self.ctype == "file" then
				self.filename = tok[CODESTR]
				append(lOut, tok)
				self.all_symbols[self.filename] = {}
				self.symbols = self.all_symbols[self.filename]
			else
				append(lOut, tok)
			end
		end
	end

	-- pass 2
	for _,tok in ipairs(lOut) do
		self.lineno = tok[LINENO]
		if tok[CTYPE] == "file" then
			self.filename = tok[CODESTR]
			self.symbols = self.all_symbols[self.filename]
		elseif tok[CTYPE] == "func" then
			tok[ADDRESS] = self.globals[tok[CODESTR]] or 0
		elseif tok[CTYPE] == "call" then
			tok[ADDRESS] = self.globals[tok[CODESTR]] or 0
		else
			for i, opc in ipairs(tok[OPCODES] or {}) do
				if type(opc) == "string" then
					if not self:handle_rip_label(tok, i, opc) then
						self:handle_label(tok, i, opc)
					end
				end
			end
		end
	end

	return lOut
end

function Asm:listing(lToken)
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

	local out = {}
	for _,tok in ipairs(lToken) do
		append(out, string.format("%5s %3d %04X: %-15s %s", tok[CTYPE], tok[LINENO] or 0, tok[ADDRESS] or 0, tok[CODESTR], mydump(tok[OPCODES])))
	end
	return table.concat(out, "\n")
end

vm16.Asm = Asm

vm16.Asm.version = version
vm16.Asm.CTYPE   = CTYPE
vm16.Asm.LINENO  = LINENO
vm16.Asm.CODESTR = CODESTR
vm16.Asm.ADDRESS = ADDRESS
vm16.Asm.OPCODES = OPCODES

