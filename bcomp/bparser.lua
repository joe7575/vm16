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
local T_STRING  = vm16.T_STRING
local T_ENDFILE = vm16.T_ENDFILE

local BPars = vm16.BConstEx:new({})

function BPars:bpars_init()
	self:bconstex_init()
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
    | 'static' 'var' var_def
    | 'const' const_def
    | 'static' 'const' const_def
    | 'func' func_def
    | 'static' 'func' func_def
    | T_NEWFILE
    | T_ASMCODE
]]--
function BPars:definition()
	local tok = self:tk_peek()
	if tok.val == "var" then
		self:tk_match("var")
		self:var_def()
	elseif tok.val == "static" then
		self:tk_match("static")
		local tok = self:tk_peek()
		if tok.val == "var" then
			self:tk_match("var")
			self:var_def(true)
		elseif tok.val == "func" then
			self:tk_match("func")
			self:func_def(true)
		elseif tok.val == "const" then
			self:tk_match("const")
			self:const_def(true)
		else
			self:error_msg(string.format("Unexpected item '%s'", tok.val))
		end
	elseif tok.val == "const" then
		self:tk_match("const")
		self:const_def()
	elseif tok.val == "func" then
		self:tk_match("func")
		self:func_def()
	elseif tok.type == T_NEWFILE then
		if self:tk_next().type ~= T_NEWFILE or tok.lineno == 0 then
			self:add_item("file", tok.lineno, tok.val)
			self:add_debugger_info("file", tok.lineno, tok.val)
		end
		self.filename = tok.val
		self:tk_match(T_NEWFILE)
		self:end_asm_code()
		self:next_file_for_local_vars()
	elseif tok.type == T_ENDFILE then
		self:add_debugger_info("endf", tok.lineno, tok.val)
		self:tk_match(T_ENDFILE)
	elseif tok.type == T_ASMCODE then
		self:add_asm_token(tok)
		if string.sub(tok.val, 1, 6) == "global" then
			local funcname = string.trim(string.sub(tok.val, 8))
			self:sym_add_func(funcname, nil, "global")
			self:add_debugger_info("func", tok.lineno, funcname)
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
function BPars:var_def(static)
	local ident = self:ident()
	local val = self:tk_peek().val
	local is_array = val == "["
	local old_ident

	if static then
		old_ident = ident
		local postfix = is_array and "[]" or ""
		ident = self:sym_get_filelocal_ref(ident)
		self:add_debugger_info("lvar", self.lineno, ident, old_ident .. postfix)
	else
		local postfix = is_array and "[]" or ""
		self:add_debugger_info("gvar", self.lineno, ident, ident .. postfix)
	end
	self:switch_to_var_def()
	self:set_global(ident)
	if is_array then
		local size = self:array_def(ident)
		if static then
			-- post-define array size
			self:sym_add_filelocal(old_ident, true, size)  -- name without postfix
			self:sym_add_filelocal(ident, true, size)
		else
			self:sym_add_global(ident, true, size)
		end
		self:tk_match(";")
		self:reset_reg_use()
	else
		if static then
			-- post-define array size
			self:sym_add_filelocal(old_ident, false, 1)  -- name without postfix
			self:sym_add_filelocal(ident, false, 1)
		else
			self:sym_add_global(ident)
		end
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
    = ident '=' const_expression ';' def_list
]]--
function BPars:const_def(static)
	self:switch_to_var_def()
	local ident = self:ident()
	self:tk_match("=")
	local right = '#' .. self:const_expression()
	self:sym_add_const(ident, right, static and "local" or "global")
	self:tk_match(";")
	self:reset_reg_use()
	self:switch_to_func_def()
end

--[[
array_def:
    = '[' ']' '=' '{' const_list '}'
   = '[' ']' '=' STRING
    = '[' const_expression ']' '=' '{' const_list '}'
    = '[' const_expression ']'
]]--
function BPars:array_def(ident)
	self:tk_match("[")
	local size = 0
	if self:tk_peek().val ~= ']' then
		size = self:const_expression()
	end
	self:tk_match("]")
	if size > 2048 then
		self:error_msg(string.format("Array '%s' is too large", ident))
		size = 1
	end
	if self:tk_peek().val ~= '=' and size > 0 then
		self:add_data(ident)
		local num = size
		while num > 1 do
			self:append_val(0)
			num = num - 1
		end
		return size
	end
	self:tk_match("=")
	if self:tk_peek().type == T_STRING then
		if size ~= 0 then
			self:error_msg(string.format("Invalid string declaration near '%s'", ident))
		end
		local tok = self:tk_match(T_STRING)
		self:add_string(ident, tok.val)
	else
		self:tk_match("{")
		size = self:const_list(ident, size)
		self:tk_match("}")
	end
	return size
end

