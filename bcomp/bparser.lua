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

local BPars = vm16.BExpr:new({})

function BPars:bpars_init()
	self:bexpr_init()
	self.tLineno2Func = {}
end

--[[
program:
    = var_def_list func_def_list
]]--
function BPars:main()
	self:var_def_list()
	self:insert_instr("jump", "main", nil, -1)
	self:func_def_list()
end

--[[
var_def_list:
    = 'var' ident [ '=' expression ] ';' glob_def_list
]]--
function BPars:var_def_list()
	local val = self:tk_peek().val
	while val == "var" do
		self:tk_match("var")
		local ident = self:ident()
		self:add_global(ident, true)
		self:add_data(ident)
		if self:tk_peek().val == "=" then
			self:tk_match("=")
			local right = self:expression()
			self:add_instr("move", ident, right)
			self:reset_reg_use()
		end
		self:tk_match(";")
		val = self:tk_peek().val
	end
end

--[[
func_def_list:
    = 'func' ident '(' param_list ')' '{' lvar_def_list stmnt_list '}' func_def_list
]]--
function BPars:func_def_list()
	local val = self:tk_peek().val
	while val == "func" do
		self:tk_match("func")
		local ident = self:ident()
		self.func_name = ident
		self.tLineno2Func[self.lineno] = ident
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
		self:tk_match("}")
		self:func_return(ident)
		val = self:tk_peek().val
	end
end

--[[
lvar_def_list:
    = 'var' ident [ '=' expression ] ';'  local_def_list
]]--
function BPars:lvar_def_list()
	local val = self:tk_peek().val
	while val == "var" do
		self:tk_match("var")
		local ident = self:ident()
		self:local_add(ident)
		self.num_auto = self.num_auto + 1
		if self:tk_peek().val == "=" then
			self:tk_match("=")
			local right = self:expression()
			self:add_instr("push", right)
		else
			self:add_instr("push", "#0")
		end
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
	while self:tk_peek().val ~= "}" do
		self:statement()
	end
end

--[[
param_list:
    = 
    | expression
    | expression  ',' param_list
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
    | assignment ";"
    | expression ";"
]]--
function BPars:statement()
	local val = self:tk_peek().val
	if val == "if" then
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
		self:tk_match(";")
		self:func_return(self.func_name or "")
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
	self:stmnt_list()
	self:tk_match("}")
	if self:tk_peek().val == 'else' then
		self:tk_match("else")
		local lbl2 = self:get_label()
		self:add_instr("jump", lbl2)
		self:add_label(lbl1)
		self:tk_match("{")
		self:stmnt_list()
		self:tk_match("}")
		self:add_label(lbl2)
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
	self:stmnt_list()
	local pos3 = self:get_instr_pos()
	self:add_instr("jump", loop)
	self:tk_match("}")
	self:add_label(lend)
	self:instr_move(pos1, pos2, pos3)
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
	self:stmnt_list()
	self:add_instr("jump", loop)
	self:tk_match("}")
	self:add_label(lend)
end

--[[
assignment:
    = left_value '=' expression
    | left_value '++'
    | left_value '--'
]]--
function BPars:assignment()
	local val = self:tk_next().val
	if val == "=" then
		local left = self:left_value()
		self:tk_match("=")
		local right = self:expression()
		self:add_instr("move", left, right)
		self:reset_reg_use()
		return true
	elseif val == "++" then
		local left = self:left_value()
		self:tk_match("++")
		self:add_instr("inc", left)
		self:reset_reg_use()
		return true
	elseif val == "--" then
		local left = self:left_value()
		self:tk_match("--")
		self:add_instr("dec", left)
		self:reset_reg_use()
		return true
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
	if self:tk_peek().val == "true" then
		return "#1"
	elseif self:tk_peek().val == "false" then
		return "#0"
	end
	local nxt = self:tk_next().val
	if nxt == "<" then
		local left = self:expression()
		self:tk_match("<")
		local right = self:expression()
		self:add_instr("sklt", left, right)
	elseif nxt == ">" then
		local left = self:expression()
		self:tk_match(">")
		local right = self:expression()
		self:add_instr("skgt", left, right)
	elseif nxt == "==" then
		local left = self:expression()
		self:tk_match("==")
		local right = self:expression()
		self:add_instr("skeq", left, right)
	elseif nxt == "!=" then
		local left = self:expression()
		self:tk_match("!=")
		local right = self:expression()
		self:add_instr("skne", left, right)
	else
		local left = self:expression()
		self:add_instr("skgt", left, "#00")
	end
	return "A"
end

function BPars:left_value()
	local ident = self:tk_match(T_IDENT).val
	local lval = self:local_get(ident) or (self.globals[ident] and ident)
	if not lval then
		error(string.format("Unknown identifier '%s'", ident))
	end
	return lval or ident
end

vm16.BPars = BPars
