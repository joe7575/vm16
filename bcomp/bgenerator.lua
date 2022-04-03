--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Asm code generation

]]--

local REGS     = {A=1, B=1, C=1, D=1, X=1, Y=1, SP=1, PC=1}  -- real registers
local REGLIST  = {"A", "B", "C", "D"}
-- Need NO special handling of operand1
local ASSIGNMENT_INSTR = {move=1, out=1}
-- Last operand register can be reused
local CLOSING_INSTR = {move=1, push=1, add=1, addc=1, mul=1, mulc=1, div=1, sub=1,
                       mod=1, ["and"]=1, ["or"]=1, xor=1, ["not"]=1, ["in"]=1, out=1,
                       push=1, shl=1, shr=1}

local tSections = {
	[".data"]  = true,
	[".code"]  = true,
	[".text"]  = true,
	[".ctext"] = true,
}

local BGen = {}

function BGen:new(o)
	o = o or {}
	o.label_cnt = 0
	o.string_cnt = 0
	o.reg_cnt = 0
	o.ctype = "code"
	o.reg_cnt_stack = {}
	o.lInit = {}
	o.lCode = {}
	o.lData = {}
	o.lText = {}
	o.lGlobal = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function BGen:error_msg(err)
	err = string.format("\001%s(%d): %s", self.filename or "", self.lineno or 0, err)
	error(err)
end

function BGen:__add_move_instr(instr, opnd1, opnd2)
	self.reg_cnt = self.reg_cnt + 1
	if self.reg_cnt < 5 then
		local new_opnd = REGLIST[self.reg_cnt]
		table.insert(self.lCode, {"code", self.lineno, "move " .. new_opnd .. ", " .. opnd1})
		return new_opnd
	else
		self:error_msg("Expression too complex", 2)
	end
end

function BGen:__next_free_reg(instr, opnd1, opnd2)
	if not ASSIGNMENT_INSTR[instr] and not REGS[opnd1] then
		return self:__add_move_instr(instr, opnd1, opnd2)
	else
		return opnd1
	end
end

function BGen:__free_last_operand_reg(instr, opnd)
	if CLOSING_INSTR[instr] then
		if REGS[opnd] then
			if self.reg_cnt > 0 then
				self.reg_cnt = self.reg_cnt - 1
			end
		end
	end
end

function BGen:next_free_indexreg()
	if not self.x_in_use then
		self.x_in_use = true
		return "X"
	elseif not self.y_in_use then
		self.y_in_use = true
		return "Y"
	else
		self:error_msg("Pointer expression too complex", 2)
	end
end

function BGen:reset_reg_use()
	self.reg_cnt = 0
	self.x_in_use = nil
	self.y_in_use = nil
end

function BGen:add_instr(instr, opnd1, opnd2)
	if opnd2 then
		opnd1 = self:__next_free_reg(instr, opnd1, opnd2)
		table.insert(self.lCode, {"code", self.lineno, instr .. " " .. opnd1 .. ", " .. opnd2})
		self.__free_last_operand_reg(instr, opnd2)
	elseif opnd1 then
		if instr == "not" then
			opnd1 = self:__next_free_reg(instr, opnd1)
			table.insert(self.lCode, {"code", self.lineno, instr .. " " .. opnd1})
		else
			table.insert(self.lCode, {"code", self.lineno, instr .. " " .. opnd1})
			self:__free_last_operand_reg(instr, opnd1)
		end
	else
		table.insert(self.lCode, {"code", self.lineno, instr})
	end
	self.last_instr = instr
	return opnd1
end

--Store used registers before function call
function BGen:push_regs()
	table.insert(self.reg_cnt_stack, self.reg_cnt)
	for i = 1, self.reg_cnt do
		table.insert(self.lCode,  {"code", self.lineno, "push " .. REGLIST[i]})
	end
	self.reg_cnt = 0
end

--Restore used registers after function call
function BGen:pop_regs()
	local reg
	self.reg_cnt = table.remove(self.reg_cnt_stack)
	-- Move function result in next free register
	local old_reg_cnt = self.reg_cnt
	if self.reg_cnt > 0 then
		reg = self:__add_move_instr("move", "A", "A")
	else
		self.reg_cnt = 1
		reg = "A"
	end
	for i = old_reg_cnt, 1, -1 do
		table.insert(self.lCode,  {"code", self.lineno, "pop  " .. REGLIST[i]})
	end
	return reg
end

function BGen:get_instr_pos()
	return #self.lCode
end