--[[
const_list:
    const_expression { ',' const_list }
]]--
function BPars:const_list(ident, size)
	local num = self:const_expression()
	self:add_data(ident, num)
	size = size - 1
	local realsize = 1
	while self:tk_peek().val == ',' do
		self:tk_match(",")

		if self:tk_peek().val == '-' then
			self:tk_match()
			local num = self:const_expression()
			self:append_val(0x10000 - num)
		else
			local num = self:const_expression()
			self:append_val(num)
		end
		size = size - 1
		realsize = realsize + 1
	end

	while size > 0 do
		self:append_val(0)
		size = size - 1
		realsize = realsize + 1
	end
	return realsize

end

--[[
func_def:
    = ident '(' param_list ')' '{' lvar_def_list stmnt_list '}'
]]--
function BPars:func_def(static)
	local ident = self:ident()
	if not static then
		self:set_global(ident)
	end
	self:add_debugger_info("func", self.lineno, ident)
	self.func_name = ident
	self:add_label(ident)
	self:tk_match("(")
	self:local_new()
	local cnt = self:param_list()
	self:sym_add_func(ident, cnt, static and "static" or "global")
	self:tk_match(")")
	-- Consider the return address in between param and local variables
	-- "func" is used here, because "func" is no valid variable name
	self:sym_add_local("func")
	self:tk_match("{")
	self:lvar_def_list();
	self:stmnt_list()
	self:sym_func_return(ident, true)
	self:tk_match("}")
end

--[[
lvar_def_list:
    = 'var' ident [ '=' expression ] ';'  local_def_list
    | 'var' ident '[' number ']' ';'
]]--
function BPars:lvar_def_list()
	local val = self:tk_peek().val
	while val and val == "var" do
		self:tk_match("var")
		local ident = self:ident()

		if self:tk_peek().val == "[" then
			self:tk_match("[")
			local size = self:number()
			self:tk_match("]")
			self:sym_add_local(ident, size)
			self:add_instr("sub", "SP", "#" .. size)
			self.num_auto = self.num_auto + size
			self:reset_reg_use()
			self:tk_match(";")
			val = self:tk_peek().val
		else
			if self:tk_peek().val == "=" then
				self:tk_match("=")
				local right = self:expression()
				self:add_instr("push", right)
			else
				self:add_instr("push", "#0")
			end
			self:sym_add_local(ident)
			self.num_auto = self.num_auto + 1
			self:reset_reg_use()
			self:tk_match(";")
			val = self:tk_peek().val
		end
	end
end

--[[
stmnt_list:
    = { statement }
]]--
function BPars:stmnt_list(lbl_loop, lbl_end)
	self:push_var("lbl_loop", lbl_loop)
	self:push_var("lbl_end", lbl_end)
	local val = self:tk_peek().val
	-- Function without code
	if val == "}" then
		-- Code is needed for 'sym_func_return'
		self:add_instr("move", "A", "A")
	end
	while val and val ~= "}" do
		self:statement()
		val = self:tk_peek().val
	end
	self:pop_var("lbl_loop")
	self:pop_var("lbl_end")
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
		self.is_func_param = true
		while true do
			local val = self:expression()
			self:sym_add_param(val)
			cnt = cnt + 1
			if self:tk_peek().val == "," then
				self:tk_match(",")
			else
				break
			end
		end
		self.is_func_param = nil
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
    | "goto" label ";"
    | "goto" ident ";"
    | "break" ";"
    | "continue" ";"
    | ident ":"
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
		local tok = self:tk_match("return")
		self:add_debugger_info("ret", tok.lineno)
		if self:tk_peek().val ~= ";" then
			local right = self:expression()
			if right ~= "A" then
				self:add_instr("move", "A", right)
			end
			self:reset_reg_use()
		else
			self:add_instr("move", "A", "#0")
		end
		self:sym_func_return(self.func_name or "")
		self:tk_match(";")
		self:reset_reg_use()
	elseif val == "goto" then
		self:tk_match("goto")
		local lbl
		if self:tk_peek().val == "*" then
			self:tk_match("*")
			lbl = self:postfix()
		else
			lbl = self:ident()
		end
		self:tk_match(";")
		self:reset_reg_use()
		self:add_instr("jump", lbl)
	elseif val == "break" then
		if self.lbl_end then
			self:tk_match("break")
			self:tk_match(";")
			self:add_instr("jump", self.lbl_end)
		else
			self:error_msg("Invalid position for a 'break'")
		end
	elseif val == "continue" then
		if self.lbl_loop then
			self:tk_match("continue")
			self:tk_match(";")
			self:add_instr("jump", self.lbl_loop)
		else
			self:error_msg("Invalid position for a 'continue'")
		end
	elseif self:label() then
		local ident = self:ident()
		self:add_label(ident)
		self:tk_match(":")
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
    | 'if' '(' condition ')' '{' stmnt_list '}' 'else' if_statement
]]--
function BPars:if_statement()
	self:tk_match("if")
	self:tk_match("(")
	local lbl_then = self:get_label()
	local lbl_else = self:get_label()
	self:condition(lbl_then, lbl_else)
	self:reset_reg_use()
	self:tk_match(")")
	self:add_instr("jump", lbl_else)
	self:add_label(lbl_then)
	self:tk_match("{")
	self:add_then_label()
	self:stmnt_list()
	self:tk_match("}")
	if self:tk_peek().val == 'else' then
		self:tk_match("else")
		local lbl2 = self:get_label()
		self:add_instr("jump", lbl2)
		self:add_label(lbl_else)
		if self:tk_peek().val == 'if' then
			self:if_statement()
			self:add_label(lbl2)
		else
			self:tk_match("{")
			self:stmnt_list()
			self:add_label(lbl2)
			self:tk_match("}")
		end
	else
		self:add_label(lbl_else)
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
	local lthen = self:get_label()
	local lend = self:get_label()
	local lbreak = self:get_label()
	self:add_label(loop)
	self:condition(lthen, lend)
	self:reset_reg_use()
	self:tk_match(";")
	self:add_instr("jump", lend)
	self:add_label(lthen)
	local pos1 = self:get_instr_pos()
	self:assignment()
	local pos2 = self:get_instr_pos()
	self:reset_reg_use()
	self:tk_match(")")
	self:tk_match("{")
	self:add_then_label()
	self:stmnt_list(lbreak, lend)
	self:add_label(lbreak)
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
	local lthen = self:get_label()
	local lend = self:get_label()
	self:add_label(loop)
	self:condition(lthen, lend)
	self:reset_reg_use()
	self:tk_match(")")
	self:add_instr("jump", lend)
	self:add_label(lthen)
	self:tk_match("{")
	self:add_then_label()
	self:stmnt_list(loop, lend)
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
]]--
function BPars:assignment()
	if self:tk_peek().val == ";" then
		return true
	end
	self:move_code1()
	local left = self:left_value()
	if left then
		local val = self:tk_peek().val
		if val == "=" then
			self:move_code2()
			self:reset_reg_use()
			self:tk_match("=")
			local right = self:expression()
			self:move_code3()
			local left = self:left_value() or left
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
    = and_condition
    | and_condition 'or' condition
    | and_condition '||' condition
]]--
function BPars:condition(lbl_then, lbl_else)
	local opnd1 = self:and_condition(lbl_then, lbl_else)
	local val = self:tk_peek().val
	if val == "or" then
		self:tk_match()
		self:add_instr("jump", "+4")
		self:add_instr("jump", lbl_then)
		self:condition(lbl_then, lbl_else)
	elseif val == "||" then
		self:tk_match()
		self:add_instr("jump", "+4")
		self:add_instr("jump", lbl_then)
		self:condition(lbl_then, lbl_else)
	end
