if(LuaAV) then
	addmodulepath = LuaAV.addmodulepath
else
	---------------------------------------------------------------
	-- Bootstrapping functions required to coalesce paths
	local function exec(cmd, echo)
		echo = echo or true
		if(echo) then
			print(cmd)
			print("")
		end
		local res = io.popen(cmd):read("*a")
		return res:sub(1, res:len()-1)
	end
	
	local function stripfilename(filename)
		return string.match(filename, "(.+)/[^/]*%.%w+$")
	end
	
	local function strippath(filename)
		return string.match(filename, ".+/([^/]*%.%w+)$")
	end
	
	local function stripextension(filename)
		local idx = filename:match(".+()%.%w+$")
		if(idx) 
			then return filename:sub(1, idx-1)
			else return filename
		end
	end
	
	function addmodulepath(path)
		-- add to package paths (if not already present)
		if not string.find(package.path, path, 0, true) then
			package.path = string.format("%s/?.lua;%s", path, package.path)
			package.path = string.format("%s/?/init.lua;%s", path, package.path)
			package.cpath = string.format("%s/?.so;%s", path, package.cpath)
		end
	end
	
	local function setup_path()
	
		local pwd = exec("pwd")
		local root = arg[0]
		if(root and stripfilename(root)) then 
			root = stripfilename(root) .. "/"
		else 
			root = "" 
		end
		
		local script_path
		local path
	
		if(root:sub(1, 1) == "/") then
			script_path = root
			path = string.format("%s%s", root, "modules")
		else
			script_path = string.format("%s/%s", pwd, root)
			path = string.format("%s/%s%s", pwd, root, "modules")
		end
		return script_path:sub(1, script_path:len()-1)
	end
	---------------------------------------------------------------
	-- Script Initialization
	script = {}
	script.path = setup_path()
end

-- now the actual script
addmodulepath(script.path.."/..")


local format = string.format
local DSL = require"DSL"
local utils = require"DSL.utilities"
local nl = utils.nl
local printt = utils.printt
local WalkerAST = require"DSL.walker.AST"

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
		--object = T"{" * (entry * ( entry)^0)^-1  * Assert(T"}", "object.RIGHT_BRACE")
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
	token_event = utils.token_event,
	rule_event = utils.rule_event,
}

local code = [[
{
	"x" : [
		123, "A"
	],
	"y" : "AAAAAAAAAAAA"
}
]]

local ok, ast = pcall(parser.parse, parser, code)

local function printnode(node, depth)
	if(not node) then
		print(string.rep("  ", depth).."<null>")
	else
		if(node.rule) then
			print(string.rep("  ", depth)..format("Rule: %s %d", node.rule, #node))
		else
			print(string.rep("  ", depth)..format("Token: %s", node[1]))
		end
	end
end

print""
if(ok and ast) then
	printt(ast, "AST")
	print( parser:print(ast) )
	--[[
	local wast = WalkerAST{ ast=ast }
	wast:printloc()
	for i=1, 11 do
		wast:next()
		wast:printloc()
	end
	print""
	wast:printloc()
	for i=1, 11 do
		wast:prev()
		wast:printloc()
	end
	--]]
else
	print(ast)
	printt(parser.errors, "Errors")
end