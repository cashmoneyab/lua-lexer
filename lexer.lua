--[[
ReLex
 Regex based lexer for Lua
 
Features include

	Quick : Can get 5,289 tokens, in one second (and i'm using a trash computer)
	Lightweight : Only < 170 lines of code (not including this comment)
	Open Source : You can modify the script into your needs
	Compatiable : With Lua 5.1 >

Bugs--?
	Doesn't support `` strings
	Can't tell \n in single-line strings.

new info!
	tokenizer : (source) -->
		{
			{	Whitespace : string, -- the whitespace infront of the token
				Source : string,  -- the source
				Type : string,  -- type of token (Number, String, Comment, Ident, Symbol)
				MultiLine : true? -- if the token uses more than one line, than it can do this
			}
		}
]]--
local rep = string.rep;

local addUp;
local luamatches = {
	WHITESPACE = {"^%s","^%s+"};
	IDENT = {"^%a","^%w+"};

	NUMBER2 = {"^0?X?%d+%.?%d*e[%+%-]?%d+","^0?X?%d+%.?%d*e[%+%-]?%d+"};
	NUMBER = {"^0?X?%d+%.?%d*",function(c)
		if c:match("^0?X?%d+%.?%d*e[%+%-]?%d+") then
			return #c:match("^0?X?%d+%.?%d*e[%+%-]?%d+")
		elseif c:match("^0?X?%d+%.?%d*e") then
			return #c:match("^0?X?%d+%.?%d*e")
		elseif c:match("^0?X?%d+%.?%d*") then
			return #c:match("^0?X?%d+%.?%d*")
		end
	end};

	STRING1 = {"^\"",function(c)
		local g = c:gsub("\\\"","aa");
		local match = g:match("%b\"\"");

		return (match and #match) or nil;
	end};
	STRING2 = {"^'",function(c)
		local g = c:gsub("\\'","aa");
		local match = g:match("%b''");

		return (match and #match) or nil;
	end};
	STRING3 = {"^%[%=*%[.*",function(c)
		local start = c:match("^%[%=*%[")
		local count = 0;

		start:gsub("%=",function()
			count = count + 1;
		end);

		local rep = rep("%=",count)
		local match = c:match("^%[%=*%[.*%]"..rep.."%]");

		return (match and #match) or nil;
	end};

	COMMENT1 = {"^%-%-.*",function(c)
		if c:match("^%-%-%[%=*%[.*") then
			local start = c:match("^%-%-%[%=*%[")
			local count = 0;

			start:gsub("%=",function()
				count = count + 1;
			end)

			local rep = rep("%=",count);
			local match = c:match("^%-%-%[%=*%[.*%]"..rep.."%]");

			return (match and #match) or nil;
		end
		local match = "--";

		for index = 3, c:len() do -- TODO: I dont know what but %-%-.*\n doesnt work!
			local character = c:sub(index, index);
			if character == "\n" then
				break;
			else
				match = match .. character;
			end
		end

		return match:len();
	end};
	SYMBOL2 = {"^[_%%%^%*%#%(%)%-%+%[%]%{%}~;:,%.%/%\\%=<>]","^[_%%%^%*%#%(%)%-%+%[%]%{%}~;:,%.%/%\\%=<>]"};

};

local function giveType(token)
	return token:match("%a+"):lower();
end

local function getToken()
	local match, token;
	for i,v in next, luamatches do
		local pattern = v[1];
		if addUp:match(pattern) then
			if match and (addUp:match(pattern):len() > match) then
				match = addUp:match(pattern):len();
				token = i;
			else
				match = addUp:match(pattern):len();
				token = i;
			end
		end
	end
	return token;
end

local function request(token)
	local parse = luamatches[token][2];
	local normal = giveType(token);
	local source = addUp;

	if type(parse) == "function" then
		if parse(addUp) then
			local index = parse(addUp);
			source = addUp:sub(1,index)
			addUp = addUp:sub(index+1);
			return normal, source;
		end
		addUp = "";
	else
		if addUp:match(parse) then
			local index = #addUp:match(parse);
			source = addUp:sub(1,index)
			addUp = addUp:sub(index+1);
			return normal, source;
		end
		addUp = "";
	end

	return normal, source;
end

local function parse(source : string) : () -> (string, string)
	addUp = source;
	return function()
		local token = getToken();
		if token then
			return request(token)
		end
		return;
	end
end;

local function tokenize(source) : {{Whitespace : string, Source : string, Type : string, MultiLine : boolean?}}
	if source then
		local tokens = {};
		local addedWhitespace = "";

		local f = parse(source)

		while true do
			local type, source = f();
			if type and source then
				if type == "whitespace" then
					addedWhitespace = addedWhitespace .. source;
				else
					if tokens[#tokens] then
						tokens[#tokens].Whitespace = addedWhitespace;
					end
					local isMultiline = (type == "string" and source:sub(1,1) == "[") or (type == "comment" and source:sub(1,3) == "--[")
					tokens[#tokens+1] = {
						Source = source;
						Type = type:sub(1,1):upper() .. type:sub(2);
						MultiLine = isMultiline or nil;
						Whitespace = "";
					}
					addedWhitespace = "";
				end	
			else
				break;
			end
		end
		if #addedWhitespace > 0 then
			tokens[#tokens].Whitespace = addedWhitespace;
			addedWhitespace = nil;
		end
		return tokens
	end
	return
end

return {
	scan = parse;
	tokenize = tokenize;
	
	parse = parse;
	array = tokenize;
}