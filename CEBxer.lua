--[[
CEBxer.lua
	Character-based parser.
	Reaching speeds 5,500 tokens per second!
	
Features include
	Compatible
		Compatible with Roblox's Luau and Lua 5.1
	Open Source
		To see how it works
	Lightweight
		Lexer.lua is only 304 lines of code!
		
Bugs--?
	Doesn't support `` strings
	
Token :
	{
		Source : the Source of the Token
		Type : What type of token is it
		Multiline : (only for strings and comments)
		Whitespace : the Whitespace after the Token (token-whitespace)
		TypeOfIdent : For Idents only! Keyword, Global, and Ident
		Index : The index of the token
	}
]]

local lexer = {};

function lexer.FixNumbers(Tokens)
	local NewTokens = {};
	if #Tokens > 0 then
		local Index = 1;
		while Index <= #Tokens do
			local Current = Tokens[Index]
			if Current.Type == "Number" then
				if Index+2 <= #Tokens then
					local Next, NN = Tokens[Index+1], Tokens[Index+2]
					if Next.Source == "." and NN.Type == "Number" then
						Current.Source = Current.Source .. "." .. NN.Source;
						Index = Index + 2;
					end
				end
			end
			NewTokens[#NewTokens+1] = Current;
			Index = Index + 1;
		end
	end
	return NewTokens;
end

function lexer.new(source, scriptname) -- Make a new tokenizer
	local tokenizer = {}
	local script = (scriptname or "main.lua") -- The script name, for syntax errors that don't correspond to what grammar the lexer analyzes.

	local Line = 1 -- First line. 
	local Index = 1 -- The Index for iterating.

	local commentaddup = "" -- For comments
	local stringaddup = "" -- For strings
	local indentaddup = "" -- For indents
	local Tokens = {} -- The finished result of tokens

	local mlrcomend,mlrstrend,mlrstrdis,mlcomend,mlrcomdis

	local globals = lexer.globals;
	local keywords = lexer.keywords;
	local numberFound = false;
	
	local function nexttoken(Source, type, ml, whitespace)
		if #Source == 0 then
			return
		end
		if tonumber(Source) then -- Remove this statement to not allow numbers
			type = "number"
			Source = Source:match('^%d');
			numberFound = true;
		end
		
		local lastWhitespace;
		local TypeOfIndent;
		local ends = Tokens[#Tokens]
		local Index = (ends and ends.Index + 1) or #Tokens + 1;
		if type == "ident" then
			TypeOfIndent = (globals[Source] and "Global") or (keywords[Source] and "Keyword") or "Ident";
		end
		Tokens[Index] = {
			Source = Source;
			Type = (type:sub(1,1):upper()..type:sub(2));
			Multiline = ml or nil;
			Whitespace = whitespace; 
			TypeOfIndent = TypeOfIndent;
			Index = Index;
		}
	end
	
	local function sqfind(Index, Source, end_)
		local r = Source:sub(Index)
		local e = "["
		if end_ then
			e = "]"
		end
		
		local i, j = r:find("^%" .. e .. "=*%" .. e .. "")
		if i and j then
			return r:sub(i, j):len() - 2
		else
			return
		end
	end
	
	local function findwhitespace(Index, Source)
		local i, j = Source:sub(Index):find("%s*")
		i = i - 1 + Index
		j = j - 1 + Index
		local ws = Source:sub(i, j)
		return (ws), i, j
	end
	
	function tokenizer:disablesynerr() -- To disable errors
		self.stringsyntaxerr = function()
		end
		self.commentsyntaxerr = function()
		end
		return self
	end
	
	function tokenizer:enablesynerr()
		function tokenizer:stringsyntaxerr(line)
			error(script .. ":" .. tostring(self.line) .. ": " .. "unfinished string near `" .. stringaddup .. "`")
		end
		function tokenizer:commentsyntaxerr(line)
			error(script .. ":" .. tostring(self.line) .. ": " .. "unfinished comment near `" .. commentaddup .. "`")
		end
		return self;
	end
	
	do
		function tokenizer:stringsyntaxerr(line)
			error(script .. ":" .. tostring(self.line) .. ": " .. "unfinished string near `" .. stringaddup .. "`")
		end
		function tokenizer:commentsyntaxerr(line)
			error(script .. ":" .. tostring(self.line) .. ": " .. "unfinished comment near `" .. commentaddup .. "`")
		end
	end
	
	function tokenizer.lex() -- lexify
		if #source == "" then
			return;
		end
		
		local luaLexerMemoization = shared.luaLexerMemo
		Tokens = {} -- Reset tokens.
		numberFound = false; -- Reset numberFound

		if luaLexerMemoization and luaLexerMemoization[source] then
			return luaLexerMemoization[source];
		end

		local lastsub
		local mlstrend
		local mlstrdis

		local mlscomend
		local mlcomdis

		while Index < #source or Index == #source do -- Main parsing 
			local sub = source:sub(Index, Index)
			if #stringaddup > 0 then -- String
				if stringaddup:sub(1, 1) == "'" or stringaddup:sub(1, 1) == '"' then -- Single line
					if sub == "\n" and not (source:sub(Index-1,Index-1) == "\\") then
						-- Syntax error since there cannot be new lines in single lined strings
						tokenizer:stringsyntaxerr(Line)
						stringaddup = stringaddup .. sub
					elseif sub == stringaddup:sub(1, 1) and lastsub ~= "\\" then
						stringaddup = stringaddup .. sub
						-- String appendation --
						local ws = findwhitespace(Index + 1, source)
						nexttoken(stringaddup, "string", false, ws)
						stringaddup = ""
					elseif
						sub == stringaddup:sub(1, 1) and lastsub == "\\" and
						stringaddup:sub(#stringaddup) == "\\"
					then -- In case of a "\\"
						local added = {};
						for r in (stringaddup:sub(2):gmatch("\\.?")) do
							if #r == 1 then
								tokenizer:stringsyntaxerr(Line)
							end
							added[#added+1] = r;
						end -- If there is a "\\\", which is a malformed string, it will make a syntax error;
						if #added > 0 then
							if added[#added]:sub(2,2) == sub then
								-- TODO: Continue???
							elseif #added[#added] == 2 then
								stringaddup = stringaddup .. sub
								-- String appendation --
								local ws = findwhitespace(Index + 1, source)
								nexttoken(stringaddup, "string", false, ws)
								stringaddup = ""
							end
						end
					else
						stringaddup = stringaddup .. sub
					end
				elseif stringaddup:sub(1, 1) == "[" then -- Multiple Line
					if sqfind(Index, source, true) ~= nil then -- If in a string, it will see the char "]", and checks if it is an ending square bracket. So it calucates how many equal signs plus the Index plus one to find the end of the string.
						local dis = sqfind(Index, source, true)
						if dis == mlstrdis then
							mlstrend = Index + 1 + dis
						end
						stringaddup = stringaddup .. sub
					elseif Index == mlstrend then
						stringaddup = stringaddup .. sub
						mlrstrend = nil
						mlrstrdis = nil
						-- String appendation --
						local ws = findwhitespace(Index + 1, source)
						nexttoken(stringaddup, "string", true, ws)
						stringaddup = ""
					else
						stringaddup = stringaddup .. sub
					end
				end
			elseif #commentaddup > 0 then -- Comment
				if commentaddup:sub(1, 3) == "--[" then -- Multiple Line
					if sub == "]" and mlcomend == nil then
						if sqfind(Index, source, true) ~= nil then
							commentaddup = commentaddup .. sub
							local dis = sqfind(Index, source, true)
							if dis == mlcomdis then
								mlcomend = Index + 1 + dis
							end
						end
					elseif Index == mlcomend then
						commentaddup = commentaddup .. sub
						mlrcomend = nil
						mlrcomdis = nil
						-- Comment appendation --
						local ws = findwhitespace(Index + 1, source)
						nexttoken(commentaddup, "comment", true, ws)
						commentaddup = ""
					else
						commentaddup = commentaddup .. sub
					end
				else -- Single line
					if sub == "\n" then
						-- Comment appendation --
						local ws = findwhitespace(Index, source)
						nexttoken(commentaddup, "comment", false, ws)
						commentaddup = ""
					else
						commentaddup = commentaddup .. sub
					end
				end
			else -- indentation
				if
					(sub == "'" or sub == '"' or (sqfind(Index, source))) and
					(#commentaddup == 0 and #stringaddup == 0)
				then -- String Start
					nexttoken(indentaddup, "ident", false, "")
					indentaddup = ""
					if sub == "'" or sub == '"' then
						stringaddup = stringaddup .. sub
					else
						mlstrdis = sqfind(Index, source)
						stringaddup = stringaddup .. sub
					end
				end
				if
					(source:sub(Index, Index + 1) == "--") and
					(#commentaddup == 0 and #stringaddup == 0)
				then --- Comment Start
					nexttoken(indentaddup, "ident", false, "")
					indentaddup = ""
					commentaddup = sub
					if source:sub(Index + 2, Index + 2) == "[" then
						if sqfind(Index + 2, source) then
							mlcomdis = sqfind(Index + 2, source)
						end
					end
				end
				if (#commentaddup == 0 and #stringaddup == 0) then
					if sub:find("%p") then
						if #indentaddup > 0 then
							nexttoken(indentaddup, "ident", false, "")
							indentaddup = ""
						end
						local ws = findwhitespace(Index + 1, source)
						nexttoken(sub, "symbol", false, ws)
					elseif sub:find("%s") then
						local ws = findwhitespace(Index, source)
						nexttoken(indentaddup, "ident", false, ws)
						indentaddup = ""
					elseif sub:find("%w") then
						indentaddup = indentaddup .. sub
					end
				end
			end
			lastsub = sub
			if sub == "\n" then
				Line = Line + 1
			end
			if Index == #source then
				if #stringaddup > 0 then
					tokenizer:stringsyntaxerr(Line)
					if stringaddup:sub(1, 1) == "[" then
						nexttoken(stringaddup, "string", true, "")
					else
						nexttoken(stringaddup, "string", false, "")
					end
				end
				if #commentaddup > 0 then
					if mlcomdis and not mlcomend then
						tokenizer:commentsyntaxerr(Line)
						commentaddup = commentaddup .. sub;
						local ws = findwhitespace(Index + 1, source)
						nexttoken(commentaddup, "comment", false, ws)
					elseif commentaddup:sub(1, 3) ~= "--[" then
						-- String appendation --
						local ws = findwhitespace(Index + 1, source)
						nexttoken(commentaddup, "comment", false, ws)
					elseif mlcomdis == nil and mlcomend == nil then
						tokenizer:commentsyntaxerr(Line)
						commentaddup = commentaddup .. sub;
						local ws = findwhitespace(Index + 1, source)
						nexttoken(commentaddup, "comment", false, ws)
					end
				end
				if #indentaddup:gsub("%s", "") ~= 0 then
					nexttoken(indentaddup, "ident", false, "")
				end
			end
			Index = Index + 1
		end
		if numberFound then
			Tokens = lexer.FixNumbers(Tokens);
		end
		if luaLexerMemoization then
			luaLexerMemoization[source] = Tokens; 
		else
			shared.luaLexerMemo = {[source] = Tokens};
		end
		return Tokens;
	end
	
	return tokenizer
end
function lexer.resetMono()
	shared.luaLexerMemo = {};
end
lexer.globals = getfenv();
lexer.keywords = {
	["if"] = true;
	["then"] = true;
	["end"] = true;
	["local"] = true;
	["function"] = true;
	["return"] = true;
	["break"] = true;
	["self"] = true;
	["else"] = true;
	["elseif"] = true;
	["or"] = true;
	["do"] = true;
	["and"] = true;
	["in"] = true;
};

return lexer