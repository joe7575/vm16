--[[

  VM16 Macro Assembler
  ====================

  Copyright (C) 2019-2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information
]]--

local version = "2.0"

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------
local strfind = string.find
local strsub = string.sub
local tinsert = table.insert

local function linessplit(text)
	local list = {}
	local pos = 1

	while true do
		local first, last = strfind(text, "\n", pos)
		if first then -- found?
			tinsert(list, strsub(text, pos, first-1))
			pos = last+1
		else
			tinsert(list, strsub(text, pos))
			break
		end
	end
	return list
end

local function append(into, from)
	if into and from then
		into[#into + 1] = from
	end
end

local function extend(into, from)
	if into and from then
		for _, t in ipairs(from or {}) do
			into[#into + 1] = t
		end
	end
end

local function startswith(s, keyword)
   return string.sub(s, 1, string.len(keyword)) == keyword
end

-------------------------------------------------------------------------------
-- Scanner with macro preprocessing
-------------------------------------------------------------------------------
local Scanner = {}

function Scanner:new(attr)
	local o = {
		get_path = attr.get_path,
		read_file = attr.read_file,
		output = {},
		macros = {},
		tokens = {},
		already_loaded = {},
		call_count = 0,
		error_count = 0,
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Scanner:err_msg(err)
	local s = string.format("Error(%u): %s!", self.lineno or 0, err)
	append(self.output, s)
	self.error_count = self.error_count + 1
	return false
end

function Scanner:expand_macro(txtline, name, params)
	local num_param = #params
	if num_param ~= self.macros[name][1] then
		self.err_msg("Invalid macro parameter(s)")
		return
	end

	append(self.tokens, {self.lineno, "", "$macro"})
	append(self.tokens, {self.lineno, "", txtline})
	for idx, txtline in ipairs(self.macros[name]) do
		if idx > 1 then
			if num_param > 0 then txtline = txtline:gsub("%%1", params[1]) end
			if num_param > 1 then txtline = txtline:gsub("%%2", params[2]) end
			if num_param > 2 then txtline = txtline:gsub("%%3", params[3]) end
			if num_param > 3 then txtline = txtline:gsub("%%4", params[4]) end
			if num_param > 4 then txtline = txtline:gsub("%%5", params[5]) end
			if num_param > 5 then txtline = txtline:gsub("%%6", params[6]) end
			if num_param > 6 then txtline = txtline:gsub("%%7", params[7]) end
			if num_param > 7 then txtline = txtline:gsub("%%8", params[8]) end
			if num_param > 8 then txtline = txtline:gsub("%%9", params[9]) end
			local _, _, codestr = txtline:find("(.+);")
			codestr = string.trim(codestr or txtline)
			append(self.tokens, {self.lineno, codestr, txtline})
		end
	end
	append(self.tokens, {self.lineno, "", "$endmacro"})
end

function Scanner:check_descent_depth(path)
	self.call_count = self.call_count + 1
	if self.call_count > 10 then
		return
	end
	if self.call_count == 1 then
		append(self.output, " - read " .. path)
	else
		append(self.output, " - import " .. path)
	end
	return true
end

function Scanner:handle_comments(lineno, codestr, txtline)
	if string.byte(codestr, 1) == 59 then -- ';'
		append(self.tokens, {lineno, "", txtline})
		return true
	elseif codestr == "" then
		append(self.tokens, {lineno, "", txtline})
		return true
	end
end

function Scanner:handle_includes(lineno, codestr, txtline)
	local _, _, fname = codestr:find('^%$include +"(.-)"')
	if fname then
		self:main(fname)
		return true
	end
end

function Scanner:handle_macros(lineno, codestr, txtline)
	if self.macro_name and startswith(txtline, "$endmacro") then
		self.macro_name = false
		return true
	elseif self.macro_name then
		append(self.macros[self.macro_name], txtline)
		return true
	elseif startswith(txtline, "$macro") then
		local pattern = '^%$macro +([A-Za-z_][A-Za-z_0-9%.]+) *([0-9]?)$'
		local _, _, name, num_param = codestr:find(pattern)
		if name then
			self.macro_name = name
			num_param = tonumber(num_param or "0")
			self.macros[self.macro_name] = {num_param}
			return true
		else
			return self.err_msg("Invalid macro syntax")
		end
	else -- expand macro
		local pattern = '^([A-Za-z_][A-Za-z_0-9%.]+) *(.*)$'
		local _, _, name, params = codestr:find(pattern)
		if name and self.macros[name] then
			params = string.split(params, " ")
			self:expand_macro(txtline, name, params)
			return true
		end
	end
	return false
end

function Scanner:handle_code(lineno, codestr, txtline)
	append(self.tokens, {lineno, codestr, txtline})
	return true
end

-- Read ASM file with all include files.
-- Function is called recursively to handle includes.
function Scanner:main(fname)
	local path = self.get_path(self.pos, fname)
	if not path then
		return self.err_msg("Can't find file")
	end

	if self.already_loaded[path] then
		return true
	end
	self.already_loaded[path] = true

	if not self:check_descent_depth(path) then
		return self.err_msg("Recursive include")
	end

	local text = self.read_file(self.pos, path)
	if not vm16.is_ascii(text) then
		return self.err_msg("Invalid ASCII file format")
	end

	append(self.tokens, {0, "namespace", string.format("; ##### File %s #####", fname)})

	for lineno, txtline in ipairs(linessplit(text)) do
		self.lineno = lineno -- needed for macro expansion
		local _, _, codestr = txtline:find("(.+);")
		codestr = string.trim(codestr or txtline)
		local res = self:handle_comments(lineno, codestr, txtline)
		res = res or self:handle_includes(lineno, codestr, txtline)
		res = res or self:handle_macros(lineno, codestr, txtline)
		res = res or self:handle_code(lineno, codestr, txtline)
	end

	append(self.tokens, {0, "namespace", string.format("; ##### EOF  %s #####", fname)})

	return true
end

function Scanner:scan(fname)
	self:main(fname)
	if self.error_count > 0 then
		append(self.output, self.error_count .. " error(s) occured!")
	end
	return self.tokens
end


-------------------------------------------------------------------------------
-- Macro Assembler
-------------------------------------------------------------------------------

local MacroAsm = vm16.Asm:new({version = version})

function MacroAsm:scanner(pos, filename, read_file, get_path)
	local s = Scanner:new({
		pos = pos,
		read_file = read_file,
		get_path = get_path,
	})
	self.tokens = s:scan(filename)
	self.output = s.output
	self.error_count = s.error_count
	return self.tokens
end

function MacroAsm:assemble(filename, tokens)
	if tokens then
		self.asm = vm16.Asm:new({support_namespaces = true})
		local errors
		tokens, errors = self.asm:assembler(filename, tokens)
		if errors then
			table.insert(self.output, errors)
		end
		return tokens
	end
end

function MacroAsm:get_output()
	return table.concat(self.output, "\n")
end

function MacroAsm:get_listing(lToken)
	return self.asm:listing(lToken)
end

vm16.MacroAsm = MacroAsm
