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

local Lut = {}

function Lut:new()
	o = {}
	o.items = {}
	o.addr2lineno = {}
	o.lineno2addr = {}
	o.step_in = {}
	o.globals = {}
	o.last_used_mem_addr = 0
	setmetatable(o, self)
	self.__index = self
	return o
end

function Lut:init(obj)
	print("Lut:init")
	local func = ""
	local file = ""
	local lineno1, lineno2
	local address1, address2

	for _, item in ipairs(obj.lCode) do
		local ctype, lineno, scode, address, opcodes = unpack(item)
		self.last_used_mem_addr = math.max(self.last_used_mem_addr, address or 0)
		if ctype == "code" and #opcodes > 0 then
			self.lineno2addr[file] = self.lineno2addr[file] or {}
			self.lineno2addr[file][lineno] = self.lineno2addr[file][lineno] or address
			self.addr2lineno[address] = lineno
			self.last_lineno = lineno
		elseif ctype == "data" then
			self.globals[#self.globals + 1] = {name = scode, addr = address, type = "global"}
		elseif ctype == "file" then
			file = scode
		elseif ctype == "func" then
			func = scode
			lineno1 = lineno
			address1 = address
		elseif ctype == "endf" then
			lineno2 = lineno
			address2 = address
			self.items[#self.items + 1] = {file = file, func = func, 
				lines = {lineno1, lineno2}, addresses = {address1, address2}}
		elseif ctype == "call" then
			self.step_in[file] = self.step_in[file] or {}
			self.step_in[file][lineno] = address
		end
	end
	self.locals = obj.locals
	table.sort(self.globals, function(a,b) return a.name < b.name end)
end

function Lut:get_globals()
	print("Lut:get_globals")
	return self.globals
end

function Lut:get_locals(address)
	print("Lut:get_locals", address)
	local item = self:get_item(address or 0)
	if item and self.locals[item.func] then
		return self.locals[item.func]
	end
	print("Lut:get_locals", "oops")
end

function Lut:get_item(address)
	print("Lut:get_item", address)
	for _, item in ipairs(self.items) do
		if address >= item.addresses[1] and address <= item.addresses[2] then
			return item
		end
	end
	print("Lut:get_item", "oops")
end

function Lut:get_item_by_lineno(lineno)
	print("Lut:get_item_by_lineno", lineno)
	if lineno then
		for _, item in ipairs(self.items) do
			if lineno >= item.lines[1] and lineno <= item.lines[2] then
				return item
			end
		end
	end
	print("Lut:get_item_by_lineno", "oops")
end

function Lut:get_line(address)
	print("Lut:get_line", address)
	if address and self.addr2lineno[address] then
		return self.addr2lineno[address]
	end
	print("Lut:get_line", "oops")
end

function Lut:get_address(file, lineno)
	print("Lut:get_address", file, lineno)
	if file and lineno and self.lineno2addr[file] and self.lineno2addr[file][lineno] then
		return self.lineno2addr[file][lineno]
	end
	print("Lut:get_address", "oops")
end

function Lut:find_next_address(address)
	print("Lut:find_next_address", address)
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
	print("Lut:find_next_address", "oops")
end

function Lut:get_next_line(address)
	print("Lut:get_next_line", address)
	if address then
		local item = self:get_item(address)
		local lineno = self.addr2lineno[address]
		if item and lineno then
			for no = lineno + 1, self.last_lineno do
				if self.lineno2addr[item.file][no] then
					return no
				end
			end
		end
	end
	print("Lut:get_next_line", "oops")
end

function Lut:get_stepin_address(file, lineno)
	print("Lut:get_stepin_address", file, lineno)
	if file and lineno and self.step_in[file][lineno] and self.step_in[file][lineno] then
		return self.step_in[file][lineno]
	end
	print("Lut:get_stepin_address", "oops")
end

vm16.Lut = Lut
