local format = string.format
--[[
local lpeg = require"DSL.proxies"
local P, S, R = lpeg.P, lpeg.S, lpeg.R
local C, V = lpeg.C, lpeg.V
local Ct, Cg, Cc = lpeg.Ct, lpeg.Cg, lpeg.Cc
local Cmt = lpeg.Cmt
local patterns = require"DSL.patterns"
local field = patterns.field
local action = patterns.action
--]]

local NONAME = "<anonymous>"

------------------------------------------------
-- AST Nodes
local Token, Rule

local function class(self)
	return self.__class
end

local function __add(v1, v2)
	--[[
	if(type(v2) == "function") then
		if(not v1:named()) then
			return Rule{ patt=v1.patt+P(v2) }
		else
			return Rule{ patt=V(v1.name)+P(v2) }
		end
	else
		return Rule{ patt=V(v1.name)+V(v2.name) }
	end
	--]]
end
local function __mul(v1, v2)
	--[[
	if(type(v2) == "userdata") then
		if(not v1:named()) 
			then return Rule{ patt=v1.patt*whitespace*v2 }
			else return Rule{ patt=V(v1.name)*whitespace*v2 }
		end
	else
		if(not v1:named() and not v2:named()) then
			return Rule{ patt=v1.patt*whitespace*v2.patt }
		elseif(not v1:named()) then
			return Rule{ patt=v1.patt*whitespace*V(v2.name) }
		elseif(not v2:named()) then
			return Rule{ patt=V(v1.name)*whitespace*v2.patt }
		else
			return Rule{ patt=V(v1.name)*whitespace*V(v2.name) }
		end
	end
	--]]
end
local function __pow(v1, v2)
	--[[
	if(not v1:named()) 
		then return Rule{ patt=(v1.patt * whitespace)^v2 }
		else return Rule{ patt=(V(v1.name) * whitespace)^v2 }
	end
	--]]
end

local function NodeClass(classname)
	local nodeclass = { __class=classname }
	nodeclass.class = class
	nodeclass.__index = nodeclass
	nodeclass.__add = __add
	nodeclass.__mul = __mul
	nodeclass.__pow = __pow
	
	local fmt = classname..": %s"
	nodeclass.__tostring = function(self)
		return format(fmt, self.name)
	end
	
	return nodeclass
end

------------------------------------------------
-- Token
Token = NodeClass"Token"
setmetatable(Token, {
	__call = function(_, t)
		t.name = t.name or NONAME
		return setmetatable(t, Token)
	end
})
function Token:named() 
	return self.name ~= NONAME
end

function Token:makerule()
	local t = {}
	for k, v in pairs(self) do
		t[k] = v
	end
	t.name = nil
	return Rule(t)
end
------------------------------------------------

------------------------------------------------
-- Rule
Rule = NodeClass"Rule"
setmetatable(Rule, {
	__call = function(_, t)
		if(type(t.patt) ~= "userdata") then
			t.patt = t.patt.patt
		end
	
		t.name = t.name or NONAME
		return setmetatable(t, Rule)
	end
})
function Rule:named()
	return self.name ~= NONAME
end

function Rule:copy()
	local t = {}
	for k, v in pairs(self) do
		t[k] = v
	end
	return Rule(t)
end

function Rule:finish(parser)
	local start_action = function(s, i)
		parser:startrule(self.name, i)
		return i
	end
	local match_action = function(s, i)
		parser:matchrule(self.name, i)
		return i
	end
	local end_action = function(s, i)
		parser:endrule(self.name, i)
	end

	if(self.collapsable) then
		self.patt = Cmt(self.patt, function(s, i, ...)
			local n = select('#', ...)
			if(n == 1) then
				return i, select(1, ...)
			else
				local args = {...}
				args.rule = self.name
				return i, args
			end
		end)
	else
		self.patt = Ct(self.patt * field("rule", self.name))
	end
	
	if(parser and parser.trace) then
		self.patt = action(start_action) * self.patt * action(match_action) + action(end_action)
	end
end
------------------------------------------------

return {
	Token = Token,
	Rule = Rule,
}