end


--[[
and_condition:
    = comparison
    | comparison 'and' and_condition
    | comparison '&&' and_condition
]]--
function BPars:and_condition(lbl_then, lbl_else)
	local opnd1 = self:comparison(lbl_then)
	local val = self:tk_peek().val
	if val == "and" then
		self:tk_match()
		self:add_instr("jump", lbl_else)
		self:and_condition(lbl_then)
	elseif val == "&&" then
		self:tk_match()
		self:add_instr("jump", lbl_else)
		self:and_condition(lbl_then)
	end
end


--[[
comparison:
    = 'true'
    | 'false'
    | '(' comparison ')'
    | expression '<' expression
    | expression '>' expression
    | expression '==' expression
    | expression '!=' expression
    | expression
]]--
function BPars:comparison(lbl_then)
	local val = self:tk_peek().val
	if val == "true" then
		self:tk_match("true")
		self:add_instr("jump", "+4")
		return
	elseif val == "false" then
		self:tk_match("false")
		return
	elseif val == "(" then
		if self:type_of_next_operand() == "comparison" then
			self:tk_match("(")
			self:comparison()
			self:tk_match(")")
			return
		end
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
	elseif val == "<=" then
		self:tk_match("<=")
		local right = self:expression()
		left = self:add_instr("sklt", left, right)
		self:add_instr("skne", left, right)
		self:add_instr("jump", lbl_then)
	elseif val == ">=" then
		self:tk_match(">=")
		local right = self:expression()
		left = self:add_instr("skgt", left, right)
		self:add_instr("skne", left, right)
		self:add_instr("jump", lbl_then)
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
		local ident = self:ident()
		local lval = self:sym_get_var(ident)
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
			local ident = self:ident()
			local lval = self:sym_get_var(ident)
			if not lval then
				self:error_msg(string.format("Unknown identifier '%s'", ident))
			end
			return lval
		end
	end
end

--[[
label:
    = identifier ":"
]]--
function BPars:label()
	if self:tk_next().val == ":" then
		return true
	end
end

function BPars:push_var(name, val)
	if not self["stack_" .. name] then
		self["stack_" .. name] = {}
	end
	if self[name] then
		table.insert(self["stack_" .. name], self[name])
	end
	self[name] = val or self[name]
end

function BPars:pop_var(name)
	self[name] = table.remove(self["stack_" .. name])
	return self[name]
end


vm16.BPars = BPars
