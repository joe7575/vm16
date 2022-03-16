--[[
	vm16
	====

	Copyright (C) 2019-2022 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information

	Compiler
]]--

vm16.comp = {}

function vm16.comp.compile(mem, code)
	local result = vm16.BCompiler(code, false)
	mem.lToken = result.output
	mem.tGlobals = result.globals
	mem.tLocals = result.locals
	mem.tFunctions = result.functions
	return result, result.errors
end

