--[[

  VM16 Asm
  ========

  Copyright (C) 2019-2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information
]]--

-- Tok Elems {1, "add A, 1",  "add A, 1  ; start value", CODESEC, 10, {0x1234, 0x001}}
local LINENO  = 1
local CODESTR = 2
local TXTLINE = 3
local SECTION = 4
local ADDRESS = 5
local OPCODES = 6

-- Sections
local DATASEC  = 1
local CODESEC  = 2
local TEXTSEC  = 3
local CTEXTSEC = 4

local tOpcodes = {}
local tOperands = {}
local IDENT = "^[A-Za-z_][A-Za-z_0-9%.]+"

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
	"IMM", "IND", "REL", "[SP+n]",
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
	[".data"]  = DATASEC,
	[".code"]  = CODESEC,
	[".text"]  = TEXTSEC,
	[".ctext"] = CTEXTSEC,
}

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------
local strfind = string.find
local strsub = string.sub
local tinsert = table.insert

local function strsplit(s)
	local words = {}
	string.gsub(s, "([^%s,]+)", function(w)
		table.insert(words, w)
	end)
	return words
end

local function linessplit(text)
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

function Asm:new(attr)
	local o = {
		section = attr.section or CODESEC,
		address = attr.address or 0,
		symbols = {},
		errors = {},
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Asm:err_msg(err)
	local s = string.format("Err (%u): %s!", self.lineno or 0, err)
	append(self.errors, s)
	self.error = true
end

function Asm:scanner(text)
    local lOut = {}  -- {lineno, codestr, txtline}

	if not vm16.is_ascii(text) then
		return nil, "Invalid ASCII file format"
	end
	for lineno, txtline in ipairs(linessplit(text)) do
		local _, _, codestr = txtline:find("(.+);")
		codestr = string.trim(codestr or txtline)
		if string.byte(codestr, 1) == 59 then -- ';'
			append(lOut, {lineno, "", txtline})
		elseif codestr == "" then
			append(lOut, {lineno, "", txtline})
		else
			append(lOut, {lineno, codestr, txtline})
		end
	end
	return lOut
end

function Asm:address_label(tok)
	local codestr = tok[CODESTR]
	local _, pos, label = codestr:find("^([A-Za-z_][A-Za-z_0-9]+):( *)")
	if label then
		self.symbols[label] = self.address
		tok[CODESTR] = codestr:sub(pos+1, -1)
	end
	return tok
end

-- New assembler section
function Asm:section_def(tok)
	local codestr = tok[CODESTR]
	if tSections[codestr] then
		self.section = tSections[codestr]
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
	if c == "+" then return tOperands["REL"], value(string.sub(s, 2, -1)) end
	if c == "-" then return tOperands["REL"], 0x10000 - value(string.sub(s, 2, -1)) end
	if string.sub(s, 1, 4) == "[SP+" then return tOperands["[SP+n]"], value(string.sub(s, 5, -2)) end
	-- valid label keyword
	if s:match(IDENT) then
		return tOperands["IND"], s
	end
	return
end

function Asm:decode_code(tok)
	local codestr = tok[CODESTR]
	local words = strsplit(codestr)
	if codestr == "" then
		return {tok[LINENO], tok[CODESTR], tok[TXTLINE], self.section, self.address, {}}
	end
	-- Aliases
	if words[2] == "=" then
		if words[1]:match(IDENT) then
			local ident = words[1]
			self.symbols[ident] = value(words[3])
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
		return
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
	if val1 and val2 then
		self:err_msg("Syntax error")
		return
	end
	if not opnd1 and not opnd2 then
		self:err_msg("Syntax error")
		return
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

	tok = {tok[LINENO], tok[CODESTR], tok[TXTLINE], self.section, self.address, tbl}
	self.address = self.address + #tbl
	return tok
end

function Asm:decode_data(tok)
	local codestr = tok[CODESTR]
	if codestr == "" then
		return {{tok[LINENO], tok[CODESTR], tok[TXTLINE], self.section, self.address, {}}}
	end
	local words = strsplit(codestr)
	local tbl = {}
	for _,word in ipairs(words) do
		if word then
			append(tbl, value(word))
		end
	end
	tok = {tok[LINENO], tok[CODESTR], tok[TXTLINE], self.section, self.address, tbl}
	self.address = self.address + #tbl
	return tok
end

function Asm:decode_text(tok)
	local codestr = tok[CODESTR]
	if codestr == "" then
		return {{tok[LINENO], tok[CODESTR], tok[TXTLINE], self.section, self.address, {}}}
	end
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
			tok = {tok[LINENO], codestr:sub(idx, idx + 7), tok[TXTLINE], self.section, self.address, tbl}
			self.address = self.address + #tbl
			append(out, tok)
		end
		return out
	else
		self:err_msg("Invalid string")
		return
	end
end

function Asm:decode_ctext(tok)
	local codestr = tok[CODESTR]
	if codestr == "" then
		return {{tok[LINENO], tok[CODESTR], tok[TXTLINE], self.section, self.address, {}}}
	end
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
			tok = {tok[LINENO], codestr:sub(idx, idx + 7), tok[TXTLINE], self.section, self.address, tbl}
			self.address = self.address + #tbl
			append(out, tok)
		end
		return out
	else
		self:err_msg("Invalid string")
		return
	end
end

function Asm:assembler(lToken)
	local lOut = {}
	-- pass 1
	for _,tok in ipairs(lToken or {}) do
		self.lineno = tok[LINENO]
		tok = self:address_label(tok)
		tok = self:section_def(tok)
		tok = self:org_directive(tok)

		if self.section == CODESEC then
			append(lOut, self:decode_code(tok))
		elseif self.section == DATASEC then
			extend(lOut, self:decode_data(tok))
		elseif self.section == TEXTSEC then
			extend(lOut, self:decode_text(tok))
		elseif self.section == CTEXTSEC then
			extend(lOut, self:decode_ctext(tok))
		end

	end

	-- pass 2
	for _,tok in ipairs(lOut) do
		for i, opc in ipairs(tok[OPCODES] or {}) do
			if type(opc) == "string" then
				if self.symbols[opc] then
					tok[OPCODES][i] = self.symbols[opc]
				else
					self:err_msg("Unknown label " .. opc)
				end
			end
		end
	end

	if self.error then
		return nil, table.concat(self.errors, "\n")
	end
	return lOut
end

function Asm:listing(lToken)
	local mydump = function(tbl)
		local t = {}
		for _,e in ipairs(tbl) do
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
		append(out, string.format("%04X: %-10s %s", tok[ADDRESS], mydump(tok[OPCODES]), tok[TXTLINE]))
	end
	return table.concat(out, "\n")
end

vm16.Asm = Asm

vm16.Asm.LINENO  = LINENO
vm16.Asm.CODESTR = CODESTR
vm16.Asm.TXTLINE = TXTLINE
vm16.Asm.SECTION = SECTION
vm16.Asm.ADDRESS = ADDRESS
vm16.Asm.OPCODES = OPCODES

vm16.Asm.DATASEC  = DATASEC
vm16.Asm.CODESEC  = CODESEC
vm16.Asm.TEXTSEC  = TEXTSEC
vm16.Asm.CTEXTSEC = CTEXTSEC

