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

### Special Rules
In the process of generating the parser, DSL will create some special rules that can be referenced in the description of a language's grammar rules.  The *terminal* rule is the set of all tokens.  If operators rules are generated, the *expression* rule will be the top-level rule and is the entry point into parsing all of the operators. 