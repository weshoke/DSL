--[[
-- DSL.datastructures
Basic datastructures used in DSL
--]]
----------------------------------------------
-- Stack
local Stack = {}
Stack.__index = Stack
setmetatable(Stack, {
	__call = function(_, init)
		return setmetatable({init}, Stack)
	end
})

function Stack:push(v)
	self[#self+1] = v
end

function Stack:pop()
	local v = self[#self]
	self[#self] = nil
	return v
end

function Stack:set(v)
	self[#self] = v
end

function Stack:top()
	return self[#self]
end

function Stack:clear()
	local n = #self
	for i=n, 1, -1 do
		self[i] = nil
	end
end

----------------------------------------------
return {
	Stack = Stack
}