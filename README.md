DSL
===

Domain Specific Language generator for Lua

Overview
---
DSL is a language generator.  Given a set of token patterns and grammar rules describing a language, DSL will generate a parser.  DSL is based on LPEG (Lua Parsing Expression Grammars), so tokens and rules are described in LPEG syntax.  DSL extends LPEG by adding functionality useful for writing custom languages such as diagnostic tools, error handling, and some new primitives that can be used for writing patterns.

### DSL features
* parsing event callbacks (token try, token match, rule try, rule match, rule end, comment try, comment match) 
* error annotations on grammar rule patterns for throwing syntactical errors
* auto-generation of expression operators such as *, /, +, etc.
* automatic whitespace handling
* Code -> AST -> Code with pretty printing round trip
* one-pass parsing of input string
* new Token primitive 'T' as an extension of the LPEG 'P' pattern for writing grammar rules


Writing a DSL
---
The DSL object is used to specify a language grammar in DSL.  Each grammar must have a set of *tokens* and *rules* patterns optionally with a list of *operators* and a set of *comment* patterns.  In addition, there are a host of options for configuring how DSL generates a parser from a language description.

### Tokens
Tokens are described using LPEG patterns and the set of patterns provided in the *DSL.patterns* module, which provide useful patterns for language generation such as string, float, integer, etc.  Tokens are used to divide input string character sequences into two categories: those that are interesting and those that are ignored.  When a parser is generated, a pattern describing which string characters to ignore is inserted between each token.  Typically this pattern matches the whitespace characters and comment patterns.  Some examples tokens might include:

	NUMBER = float+integer
	CONTINUE = P"continue"
	
Here, two token patterns called NUMBER and CONTINUE are described.  NUMBER uses the float and integer patterns from DSL.patterns.  CONTINUE uses the lpeg.P pattern to create a 'continue' keyword.

### Rules
Rules are also described using LPEG patterns but are composed only of tokens and other rules in order for DSL to apply transformations to the input patterns during parser generation.  Often, a language uses tokens that are purely syntactic with no semantic value.  As a result, these tokens can be left out of the output AST (Abstract Syntax Tree).  In DSL, such tokens are called *anonymous tokens*.  Anonymous tokens are generated in the description of rules using the 'Token' or 'T' pattern.  For example:

	value = object + array + terminals
	array = T"[" * (value * (T"," * value)^0)^-1 * T"]"
	
Here, two of the rules describing JSON arrays.  The value rule chooses between a set of potential value patterns.  The array rule, on the other hand, describes arrays as a list of zero or more comma-delimited (',') values between a '[' and a ']'.  The tokens ',', '[', and ']' are anonymous tokens and will not appear in the AST.

#### Operator Rules
One of the more tedious parts of writing a parser for a DSL is specifying all of the operator rules and their priority.  Since operator rules follow a specific pattern, DSL can automate their generation from a list of input information.  The operator description is provided as a Lua table specifying the name of the operator and a list of symbols that can be used.  For example:

	{
		{name="multiplicative_op", "*", "/", "%"},
		{name="additive_op", "+", "-"},
	}

The list above describes two operators: multiplicative\_op and additive\_op.  Each provides a name and a list of operator symbols.  In addition, their ordering in the list specifies their priority with the lower position in the array indicating a higher priority.  In the above example, multiplicative\_op has a priority of 1 and additive\_op a priority of 2.  As a result, multiplicative\_op has a higher priority in terms of operator precedence.

While the above example works for binary operators, not all operators are binary.  Some are unary or ternary while others require customized rule patterns.  For non-binary operators, the arity of an operator can be specified.  For operators, such as a function call, that need special syntax, a rule can be provided that names a grammar rule to use instead of trying to auto-generate a pattern.  For example:

	{
		{name="function_call_op", rule="function_call"},
		{name="unary_op", arity=1, "!", "-"},
		{name="multiplicative_op", "*", "/", "%"},
		{name="additive_op", "+", "-"},
		{name="conditional_op", arity=3, {"?", ":"}},
	}

Here, the unary op is marked as having arity 1 while the conditional\_op (C ternary operator) is marked at having arity 3.  Note that conditional\_op has an array of operators for its operator symbol.  This is due to the fact that the C ternary operator has two distinct characters.  Also not that the function\_call\_op names its rule as function\_call, telling DSL to use the function\_call rule instead of auto-generating one.

### Annotations
Annotations are additional properties attached to tokens and rules.  There are no restrictions on the properties that can be attached as long as their names don't conflict with existing fields.  The reserved fields are:

* name = The name of the Token/Rule
* patt = The LPEG pattern representing the Token/Rule

In addition, there are certain fields that DSL looks for that, if defined, direct DSL to modify how it treats a particular token or rule.  For tokens, the fields are:

* value = Mark this Token as a value to be included as a choice in the *values* Rule
* keyword = Mark this Token as a value to be included as a choice in the *keyword* Rule

