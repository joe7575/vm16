--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Constant Expression parser

]]--

local T_NUMBER  = vm16.T_NUMBER

local BConstEx = vm16.BExpr

function BConstEx:bconstex_init()
	self:bexpr_init()
end

--[[
const_expression:
    = const_term
    | const_term '+' const_expression
    | const_term '-' const_expression
]]--
function BConstEx:const_expression()
	local opnd1 = self:const_term()
	local val = self:tk_peek().val
	if val == "+" then
		self:tk_match()
		local opnd2 = self:const_expression()
		return opnd1 + opnd2
	elseif val == "-" then
		self:tk_match()
		local opnd2 = self:const_expression()
		return opnd1 - opnd2
	end
	return opnd1
end

--[[
const_term:
    = const_factor
    | const_factor '*' const_term
    | const_factor '/' const_term
]]--
function BConstEx:const_term()
	local opnd1 = self:const_factor()
	local val = self:tk_peek().val
	if val == "*" then
		self:tk_match()
		local opnd2 = self:const_term()
		return math.floor(opnd1 * opnd2)
	elseif val == "/" then
		self:tk_match()
		local opnd2 = self:const_term()
		return math.floor(opnd1 / opnd2)
	end
	return opnd1
end

--[[
const_factor:
    = '(' const_expression ')'
    | number
    | CONST
]]--
function BConstEx:const_factor()
	local tok = self:tk_peek()
	if tok.type == T_NUMBER then
		self:tk_match()
		return tok.val
	elseif self:sym_is_const(tok.val) then
		self:tk_match()
		return tonumber(string.sub(self:sym_get_const(tok.val), 2))
	elseif self:sym_is_func(tok.val) then
		self:tk_match()
		return tok.val
	elseif tok.val == "(" then
		self:tk_match("(")
		local res = self:const_expression()
		self:tk_match(")")
		return res
	else
		self:error_msg(string.format("Syntax error at '%s'", tok.val or ""))
		return tok.val or ""
	end
end

vm16.BConstEx = BConstEx
