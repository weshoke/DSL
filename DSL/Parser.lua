--[[
-- DSl.Parser
The workhorse object of DSL.  The Parser generates a parser from LPEG based on the definitions given to its 
parent DSL object.  Parser will annotate the basic patterns provided with extra structure according to the options 
provided to the DSL object, which can be used to generate events during parsing and add extra information to the 
resulting AST nodes.
--]]

local format = string.format

local Nodes = require"DSL.Nodes"

local peg = require"listlpeg"

local lpeg = require"DSL.proxies"
local P, S, R = lpeg.P, lpeg.S, lpeg.R
local C, V = lpeg.C, lpeg.V
local Ct, Cg, Cc = lpeg.Ct, lpeg.Cg, lpeg.Cc
local Cp, Cmt = lpeg.Cp, lpeg.Cmt
local T = lpeg.T
local Rule = lpeg.Rule

local patterns = require"DSL.patterns"
local space = patterns.space
local whitespace = patterns.whitespace
local field = patterns.field
local tag = patterns.tag
local position = patterns.position
local mark_position = patterns.mark_position
local action = patterns.action
local choice = patterns.choice

local datastructures = require"DSL.datastructures"
local Stack = datastructures.Stack

local utils = require"DSL.utilities"
local  table_derive = utils.table_derive
local table_format = utils.table_format
local keys = utils.keys
local optbool = utils.optbool
local linecol = utils.linecol


local M = {}
M.__index = M
setmetatable(M, {
	__call = function(_, t)
		assert(t.dsl)
		assert(t.root)
		t.mark_position = optbool(t.mark_position, true)
		t.trace = optbool(t.trace, false)
		t.errors = Stack()
		t.rulestack = Stack()
		return setmetatable(t, M)
	end
})

-- Evaluate the Token strings into LPEG patterns
local token_env = table_derive({P=P, S=S, R=R, C=C}, patterns)
token_env.__index = token_env
function M:eval_tokens(code)
	local env = setmetatable({}, token_env)
	setfenv(loadstring(code), env)()
	for name, patt in pairs(env) do
		env[name] = T{
			name = name,
			patt = patt,
		}
	end
	return env
end

-- Evaluate the Rule strings into LPEG patterns
local rule_env = table_derive({
	P=P, S=S, R=R, C=C, T=T, Token=T,
}, patterns)
function M:eval_rules(code)
	local env_meta
	env_meta = {
		Assert = function(...)
			return self:err(...)
		end,
		__newindex = function(t, k, v)
			self.rules[k] = Rule{
				name = k,
				patt = v,
			}
		end,
		__index = function(t, k)
			return env_meta[k] or V(k)
		end,
	}

	local env = setmetatable({}, table_derive(env_meta, rule_env))
	setfenv(loadstring(code), env)()
end

local comment_env =  table_derive({
	P=P, S=S, R=R, C=C
}, patterns)
comment_env.__index = comment_env
function M:eval_comments(code)
	local env = setmetatable({}, comment_env)
	setfenv(loadstring(code), env)()
	return env
end

function M:err(patt, ctx)
	return patt + function(s, i)
		self.errors:push{
			ctx = ctx,
			pos = i,
		}
		local line, col = linecol(s, i)
		error(format("parsing error: %s at %d:%d", ctx, line, col))
		return false
	end
end

function M:create_tokens(code)
	self.tokens = self:eval_tokens(code)
end

function M:create_rules(code)
	self:eval_rules(code)
end

function M:create_comments(code)
	if(code) then
		self.comments = self:eval_comments(code)
	end
end

function M:create_grammar(ignore)
	local grammar = {}
	for name, rule in pairs(self.rules) do
		assert(name == rule.name)
		grammar[name] = rule.patt
	end
	for name, tok in pairs(self.tokens) do
		grammar[tok.name] = tok.patt
	end
	grammar[1] = self.root
	self.patt = ignore * peg.P(grammar) * ignore * peg.P(-1)
end

