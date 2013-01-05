--[[
-- DSL.walker.Code
The code walker reconstructs AST nodes into their full syntactical representation.  In mirrors the AST tree with each tree node storing an AST tree node along with the list of child nodes and tokens (including anonymous tokens) written into it.

The format method synthesizes final code output once all of the AST tokens have been inserted.
--]]

local format = string.format
local datastructures = require"DSL.datastructures"
local Stack = datastructures.Stack

local utils = require"DSL.utilities"
local printt = utils.printt

local template = require"DSL.template"

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

-- events from DSL.walker.AST
function M:event(e)
	if(e == "push") then
		self:push(self.wast:current())
	elseif(e == "pop") then
		self:pop()
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

local codeast_format
local function synthesize(codeast, fmts)
	local fmt = fmts[codeast.node.rule]
	local ops = template.parse(fmt)
	
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