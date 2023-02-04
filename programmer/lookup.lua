--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Debugger lookup table
]]--

-- for lazy programmers
local M = minetest.get_meta
local DBG = function() end
--local DBG = print
local Lut = {}

function Lut:new(o)
	o = {}
	o.items = {}
	o.addr2lineno = {}
	o.lineno2addr = {}
	o.step_in = {}
	o.step_out = {}
	o.globals = {}
	o.branches = {}
	o.func_locals = {}
	o.file_locals = {}
	o.last_lineno = 0  -- source file size in lines
	o.last_used_mem_addr = 0
	setmetatable(o, self)
	self.__index = self
	return o
end


function Lut:init(obj)
	DBG("Lut:init")
	local func = ""
	local file = ""
	local address1
	local file1
	local file_start_address = {}

	local add = function(_file, _func, a1, a2)
		if a1 then
			self.items[#self.items + 1] =
				{file = _file, func = _func, addresses = {a1, a2}}
		end
	end

	for _, item in ipairs(obj.lCode) do
		local ctype, lineno, address, ident = item[1], item[2], item[3],item[4]
		self.last_used_mem_addr = math.max(self.last_used_mem_addr, address or 0)
		if ctype == "file" then
			file = ident
			if not self.main_file then
				self.main_file = file
			end
		elseif ctype == "code" then
			self.lineno2addr[file] = self.lineno2addr[file] or {}
			self.lineno2addr[file][lineno] = self.lineno2addr[file][lineno] or address
			self.addr2lineno[address] = lineno
			self.last_lineno = math.max(self.last_lineno, lineno)
		end
	end

	for _, item in ipairs(obj.lDebug) do
		local ctype, lineno, address, ident = item[1], item[2], item[3], item[4]
		self.last_used_mem_addr = math.max(self.last_used_mem_addr, address or 0)
		if ctype == "file" then
			file = ident
			address1 = nil
			file_start_address[file] = address
			self.file_locals[file] = {}
		elseif ctype == "endf" then
			add(file, "", file_start_address[ident], address)
			if address1 then
				add(file, func, address1, address)
			end
			address1 = address
		elseif ctype == "func" then
			if address1 then
				add(file, func, address1, address - 1)
			end
			address1 = address
			func = ident
		end

		if ctype == "call" then
			self.step_in[file] = self.step_in[file] or {}
			self.step_in[file][lineno] = address
		elseif ctype == "ret" then
			self.step_out[file] = self.step_out[file] or {}
			self.step_out[lineno] = true
		elseif ctype == "gvar" then
			table.insert(self.globals, {name = ident, addr = address, type = "global"})
		elseif ctype == "lvar" then
			table.insert(self.file_locals[file], {name = ident, addr = address, type = "global"})
		elseif ctype == "svar" then
			self.func_locals[func] = self.func_locals[func] or {}
			self.func_locals[func][ident] = address
		elseif ctype == "brnch" then
			self.branches[lineno] = address
		end
	end

	table.sort(self.globals, function(a,b) return a.name < b.name end)
end

function Lut:get_files()
	local tbl = {}
	for file,_  in pairs(self.file_locals) do
		tbl[#tbl + 1] = file
	end
	return tbl
end

function Lut:get_globals()
	DBG("Lut:get_globals")
	return self.globals
end

function Lut:get_file_locals(filename)
	DBG("Lut:get_file_locals")
	return self.file_locals[filename]
end

function Lut:get_locals(address)
	DBG("Lut:get_locals", address)
	if address then
		local item = self:get_func_item(address)
		if item and self.func_locals[item.func] then
			return self.func_locals[item.func]
		end
	end
	DBG("Lut:get_locals", "oops")
end

function Lut:get_item(address)
	DBG("Lut:get_item", address)
	if address then
		for _, item in ipairs(self.items) do
			if address >= item.addresses[1] and address <= item.addresses[2] then
				return item
			end
		end
	end
	DBG("Lut:get_item", "oops")
end

function Lut:get_func_item(address)
	DBG("Lut:get_item", address)
	if address then
		for _, item in ipairs(self.items) do
			if item.func ~= "" and address >= item.addresses[1] and address <= item.addresses[2] then
				return item
			end
		end
	end
	DBG("Lut:get_item", "oops")
end

function Lut:get_line(address)
	DBG("Lut:get_line", address)
	if address and self.addr2lineno[address] then
		return self.addr2lineno[address]
	end
	DBG("Lut:get_line", "oops")
end

function Lut:get_address(file, lineno)
	if file and lineno and self.lineno2addr[file] and self.lineno2addr[file][lineno] then
		return self.lineno2addr[file][lineno]
	end
end

function Lut:find_next_address(address)
	DBG("Lut:find_next_address", address)
	if address then
		local item = self:get_item(address)
		local lineno = self.addr2lineno[address]
		if item and lineno then
			for no = lineno + 1, self.last_lineno do
				if self.lineno2addr[item.file][no] then
					return self.lineno2addr[item.file][no]
				end
			end
		end
	end
	DBG("Lut:find_next_address", "oops")
end

function Lut:get_next_line(address)
	DBG("Lut:get_next_line", address)
	if address then
		local item = self:get_item(address)
		local lineno = self.addr2lineno[address]
		if item and lineno then
			for no = lineno + 1, self.last_lineno do
				if self.lineno2addr[item.file][no] then
					return no
				end
			end
			DBG("Lut:get_next_line", "oops", item.file, lineno)
		end
	end
	DBG("Lut:get_next_line", "oops")
end

function Lut:is_return_line(file, address)
	DBG("Lut:is_return_line", address)
	if address then
		local lineno = self.addr2lineno[address]
		return lineno and self.step_out[file] and self.step_out[file][lineno]
	end
	DBG("Lut:is_return_line", "oops")
end

function Lut:get_stepin_address(file, lineno)
	DBG("Lut:get_stepin_address", file, lineno)
	if file and lineno and self.step_in[file] and self.step_in[file][lineno] then
		return self.step_in[file][lineno]
	end
	DBG("Lut:get_stepin_address", "oops")
end

function Lut:get_function_address(func)
	DBG("Lut:get_function_address", func)
	for _, item in ipairs(self.items) do
		if item.func == func then
			return item.addresses[1]
		end
	end
	DBG("Lut:get_function_address", "oops")
end

function Lut:get_branch_address(lineno)
	return self.branches[lineno]
end

function Lut:get_program_size()
	return self.last_used_mem_addr or 0
end

vm16.Lut = Lut
