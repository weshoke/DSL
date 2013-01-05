local format = string.format
local datastructures = require"DSL.datastructures"
local Stack = datastructures.Stack

local patterns = require"dsl.patterns"
local whitespace = patterns.whitespace

local lpeg = require"lpeg"
local P, S, R = lpeg.P, lpeg.S, lpeg.R
local C, V = lpeg.C, lpeg.V
local Ct, Cg, Cc = lpeg.Ct, lpeg.Cg, lpeg.Cc
local Cp, Cmt = lpeg.Cp, lpeg.Cmt
local Cb = lpeg.Cb

local iswhitespace = whitespace * P(-1)

local DBG = false
local _print = print
local print = function(...)
	if(DBG) then _print(...) end
end

local M = {}
M.__index = M

function M:append(tok)
	self.tokens[#self.tokens+1] = tok:gsub("\n", "\n"..self.indent)
end

function M:rewind(idx)
	for i=#self.tokens, idx, -1 do
		self.tokens[i] = nil
	end
end

function M:loop()
	print"loop"
	local ops = self:current()
	local idx = self.positions[ops]
	
	idx = 1
	while(idx <= #ops) do
		self.positions[ops] = idx
		local ok = self:dispatch(ops[idx])
		if(not ok) then
			return false
		end
		idx = idx+1
	end
	return true
end

function M:rep(op)
	print("rep", op.n, #op)
	self.opstack:push(op)
	self.positions[op] = 0
	
	local ntok = #self.tokens
	local loc = self.wtem:loc()
	op.count = 0
	while(true) do
		-- loop
		local ok = self:loop()
		if(not ok) then
			break
		end
		ntok = #self.tokens
		loc = self.wtem:loc()

		op.count = op.count+1
		if(op.count > 3) then
			break
		end
	end
	
	self:rewind(ntok+1)
	self.wtem:rewind(loc)
	self.opstack:pop(op)
	print("end rep", op.n, op.count)
	return true
end

function M:sym(op)
	print("sym", self.wtem:current())
	local v = self.wtem:current()
	if(type(v) == "table")
		then self:append(self.cb(v)) --self.tokens[#self.tokens+1] = self.cb(v)
		else return false
	end	
	self.wtem:next()
	return true
end

function M:newline(op)
	print"newline"
	self.tokens[#self.tokens+1] = op
	
	local ops = self:current()
	local idx = self.positions[ops]
	local next_op = ops[idx+1]
	if(
		next_op and 
		type(next_op) == "string" and 
		iswhitespace:match(next_op)
	) then
		self.indent = next_op
	end
	return true
end

function M:whitespace(op)
	print"whitespace"
	--self.tokens[#self.tokens+1] = op
	self:append(op)
	return true
end

function M:tok(op)
	print("tok", op, self.wtem:current())
	local ops = self:current()
	
	local advance = false
	if(ops.n) then
		if(ops.n == 0) then
			if(op == self.wtem:current()) then
				advance = true
			end
		else
			error"XXX"
		end
	else
		--print(ops.n, op, self.wtem:current())
		assert(op == self.wtem:current())
		advance = true
	end
	
	if(advance) then
		--self.tokens[#self.tokens+1] = op
		self:append(op)
		self.wtem:next()
	end
	return advance
end

function M:dispatch(op)
	if(type(op) == "table") then
		return self:rep(op)
	elseif(op == "%s") then
		return self:sym(op)
	elseif(op == "\n" or op == "\r") then
		return self:newline(op)
	elseif(iswhitespace:match(op)) then
		return self:whitespace(op)
	else
		return self:tok(op)
	end
end

function M:write()
	local ok = self:loop()
	if(not ok) then
		error"XXXX"
	end
	return table.concat(self.tokens)
end


function M:nodestring(node)
	node = node or self:current()
	if(node) then
		return tostring(node)
	else
		return "<null>"
	end
end

function M:loc()
	return {
		node = self:current(),
		idx = self.positions[self:current()],
	}
end

function M:locstring(loc)
	loc = loc or self:loc()

	local str = self:nodestring(loc.node)
	if(self:current()) then
		return format("%s:%d", str, loc.idx or -1)
	else
		return str
	end
end

function M:printloc()
	print(self:locstirng())
end

function M:top()
	
end

function M:current()
	return self.opstack:top()
end

return setmetatable(M, {
	__call = function(_, init)
		assert(init.ops)
		assert(init.wtem)
		assert(init.cb)
		local m = setmetatable(init, M)
		m.opstack = Stack(init.ops)
		m.positions = {
			[init.ops] = 0
		}
		m.tokens = {}
		m.indent = ""
		return m
	end
})