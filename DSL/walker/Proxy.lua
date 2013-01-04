local WCode = require"DSL.walker.Code"

local datastructures = require"DSL.datastructures"
local Stack = datastructures.Stack
local OneToMany = datastructures.OneToMany

local DBG = false

local M = {}
M.__index = M

local LEVEL = 0
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

function M:add(proxy)
	dbgprint(self.wast:locstring(), "add 1", proxy[1])
	local ok = self:dispatch(proxy[1])
	if(not ok) then
		dbgprint(self.wast:locstring(), "add 2", proxy[2])
		ok = self:dispatch(proxy[2])
	end
	return ok
end

function M:mul(proxy)
	dbgprint(self.wast:locstring(), "mul 1", proxy[1])
	local ok = self:dispatch(proxy[1])
	if(ok) then
		dbgprint(self.wast:locstring(), "mul 2", proxy[2])
		ok = self:dispatch(proxy[2])
	end
	return ok
end

function M:pow(proxy)
	dbgprint(self.wast:locstring(), "pow", proxy)
	local n = proxy[2]
	
	if(not self.wast:current() and n <= 0) then
		return true
	end
	
	if(n == -1) then
		local ok = self:dispatch(proxy[1])
		dbgprint(self.wast:locstring(), "POW:", ok)
		return true
	elseif(n == 0) then
		local loc = self.wast:loc()
		local TEST = self.wcode:loc()
		local ok = self:dispatch(proxy[1])
		dbgprint(self.wast:locstring(), "POW:", ok)
		if(not ok) then
			self:remove_tokens(loc)
			dbgprint(self.wast:locstring(), "POW "..tostring(proxy[1]), self.wast:locstring())
			--print("REMOVE:", TEST, self.wcode:locstring())
			self.wcode:rewind(TEST)
			--self.wast:next()
		end
		return true
	end
end

function M:V(proxy)
	local name = proxy[1]
	
	self.wast:next()
	dbgprint(self.wast:locstring(), proxy)
	if(self.wast:finished()) then
		return false
	end
	
	local collapsed = false
	local res = false
	if(self.parser:istoken(name)) then
		if(self.wast:isrule()) then
			error""
		elseif(name == self.wast:tokenname()) then
			local tok = self.wast:current()
			self:append_token(tok[1])
			dbgprint(self.wast:locstring(), "MATCH")
			res = true
		else
			dbgprint(self.wast:locstring(), "NO MATCH", name, self.wast:tokenname())
			res = false
		end
	else
		local newproxy = self.parser:def(name)
		local rulename = self.wast:rulename()
		if(name == rulename) then
			self.proxystack:push(newproxy)
			
			dbgprint(self.wast:locstring(), "Matched:", self.wast:nodestring())
			local ok = self:dispatch(newproxy)
			self.proxystack:pop()
			if(not ok) then
				dbgprint(self.wast:locstring(), "Didn't match:", name)
				error""
			else
				res = true
			end
		else
			dbgprint(self.wast:locstring(), "TryCollapse:", name, self.parser:property(name, "collapsable"))
			if(self.parser:property(name, "collapsable")) then
				dbgprint(self.wast:locstring(), "collapse")
				collapsed = true
				self.wast:prev()
				self.proxystack:push(newproxy)

				local ok = self:dispatch(newproxy)
				self.proxystack:pop()
				
				if(not ok) then
					res = false
				else
					res = true
				end
			else
				res = false
			end
		end
	end
	
	if(not collapsed) then
		if(not res) then
			dbgprint(self.wast:locstring(), "BACKUP rule", name)
			self.wast:prev()
		--elseif(not self.parser:istoken(name)) then
		elseif(res) then
			if(not self.parser:istoken(name)) then
				dbgprint(self.wast:locstring(), "FINISHED RULE:", proxy, self.parser:def(name))
			else
				dbgprint(self.wast:locstring(), "FINISHED TOKEN:", proxy, name)
			end
			self.wast:next()
		end
	end
--	print("XX", res, self.wast:nodestring())
	return res
end

function M:Token(proxy)
	dbgprint(self.wast:locstring(), "Token", proxy)
	self:append_token(proxy[1])
	return true
end

function M:remove_tokens(loc)
	local tok = self.tokenlist[#self.tokenlist]
	dbgprint(self.wast:locstring(), "REMOVE TOKENS:", self.wast:locstring(loc))
	while(tok.node ~= loc.node and tok.idx ~= loc.idx) do
		self.tokenlist[#self.tokenlist] = nil
		tok = self.tokenlist[#self.tokenlist]
	end
end

function M:append_token(tok)
	local loc = self.wast:loc()
	loc.token = tok
	self.tokenlist[#self.tokenlist+1] = loc
	self.tokens:map(self.wast:locstring(), tok)
	
	self.wcode:child(tok)
end

function M:dispatch(proxy)
	LEVEL = LEVEL+1
	local res
	if(type(proxy) == "table") 
		then res = self[proxy.op](self, proxy)
		else res = false
	end
	LEVEL = LEVEL-1
	return res
end

function M:match(tokens)
	LEVEL = 0
	dbgprint(self.wast:locstring(), "AST:", self.proxy)
	--self.wast:next()
	self:dispatch(self.proxy)
	
	local res = {}
	for i=1, #self.tokenlist do
		res[i] = self.tokenlist[i].token
	end
	return table.concat(res, " ")
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