LuaAV.addmodulepath(script.path.."/..")
LuaAV.addmodulepath(script.path.."/../../Lust")
local DSL = require"DSL"
local utils = require"DSL.utilities"
local Lust = require"Lust"

local dsl = DSL{
	tokens = [=[
		NUMBER = float+integer
		STRING = string
		TRUE = P"true"
		FALSE = P"false"
		NULL = P"null"
	]=],
	rules = [==[
		value = object + array + values
		entry = STRING * T":" * Assert(value, "entry.value")
		object = T"{" * (entry * (T"," * entry)^0)^-1  * Assert(T"}", "object.RIGHT_BRACE")
		array = T"[" * (value * (T"," * value)^0)^-1 * Assert(T"]", "array.RIGHT_BRACKET")
	]==],
	annotations = {
		-- value tokens
		NUMBER = { value=true },
		STRING = { value=true },
		TRUE = { value=true },
		FALSE = { value=true },
		NULL = { value=true },
		-- rule annotations
		value = { collapsable=true },
		values = { collapsable=true },
	},
}
local parser = dsl:parser{
	root = "object",
	mark_position = false,
	trace = true,
	--token_trace = true,
	--anonymous_token_trace = true,
	--token_event = utils.token_event,
	--rule_event = utils.rule_event,
}

local function nl(str) return string.gsub(str, [[\n]], "\n"):gsub([[\t]], "\t") end
local lust = Lust{
	[1] = "@dispatch",
	dispatch = [[@if(rule)<{{@(rule)}}>else<{{$1}}>]],
	object = nl[[
{
	@map{., _=",\n"}:dispatch
}]],
	array = '[@map{., _=", "}:dispatch]',
	entry = [[@1:dispatch : @2:dispatch]],
}

local code = [[
{
	"list" : [1, 2, 3],
	"vec3" : {
		"x": 1, "y": 0, "z": 0.5
	}
}
]]

local ok, ast = pcall(parser.parse, parser, code)
if(ok and ast) then
	--utils.printt(ast, "AST")
	print"Resynthesized code:"
	print"*******************"
	print(lust:gen(ast))
	print"*******************"
end