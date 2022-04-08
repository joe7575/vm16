--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Expression parser

]]--

local T_IDENT   = vm16.T_IDENT
local T_NUMBER  = vm16.T_NUMBER
local T_OPERAND = vm16.T_OPERAND
local T_STRING  = vm16.T_STRING

local BUILDIN  = {system=1, input=1, output=1, sleep=1}

local BExpr = vm16.BSym

function BExpr:bexpr_init()
	self:bsym_init()
	self.num_param_stack = {}
end

--[[
expression:
    = shift_expr
    | shift_expr '&' expression
    | shift_expr '|' expression
    | shift_expr '^' expression
]]--
function BExpr:expression()
	local opnd1 = self:shift_expr()
	local val = self:tk_peek().val
	if val == "&" then
		self:tk_match()
		local opnd2 = self:expression()
		return self:add_instr("and", opnd1, opnd2)
	elseif val == "|" then
		self:tk_match()
		local opnd2 = self:expression()
		return self:add_instr("or", opnd1, opnd2)
	elseif val == "^" then
		self:tk_match()
		local opnd2 = self:expression()
		return self:add_instr("xor", opnd1, opnd2)
	end
	return opnd1
end

--[[
shift_expr:
    = add_expr
    | add_expr '>>' shift_expr
    | add_expr '<<' shift_expr
]]--
function BExpr:shift_expr()
	local opnd1 = self:add_expr()
	local val = self:tk_peek().val
	if val == ">>" then
		self:tk_match()
		local opnd2 = self:shift_expr()
		return self:add_instr("shr", opnd1, opnd2)
	elseif val == "<<" then
		self:tk_match()
		local opnd2 = self:shift_expr()
		return self:add_instr("shl", opnd1, opnd2)
	end
	return opnd1
end

--[[
add_expr:
    = term
    | term '+' add_expr
    | term '-' add_expr
]]--
function BExpr:add_expr()
	local opnd1 = self:term()
	local val = self:tk_peek().val
	if val == "+" then
		self:tk_match()
		local opnd2 = self:add_expr()
		return self:add_instr("add", opnd1, opnd2)
	elseif val == "-" then
		self:tk_match()
		local opnd2 = self:add_expr()
		return self:add_instr("sub", opnd1, opnd2)
	end
	return opnd1
end

--[[
term:
    = unary
    | unary '*' term
    | unary '/' term
    | unary '%' term
    | unary 'mod' term
]]--
function BExpr:term()
	local opnd1 = self:unary()
	local val = self:tk_peek().val
	if val == "*" then
		self:tk_match()
		local opnd2 = self:term()
		return self:add_instr("mul", opnd1, opnd2)
	elseif val == "/" then
		self:tk_match()
		local opnd2 = self:term()
		return self:add_instr("div", opnd1, opnd2)
	elseif val == "%" or val == "mod" then
		self:tk_match()
		local opnd2 = self:term()
		return self:add_instr("mod", opnd1, opnd2)
	end
	return opnd1
end

--[[
unary:
    = postfix
    | '-' postfix
    | '~' postfix
    | '*' postfix
    | '&' postfix
]]--
function BExpr:unary()
	local val = self:tk_peek().val
	if val == "-" then
		self:tk_match()
		local opnd = self:postfix()
		opnd = self:add_instr("not", opnd)
		return self:add_instr("add", opnd, "#1")
	elseif val == "~" then
		self:tk_match()
		local opnd = self:postfix()
		return self:add_instr("not", opnd)
	elseif val == "*" then
		self:tk_match("*")
		local opnd = self:postfix()
		local reg = self:next_free_indexreg()
		self:add_instr("move", reg, opnd)
		return "[" .. reg .. "]"
	elseif val == "&" then
		self:tk_match("&")
		return "#" .. self:postfix() -- TODO
	end
	return self:postfix()
end

--[[
postfix:
    = factor
    | variable '[' expression ']'
]]--
function BExpr:postfix()
	if self:tk_next().val == "[" then
		local opnd1 = self:variable()
		self:tk_match("[")
		local opnd2 = self:expression()
		self:tk_match("]")
		opnd1 = self:add_instr("add", opnd1, opnd2)
		local reg = self:next_free_indexreg()
		self:add_instr("move", reg, opnd1)
		return "[" .. reg .. "]"
	end
	return self:factor()
end

