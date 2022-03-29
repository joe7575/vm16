--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Compiler API

]]--

local version = "1.1"

local function extend(into, from)
	if into and from then
		for _, t in ipairs(from or {}) do
			into[#into + 1] = t
		end
	end
end

local function gen_comp_output(lCode, lData, lString)
	local out = {}

	for idx,line in ipairs(lCode) do
		table.insert(out, line)
	end
	table.insert(out, "")
	for idx,line in ipairs(lData) do
		table.insert(out, line)
	end
	if #lString > 1 then
		table.insert(out, "")
		for idx,line in ipairs(lString) do
			table.insert(out, line)
		end
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


local function error_msg(err)
	local t = string.split(err, "\001")
	if t and #t > 1 then
		return t[#t]
	end
	return err
end

local function format_output_for_sourcecode_debugging(lToken)
	local out = {}
	local tok
	local lineno
	local inline_asm = false
	for _,item in ipairs(lToken) do
		if item[vm16.Asm.SECTION] == vm16.Asm.COMMENT then
			inline_asm = string.find(item[vm16.Asm.TXTLINE], "_asm_")
			if tok then
				out[#out + 1] = tok
				tok = nil
			end
			lineno = tonumber(item[vm16.Asm.TXTLINE]:sub(2,5))
			tok = {lineno = lineno}
		elseif inline_asm then
			-- Add each line until the next comment line
			lineno = lineno + 1
			out[#out + 1] = {lineno = lineno, address = item[vm16.Asm.ADDRESS], opcodes = item[vm16.Asm.OPCODES]}
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
		local lToken = gen_asm_token_list(prs.lCode, prs.lData, prs.lString)
		lToken, err = asm:assembler(file_base(filename) .. ".asm", lToken)
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
	local fname = prs.filename or ""
	local lineno = prs.lineno or "0"
	local errors = string.format("%s(%d): %s", fname, lineno, error_msg(err))
	return {
		locals = {},
		output = {},
		globals = {},
		functions = {},
		errors = errors}
end

function vm16.gen_asm_code(filename, code)
	local out = {}
	local prs =  vm16.BPars:new({text = code, add_sourcecode = true})
	prs.filename = filename
	prs:bpars_init()
	local status, err = pcall(prs.main, prs)
	if not err then
		return gen_comp_output(prs.lCode, prs.lData, prs.lString)
	else
		local fname = prs.filename or ""
		local lineno = prs.lineno or "0"
		return gen_comp_output(prs.lCode, prs.lData, prs.lString), 
			string.format("%s(%d): %s", fname, lineno, error_msg(err))
	end
end

function vm16.assemble(filename, code)
	local a = vm16.Asm:new({})
	code = code:gsub("\t", "  ")
	local lToken, err = a:scanner(code)
	if lToken then
		lToken, err = a:assembler(file_base(filename) .. ".asm", lToken)
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

function vm16.compile(pos, filename, readfile, debug)
	local prs =  vm16.BPars:new({pos = pos, readfile = readfile})
	prs:bpars_init()

	local sts, res = pcall(prs.scanner, prs, filename)
	if not sts then
		return false, error_msg(res)
	end

	sts, res = pcall(prs.main, prs)
	if not sts then
		return false, error_msg(res)
	end

	if debug then
		local output = prs:gen_output()
		return true, prs:gen_dbg_dump(output)
	end
	
	return true, prs:gen_output()
end

function vm16.gen_asm_code(output, sourcecode)
	local out = {}
	local oldlineno = 0
	local add_src_code = function(lineno)
		for no = oldlineno + 1, lineno do
			if sourcecode[no] and sourcecode[no] ~= "" then
				out[#out + 1] = string.format("; %3d: %s", no, sourcecode[no])
			end
		end
		oldlineno = math.max(oldlineno, lineno)
	end

	for idx,tok in ipairs(output.lCode) do
		local ctype, lineno, code = tok[1], tok[2], tok[3]

		if sourcecode and ctype == "code" then
			add_src_code(lineno)
		elseif sourcecode and ctype == "data" then
			add_src_code(#sourcecode)
		end

		if ctype == "code" then
			if code == ".code" then
				out[#out + 1] = "  " .. code
			elseif string.sub(code, -1, -1) == ":" then
				out[#out + 1] = code
			else
				out[#out + 1] = "  " .. code
			end
		elseif ctype == "data" then
			if code == ".data" then
				out[#out + 1] = "\n  " .. code
			else
				out[#out + 1] = "" .. code
			end
		elseif ctype == "ctext" then
			if code == ".ctext" then
				out[#out + 1] = "  " .. code
			else
				out[#out + 1] = "  " .. code
			end
		end
	end

	if sourcecode then
		add_src_code(#sourcecode)
	end
	
	return table.concat(out, "\n")
end
