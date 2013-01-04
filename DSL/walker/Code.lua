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
	self:child(codenode)
	self.nodestack:push(codenode)
end

function M:pop()
	local codenode = self:current()
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

local SYM = C(P"%s")
local SEP = C(whitespace)
local TOK = C((1-space-V"SYM"-P"_)" - P"_(")^1)
local group = P"_(" * V"SEP" * V"val" * (V"SEP" * V"val")^0 * P"_)"
local val = V"group" + V"SYM" + V"TOK"
local rep = Ct(V"val" * P"^" * Cg(C(integer)/tonumber, "n"))
local fmt = Ct(V"SEP" * ((V"rep" + V"val") * V"SEP")^1 * V"SEP")

local FMT = P{
	[1] = "fmt",
	fmt = fmt,
	rep = rep,
	val = val,
	group = group,
	text = text,
	TOK = TOK,
	SEP = SEP,
	SYM = SYM,
}*P(-1)

local codeast_format

local iswhitespace = whitespace * P(-1)

local fmt_ops
local function dispatch(codeast, fmts, patt, i, j, res)
	local v = patt[j]
	if(type(v) == "table") then
		return fmt_ops.rep(codeast, fmts, patt, i, j, res)
	elseif(v == "%s") then
		return fmt_ops.sym(codeast, fmts, patt, i, j, res)
	elseif(iswhitespace:match(v)) then
		return fmt_ops.whitespace(codeast, fmts, patt, i, j, res)
	else
		return fmt_ops.tok(codeast, fmts, patt, i, j, res)
	end
end

local function iter(codeast, fmts, patt, i, j, res)
	local k=1
	--print("iter", codeast[i], i, j)
	
	while(i <= #codeast and j <= #patt) do
		local done
		i, j, done = dispatch(codeast, fmts, patt, i, j, res)
		if(done) then
			break
		end
		k=k+1
		if(k > 10) then
			error"kkk"
		end
	end
	--print("end iter", i, j)
	return i, j
end

fmt_ops = {
	rep = function(codeast, fmts, patt, i, j, res)
		--print"rep"
		local v = patt[j]
		v.count = 0
		local bail = 0
		if(v.n >= 0) then
			local previ = i
			while(true) do
				i = iter(codeast, fmts, v, i, 1, res)
				if(i == previ) then
					break
				end
				--print("rep:", previ, i)
				previ = i
				bail = bail+1
				if(bail > 10) then
					error"bail"
				end
				v.count = v.count +1		
			end
		elseif(v.n < 0) then
			local previ = i
			for k=1, math.abs(v.n) do
				i = iter(codeast, fmts, v[j], i, 1, res)
				if(i == previ) then
					break
				end
				bail = bail+1
				if(bail > 10) then
					error"bail"
				end
				v.count = v.count +1		
			end
		end
		
		--print("DONE REP", i, j, #codeast, codeast[2])
		j = j+1
		return i, j
	end,
	sym = function(codeast, fmts, patt, i, j, res)
		
		if(type(codeast[i]) == "table")
			then res[#res+1] = codeast_format(codeast[i], fmts)
			else res[#res+1] = codeast[i]
		end
		--print("sym", res[#res])
		i = i+1
		j = j+1
		return i, j
	end,
	whitespace = function(codeast, fmts, patt, i, j, res)
		--print"whitespace"
		res[#res+1] = patt[j]
		j = j+1
		return i, j
	end,
	tok = function(codeast, fmts, patt, i, j, res)
		local v = patt[j]
		
		--print("tok", codeast[i], v, v.n, patt.n)

		local doassert = true
		if(patt.n) then
			if(patt.n == 0) then
				doassert = false
			elseif(patt.n > 0 and patt.count >= patt.n) then
				doassert = false
			end
		end
		
		if(doassert) then
			assert(codeast[i] == v)
		elseif(codeast[i] ~= v) then
			return i, j+1, true
		end
		res[#res+1] = v
		i = i+1
		j = j+1
		return i, j
	end,
}

local function synthesize(codeast, fmts)
	local fmt = fmts[codeast.node.rule]
	local patt = FMT:match(fmt)
	--printt(patt)
	local res = {}
	local i, j = iter(codeast, fmts, patt, 1, 1, res)
	while(j < #patt) do
		local v = patt[j]
		assert(iswhitespace:match(v))
		res[#res+1] = v
		j = j+1
	end
	return table.concat(res)
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
	
	fmts.array = "[%s_(, %s_)^0]"
	
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