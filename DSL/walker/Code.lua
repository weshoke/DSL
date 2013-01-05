local format = string.format
local datastructures = require"DSL.datastructures"
local Stack = datastructures.Stack

local utils = require"DSL.utilities"
local printt = utils.printt

local lpeg = require"lpeg"
local P, S, R = lpeg.P, lpeg.S, lpeg.R
local C, V = lpeg.C, lpeg.V
local Ct, Cg, Cc = lpeg.Ct, lpeg.Cg, lpeg.Cc
local Cp, Cmt = lpeg.Cp, lpeg.Cmt
local Cb = lpeg.Cb

local patterns = require"dsl.patterns"
local space = patterns.space
local whitespace = patterns.whitespace
local integer = patterns.integer

local WTem = require"DSL.walker.Template"
local WFmt = require"DSL.walker.Format"

local M = {}
M.__index = M

local function codenode_name(codenode)
	return codenode.node.rule or codenode.node.token
end

function M:push(node)
	local codenode
	if(self:depth() == 0 and self.codeast) 
		then codenode = self.codeast
		else codenode = { node=node }
	end
	--print("->push:", codenode_name(codenode))
	self:child(codenode)
	self.nodestack:push(codenode)
end

function M:pop()
	local codenode = self:current()
	--print("<-pop:", codenode_name(codenode))
	self.nodestack:pop()
	if(#codenode == 0) then
		self:remove_child()
	end
end

function M:child(v)
	local codenode = self:current()
	if(codenode) then
		codenode[#codenode+1] = v
	end
end

function M:remove_child()
	local codenode = self:current()
	if(codenode) then
		codenode[#codenode] = nil
	end
end

function M:rewind(loc)
	local cloc = self:loc()
	assert(cloc.node == loc.node)
	for i=cloc.idx-1, loc.idx, -1 do
		self:remove_child()
	end
end

function M:event(e)
	if(e == "push") then
		self:push(self.wast:current())
	elseif(e == "pop") then
		self:pop()
	elseif(e == "next") then
	elseif(e == "prev") then
	end
end

function M:nodestring(codenode)
	codenode = codenode or self:current()
	if(codenode) 
		then return format("Codenode: %s", codenode_name(codenode))
		else return "<null>"
	end
end

function M:loc()
	local codenode = self:current()
	return {
		codenode = codenode,
		idx = #codenode,
	}
end

function M:locstring(loc)
	loc = loc or self:loc()

	local str = self:nodestring(loc.codenode)
	if(self:current()) 
		then return format("%s:%d", str, loc.idx)
		else return str
	end
end

function M:printloc()
	print(self:locstirng())
end

function M:current()
	return self.nodestack:top()
end

function M:depth()
	return #self.nodestack
end

local function indent(str, amt)
	return str:gsub("\n", "\n"..amt)
end

local function codeast_string(codeast, lvl, dbg)
	lvl = lvl or 0
	local res = {
		(codeast.node.rule or codeast.node.token)
	..": "}
	for i=1, #codeast do
		local v = codeast[i]
		if(type(v) == "table") then
			res[#res+1] = indent(codeast_string(v, lvl+1), "   ")
		else
			res[#res+1] = v
		end
	end
	return table.concat(res, "\n")
end

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
		if(not t.n) then
			return unpack(t)
		else
			return t
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

local codeast_format
local function synthesize(codeast, fmts)
	local fmt = fmts[codeast.node.rule]
	local ops = FMT:match(fmt)
	
	--print"****************************"
	--print(fmt)
	--printt(ops)

	local wfmt = WFmt{
		ops = ops,
		wtem = WTem{ codeast=codeast },
		cb = function(codeast)
			return codeast_format(codeast, fmts)
		end
	}
	return wfmt:write()
end

function codeast_format(codeast, fmts)
	if(fmts[codeast.node.rule]) then
		return synthesize(codeast, fmts)
	else
		local res = {}
		for i=1, #codeast do
			local v = codeast[i]
			if(type(v) == "table")
				then res[i] = codeast_format(v, fmts)
				else res[i] = v
			end
		end
		return table.concat(res, " ")
	end
end

function M:format(fmts)
	fmts = fmts or {}
	return codeast_format(self.codeast, fmts)
end

function M:__tostring()
	return codeast_string(self.codeast, nil)
end

return setmetatable(M, {
	__call = function(_, init)
		assert(init.wast)
		local m = setmetatable(init, M)
		m.nodestack = Stack()
		m:push(m.wast:current())
		m.wast:register(m)
		m.codeast = assert(m:current())
		m.nopop = false
		return m
	end
})