--[[

  VM16 BLL Compiler
  =================

  Copyright (C) 2022 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

  Compiler API

  The compiler generates a list with tokens according to:

  {<type>, <lineno>, <asm-code>}
  {"file", 0, "test.c"}         -- File info
  {"code", 2, "move A, #1"}     -- ASM code
  {"data", 3, "va1: 0"}         -- Variable
  {"ctext", 4, "str: 'Hallo'"}  -- String
  {"func", 5, "foo"}            -- Start of function 'foo' (debugging)
  {"call", 7, "foo"}            -- Call of function 'foo' (debugging)

  And a table with local variable definitions:

  {foo = {<name> = <offs>, ...} -- positive offs = parameter, negative offs = stack variable

  The assembler adds address and opcode information:

  {CTYPE,  LINENO,  CODESTR,      ADDRESS,  OPCODES}
  {"code",  2,     "move A, #1",   10,     {0x1020, 0x0001}}

--]]

local version = "1.2"

local function error_msg(err)
	local t = string.split(err, "\001")
	if t and #t > 1 then
		return t[#t]
	end
	return err
end

local function comp_code_listing(lCode, filename)
	local mydump = function(tbl)
		local t = {}
		for _,e in ipairs(tbl or {}) do
			if type(e) == "number" then
				table.insert(t, string.format("%04X", e))
			else
				table.insert(t, "'"..e.."'")
			end
		end
		return table.concat(t, " ")
	end

	local out = {"##### " .. vm16.file_base(filename) .. ".lst" .. " #####"}
	for _,item in ipairs(lCode) do
		local ctype, lineno, scode, address, opcodes = unpack(item)
		table.insert(out, string.format("%5s %3d %04X: %-15s %s", ctype, lineno, address or 0, scode, mydump(opcodes)))
	end
	return table.concat(out, "\n")
end

local function gen_asm_code(pos, output, filename, readfile)
	local out = {}
	local oldlineno = 0
	local oldctype = nil
	local text = readfile(pos, filename)
	local sourcecode = vm16.splitlines(text)
	local is_asm_file = vm16.file_ext(filename) == "asm"

	local add_src_code = function(lineno)
		if not is_asm_file then
			for no = oldlineno + 1, lineno do
				if sourcecode[no] and sourcecode[no] ~= "" then
					out[#out + 1] = string.format("; %3d: %s", no, sourcecode[no])
				end
			end
			oldlineno = math.max(oldlineno, lineno)
		end
	end

	for idx,tok in ipairs(output.lCode) do
		local ctype, lineno, code = tok[1], tok[2], tok[3]

		if ctype == "code" then
			add_src_code(lineno)
		elseif ctype == "data" then
			add_src_code(#sourcecode)
		elseif ctype == "file" then
			filename = code
			text = readfile(pos, filename)
			sourcecode = vm16.splitlines(text)
			is_asm_file = vm16.file_ext(filename) == "asm"
			oldlineno = 0
			oldctype = nil
			out[#out + 1] = ";##### " .. filename .. " #####"
		end

		if oldctype ~= ctype and (ctype == "code" or ctype == "data" or ctype == "ctext") then
			out[#out + 1] = "  ." .. ctype
			oldctype = ctype
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

	add_src_code(#sourcecode)

	return table.concat(out, "\n")
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------
function vm16.assemble(pos, filename, readfile, debug)
	local code = readfile(pos, filename)
	code = code:gsub("\t", "  ")

	local a = vm16.Asm:new({})
	local sts, res = pcall(a.scanner, a, code, filename)
	if not sts then
		return false, error_msg(res)
	end

	sts, res = pcall(a.assembler, a, filename, res)
	if not sts then
		return false, error_msg(res)
	end

	if debug then
		return true, a:listing(res)
	end

	return true, {lCode = res, locals = {}}
end

function vm16.compile(pos, filename, readfile, output_format)
	local prs =  vm16.BPars:new({pos = pos, readfile = readfile})
	prs:bpars_init()

	local sts, res = pcall(prs.scanner, prs, filename)
	if not sts then
		return false, error_msg(res)
	end

	if output_format == "tok" then
		return true, prs:scan_dbg_dump()
	end

	sts, res = pcall(prs.main, prs)
	if not sts then
		return false, error_msg(res)
	end

	local output = prs:gen_output()

	if output_format == "dbg" then
		return true, prs:gen_dbg_dump(output)
	end

	if output_format == "asm" then
		return true, gen_asm_code(pos, output, filename, readfile)
	end

	local asm = vm16.Asm:new({})
	sts, res = pcall(asm.assembler, asm, filename, output.lCode)
	if not sts then
		return false, error_msg(res)
	end

	if output_format == "lst" then
		return true, comp_code_listing(res, filename)
	end

	return true, {lCode = res, locals = output.locals}
end