--[[
factor:
    = '(' expression ')'
    | variable
    | number
    | CONST
    | STRING
    | func_call
    | buildin_call
]]--
function BExpr:factor()
	local tok = self:tk_peek()
	if tok.type == T_NUMBER then
		self:tk_match()
		return "#" .. tok.val
	elseif self:is_const(tok.val) then
		self:tk_match()
		return self:get_const(tok.val)
	elseif tok.val == "(" then
		self:tk_match("(")
		local res = self:expression()
		self:tk_match(")")
		return res
	elseif self:tk_next().val == "(" then
		local ident = tok.val
		if BUILDIN[ident] then
			return self:buildin_call()
		else
			return self:func_call()
		end
	elseif tok.type == T_IDENT then
		return self:variable()
	elseif tok.type == T_STRING then
		local lbl = self:get_string_lbl()
		self:add_string(lbl, tok.val)
		self:tk_match(T_STRING)
		return "#" .. lbl
	else
		self:error_msg(string.format("Syntax error at '%s'", tok.val or ""))
		return tok.val or ""
	end
end

--[[
buildin_call:
    = system '(' expression ',' expression  ',' expression ')'
    | sleep '(' expression ')'
    | input '(' expression ')'
    | output '(' expression ',' expression { ',' expression } ')'
]]--
function BExpr:buildin_call()
	self:push_regs()
	local ident = self:ident()
	self:tk_match("(")
	if ident == "system" then
		local opnd1 = self:expression()
		self:tk_match(",")
		local opnd2 = self:expression()
		if opnd2 ~= "A" then
			self:add_instr("move", "A", opnd2)
		end
		if self:tk_peek().val == "," then
			self:tk_match(",")
			local opnd3 = self:expression()
			if opnd3 ~= "B" then
				self:add_instr("move", "B", opnd3)
			end
		end
		self:add_instr("sys", opnd1)
	elseif ident == "sleep" then
		local opnd = self:expression()
		self:add_instr("move", "A", opnd)
		self:add_instr("nop")
		self:add_instr("dbnz", "A", "-1")
	elseif ident == "input" then
		local opnd = self:expression()
		self:add_instr("in", "A", opnd)
	elseif ident == "output" then
		local opnd1 = self:expression()
		self:tk_match(",")
		local opnd2 = self:expression()
		if self:tk_peek().val == "," then
			self:tk_match(",")
			local opnd3 = self:expression()
			self:add_instr("move", "B", opnd3)
		end
		self:add_instr("out", opnd1, opnd2)
	end
	local opnd = self:pop_regs()
	self:tk_match(")")
	return opnd
end

--[[
func_call:
    | address '(' ')'
    | address '(' expression { ',' expression } ')'
]]--
function BExpr:func_call()
	self:push_regs()
	-- A function call as parameter is a recursive call to 'func_call'
	table.insert(self.num_param_stack, self.num_param)
	self.num_param = 0
	local addr = self:address()
	self:tk_match("(")
	if self:tk_peek().val ~= ")" then
		while true do
			local val = self:expression()
			self.num_param = self.num_param + 1
			self:add_instr("push", val)
			if self:tk_peek().val == "," then
				self:tk_match(",")
			else
				break
			end
		end
	end
	self:tk_match(")")
	self:add_item("call", self.lineno, addr)
	self:add_instr("call", addr)
	if self.num_param > 0 then
		self:add_instr("add", "SP", "#" .. self.num_param)
	end
	if self:is_func(ident) then
		self:add_global(ident, self.num_param)
	end
	self.num_param = table.remove(self.num_param_stack)
	local opnd = self:pop_regs()
	return opnd
end

--[[
address:
    | <func>
    | <local variabe>
    | <global variable>
]]--
function BExpr:address()
	local ident = self:ident()
	if not self.is_func_param and not self:local_get(ident)
	and not self:is_global_var(ident) and not self:is_func(ident) then
		self:error_msg(string.format("Unknown variable '%s'", ident or ""))
	end
	if self:is_func(ident) then
		return ident
	elseif self:local_get(ident) then
		local opnd = self:local_get(ident)
		self:add_instr("move", "A", opnd)
		return "A"
	elseif self:is_global_var(ident) then
		self:add_instr("move", "A", ident)
		return "A"
	else
		self:error_msg(string.format("Syntax error at '%s'", ident or ""))
	end
end

--[[
variable: (check if valid)
    | ident
]]--
function BExpr:variable()
	local ident = self:ident()
	if not self.is_func_param and not self:local_get(ident)
	and not self:is_global_var(ident) and not self:is_func(ident) then
		self:error_msg(string.format("Unknown variable '%s'", ident or ""))
	end
	if self:is_array(ident) or self:is_func(ident) then
		return "#" .. ident
	end
	return self:local_get(ident) or ident or ""
end

function BExpr:ident()
	return (self:tk_match(T_IDENT) or {}).val
end

vm16.BExpr = BExpr
