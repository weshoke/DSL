--[[
-- DSL.walker.Proxy
A cursor over the Proxy grammar rules of the Parser.  Proxy stitches together the network 
of rules, matching them with an AST using DSL.walker.AST and outputting the result in a 
codeast as created by DSL.walker.Code.  The resulting codeast can be used to synthesize 
a codestring.  Proxy naviages the rules defined in a Parser, extracting anonymous tokens and 
interleaving them with named tokens from an AST.
--]]
local WCode = require"DSL.walker.Code"

local datastructures = require"DSL.datastructures"
local Stack = datastructures.Stack
local OneToMany = datastructures.OneToMany

local DBG = false

local M = {}
M.__index = M

local function dbgprint(loc, str, ...)
	if(DBG) then
		local res = {...}
		for i=1, #res do
			res[i] = tostring(res[i])
		end
		local n = #loc
		local pad = string.rep(" ", 20-n) .. string.rep("  ", LEVEL)
		print(loc..pad..tostring(str).." "..table.concat(res, " "))
	end
end

-- v1 + v2
function M:add(proxy)
	local ok = self:dispatch(proxy[1])
	if(not ok) then
		ok = self:dispatch(proxy[2])
	end
	return ok
end

-- v1 * v2
function M:mul(proxy)
	local ok = self:dispatch(proxy[1])
	if(ok) then
		ok = self:dispatch(proxy[2])
	end
	return ok
end

-- v1 ^ N
function M:pow(proxy)
	local n = proxy[2]
	
	if(not self.wast:current() and n <= 0) then
		return true
	end
	
	if(n == -1) then
		local codeloc = self.wcode:loc()
		local ok = self:dispatch(proxy[1])
		if(not ok) then
			self.wcode:rewind(codeloc)
		end
		return true
	elseif(n == 0) then
		local loc = self.wast:loc()
		local codeloc = self.wcode:loc()
		local ok = self:dispatch(proxy[1])
		while(ok) do
			codeloc = self.wcode:loc()
			ok = self:dispatch(proxy[1])
		end
		if(not ok) then
			self.wcode:rewind(codeloc)
		end
		return true
	else
		error"TODO"
	end
end

function M:V(proxy)
	-- early bail
	if(self.wast:next_will_pop(true)) then
		return false
	end
	
	
	self.wast:next()
	
	local collapsed = false
	local res = false
	local name = proxy[1]
	if(self.parser:istoken(name)) then
		if(self.wast:isrule()) then
			error""
		elseif(name == self.wast:tokenname()) then
			local tok = self.wast:current()
			self:append_token(tok[1])
			res = true
		else
			res = false
		end
	else
		local newproxy = self.parser:def(name)
		local rulename = self.wast:rulename()
		if(name == rulename) then
			self.proxystack:push(newproxy)
			res = self:dispatch(newproxy)
			self.proxystack:pop()
		else
			-- try to collapse the node
			if(self.parser:property(name, "collapsable")) then
				collapsed = true
				self.wast:prev()
				
				self.proxystack:push(newproxy)
				res = self:dispatch(newproxy)
				self.proxystack:pop()
			else
				res = false
			end
		end
	end
	
	if(not collapsed) then
		if(not res) then
			if(not self.wast:prev_will_push()) then
				self.wast:prev()
			end
		elseif(res) then
			self.wast:next()
		end
	end
	return res
end

function M:Token(proxy)
	self:append_token(proxy[1])
	return true
end

function M:append_token(tok)
	self.wcode:child(tok)
end

function M:dispatch(proxy)
	local res
	if(type(proxy) == "table") 
		then res = self[proxy.op](self, proxy)
		else res = false
	end
	return res
end

function M:match(tokens)
	self:dispatch(self.proxy)
end

function M:current()
	return self.proxystack:top()
end

function M:depth()
	return #self.proxystack
end


return setmetatable(M, {
	__call = function(_, init)
		assert(init.wast)
		assert(init.parser)
		
		local proxy = init.parser:def(init.wast:rulename())
		local m = setmetatable(init, M)
		m.wcode = WCode{ wast=m.wast }
		
		m.proxy = proxy
		m.proxystack = Stack(m.proxy)
		m.tokens = OneToMany()
		m.tokenlist = {}
		m.positions = {
			[m.proxy] = 0
		}
		return m
	end
})