For rules, the fields are:

* collapsable = Remove this Rule from the AST if it only has one child node

The *collapsable* field is very useful for simplifying an AST.  For example, all auto-generated operator rules have their collapsable property set to true.  As a result, even though an operator rule might be matched, it will only appear in the AST if it carries any semantic information (i.e. it has more than one child node).  If it doesn't, then it is removed from the AST and its sole child is set as a child of the parent rule.

Aside from the annotations DSL understands, it may be useful to store data of some sort in a token or rule definition.  This is exactly what annotations are for.

#### Special Rules
In the process of generating the parser, DSL will create some special rules that can be referenced in the description of a language's grammar rules.  Special rules may or may not be defined depending on what information is input to DSL.  The special rules are:

* values = The set of value Tokens if any are defined
* keywords = The set of keyword Tokens if any are defined
* expression = The top-level entry point rule into the chain of auto-generated operator rules

Below is an example of using the keywords special rule to exclude certain names from being defined as an IDENTIFIER token:

	IDENTIFIER = idchar * (idchar+digit)^0 - keywords

### Parser
DSL.Parser is the main workhorse of DSL.  It is the object that synthesizes a parser from the input data configured according to user settings.  A Parser can be created from a DSL object.  Every Parser must have a root rule defined, which is the top-level rule of the grammar.  It should be set to the name of a rule defined in the DSL.

#### Settings
Depending on how much diagnostic information you want back from the parser, there are a number of flags for modifying how a parser is generated.  This can be very handy when debugging a grammar, for example, since some of the flags will allow you to trace the path the parser takes through a grammar as it processes input strings.  The possible options are:

* trace = Trace the Rules visited during parsing (default false)
* token_trace = Trace the named Tokens visited during parsing (default false)
* anonymous\_token\_trace = Trace the anonymous Tokens visited during parsing (default false)
* comment_trace = Trace the comments visited during parsing (default false)
* mark_position = Mark the start and end position of a Token in the input string and store the values in the Token nodes of the AST (default true)

#### Events
As a parser processes input strings, it can generate a number of events that can be handled via callbacks defined on the parser.  Events can be generated for comments, tokens, and rules depending on how the settings for the parser are configured.  For each class of event, if a callback function is defined, it will be called.  The callback functions are:

* comment\_event(parser, event\_name, position, comment)
* token\_event(parser, event\_name, token\_name, position)
* rule\_event(parser, event\_name, rule\_name, position)

The comment\_event callback will be called anytime a comment is encountered.  If the comment\_trace flag is set, it will also be called when an attempt to match a comment pattern occurs.  The token\_event callback will be called if the trace flag is set and a token is matched.  If trace\_token is set, it will also be called when an attempt to match a token pattern occurs.  If the anonymous\_token\_trace flag is set, it will also be called whenever an anonymous token match is attempted and matched.  The rule\_event callback will be called if the trace flag is set whenever an attempted match, successful match, or failed match occurs.

### Error Handling
One task of a good language parser is to provide useful error messages when parsing fails.  Some errors depend on semantic information, so they can't be directly embedded in the grammar, but others are syntactic and can be embedded.  Furthermore, syntactic information about where parsing failed can help in diagnosing semantic errors.  DSL has a function called *Assert* than can be used to assert that a particular pattern matches if the parser reaches that point.  If parsing happens to fail, then a provided error string can be used to generate an error message for the user. Assert has the following signature:

	Assert(patt, msg)
	
It's usage looks like:

	expression_statement =  assignment_expression * Assert(T";", "expression_statement.SEMICOLON")

Here, we assert that if an expression\_statement is matched up through assignment\_expression that a semicolon must follow.  If not, an error messaging noting the location of the error and the message "expression_statement.SEMICOLON" is thrown.

### AST Nodes
The output of a DSL parser is an Abstract Syntax Tree.  The nodes in the AST correspond to matched rules and tokens with tokens as the leaf nodes.  For every rule matched, a node is added to the AST where the rule field is set to the name of the rule matched and the list of child nodes ordered in the array portion of the node.  If a rule is marked as collapsable, it will not appear in the AST if it only has one child node.

Token nodes have the token field set with the name of the token and the value of the token in the first position of the array portion of the node.  Tokens can only have one value, so they are always arrays of length one.  As an example output, below is some JSON code and its resulting AST:

	{
		"x" : "yyy"
	}

	AST = {
	    rule = "object",
	    [1] = {
	        rule = "entry",
	        [1] = {
	            token = "STRING",
	            [1] = "\"x\"",
	        },
	        [2] = {
	            token = "STRING",
	            [1] = "\"yyy\"",
	        },
	    },
	},

### Limitations
DSL uses proxies to manipulate LPEG.  Since Lua 5.1 doesn't support metamethods for the # operator on tables, the LPEG operator #patt, will not work in DSL.  Instead, use the function Ignore, which is functionally equivalent.