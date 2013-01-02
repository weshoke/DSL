--[[
-- DSl.Nodes
Simple representation of AST node types: Token and Rule.  These structures have no functionality and are simply 
here as convenient holders of information.
--]]

local format = string.format
local NONAME = "<anonymous>"

------------------------------------------------
-- AST Nodes
local Token, Rule

local function class(self)
	return self.__class
end

local function NodeClass(classname)
	local nodeclass = { __class=classname }
	nodeclass.class = class
	nodeclass.__index = nodeclass
	
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
------------------------------------------------

return {
	Token = Token,
	Rule = Rule,
}