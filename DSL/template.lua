local lpeg = require"lpeg"
local P, S, R = lpeg.P, lpeg.S, lpeg.R
local C, V = lpeg.C, lpeg.V
local Ct, Cg, Cc = lpeg.Ct, lpeg.Cg, lpeg.Cc
local Cp, Cmt = lpeg.Cp, lpeg.Cmt
local Cb = lpeg.Cb

local patterns = require"dsl.patterns"
local integer = patterns.integer

local N = Cg(C(integer)/tonumber, "n")
local SYM = C(P"%s")
local space = P" \t"
local NL = C("\n\r")
local SEP = C(space^0) / function(v)
	if(#v > 0) then
		return v
	end
end
local SPACE = NL^1 + SEP
local TOK = (
	P"%" * C(S"()") +
	C((1-space-V"SYM" - P")" - P"("))
)^1

local values = V"SYM" + V"TOK"
local item = V"SPACE" * V"values"
local primary = V"item" + P"(" * V"SPACE" * V"sequence" * V"SPACE" * P")"
local rep = Ct(V"primary" * (P"^" * V"N")^0) / function(t)
	if(#t == 1) then
		return t[1]
	else 
		if(not t.n) 
			then return unpack(t)
			else return t
		end
	end
end
local sequence = (V"rep" * V"SPACE")^1
local fmt = V"SPACE" * V"sequence" * V"SPACE"
local unit = Ct(V"fmt")

local FMT = P{
	[1] = "unit",
	unit = unit,
	fmt = fmt,
	sequence = sequence,
	fmt = fmt,
	rep = rep,
	primary = primary,
	item = item,
	values = values,
	TOK = TOK,
	SPACE = SPACE,
	SEP = SEP,
	NL = NL,
	SYM = SYM,
	N = N,
}*P(-1)

local function parse(tem)
	return FMT:match(tem)
end

return {
	parse = parse,
}