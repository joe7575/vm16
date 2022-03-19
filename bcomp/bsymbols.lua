--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Symbol table

]]--

local KEYWORDS = {var=1, func=1, ["while"]=1, ["return"]=1, input=1, output=1,
                  putchar=1, system=1, sleep=1, ["if"]=1, ["else"]=1,
                  ["for"]=1, ["switch"]=1, ["case"]=1, ["break"]=1, ["continue"]=1, ["goto"]=1,
                  ["and"]=1, ["or"]=1, ["not"]=1, ["xor"]=1, ["mod"]=1}

local BSym = vm16.BScan:new({})

function BSym:bsym_init()
	self:bscan_init()
	self.globals = {}
	self.locals = {}
	self.all_locals = {}
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
		return "[SP+" .. pos .. "]"
	end
end

function BSym:func_return(ident)
	if ident == "main" then
		self:add_instr("halt")
	elseif self:get_last_instr() ~= "ret" then
		if self.num_auto > 0 then
			self:add_instr("add", "SP", "#" .. self.num_auto)
		end
		self:add_instr("ret")
	end

	-- Generate a table with BS relative addresses of function local variables
	local base
	for k,v in pairs(self.locals) do
		if k == "func" then
			base = v
			break
		end
	end

	local num_stack_var = 0
	self.all_locals[ident] = {}
	for k,v in pairs(self.locals) do
		if k ~= "func" then
			self.all_locals[ident][k] = base - v
			num_stack_var = math.min(num_stack_var, base - v)
		end
	end
	self.all_locals[ident]["@nsv@"] = -num_stack_var
end

-------------------------------------------------------------------------------
-- Globals and functions
-------------------------------------------------------------------------------
function BSym:add_global(ident, value)
	if type(value) == "number" and type(self.globals[ident]) == "number" then
		if value ~= self.globals[ident] then
			error(string.format("Wrong number of parameters for '%s'", ident))
		end
	elseif self.globals[ident] then
		error(string.format("Redefinition of '%s'", ident))
	elseif KEYWORDS[ident] then
		error(string.format("'%s' is a protected keyword", ident))
	end
	self.globals[ident] = value
end

function BSym:is_global_var(val)
	if self.globals[val] and self.globals[val] == true then
		return val
	end
end

function BSym:num_func_param(val)
	if self.globals[val] and (self.globals[val]) == "number" then
		return self.globals[val]
	end
end

vm16.BSym = BSym
