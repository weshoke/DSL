--[[
-- DSl.patterns
A collection of convenient LPEG patterns and pattern generating functions useful when writing DSLs.
--]]

local lpeg = require"lpeg"
local P, S, R = lpeg.P, lpeg.S, lpeg.R
local C, V = lpeg.C, lpeg.V
local Ct, Cg, Cc = lpeg.Ct, lpeg.Cg, lpeg.Cc
local Cp, Cmt = lpeg.Cp, lpeg.Cmt

local space = S" \t\r\n"
local whitespace = space^0
local nonzero = R"19"
local zero = P"0"
local digit = R"09"
local letter = R("az", "AZ")
local idchar = letter + P"_"
local integer = P"-"^-1 * (zero + nonzero*digit^0)
local fractional = digit^0
local scientific = S"eE" * S"-+"^-1 * fractional
local float = P"-"^-1 * (P"."*fractional + integer*P"."*fractional^-1*scientific^-1)
local string_escapes = P"\\\"" + P"\\\\" + P"\\b" + P"\\f" + P"\\n" + P"\\r" + P"\\t" + P"\\u"*digit*digit*digit*digit
local string = P[["]] * (string_escapes + (1-P[["]]))^0 * P[["]]

local function field(k, v)
	return Cg(Cc(v), k)
end

local function tag(patt, k, v)
	return patt*field(k, v)
end

local function position(name)
	return Cg(Cp(), name)
end

local function mark_position(patt, sname, ename)
	sname = sname or "startpos"
	ename = ename or "endpos"
	return position(sname) * patt * position(ename)
end

local function action(f)
	return P(f)
end

local function choice(list)
	local patt = P(list[1]) + P(list[2])
	for i=3, #list do
		patt = patt + P(list[i])
	end
	return patt
end

return {
	space = space,
	whitespace = whitespace,
	nonzero = nonzero,
	zero = zero,
	digit = digit,
	letter = letter,
	idchar = idchar,
	integer = integer,
	fractional = fractional,
	float = float,
	string_escapes = string_escapes,
	string = string,
	field = field,
	tag = tag,
	position = position,
	mark_position = mark_position,
	action = action,
	choice = choice,
}