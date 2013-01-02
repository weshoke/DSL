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


--[[
TODO:
	- fast lookahead to terminals
	- customized terminals or expression
	- integrating annotations into syntax?
	- AST -> string
--]]

local format = string.format
local DSL = require"DSL"
local utils = require"DSL.utilities"
local printt = utils.printt
local nl = utils.nl

local dsl = DSL{
	tokens = [=[
		IDENTIFIER = idchar * (idchar+digit)^0 - keywords
		NUMBER = float+integer
		BREAK = P"break"
		CONTINUE = P"continue"
		RETURN = P"return"
		EQ = P"="
		PLUS_EQ = P"+="
	]=],
	ops = {
		{name="index_op", rule="index"},
		{name="function_call_op", rule="function_call"},
		{name="unary_op", arity=1, "!", "-"},
		{name="multiplicative_op", "*", "/", "%"},
		{name="additive_op", "+", "-"},
		{name="relational_op", "<", "<=", ">", ">="},
		{name="equality_op", "==", "!="},
		{name="logical_and_op", "&&"},
		{name="logical_or_op", "||"},
		{name="conditional_op", arity=3, {"?", ":"}},
	},
	rules = [==[
		index = IDENTIFIER * T"." * Assert(IDENTIFIER, "index.IDENTIFIER")
		function_call = IDENTIFIER * args

		assignment_operator = EQ + PLUS_EQ
		assignment_expression = IDENTIFIER * assignment_operator * 
			Assert(expression, "expression_statement.expression")
			
		expression_statement =  assignment_expression * Assert(T";", "expression_statement.SEMICOLON")
		argument_list = expression * (T"," * expression)^0
		args = T"(" * argument_list^-1 * Assert(T")", "args.RIGHT_PAREN")
		declaration = IDENTIFIER * IDENTIFIER * args^-1
		
		declaration_statement = declaration * Assert(T";", "declaration_statement.SEMICOLON")
		condition = T"(" * expression * Assert(T")", "condition.RIGHT_PAREN")
		selection_statement = T"if" * condition * statement * (T"else" * statement)^-1
		while_statement = T"while" * condition * statement
		loop_condition = expression * Assert(T";", "loop_condition.SEMICOLON")

		for_statement = T"for" * T"(" * 
			expression_statement * 
			loop_condition * 
			assignment_expression * 
			Assert(T")", "for_statement.RIGHT_PAREN")
			
		iteration_statement = while_statement + for_statement
		jump_statement = (BREAK + CONTINUE + RETURN * expression) * Assert(T";", "jump_statement.SEMICOLON")
		statement = 
			compound_statement + 
			selection_statement + 
			iteration_statement + 
			jump_statement + 
			function_definition + 
			declaration_statement + 
			expression_statement
		statement_list = statement^0
		compound_statement = T"{" * statement_list * T"}"
		
		function_definition = IDENTIFIER * args * compound_statement
	]==],
	comments = nl[=[
		singleline_comment = P"//" * (1-P[[\n]])^0
		multiline_comment = P"/*" * (1-P"*/")^0 * P"*/"
	]=],
	annotations = {
		-- value tokens
		NUMBER = { value=true },
		IDENTIFIER = { value=true },
		-- keyword tokens
		BREAK = { keyword=true },
		CONTINUE = { keyword=true },
		RETURN = { keyword=true },
		-- rule annotations
		args = { collapsable=true },
		assignment_operator = { collapsable=true },
		expression_statement = { collapsable=true },
		statement = { collapsable=true },
		condition = { collapsable=true },
		iteration_statement = { collapsable=true },
		compound_statement = { collapsable=true },
	}
}
local parser = dsl:parser{
	root = "statement_list",
	--root = "selection_statement",
	--root = "declaration",
	--root = "statement",
	--root = "expression_statement",
	mark_position = false,
	trace = true,
	--token_trace = true,
	--anonymous_token_trace = true,
	--commenttrace = false,
	comment_event = function(parser, e, idx, comment)
		print("COMMENT:", e, idx, comment)
	end,
	token_event = utils.token_event,
	rule_event = utils.rule_event,
}

local code = [[
Param z;
x = 10;
y = x;
]]
local code = [[
xx(x) { return x; }
x = x*y;
]]

local ok, ast = pcall(parser.parse, parser, code)

print""
if(ok and ast) then
	printt(ast, "AST")
else
	print(ast)
	printt(parser.errors, "Errors")
end