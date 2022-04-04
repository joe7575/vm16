--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Main Parser

]]--

local T_IDENT   = vm16.T_IDENT
local T_NUMBER  = vm16.T_NUMBER
local T_OPERAND = vm16.T_OPERAND
local T_ASMCODE = vm16.T_ASMCODE
local T_NEWFILE = vm16.T_NEWFILE

local BPars = vm16.BExpr:new({})

function BPars:bpars_init()
	self:bexpr_init()
end

--[[
program:
    = definition { definition }
]]--
function BPars:main()
	local tok = self:tk_peek()
	while tok.val do
		self:definition()
		tok = self:tk_peek()
	end
end

--[[
definition:
    = 'var' var_def
    | 'const' const_def
    | 'func' func_def
    | T_NEWFILE
    | T_ASMCODE
]]--
function BPars:definition()
	local tok = self:tk_peek()
	if tok.val == "var" then
		self:tk_match("var")
		self:var_def()
	elseif tok.val == "const" then
		self:tk_match("const")
		self:const_def()
	elseif tok.val == "func" then
		self:tk_match("func")
		self:func_def()
	elseif tok.type == T_NEWFILE then
		self:add_item("file", tok.lineno, tok.val)
		self:tk_match(T_NEWFILE)
		self:end_asm_code()
	elseif tok.type == T_ASMCODE then
		self:add_asm_token(tok)
		if string.sub(tok.val, 1, 6) == "global" then
			local funcname = string.trim(string.sub(tok.val, 8))
			self:add_func(funcname)
		end
		self:tk_match(T_ASMCODE)
	elseif tok.val ~= nil then
		self:error_msg(string.format("Unexpected item '%s'", tok.val))
	end
end

--[[
var_def:
    = ident [ '=' expression ] ';
    | array_def ';'
]]--
function BPars:var_def()
	self:switch_to_var_def()
	local ident = self:ident()
	self:set_global(ident)
	if self:tk_peek().val == "[" then
		self:add_global(ident, true, true)
		self:array_def(ident)
		self:tk_match(";")
		self:reset_reg_use()
	else
		self:add_global(ident, true)
		self:add_data(ident)
		if self:tk_peek().val == "=" then
			self:tk_match("=")
			local right = self:expression()
			self:add_instr("move", ident, right)
			self:reset_reg_use()
		end
		self:tk_match(";")
	end
	self:switch_to_func_def()
end

--[[
const_def:
    = ident '=' expression ';' def_list
]]--
function BPars:const_def()
	self:switch_to_var_def()
	local ident = self:ident()
	self:tk_match("=")
	local right = self:expression()
	self:add_const(ident, right)
	self:tk_match(";")
	self:reset_reg_use()
	self:switch_to_func_def()
end

--[[
array_def:
    = '[' ']' '=' '{' const_list '}'
    = '[' number ']' '=' '{' const_list '}'
    = '[' number ']'
]]--
function BPars:array_def(ident)
	self:tk_match("[")
	local size = 0
	if self:tk_peek().val ~= ']' then
		local tok = self:tk_match(T_NUMBER)
		size = tok.val
	end
	self:tk_match("]")
	if self:tk_peek().val ~= '=' and size > 0 then
		self:add_data(ident)
		while size > 1 do
			self:append_val(0)
			size = size - 1
		end
		return
	end
	self:tk_match("=")
	self:tk_match("{")
	self:const_list(ident, size)
	self:tk_match("}")
end

--[[
const_list:
    number { ',' const_list }
]]--
function BPars:const_list(ident, size)
	local tok = self:tk_match(T_NUMBER)
	self:add_data(ident, tok.val)
	size = size - 1
	while self:tk_peek().val == ',' do
		self:tk_match(",")
		tok = self:tk_match(T_NUMBER)
		self:append_val(tok.val)
		size = size - 1
	end

	while size > 0 do
		self:append_val(0)
		size = size - 1
	end
end

