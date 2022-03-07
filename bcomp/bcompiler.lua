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

local function format_asm_output(lToken)
	local out = {}
	local tok
	for _,item in ipairs(lToken) do
		if item[vm16.Asm.SECTION] == vm16.Asm.COMMENT then
			if tok then
				out[#out + 1] = tok
				tok = nil
			end
			local lineno = tonumber(item[vm16.Asm.TXTLINE]:sub(12))
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

function vm16.BCompiler(code, gen_asmcode, break_ident)
	local out = {}
	local prs =  vm16.BPars:new({text = code, add_sourcecode = gen_asmcode})
	prs:bpars_init()
	prs.break_ident = break_ident
	local status, err = pcall(prs.main, prs)
	
	if not err then
		local asm = vm16.Asm:new({})
		local asm_code, lToken, err
		
		if gen_asmcode then
			asm_code = gen_comp_output(prs.lCode, prs.lData)
			lToken, err = asm:scanner(asm_code)
		else
			asm_code = "disabled"
			lToken = gen_asm_token_list(prs.lCode, prs.lData)
		end
		
		if lToken then
			local globals
			lToken, err = asm:assembler(lToken)
			if lToken then
				return {
					asm_code = asm_code, 
					output = format_asm_output(lToken),
					locals = prs.all_locals,
					globals = asm.symbols}
			else
				return {
					asm_code = asm_code, 
					errors = err}
			end
		else
			return {
				asm_code = asm_code, 
				errors = err}
		end
	else
		return {errors = err}
	end
end
