--[[
-- DSl.proxies
A set of proxies for LPEG functionality.  The proxies are needed so that transformations can be applied
to the input DSL token and rule patterns.  Without the proxies, there would be no way to automatically insert 
whitespace between tokens, etc.
--]]

local format = string.format
local lpeg = require"lpeg"

local Proxy
local function nilop(op)
	return function()
		return Proxy{ op=op }
	end
end

local function unop(op)
	return function(v)
		return Proxy{ op=op, v }
	end
end

local function binop(op)
	return function(v1, v2)
		return Proxy{ op=op, v1, v2 }
	end
end

local function varop(op)
	return function(...)
		return Proxy{op=op, ...}
	end
end

Proxy = setmetatable({}, {
	__call = function(meta, t)
		return setmetatable(t or {}, meta)
	end
})
local binops = {
	add="+", sub="-", div="/", mul="*", pow="^"
}
local priority = {
	add=2, sub=2, div=1, mul=1, pow=0
}

function Proxy:__tostring()
	if(#self == 1 and type(self[1]) == "string") then
		return format([[%s"%s"]], self.op or "<no-op>", self[1])
	elseif(self.op == "Rule" or self.op == "Token") then
		local name
		if(type(self[1]) == "table") 
			then name = self[1].name
			else name = self[1]
		end
		return format([[%s"%s"]], self.op, name)
	else
		local res = {}
		local oppriority = priority[self.op]
		for i=1, #self do
			if(type(self[i]) == "string") then
				res[i] = format('"%s"', self[i])
			elseif(
				type(self[i]) == "table" and self[i].class and 
				self[i]:class() == "Proxy"
			) then
				res[i] = tostring(self[i])
				if(
					oppriority and priority[self[i].op] and 
					oppriority < priority[self[i].op]
				) then
					res[i] = format("(%s)", res[i])
				end
			else
				res[i] = tostring(self[i])
			end
		end
		if(binops[self.op]) then
			--return table.concat(res, " "..binops[self.op].." ")
			return table.concat(res, binops[self.op])
		else
			return format("%s(%s)", self.op or "<no-op>", table.concat(res, ", "))
		end
	end
end

Proxy.__class = "Proxy"
Proxy.__index = Proxy
Proxy.__add = binop"add"
Proxy.__sub = binop"sub"
Proxy.__mul = binop"mul"
Proxy.__div = binop"div"
Proxy.__pow = binop"pow"
Proxy.__unm = unop"unm"

function Proxy:class()
	return self.__class
end


local opcodes = {
	P = lpeg.P,
	S = lpeg.S,
	R = lpeg.R,
	V = lpeg.V,
	C = lpeg.C,
	Carg = lpeg.Carg,
	Cb = lpeg.Cb,
	Cc = lpeg.Cc,
	Cf = lpeg.Cf,
	Cg = lpeg.Cg,
	Cp = lpeg.Cp,
	Cs = lpeg.Cs,
	Cmt = lpeg.Cmt,
	unm = function(v1) return -v end,
	add = function(v1, v2) return v1+v2 end,
	sub = function(v1, v2) return v1-v2 end,
	mul = function(v1, v2) return v1*v2 end,
	div = function(v1, v2) return v1/v2 end,
	pow = function(v1, v2) return v1^v2 end,
	Ignore = function(v) return #v end,
}

function Proxy:eval(handlers)
	local args = {}
	for i=1, #self do
		if(
			type(self[i]) == "table" and self[i].class and 
			self[i]:class() == "Proxy"
		) 
			then args[i] = self[i]:eval(handlers)
			else args[i] = self[i]
		end
	end
	if(handlers and handlers[self.op])
		then return handlers[self.op](unpack(args))
		else return opcodes[self.op](unpack(args))
	end
end

local Token = unop"Token"
return {
	P = unop"P",
	S = unop"S",
	R = varop"R",
	V = unop"V",
	C = unop"C",
	Carg = unop"Carg",
	Cb = unop"Cb",
	Cc = unop"Cc",
	Cf = binop"Cf",
	Cg = varop"Cg",
	Cp = nilop"Cp",
	Cs = unop"Cs",
	Ct = unop"Ct",
	Cmt = binop"Cmt",
	Ignore = unop"#",
	Comment = unop"Comment",
	Token = Token,
	T = Token,
	Rule = unop"Rule",
}