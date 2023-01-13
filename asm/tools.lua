--[[

  VM16 Asm
  ========

  Copyright (C) 2019-2023 Joachim Stolberg

  AGPL v3
  See LICENSE.txt for more information

]]--

local function generate_h16line(addr, code)
	local t = {}
	local num = #code
	for _, val in ipairs(code) do
		table.insert(t, string.format("%04X", val))
	end
	return string.format(":%u%04X00%s", num, addr, table.concat(t, ""))
end

local function add_h16lines(tbl, addr, code, force)
	while #code > 8 or force and #code > 0 do
		local s = generate_h16line(addr, {unpack(code, 1, 8)})
		addr = addr + math.min(8, #code)
		code = {unpack(code, 9)}
		table.insert(tbl, s)
	end
	return code, addr
end

local function tbl_append(tbl, new_tbl)
	for _,v in ipairs(new_tbl) do
		table.insert(tbl, v)
	end
	return tbl
end

-- Convert tokwnlist into H16 format text block
function vm16.Asm.generate_h16(lToken)
	local curr = {}
	local first = 0xFFFF
	local last  = 0
	local size = 0
	local nextaddr  -- next expected address (without gap)
	local curraddr  -- currently writing to

	local t = {}
	for _,tok in ipairs(lToken) do
		local ctype, lineno, address, opcodes = unpack(tok)
		if ctype == "code" then
			first = math.min(first, address)
			last = math.max(last, address + #opcodes)
			curraddr = curraddr or address  -- initial value

--			if ttype == asm.CODESYMSEC then
--				if not asm.tSymbols[code[2]] then
--					asm.err_msg(pos, "Invalid symbol: "..code[2])
--					return
--				end
--				code[2] = asm.tSymbols[code[2]]
--			end

			if nextaddr == address then
				-- append code
				tbl_append(curr, opcodes)
				curr, curraddr = add_h16lines(t, curraddr, curr)
			else
				-- start new line
				curr, curraddr = add_h16lines(t, curraddr, curr, true)
				tbl_append(curr, opcodes)
				nextaddr = address
				curraddr = address
			end

			-- next calculated addess
			nextaddr = nextaddr + #opcodes
			size = size + #opcodes
		else
			print("ctype", ctype)
		end
	end

	-- write the rest
	add_h16lines(t, curraddr, curr, true)

	last = last - 1
	local s = string.format(":2000001%04X%04X", first, last)
	table.insert(t, 1, s)
	table.insert(t, ":00000FF")
	return first, last, size, table.concat(t, "\n")
end


function vm16.Asm.listing(pos, lToken2, filename)
	filename = filename .. ".lst"
	asm.outp(pos, " - write " .. filename .. "...")

	local dump = function(tbl)
		local t = {}
		for _,e in ipairs(tbl) do
			if type(e) == "number" then
				table.insert(t, string.format("%04X", e))
			else
				table.insert(t, "'"..e.."'")
			end
		end
		return table.concat(t, " ")
	end

	local t = {asm.TITLE, ""}
	for _,tok in ipairs(lToken2) do
		if tok[5] then
			if tok[1] == 3 then
				table.insert(t, string.format('%3u  %04X  "%s"', tok[2], tok[3], tok[5]))
				table.insert(t, string.format("%s", dump(tok[4])))
			else
				table.insert(t, string.format("%3u  %04X  %-10s %s", tok[2], tok[3], dump(tok[4]), tok[5]))
			end
		elseif tok[1] == asm.FILENAME then
			table.insert(t, string.format("##### File: %s #####", tok[2]))
		else
			table.insert(t, string.format("##### End-of-file #####"))
		end
	end
	pdp13.write_file(pos, filename , table.concat(t, "\n"))
end