function M:eval()
	local dsl = self.dsl
	self:create_tokens(dsl.tokens.."\n"..(dsl.optokens or ""))
	
	self.rules = {}
	self:create_rules(format("terminals = %s", table.concat(keys(self.tokens), "+")))
	dsl.annotations.terminals = { collapsable=true }
	self:create_rules(dsl.rules)
	if(dsl.oprules) then
		self:create_rules(dsl.oprules)
	end
	self:create_comments(dsl.comments)

	for k, v in pairs(self.tokens) do
		self.tokens[k] = v:eval{
			Token = function(v)
				if(type(v.patt) ~= "userdata") then
					v.patt = v.patt:eval()
				end
				local tok = Nodes.Token(v)
				
				local patt = tok.patt
				-- set the token field of the AST node
				patt = tag(peg.C(patt), "token", k)
				if(self.mark_position) then
					-- capture starting and ending position of token
					patt = mark_position(patt)
				end
				-- create the AST node
				patt = peg.Ct(patt)
				
				if(self.trace) then
					-- generate a callback when the token is matched
					patt = patt * action(function(s, i)
						self:matchtoken(k, i)
						return i
					end)
				end
				if(self.token_trace) then
					patt = action(function(s, i)
						self:trytoken(k, i)
						return i
					end) * patt
				end
				tok.patt = patt
				
				return tok
			end,
		}
	end
	
	local ignore = whitespace
	if(self.comments) then
		ignore = space
		for k, v in pairs(self.comments) do
			local try_action = function(s, i)
				self:trycomment(i)
				return i
			end
			local match_action = function(s, i, comment)
				self:matchcomment(i, comment)
				return i
			end
			
			local patt = peg.Cmt(peg.C(v:eval()), match_action)
			if(self.commenttrace) then
				patt = action(try_action) * patt
			end
			ignore = ignore + patt
		end
		ignore = ignore^0
	end
	
	local handlers
	handlers = {
		Token = function(v)
			-- anonymous tokens
			local patt = peg.P(v)
			if(self.anonymous_token_trace) then
				patt = action(function(s, i)
					self:trytoken('"'..v..'"', i)
					return i
				end) * patt * action(function(s, i)
					self:matchtoken('"'..v..'"', i)
					return i
				end)
			end
			return patt
		end,
	
		Rule = function(v)
			local patt = v.patt:eval(handlers)
			if(self.dsl.annotations[v.name]) then
				table_derive(v, self.dsl.annotations[v.name])
			end
			
			if(v.collapsable) then
				patt = peg.Cmt(patt, function(s, i, ...)
					local n = select('#', ...)
					if(n == 1) then
						local v = select(1, ...)
						if(type(v) == "table") 
							then return i, v
							else return i
						end
					else
						local args = {...}
						args.rule = v.name
						return i, args
					end
				end)
			else
				patt = peg.Ct(tag(patt, "rule", v.name))
			end
			
			if(self.trace) then
				local start_action = function(s, i)
					self:startrule(v.name, i)
					return i
				end
				local match_action = function(s, i)
					self:matchrule(v.name, i)
					return i
				end
				local end_action = function(s, i)
					self:endrule(v.name, i)
				end
				patt = action(start_action) * patt * action(match_action) + action(end_action)
			end
			
			v.patt = patt

			return Nodes.Rule(v)
		end,
		mul = function(v1, v2)
			return v1 * ignore * v2
		end,
		pow = function(v1, v2)
			return (v1 * ignore)^v2
		end
	}
	
	for k, v in pairs(self.rules) do
		self.rules[k] = v:eval(handlers)
	end

	self:create_grammar(ignore)
end

---------------------------
-- Parsing Events
function M:trycomment(i)
	if(self.comment_event) then
		self:comment_event("try", i)
	end
end

function M:matchcomment(i, comment)
	if(self.comment_event) then
		self:comment_event("match", i, comment)
	end
end

function M:trytoken(name, i)
	if(self.token_event) then
		self:token_event("try", name, i)
	end
end

function M:matchtoken(name, i)
	if(self.token_event) then
		self:token_event("match", name, i)
	end
end

function M:startrule(name, i)
	self.rulestack:push(name)
	if(self.rule_event) then
		self:rule_event("start", name, i)
	end
end

function M:matchrule(name, i)
	if(self.rule_event) then
		self:rule_event("match", name, i)
	end
	self.rulestack:pop()
end

function M:endrule(name, i)
	if(self.rule_event) then
		self:rule_event("end", name, i)
	end
	self.rulestack:pop()
end

function M:parse(code)
	if(not self.patt) then
		self:eval()
	end
	self.rulestack:clear()
	return self.patt:match(code)
end

return M