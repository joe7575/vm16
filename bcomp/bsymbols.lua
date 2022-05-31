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
	self.constants = {}
	self.globals = {}
	self.functions = {}
	self.arrays = {}
	self.file_locals = {}  -- file local variables
	self.locals = {}       -- function local variables
	self.file_locals_cnt = 1
end

-------------------------------------------------------------------------------
-- Locals or auto/stack variables
-------------------------------------------------------------------------------
function BSym:local_new()
	self.locals = {}
	self.stack_size = 0  -- params + return addr + locals
	self.num_auto = 0    -- locals only
	self.num_param = 0   -- params only
end

function BSym:local_add(ident)
	self.stack_size = self.stack_size + 1
	self.locals[ident] = self.stack_size
end

function BSym:param_add(ident)
	self.stack_size = self.stack_size + 1
	self.locals[ident] = self.stack_size
end

function BSym:local_get(ident)
	if self.locals[ident] then
		local pos = self.stack_size - self.locals[ident] + self.num_param
		self.stack_offs = pos
		return "[SP+" .. pos .. "]"
	end
end

function BSym:func_return(ident, end_of_func)
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
				base = v
				break
			end
		end

		local num_stack_var = 0
		for k,v in pairs(self.locals) do
			if k ~= "func" then
				self:add_debugger_info("svar", self.lineno, k, base - v)
				num_stack_var = math.min(num_stack_var, base - v)
			end
		end
		self:add_debugger_info("svar", self.lineno, "@num_stack_var@", -num_stack_var)
		self.locals = {}
	end
end

-------------------------------------------------------------------------------
-- Globals, constants, and functions
-------------------------------------------------------------------------------
function BSym:add_global(ident, value, is_array)
	if type(value) == "number" and type(self.globals[ident]) == "number" then
		if value ~= self.globals[ident] then
			self:error_msg(string.format("Wrong number of parameters for '%s'", ident))
		end
	elseif self.globals[ident] then
		self:error_msg(string.format("Redefinition of '%s'", ident))
	elseif KEYWORDS[ident] then
		self:error_msg(string.format("'%s' is a protected keyword", ident))
	end
	self.globals[ident] = value
	self.arrays[ident] = is_array
end

function BSym:is_global_var(val)
	if self.globals[val] and self.globals[val] == true then
		return val
	end
end

-- Because of ASM limitations, file local variables (static) have to be declared
-- as global variables. To be able to distinguish local variables with the same name,
-- add a prefix to the variable name.
function BSym:next_file_for_local_vars()
	self.file_locals_cnt = self.file_locals_cnt + 1
	self.file_locals = {}
end

function BSym:set_file_local(ident)
	self.file_locals[ident] = ident .. "@" .. self.file_locals_cnt
	return self.file_locals[ident]
end

function BSym:get_file_local(ident)
	return self.file_locals[ident] or ident
end

function BSym:is_array(val)
	if self.arrays[val] and self.arrays[val] == true then
		return val
	end
end

function BSym:add_func(ident)
	self.functions[ident] = true
end

function BSym:is_func(ident)
	return self.functions[ident] ~= nil
end

function BSym:add_const(ident, val)
	self.constants[ident] = val
end

function BSym:is_const(ident)
	return self.constants[ident] ~= nil
end

function BSym:get_const(ident)
	return self.constants[ident]
end

vm16.BSym = BSym
