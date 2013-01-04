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
	return v
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
-- OneToMany
local OneToMany = {}
OneToMany.__index = OneToMany
setmetatable(OneToMany, {
	__call = function(_, init)
		return setmetatable({mapping = {}}, OneToMany)
	end
})

function OneToMany:map(k, v)
	local list = self.mapping[k]
	if(not list) then
		list = {}
		self.mapping[k] = list
	end
	list[#list+1] = v
end
OneToMany.add = OneToMany.map

function OneToMany:mapmany(map, v)
	for k in pairs(map) do
		self:map(k, v)
	end
end

function OneToMany:index(k)
	return self.mapping[k]
end
OneToMany.get = OneToMany.index

function OneToMany:print()
	for name, list in pairs(self.mapping) do
		print(name, #list)
	end
end

function OneToMany:remove(k)
	self.mapping[k] = nil
end
----------------------------------------------
return {
	Stack = Stack,
	OneToMany = OneToMany,
}