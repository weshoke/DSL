local format = string.format
local lpeg = require"lpeg"
local P, S, R = lpeg.P, lpeg.S, lpeg.R
local C, V = lpeg.C, lpeg.V
local Ct, Cg, Cc = lpeg.Ct, lpeg.Cg, lpeg.Cc
local Cp, Cmt = lpeg.Cp, lpeg.Cmt
local Cb, Cs = lpeg.Cb, lpeg.Cs

local patterns = require"DSL.patterns"
local space = patterns.space

local function table_derive(dst, src)
	assert(type(dst) == "table" and type(src) == "table", "cannot derive with non-table")
	for k, v in pairs(src) do
		if(not dst[k]) then
			dst[k] = v
		end
	end
	return dst
end

local function table_format(t, fmt)
	local res = {}
	for i=1, #t do
		res[i] = format(fmt, t[i])
	end
	return res
end

local function keys(map)
	local list = {}
	for k in pairs(map) do
		list[#list+1] = k
	end
	return list
end

local function remap(list, map)
	local res = {}
	for i=1, #list do
		local v = list[i]
		if(type(v) == "table")
			then list[i] = remap(v, map)
			else list[i] = assert(map[v])
		end
	end
	return list
end

local function optbool(v, def)
	if(type(v) == "boolean")
		then return v
		else return def
	end
end

local nl = (function()
	local eq = P"="^0
	local open = "[" * Cg(eq, "init") * "[" * P"\n"^-1
	local close = "]" * C(eq) * "]"
	local closeeq = Cmt(close * Cb("init"), 
		function (s, i, a, b) 
			return a == b 
		end
	)
	local STR = Cs((open * C((P(1) - closeeq)^0) * close / function (s, o)
		if(s == [[\n]]) 
			then return "[[\n\n]]"
			else return format("[===[%s]===]", string.gsub(s, [[\n]], "\n"))
		end
	end + P(1))^1)
	
	return function(str)
		return STR:match(str)
	end
end)()

local function trimwhitespace(s)
	return s:match("(.-)%s*$")
end

local function linecol(s, i, trim)
	trim = optbool(trim, true)
	
	s = s:sub(1, i)
	if(trim) then
		local len = s:len()
		s = trimwhitespace(s)
		i = i - (len-s:len())
	end
	
	local line = 1
	local col = i
	local count = function(loc)
		col = i-loc
		line = line+1
	end
	
	local nonspace = P(1)-space
	local newline = P"\n"
	local patt = ((newline*Cp())/count + nonspace + space)^1
	patt:match(s)

	return line, col
end

local function token_event(parser, e, name, idx)
	if(e == "try") 
		then print(idx.." try token: "..name)
		else print(idx.." TOKEN: "..name)
	end
end

local function rule_event(parser, e, name, idx)
	local depth = #parser.rulestack
	local dir = e == "start" and "->" or "<-"
	
	print(format("%d%s%d %s %s", 
		idx, string.rep(" ", depth), depth,
		dir, name
	))
end

local printt = (function()
	local 
	function ref_table_iter(name, t, references, id, skip_key_set)
		local skip_key_set = skip_key_set or {}
		if not skip_key_set[t] then
			if type(t) == "table" then
				if references[t] then
					references[t].count = references[t].count + 1
					table.insert(references[t].name, name)
				else
					id = id + 1
					references[t] = { count=1, id=id, data=t, name={name} }
					for k, v in pairs(t) do
						if not skip_key_set[k] then
							local name1
							if type(k) == "string" then 
								name1 = format("%q", k)
							end
							id = ref_table_iter(name1, k, references, id, skip_key_set)
							id = ref_table_iter(name1, k, references, id, skip_key_set)
							id = ref_table_iter(name1, v, references, id, skip_key_set)
						end
					end
				end		
			end
		end
		return id
	end
	
	local function ref_string(ref)
		return string.format("REF%d", ref.id)
	end
	local function ref_stringv(ref)
		return string.format("REF%d", ref.id)
	end
	
	local function qk(v, references) 
		if references[v] and references[v].count > 1 then
			return ref_string(references[v]) -- string.format("REF%d", references[v].id)
		else
			return (type(v)=="number" or type(v)=="boolean") and string.format("[%s]", tostring(v)) or
			(type(v)=="string") and v or
			(v and string.format("[%q]", tostring(v)) or "")
		end
	end
	local function qv(v, references) 
		if references[v] and references[v].count > 1 then
			return ref_string(references[v]) --string.format("\"REF%d\"", references[v].id)
		else
			return (type(v)=="number" or type(v)=="boolean") and tostring(v) or
			(v and string.format("%q", tostring(v)) or "")
		end
	end
	
	local 
	function print_table_keysorter(a, b)
		if type(a) ~= type(b) then
			return type(a) < type(b)
		else
			if(type(a) == "table") then
				a = tostring(a)
			end
			if(type(b) == "table") then
				b = tostring(b)
			end
			return a < b
		end
	end
	
	local
	function print_table_iter(t, name, lvl, references, skip_key_set, skip_value_types)
		local skip_key_set = skip_key_set or {}
		local indent = "    "
		
		--[[
		if t.__class then
			print(string.format("%s-- __class = %s", string.rep(indent, lvl), tostring(t.__class)))
		end
		--]]
		
		-- sort keys:
		local keys = {}
		for k, v in pairs(t) do table.insert(keys, k) end
		table.sort(keys, print_table_keysorter)
		
		if #keys == 0 then
			print(string.format("%s%s = {},", string.rep(indent, lvl), qk(name, references)))
		else
			print(string.format("%s%s = {", string.rep(indent, lvl), qk(name, references), qv(t, references)))
			--for k, v in pairs(t) do 
			for i, k in ipairs(keys) do
				if skip_key_set[k] then
					--print("skipping", k)
					print(string.format("%s%s = <skipped>,", string.rep(indent, lvl+1), qk(k, references)))
				else
					local v = t[k]
					if not skip_value_types[type(v)] then
						local refs = references[v]
						if not (type(k) == "number" and k > 0 and k <= #t) then
							if refs and refs.count > 1 then
								print(string.format("%s%s = %s,", string.rep(indent, lvl+1), qk(k, references), ref_stringv(refs)))
							elseif(type(v) == "table") then
								print_table_iter(v, k, lvl+1, references, skip_key_set, skip_value_types)
							else
								print(string.format("%s%s = %s,", string.rep(indent, lvl+1), qk(k, references), qv(v, references)))
							end
						end
					end
				end
			end
			--for k, v in pairs(t) do 
			for i, k in ipairs(keys) do
				if skip_key_set[k] then
					--print("skipping", k)
				else
					local v = t[k]
					if not skip_value_types[type(v)] then
						local refs = references[v]
						if (type(k) == "number" and k > 0 and k <= #t) then
							if refs and refs.count > 1 then
								print(string.format("%s%s = %s,", string.rep(indent, lvl+1), qk(k, references), ref_string(refs)))
							elseif(type(v) == "table") then
								print_table_iter(v, k, lvl+1, references, skip_key_set, skip_value_types)
							else
								print(string.format("%s%s = %s,", string.rep(indent, lvl+1), qk(k, references), qv(v, references)))
							end
						end
					end
				end
			end
			print(string.rep(indent, lvl).."},")
		end
	end

	return function(t, name, skip_key_set, skip_value_types)
		local skip_key_set = skip_key_set or {}
		local skip_value_types = skip_value_types or {}
		local references = {}
		local id = 0
		local name = name or "RESULT"
		ref_table_iter(name, t, references, 0, skip_key_set, skip_value_types)
		
		local refs = {}
		for k, v in pairs(references) do
			if v.count > 1 then
				table.insert(refs, v)
			end
		end
		table.sort(refs, function(a, b) return a.id > b.id end)
		for i, v in ipairs(refs) do
			if #v.name > 0 then print(format("-- %s:", table.concat(v.name, ","))) end
			print_table_iter(v.data, ref_string(v), 0, references, skip_key_set, skip_value_types)
		end
		if references[t].count > 1 then
			print(string.format("%s = %s", name, ref_string(references[t])))
		else
			print_table_iter(t, name, 0, references, skip_key_set, skip_value_types)
		end
	end
end)()

return {
	table_derive = table_derive,
	table_format = table_format,
	keys = keys,
	remap = remap,
	optbool = optbool,
	nl = nl,
	trimwhitespace = trimwhitespace,
	linecol = linecol,
	token_event = token_event,
	rule_event = rule_event,
	printt = printt,
}