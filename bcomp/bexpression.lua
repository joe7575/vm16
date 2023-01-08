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
end

--[[
expression:
    = shift_expr
    | shift_expr '&' expression
    | shift_expr '|' expression
    | shift_expr '^' expression
]]--
function BExpr:expression()
--	local opnd1
--	local val = self:tk_peek().val
--	if val == "(" then
--		self:tk_match("(")
--		opnd1 = self:expression()
--		self:tk_match(")")
--		return opnd1
--	else
--		opnd1 = self:shift_expr()
--	end
--	val = self:tk_peek().val
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
    | 'sizeof' '(' variable ')'
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
		self.stack_offs = nil
		local opnd = self:postfix()
		if opnd == "[X]" then
			return "X"
		elseif opnd == "[Y]" then
			return "Y"
		elseif self.stack_offs then
			local reg = self:next_free_reg()
			self:add_instr("move", reg, "SP")
			self:add_instr("add", reg, "#" .. self.stack_offs)
			return reg
		end
		return "#" .. opnd
	elseif val == "sizeof" then
		self:tk_match("sizeof")
		self:tk_match("(")
		local ident = (self:tk_match(T_IDENT) or {}).val
		if not self:sym_get_var(ident) then
			self:error_msg(string.format("Unknown variable '%s'", ident or ""))
		end
		local size = self:sym_get_var_size(ident)
		self:tk_match(")")
		return "#" .. size
	end
	return self:postfix()
end

--[[
postfix:
    = factor
    | variable '[' expression ']'
    | variable '[' expression ']' func_call
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
		if self:tk_peek().val == "(" then
			return self:func_call(reg, true)
		else
			return "[" .. reg .. "]"
		end
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
	elseif self:sym_is_const(tok.val) then
		self:tk_match()
		return self:sym_get_const(tok.val)
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
			return self:func_call(ident)
		end
	elseif tok.type == T_IDENT then
		return self:variable()
	elseif tok.type == T_STRING then
		local lbl = self:get_string_lbl()
		self:add_string(lbl, tok.val)
		self:set_global(lbl)
		self:tk_match(T_STRING)
		return "#" .. lbl
	else
		self:error_msg(string.format("Syntax error at '%s'", tok.val or ""))
		return tok.val or ""
	end
end

--[[
buildin_call:
    = system '(' expression ',' expression  { ',' expression { ',' expression } } ')'
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
		if self:tk_peek().val == "," then
			self:tk_match(",")
			local opnd4 = self:expression()
			if opnd4 ~= "C" then
				self:add_instr("move", "C", opnd4)
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
function BExpr:func_call(ident, inReg)
	self:push_regs()
	-- A function call as parameter is a recursive call to 'func_call'
	local base_val = self.num_param
	-- If address is already calculated and stored in reg
	local addr = inReg and ident or self:address()
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
	self:add_debugger_info("call", self.lineno, ident, ident)
	if inReg then
		self:add_instr("call", "[" .. addr .. "]")
	else
		self:add_instr("call", addr)
	end
	if self.num_param > base_val then
		self:add_instr("add", "SP", "#" .. (self.num_param - base_val))
	end
	if self:sym_is_func(ident) then
		self:sym_check_num_param(ident, self.num_param - base_val)
	end
	self.num_param = base_val
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
	if not self:sym_get_var(ident) then
		self:error_msg(string.format("Unknown variable '%s'", ident or ""))
	end
	if self:sym_is_func(ident) then
		return ident
	elseif self:sym_get_local(ident) then
		local opnd = self:sym_get_local(ident)
		self:add_instr("move", "A", opnd)
		return "A"
	elseif self:sym_is_global(ident) then
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
	local ident = (self:tk_match(T_IDENT) or {}).val
	local ref = self:sym_get_var(ident)
	if not ref and not self.is_func_param then
		self:error_msg(string.format("Unknown variable '%s'", ident or ""))
	end
	if self:sym_is_func(ident) then
		return "#" .. ref
	end
	return ref or ident or ""
end

function BExpr:number()
	local tok = self:tk_match()
	if self:sym_is_const(tok.val) then
		local val = self:sym_get_const(tok.val)
		if type(val) == "string" then
			return tonumber(val:sub(2)) or 0
		else
			return val
		end
	end
	return tok.val
end

function BExpr:ident()
	local ident = (self:tk_match(T_IDENT) or {}).val
	return self:sym_get_filelocal(ident) or ident
end

vm16.BExpr = BExpr