function BGen:instr_move(pos1, pos2, pos3)
	local n = pos2 - pos1
	for idx = 1, n do
		local val = table.remove(self.lCode, pos1 + 1)
		table.insert(self.lCode, pos3, val)
	end
end

function BGen:get_last_instr()
	return self.last_instr
end

function BGen:add_label(lbl)
	table.insert(self.lCode, {"code", self.lineno, lbl .. ":"})
end

function BGen:add_asm_token(tok)
	local _, _, codestr = tok.val:find("(.+);?")
	codestr = string.trim(codestr or "")
	if tSections[codestr] then
		self.ctype = string.sub(codestr, 2)
	elseif codestr ~= "" and string.byte(codestr, 1) ~= 59 then -- ';'
		if self.ctype == "code" then
			table.insert(self.lCode, {"code", tok.lineno, codestr})
		elseif self.ctype == "data" then
			table.insert(self.lData, {"data", tok.lineno, codestr})
		elseif self.ctype == "ctext" then
			table.insert(self.lText, {"ctext", tok.lineno, codestr})
		end
	end
end

function BGen:end_asm_code()
	self.ctype = "code"
end

function BGen:add_then_label()
	if self.then_lbl then
		table.insert(self.lCode, {"code", self.lineno, self.then_lbl .. ":"})
		self.then_lbl = nil
	end
end

function BGen:add_item(ctype, lineno, val)
	table.insert(self.lCode, {ctype, lineno, val})
end

-- For functions and Variables to be declared as global
function BGen:set_global(name)
	table.insert(self.lGlobal, name)
end

function BGen:add_data(ident, val)
	table.insert(self.lData, {"data", self.lineno, ident .. ": " .. (val or "0")})
end

function BGen:append_val(val)
	if #self.lData[#self.lData][3] > 32 then
		table.insert(self.lData, {"data", self.lineno, "  "})
	end
	self.lData[#self.lData][3] = self.lData[#self.lData][3] .. "," .. val
end

function BGen:get_label()
	self.label_cnt = self.label_cnt + 1
	return "lbl" .. self.label_cnt
end

function BGen:get_string_lbl()
	self.string_cnt = self.string_cnt + 1
	return "s" .. self.string_cnt
end

function BGen:add_string(ident, str)
	table.insert(self.lText, {"ctext", self.lineno, ident .. ": " .. str})
end

function BGen:switch_to_var_def()
	self.gen_base_pos = #self.lCode + 1
end

function BGen:switch_to_func_def()
	for i = self.gen_base_pos, #self.lCode do
		local item = table.remove(self.lCode, self.gen_base_pos)
		table.insert(self.lInit, item)
	end
end

function BGen:gen_output()
	local out = {}

	-- "new file" line first
	table.insert(out, table.remove(self.lCode, 1))

	if #self.lGlobal > 0 then
		for _,name in ipairs(self.lGlobal) do
			table.insert(out, {"code", 0, "global " .. name})
		end
	end

	if #self.lInit > 0 then
		for _,item in ipairs(self.lInit) do
			table.insert(out, item)
		end
	end

	table.insert(out, {"code", 0, "call main"})
	table.insert(out, {"code", 0, "halt"})

	if #self.lCode > 0 then
		for _,item in ipairs(self.lCode) do
			table.insert(out, item)
		end
	end
	if #self.lData > 0 then
		for _,item in ipairs(self.lData) do
			table.insert(out, item)
		end
	end
	if #self.lText > 0 then
		for _,item in ipairs(self.lText) do
			table.insert(out, item)
		end
	end
	return {locals = self.all_locals, lCode = out}
end

function BGen:gen_dbg_dump(output)
	local out = {}

	out[#out + 1] = "#### Code ####"
	for idx,tok in ipairs(output.lCode) do
		local ctype, lineno, code = tok[1], tok[2], tok[3]
		out[#out + 1] = string.format('%5s: (%d) "%s"', ctype, lineno, code)
	end

	out[#out + 1] = "#### Locals ####"
	for func, item in pairs(output.locals) do
		out[#out + 1] = string.format('function %s (%d):', func, item["@nsv@"]) -- number of variables
		for id, offs in pairs(item) do
			if id ~= "@nsv@" then
				if offs > 0 then
					out[#out + 1] = string.format('  parameter %-12s: %d', id, offs)
				else
					out[#out + 1] = string.format('  variable  %-12s: %d', id, offs)
				end
			end
		end
	end

	return table.concat(out, "\n")
end

vm16.BGen = BGen
