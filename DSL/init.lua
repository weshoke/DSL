--[[
-- DSL
Top-level interface for DSL.  DSL maintains the basic information required to generate a Parser.
It will generate any necessary structure that isn't Parser-specific such as the expression operators 
if they exist.
--]]

local format = string.format
local patterns = require"DSL.patterns"
local Nodes = require"DSL.Nodes"
local Parser = require"DSL.Parser"

local utils = require"DSL.utilities"
local table_format = utils.table_format
local remap = utils.remap
local printt = utils.printt

local uid = (function()
	local id = 1
	return function(name)
		local res = id
		id = id+1
		return name..res
	end
end)()


local M = {}
M.__index = M
setmetatable(M, {
	__call = function(_, t)
		local m = setmetatable(t or {}, M)
		m.annotations = m.annotations or {}
		return m
	end
})

function M:opsym(optokens, sym)
	if(type(sym) == "table") then
		for i=1, #sym do
			self:opsym(optokens, sym[i])
		end
	else
		if(not optokens[sym]) then
			local tok = uid"OP"
			optokens[sym] = tok
			optokens[tok] = sym
			optokens[#optokens+1] = tok
		end
	end
end

function M:unop(child, op, optokens)
	--local opsym = table.concat(table_format(op, [[T"%s"]]), "+")
	local opsym = table.concat(remap(op, optokens), "+")
	--return format("%s = %s + (%s)*%s", op.name, child, opsym, op.name)
	return format("%s = (%s)*%s", op.name, opsym, "unops")
end

function M:binop(child, op, optokens)
	--local opsym = table.concat(table_format(op, [[T"%s"]]), "+")
	local opsym = table.concat(remap(op, optokens), "+")
	return format([[%s = %s*((%s)*Assert(%s, "%s"))^0]], op.name, child, opsym, child, op.name)
end

function M:ternop(child, op, optokens)
	if(#op > 1) then
		error"TODO"
	end
	
	local opsyms = remap(op, optokens)
	local branches = {}
	for i=1, #opsyms do
		local syms = opsyms[i]
		if(type(syms) == "table") then
			branches[#branches+1] = format([[%s*(%s*%s*%s*%s)^0]], 
				child, syms[1], op.name, syms[2], op.name
			)
		else
			branches[#branches+1] = format([[%s*(%s*%s*%s*%s)^0]], 
				child, syms, op.name, syms, op.name
			)
		end
	end
	return format("%s = %s", op.name, table.concat(branches, "+"))
end

function M:op(op, prevopname, optokens)
	self:opsym(optokens, op)

	if(op.rule) then
		if(not op.name) then
			error(string.format("op with rule %s missing name", op.rule))
		end
		return format("%s = %s + %s", op.name, op.rule, prevopname)
	else
		if(op.arity == 1) then
			return self:unop(prevopname, op, optokens)
		elseif(op.arity == 3) then
			return self:ternop(prevopname, op, optokens)
		else
			return self:binop(prevopname, op, optokens)
		end
	end
end

local function op_arity(op)
	return op.arity or 2
end

function M:create_ops(list)
	local op1 = list[1]
	local optokens = {}
	local rules = { self:op(op1, "values", optokens) }
	--self.annotations[op1.name] = { collapsable=true }
	for i=2, #list do
		local prevop = list[i-1]
		local op = list[i]
		rules[i] = self:op(op, prevop.name, optokens)
		--self.annotations[op.name] = { collapsable=true }
	end
	
	self.op_priority = {}
	local opsym_op_map = {}
	local unops = {}
	local optoken_rules = {}
	for i=#list, 1, -1 do
		local op = list[i]
		if(op_arity(op) == 1) then
			table.insert(unops, 1, op.name)
		elseif(op_arity(op) == 2) then
			self.op_priority[op.name] = i
			
			local branches = {}
			for j=1, #op do
				opsym_op_map[op[j]] = op.name
				branches[#branches+1] = string.format([[T"%s"]], optokens[op[j]])
			end
			optoken_rules[#optoken_rules+1] = string.format([[C(%s)*Cg(Cc("%s"), "name")]], table.concat(branches, "+"), op.name)
		elseif(op_arity(op) == 3) then
			self.op_priority[op.name] = i
			local branches = {}
			for j=1, #op do
				local syms = op[j]
				if(type(syms) == "table") then
					branches[#branches+1] = format([[C(T"%s")*__values^1*C(T"%s")]], 
						optokens[syms[1]], optokens[syms[2]]
					)
					branches[#branches+1] = format([[C(T"%s")*__values*C(T"%s")]], 
						optokens[syms[1]], optokens[syms[2]]
					)
				else
					branches[#branches+1] = format([[T"%s"*%s*T"%s"*%s]], 
						optokens[syms], "(unops*opsyms)", optokens[syms], "(unops*opsyms)"
					)
				end
			end
			optoken_rules[#optoken_rules+1] = string.format([[(%s)*Cg(Cc("%s"), "name")]], table.concat(branches, "+"), op.name)
		end
	end
	
	--print(table.concat(optoken_rules, "\n"))
	--error""
	--rules[#rules+1] = format("expression =  %s", list[#list].name)
	rules[#rules+1] = format("expression =  __values + %s", list[#list].name)
	--self.annotations.expression = { collapsable=true }
	
	local optokendefs = {}
	for i=1, #optokens do
		local name = optokens[i]
		optokendefs[i] = format([[%s = P"%s"]], name, optokens[name])
	end
	
	-- create opsym ordering
	local opsyms = {}
	for i=#optokens, 1, -1 do
		local name = optokens[i]
		local opname = opsym_op_map[name]
		if(opname) then
			opsyms[#opsyms+1] = string.format([[C(T"%s")*Cg(Cc("%s"), "name")]], 
				optokens[name], opname
			)
		end
	end
	
	self.optokens = table.concat(optokendefs, "\n")
	self.oprules = table.concat(rules, "\n")
	--self.oprules = string.format("%s\n%s", self.oprules, "opsyms = "..table.concat(opsyms, "+"))
	self.oprules = string.format("%s\n%s", self.oprules, "opsyms = "..table.concat(optoken_rules, "+"))
	self.oprules = string.format("%s\n%s", self.oprules, "unops = values + "..table.concat(unops, "+"))
	--print(self.optokens)
	--print(self.oprules)
	
	self.annotations.unops = { collapsable=true }
end

function M:parser(args)
	if(not self.oprules and self.ops) then
		self:create_ops(self.ops)
	end

	if(type(args) == "string") then
		args = { root=args }
	end
	args.dsl = self
	return Parser(args)
end

return M
