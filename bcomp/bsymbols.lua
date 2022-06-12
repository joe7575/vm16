--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Symbol table

]]--

local KEYWORDS = {var=1, func=1, ["while"]=1, ["return"]=1, input=1, output=1,
                  system=1, sleep=1, ["if"]=1, ["else"]=1,
                  ["for"]=1, ["switch"]=1, ["case"]=1, ["break"]=1, ["continue"]=1, ["goto"]=1,
                  ["and"]=1, ["or"]=1, ["not"]=1, ["xor"]=1, ["mod"]=1,
                  A=1, B=1, C=1, D=1, X=1, Y=1, PC=1, SP=1,
                  import=1, pragma=1, _asm_=1}

local BSym = vm16.BScan:new({})

function BSym:bsym_init()
	self:bscan_init()
	self.globals = {}      -- global variables
	self.file_locals = {}  -- file local variables
	self.locals = {}       -- function local variables
	self.file_locals_cnt = 1
end

-------------------------------------------------------------------------------
-- Local/stack variables
-------------------------------------------------------------------------------
function BSym:local_new()
	self.locals = {}
	self.stack_size = 0  -- params + return addr + locals
	self.num_auto = 0    -- locals only
	self.num_param = 0   -- params only
end

function BSym:sym_add_local(ident, array_size)
	if self.locals[ident] then
		self:error_msg(string.format("Redefinition of '%s'", ident))
	elseif KEYWORDS[ident] and ident ~= "func" then
		self:error_msg(string.format("'%s' is a protected keyword", ident))
	end
	self.stack_size = self.stack_size + 1
	if array_size then
		self.locals[ident] = {type = "array", ref = self.stack_size, offs = array_size - 1}
	else
		self.locals[ident] = {type = "var", ref = self.stack_size}
	end
end

function BSym:sym_add_param(ident)
	self.stack_size = self.stack_size + 1
	self.locals[ident] = {type = "param", ref = self.stack_size}
end

function BSym:sym_get_local(ident)
	if self.locals[ident] then
		local pos = self.stack_size - self.locals[ident].ref + self.num_param
		self.stack_offs = pos  -- TODO: als Returnwert
		if self.locals[ident].type == "array" then
			return "SP+" .. pos
		else
			return "[SP+" .. pos .. "]"
		end
	end
end

-------------------------------------------------------------------------------
-- Globals
-------------------------------------------------------------------------------
function BSym:sym_add_global(ident, is_array)
	if self.globals[ident] then
		self:error_msg(string.format("Redefinition of '%s'", ident))
	elseif KEYWORDS[ident] then
		self:error_msg(string.format("'%s' is a protected keyword", ident))
	end
	self.globals[ident] = {type = is_array and "array" or "var"}
end

function BSym:sym_is_global(val)
	return self.globals[val] ~= nil
end

function BSym:sym_get_global(ident)
	if self.globals[ident] then
		if self.globals[ident].type == "array" then
			return "#" .. ident
		else
			return ident
		end
	end
end

-------------------------------------------------------------------------------
-- File locals
-------------------------------------------------------------------------------
-- Because of ASM limitations, file local variables (static) have to be declared
-- as global variables. To be able to distinguish local variables with the same name,
-- add a prefix to the variable name.
function BSym:next_file_for_local_vars()
	self.file_locals_cnt = self.file_locals_cnt + 1
	self.file_locals = {}
end

function BSym:sym_add_filelocal(ident, is_array)
	if self.file_locals[ident] then
		self:error_msg(string.format("Redefinition of '%s'", ident))
	elseif KEYWORDS[ident] then
		self:error_msg(string.format("'%s' is a protected keyword", ident))
	end
	self.file_locals[ident] = {type = is_array and "array" or "var", ref = ident .. "@" .. self.file_locals_cnt}
	return self.file_locals[ident].ref
end

function BSym:sym_get_filelocal(ident)
	local item = self.file_locals[ident]
	if item then
		if item.type == "array" then
			return "#" .. item.ref
		else
			return item.ref
		end
	end
end

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------
function BSym:sym_add_func(ident, num_param, scope)
	if scope == "global" then
		if self.globals[ident] then
			self:error_msg(string.format("Redefinition of '%s'", ident))
		elseif KEYWORDS[ident] then
			self:error_msg(string.format("'%s' is a protected keyword", ident))
		end
		self.globals[ident] = {type = "func", num_param = num_param}
	else
		if self.file_locals[ident] then
			self:error_msg(string.format("Redefinition of '%s'", ident))
		elseif KEYWORDS[ident] then
			self:error_msg(string.format("'%s' is a protected keyword", ident))
		end
		self.file_locals[ident] = {type = "func", num_param = num_param, ref = ident}
	end
end

function BSym:sym_check_num_param(ident, num_param)
	local item = self.globals[ident] or self.file_locals[ident]
	if item and item.num_param and item.num_param ~= num_param then
		self:error_msg(string.format("Wrong number of parameters for '%s'", ident))
	end
end

function BSym:sym_is_func(ident)
	local item = self.globals[ident] or self.file_locals[ident]
	return item and item.type == "func"
end

function BSym:sym_func_return(ident, end_of_func)
	if self:get_last_instr() ~= "ret" then
		if self.num_auto > 0 then
			self:add_instr("add", "SP", "#" .. self.num_auto)
		end
		self:add_instr("ret")
	end

	-- Generate a table with BS relative addresses of function local variables
	if end_of_func then
		local base
		for k,v in pairs(self.locals) do
			if k == "func" then
				base = v.ref
				break
			end
		end

		local num_stack_var = 0
		for k,v in pairs(self.locals) do
			if k ~= "func" then
				self:add_debugger_info("svar", self.lineno, k, base - v.ref - (v.offs or 0))
				num_stack_var = math.min(num_stack_var, base - v.ref)
			end
		end
		self:add_debugger_info("svar", self.lineno, "@num_stack_var@", -num_stack_var)
		self.locals = {}
	end
end

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
function BSym:sym_add_const(ident, val, scope)
	if scope == "global" then
		if self.globals[ident] then
			self:error_msg(string.format("Redefinition of '%s'", ident))
		elseif KEYWORDS[ident] then
			self:error_msg(string.format("'%s' is a protected keyword", ident))
		end
		self.globals[ident] = {type = "const", value = val}
	else
		if self.file_locals[ident] then
			self:error_msg(string.format("Redefinition of '%s'", ident))
		elseif KEYWORDS[ident] then
			self:error_msg(string.format("'%s' is a protected keyword", ident))
		end
		self.file_locals[ident] = {type = "const", value = val}
	end
end

function BSym:sym_is_const(ident)
	local item = self.globals[ident] or self.file_locals[ident]
	return item and item.type == "const"
end

function BSym:sym_get_const(ident)
	local item = self.globals[ident] or self.file_locals[ident]
	return item and item.type == "const" and item.value
end

-------------------------------------------------------------------------------
-- Common
-------------------------------------------------------------------------------
function BSym:sym_get_var(ident)
	if ident:find("@") then
		return ident
	end
	return self:sym_get_local(ident) or self:sym_get_filelocal(ident) or self:sym_get_global(ident)
end

vm16.BSym = BSym