--[[
func_def:
    = ident '(' param_list ')' '{' lvar_def_list stmnt_list '}'
]]--
function BPars:func_def()
	local ident = self:ident()
	self:set_global(ident)
	self:add_func(ident)
	self.func_name = ident
	self:add_label(ident)
	self:tk_match("(")
	self:local_new()
	local cnt = self:param_list()
	self:add_global(ident, cnt)
	self:tk_match(")")
	-- Consider the return address in between param and local variables
	-- "func" is used here, because "func" is no valid variable name
	self:local_add("func")
	self:tk_match("{")
	self:lvar_def_list();
	self:stmnt_list()
	self:func_return(ident)
	self:tk_match("}")
end

--[[
lvar_def_list:
    = 'var' ident [ '=' expression ] ';'  local_def_list
]]--
function BPars:lvar_def_list()
	local val = self:tk_peek().val
	while val and val == "var" do
		self:tk_match("var")
		local ident = self:ident()
		if self:tk_peek().val == "=" then
			self:tk_match("=")
			local right = self:expression()
			self:add_instr("push", right)
		else
			self:add_instr("push", "#0")
		end
		self:local_add(ident)
		self.num_auto = self.num_auto + 1
		self:reset_reg_use()
		self:tk_match(";")
		val = self:tk_peek().val
	end
end

--[[
stmnt_list:
    = { statement }
]]--
function BPars:stmnt_list()
	local val = self:tk_peek().val
	while val and val ~= "}" do
		self:statement()
		val = self:tk_peek().val
	end
end

--[[
param_list:
    =
    | expression
    | expression ',' param_list
]]--
function BPars:param_list()
	local cnt = 0
	if self:tk_peek().type == T_IDENT then
		self.new_local_variables = true
		while true do
			local val = self:expression()
			self:param_add(val)
			cnt = cnt + 1
			if self:tk_peek().val == "," then
				self:tk_match(",")
			else
				break
			end
		end
		self.new_local_variables = nil
	end
	return cnt
end


--[[
statement:
    = if_statement
    | for_statement
    | while_statement
    | 'return' expression ";"
    | 'return' ";"
    | asm_declaration
    | assignment ";"
    | expression ";"
]]--
function BPars:statement()
	local val = self:tk_peek().val
	if self:tk_peek().type == T_ASMCODE then
		self:asm_declaration()
	elseif val == "if" then
		self:if_statement()
	elseif val == "for" then
		self:for_statement()
	elseif val == "while" then
		self:while_statement()
	elseif val == "return" then
		self:tk_match("return")
		if self:tk_peek().val ~= ";" then
			local right = self:expression()
			self:add_instr("move", "A", right)
			self:reset_reg_use()
		else
			self:add_instr("move", "A", "#0")
		end
		self:func_return(self.func_name or "")
		self:tk_match(";")
		self:reset_reg_use()
	elseif self:assignment() then
		self:tk_match(";")
	else
		self:expression()
		self:tk_match(";")
		self:reset_reg_use()
	end
end

--[[
if_statement:
    = 'if' '(' condition ')' '{' stmnt_list '}' [ 'else' '{' stmnt_list '}' ]
]]--
function BPars:if_statement()
	self:tk_match("if")
	self:tk_match("(")
	self:condition()
	self:reset_reg_use()
	self:tk_match(")")
	local lbl1 = self:get_label()
	self:add_instr("jump", lbl1)
	self:tk_match("{")
	self:add_then_label()
	self:stmnt_list()
	self:tk_match("}")
	if self:tk_peek().val == 'else' then
		self:tk_match("else")
		local lbl2 = self:get_label()
		self:add_instr("jump", lbl2)
		self:add_label(lbl1)
		self:tk_match("{")
		self:stmnt_list()
		self:add_label(lbl2)
		self:tk_match("}")
	else
		self:add_label(lbl1)
	end
end

