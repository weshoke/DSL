local format = string.format
local datastructures = require"DSL.datastructures"
local Stack = datastructures.Stack

local M = {}
M.__index = M

function M:prev()
	self.idx = self.idx-1
	return self:current()
end

function M:next()
	self.idx = self.idx+1
	return self:current()
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
	return self.idx
end

function M:rewind(loc)
	self.idx = loc
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

function M:current()
	return self.codeast[self.idx]
end

function M:depth()
	return #self.nodestack
end

return setmetatable(M, {
	__call = function(_, init)
		assert(init.codeast)
		local m = setmetatable(init, M)
		m.idx = 1
		m.nodelist = {}
		return m
	end
})