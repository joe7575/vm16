--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Compiler API

]]--

local version = "1.0"

local function extend(into, from)
	if into and from then
		for _, t in ipairs(from or {}) do
			into[#into + 1] = t
		end
	end
end

local function gen_comp_output(lCode, lData)
	local out = {}

	for idx,line in ipairs(lCode) do
		table.insert(out, line)
	end
	table.insert(out, "")
	for idx,line in ipairs(lData) do
		table.insert(out, line)
	end

	return table.concat(out, "\n")
end

local function get_glob_variables(prs, symbols)
	local out = {}
	for ident,addr in pairs(symbols or {}) do
		if prs:is_global_var(ident) then
			out[ident] = addr
		end
	end
	return out
end

local function lineno_to_Function(prs, lToken)
	local out = {}
	local fname = ""
	for _, tok in ipairs(lToken) do
		if tok.lineno and tok.address then
			fname = prs.tLineno2Func[tok.lineno] or fname
			out[tok.lineno] = fname
		end
	end
	return out
end

local function gen_asm_token_list(lCode, lData)
	local out = {}

	local lineno = 0
	for _,txtline in ipairs(lCode) do
		lineno = lineno + 1
		if string.byte(txtline, 1) == 59 then -- ';'
			table.insert(out, {lineno, "", txtline})
		else
			table.insert(out, {lineno, txtline:trim(), ""})
		end
	end
	for idx,txtline in ipairs(lData) do
		lineno = lineno + 1
		table.insert(out, {lineno, txtline:trim(), ""})
	end
	return out
end

local function error_msg(err)
	local t = string.split(err, ":")
	if t and #t > 1 then
		return t[#t]
	end
	return err
end

local function format_output_for_sourcecode_debugging(lToken)
	local out = {}
	local tok
	for _,item in ipairs(lToken) do
		if item[vm16.Asm.SECTION] == vm16.Asm.COMMENT then
			if tok then
				out[#out + 1] = tok
				tok = nil
			end
			local lineno = tonumber(item[vm16.Asm.TXTLINE]:sub(2,5))
			tok = {lineno = lineno}
		else
			if tok and tok.address then
				extend(tok.opcodes, item[vm16.Asm.OPCODES])
			else
				tok = tok or {}
				tok.address = item[vm16.Asm.ADDRESS]
				tok.opcodes = item[vm16.Asm.OPCODES]
			end
		end
	end
	out[#out + 1] = tok
	return out
end

local function format_output_for_assembler_debugging(lToken)
	local out = {}
	for _,item in ipairs(lToken) do
		if item[vm16.Asm.SECTION] ~= vm16.Asm.COMMENT then
			out[#out + 1] = {
				lineno  = item[vm16.Asm.LINENO],
				address = item[vm16.Asm.ADDRESS],
				opcodes = item[vm16.Asm.OPCODES],
			}
		end
	end
	return out
end

function vm16.gen_obj_code(filename, code)
	local out = {}
	local prs =  vm16.BPars:new({text = code})
	prs.filename = filename
	prs:bpars_init()
	local status, err = pcall(prs.main, prs)
	if not err then
		local asm = vm16.Asm:new({})
		local lToken = gen_asm_token_list(prs.lCode, prs.lData)
		lToken, err = asm:assembler(lToken)
		if lToken then
			local output = format_output_for_sourcecode_debugging(lToken)
			return {
				locals = prs.all_locals,
				output = output,
				globals = get_glob_variables(prs, asm.symbols),
				functions = lineno_to_Function(prs, output)}
		end
		return {
			locals = {},
			output = {},
			globals = {},
			functions = {},
			errors = err}
	end
	return {
		locals = {},
		output = {},
		globals = {},
		functions = {},
		errors = error_msg(err)}
end

function vm16.gen_asm_code(filename, code)
	local out = {}
	local prs =  vm16.BPars:new({text = code, add_sourcecode = true})
	prs.filename = filename
	prs:bpars_init()
	local status, err = pcall(prs.main, prs)
	if not err then
		return gen_comp_output(prs.lCode, prs.lData)
	else
		local fname = prs.filename or ""
		local lineno = prs.lineno or "0"
		return nil, string.format("%s(%d): %s", fname, lineno, error_msg(err))
	end
end

function vm16.assemble(filename, code)
	local a = vm16.Asm:new({})
	code = code:gsub("\t", "  ")
	local lToken, err = a:scanner(code)
	if lToken then
		lToken, err = a:assembler(lToken)
		if lToken then
			local output = format_output_for_assembler_debugging(lToken)
			return {
				locals = {},
				output = output,
				globals = {},
				functions = {}}
		end
		return {
			locals = {},
			output = {},
			globals = {},
			functions = {},
			errors = err}
	end
	return {
		locals = {},
		output = {},
		globals = {},
		functions = {},
		errors = err}
end
