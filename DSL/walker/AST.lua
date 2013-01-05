local format = string.format
local datastructures = require"DSL.datastructures"
local Stack = datastructures.Stack

local M = {}
M.__index = M

function M:notify(e)
	if(self.listener) then
		self.listener:event(e)
	end
end

function M:pop()
	self:notify"pop"
	self.nodestack:pop()
end

function M:push(node)
	self.nodestack:push(node)
	self:notify"push"
end

function M:prev()
	local node = self:current()
	if(node) then
		if(node.rule) then
			local idx = self.positions[node]
			if(idx <= 0) then
				self:pop()
				node = self:current()
				idx = self.positions[node]
				self.positions[node] = idx-1
			elseif(idx > 0) then
				local prevnode = node[idx]
				self:push(prevnode)
				if(prevnode.rule) 
					then self.positions[prevnode] = #prevnode
					else self.positions[prevnode] = 0
				end
			end
		else
			self:pop()
			node = self:current()
			idx = self.positions[node]
			self.positions[node] = idx-1
		end
	else
		self:push(self.ast)
		self.positions[self.ast] = #self.ast
	end
	self:notify"prev"
	return self:current()
end

function M:prev_will_push()
	local node = self:current()
	if(node) then
		if(node.rule) then
			local idx = self.positions[node]
			if(idx > 0) then
				return true
			end
		end
	else
		return true
	end
end

function M:next()
	local node = self:current()
	if(node) then
		if(node.rule) then
			local idx = self.positions[node]
			idx = idx+1
			self.positions[node] = idx
			
			if(idx > #node) then
				self:pop()
			else
				local nextnode = node[idx]
				self:push(nextnode)
				self.positions[nextnode] = 0
			end
		else
			self:pop()
		end
	end
	self:notify"next"
	return self:current()
end

function M:next_will_pop(onlyrule)
	local node = self:current()
	if(node) then
		if(node.rule) then
			local idx = self.positions[node]
			if(idx+1 > #node) then
				return true
			end
		else
			if(not onlyrule) then
				return true
			end
		end
	end
end

function M:rulename()
	local node = self:current()
	if(node) then
		return node.rule
	end
end

function M:tokenname()
	local node = self:current()
	if(node) then
		return node.token
	end
end

function M:nodestring(node)
	node = node or self:current()
	if(node) then
		if(node.rule)
			then return format("Rule: %s", node.rule)
			else return format("Token: %s:%s", node.token, node[1])
		end
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

function M:isrule()
	return self:rulename() ~= nil
end

function M:finished()
	local node = self:current()
	local idx = self.positions[node]
	return self:isrule() and idx == #node
end

function M:current()
	return self.nodestack:top()
end

function M:depth()
	return #self.nodestack
end

function M:register(o)
	self.listener = o
end

return setmetatable(M, {
	__call = function(_, init)
		assert(init.ast)
		local m = setmetatable(init, M)
		m.nodestack = Stack(m.ast)
		m.positions = {
			[m.ast] = 0
		}
		return m
	end
})