--[[
for_statement:
    = 'for' '(' assignment ";" condition ";" assignment ')' '{' stmnt_list '}'
]]--
function BPars:for_statement()
	self:tk_match("for")
	self:tk_match("(")
	self:assignment()
	self:tk_match(";")
	local loop = self:get_label()
	local lend = self:get_label()
	self:add_label(loop)
	self:condition()
	self:reset_reg_use()
	self:tk_match(";")
	self:add_instr("jump", lend)
	local pos1 = self:get_instr_pos()
	self:assignment()
	local pos2 = self:get_instr_pos()
	self:reset_reg_use()
	self:tk_match(")")
	self:tk_match("{")
	self:add_then_label()
	self:stmnt_list()
	local pos3 = self:get_instr_pos()
	self:add_instr("jump", loop)
	self:add_label(lend)
	self:instr_move(pos1, pos2, pos3)
	self:tk_match("}")
end

--[[
while_statement:
    = 'while' '(' condition ')' '{' stmnt_list '}'
]]--
function BPars:while_statement()
	self:tk_match("while")
	self:tk_match("(")
	local loop = self:get_label()
	local lend = self:get_label()
	self:add_label(loop)
	self:condition()
	self:reset_reg_use()
	self:tk_match(")")
	self:add_instr("jump", lend)
	self:tk_match("{")
	self:add_then_label()
	self:stmnt_list()
	self:add_instr("jump", loop)
	self:add_label(lend)
	self:tk_match("}")
end

--[[
asm_declaration:
    | _asm_ "{" { instruction } "}"
]]--
function BPars:asm_declaration()
	local tok = self:tk_peek()
	while tok.type == T_ASMCODE do
		self:tk_match()
		self:add_asm_token(tok)
		tok = self:tk_peek()
	end
	self:end_asm_code()
end

--[[
assignment:
    = left_value '=' expression
    | left_value '++'
    | left_value '--'
	|
]]--
function BPars:assignment()
	if self:tk_peek().val == ";" then
		return true
	end
	local left = self:left_value()
	if left then
		local val = self:tk_peek().val
		if val == "=" then
			self:tk_match("=")
			local right = self:expression()
			self:add_instr("move", left, right)
			self:reset_reg_use()
			return true
		elseif val == "++" then
			self:tk_match("++")
			self:add_instr("inc", left)
			self:reset_reg_use()
			return true
		elseif val == "--" then
			self:tk_match("--")
			self:add_instr("dec", left)
			self:reset_reg_use()
			return true
		end
	end
end

--[[
condition:
    = 'true'
    | 'false'
    | expression '<' expression
    | expression '>' expression
    | expression '==' expression
    | expression '!=' expression
    | expression
]]--
function BPars:condition()
	local val = self:tk_peek().val
	if val == "true" then
		self:add_instr("move", "A", "#1")
		return
	elseif val == "false" then
		self:add_instr("move", "A", "#0")
		return
	end
	local left = self:expression()
	val = self:tk_peek().val
	if val == "<" then
		self:tk_match("<")
		local right = self:expression()
		self:add_instr("sklt", left, right)
	elseif val == ">" then
		self:tk_match(">")
		local right = self:expression()
		self:add_instr("skgt", left, right)
	elseif val == "==" then
		self:tk_match("==")
		local right = self:expression()
		self:add_instr("skeq", left, right)
	elseif val == "!=" then
		self:tk_match("!=")
		local right = self:expression()
		self:add_instr("skne", left, right)
	else
		self:add_instr("skgt", left, "#00")
	end
end

--[[
left_value:
    = ident
    | '*' ident
    | postfix
]]--
function BPars:left_value()
	if self:tk_peek().val == '*' then
		self:tk_match("*")
		local ident = self:tk_match(T_IDENT).val
		local lval = self:local_get(ident) or (self.globals[ident] and ident)
		if not lval then
			self:error_msg(string.format("Unknown identifier '%s'", ident))
		end
		local reg = self:next_free_indexreg()
		self:add_instr("move", reg, lval)
		return "[" .. reg .. "]"
	elseif self:tk_next().val == '[' then
		return self:postfix()
	else
		local val = self:tk_next().val
		if val == "=" or val == "++" or val == "--" then
			local ident = self:tk_match(T_IDENT).val
			local lval = self:local_get(ident) or (self.globals[ident] and ident)
			if not lval then
				self:error_msg(string.format("Unknown identifier '%s'", ident))
			end
			return lval
		end
	end
end

vm16.BPars = BPars
