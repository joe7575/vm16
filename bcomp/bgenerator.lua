--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Asm code generation

]]--

local REGS     = {A=1, B=1, C=1, D=1, X=1, Y=1, SP=1, PC=1, ["#0"]=1, ["#1"]=1}
local REGLIST  = {"A", "B", "C", "D"}
-- Need NO special handling of operand1
local ASSIGNMENT_INSTR = {move=1, out=1} 
-- Last operand register can be reused
local CLOSING_INSTR = {move=1, push=1, add=1, addc=1, mul=1, mulc=1, div=1, sub=1, 
                       mod=1, ["and"]=1, ["or"]=1, xor=1, ["not"]=1, ["in"]=1, out=1,
                       push=1, shl=1, shr=1}

local BGen = {}

function BGen:new(o)
	o = o or {}
	o.label_cnt = 0
	o.reg_cnt = 0
	o.reg_cnt_stack = {}
	o.lCode = {"  .code"}
	o.lData = {"  .data"}
	setmetatable(o, self)
	self.__index = self
	return o
end

function BGen:add_move_instr(instr, opnd1, opnd2)
	self.reg_cnt = self.reg_cnt + 1
	if self.reg_cnt < 5 then
		local new_opnd = REGLIST[self.reg_cnt]
		self.lCode[#self.lCode + 1] = "  move " .. new_opnd .. ", " .. opnd1
		return new_opnd
	else
		print(dump(self.lCode))
		error("Expression too complex", 2)
	end
end

function BGen:next_free_reg(instr, opnd1, opnd2)
	if not ASSIGNMENT_INSTR[instr] and not REGS[opnd1] then
		return self:add_move_instr(instr, opnd1, opnd2)
	else
		return opnd1
	end
end

function BGen:free_last_operand_reg(instr, opnd)
	if CLOSING_INSTR[instr] then
		if REGS[opnd] then
			if self.reg_cnt > 0 then
				self.reg_cnt = self.reg_cnt - 1
			end
		end
	end
end

function BGen:reset_reg_use()
	self.reg_cnt = 0
end

function BGen:add_instr(instr, opnd1, opnd2)
	if opnd2 then
		opnd1 = self:next_free_reg(instr, opnd1, opnd2)
		self.lCode[#self.lCode + 1] = "  " .. instr .. " " .. opnd1 .. ", " .. opnd2
		self.free_last_operand_reg(instr, opnd2)
	elseif opnd1 then
		--opnd1 = self:next_free_reg(instr, opnd1)
		self.lCode[#self.lCode + 1] = "  " .. instr .. " " .. opnd1
		self:free_last_operand_reg(instr, opnd1)
	else
		self.lCode[#self.lCode + 1] = "  " .. instr
	end
	self.last_instr = instr
	return opnd1
end

function BGen:insert_instr(instr, opnd1, opnd2, pos)
	pos = #self.lCode + pos + 1
	if opnd2 then
		table.insert(self.lCode, pos, "  " .. instr .. " " .. opnd1 .. ", " .. opnd2)
	elseif opnd1 then
		table.insert(self.lCode, pos, "  " .. instr .. " " .. opnd1)
	else
		table.insert(self.lCode, pos, "  " .. instr)
	end
	self.last_instr = instr
	return opnd1
end

--Store used registers before function call
function BGen:push_regs()
	table.insert(self.reg_cnt_stack, self.reg_cnt)
	for i = 1, self.reg_cnt do
		table.insert(self.lCode, "  push " .. REGLIST[i] .. "  ; push_regs")
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
		reg = self:add_move_instr("move", "A", "A")
	else
		self.reg_cnt = 1
		reg = "A"
	end
	for i = old_reg_cnt, 1, -1 do
		table.insert(self.lCode, "  pop  " .. REGLIST[i] .. "  ; pop_regs")
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
	self.lCode[#self.lCode + 1] = lbl .. ":"
end

function BGen:add_line(line)
	self.lCode[#self.lCode + 1] = line
end

function BGen:add_data(ident)
	self.lData[#self.lData + 1] = ident .. ": 0"
end

function BGen:get_label()
	self.label_cnt = self.label_cnt + 1
	return "lbl" .. self.label_cnt
end

vm16.BGen = BGen