package.path = ".\\..\\?.lua;" .. package.path
require('class')
require('FiniteAutomaton')
local V = {"h", "q", "doll", "eq", "a", "x", "i", "o", "m", "n", "t", "e", "r", "u", "l", "p", "s", "ln", "ws", "ast", "az", "eof", "oth"}
local Q = {"q0", "NTm", "FNTm", "FNTmh", "Tm", "Tmq", "FTm", "WS", "FWS", "KW", "KW$", "FKW", "Comm", "FComm", }
local d = {
	q0 = {
		lambda = { "NTm", "WS", "Tm", "KW", "Comm"}
	},
	NTm = {
		az = {"FNTm"},
		a = {"FNTm"},
		x = {"FNTm"},
		i = {"FNTm"},
		o = {"FNTm"},
		m = {"FNTm"},
		n = {"FNTm"},
		t = {"FNTm"},
		e = {"FNTm"},
		r = {"FNTm"},
		u = {"FNTm"},
		l = {"FNTm"},
		p = {"FNTm"},
		s = {"FNTm"},
	},
	FNTm = {
		az = {"FNTm"},
		a = {"FNTm"},
		x = {"FNTm"},
		i = {"FNTm"},
		o = {"FNTm"},
		m = {"FNTm"},
		n = {"FNTm"},
		t = {"FNTm"},
		e = {"FNTm"},
		r = {"FNTm"},
		u = {"FNTm"},
		l = {"FNTm"},
		p = {"FNTm"},
		s = {"FNTm"},
		h = {"FNTmh"}
	},
	Tm = {
		q = {"Tmq"}
	},
	Tmq = {
		-- all \ { q, eof } = {"Tmq"}
		q = {"FTm"}
	},
	WS = {
		ws = {"FWS"},
		-- ln = {"FWS"}
	},
	FWS = {
		ws = {"FWS"},
		-- ln = {"FWS"}
	},
	KW = {
		eq = {"FKW"},
		doll = {"KW$"},
        eof = {"FKW"},
		ln = {"FKW"}
	},
	Comm = {
		ast = {"FComm"},
	},
	FComm = {
		-- all \ { ln, eof } = {"FComm"}
	}
}
local function addTrans(symbs, start, finish, others)
	local ss = {}
	local symbs_map = list2map(symbs)
	if others then
		for _, v in ipairs(V) do
			if not symbs_map[v] then
				table.insert(ss, v)
			end
		end
	else
		ss = symbs
	end
	for _, c in ipairs(ss) do
		if not d[start][c] then d[start][c] = {} end
		table.insert(d[start][c], finish)
	end
end
local function addBranches(terms, start, finish)
	for _, term in ipairs(terms) do
		local name = start
		for i = 1, #term do
			local c = string.sub(term,i,i)
			if not d[name] then d[name] = {} end
			if not d[name][c] then d[name][c] = {} end
			if i ~= #term then
				table.insert(d[name][c], name .. c)
				table.insert(Q, name .. c)
				d[name .. c] = {}
			else
				table.insert(d[name][c], finish)
			end
			name = name .. c
		end
	end
end
addBranches({"axiom", "nterm", "term", "rule", "eps"}, "KW$", "FKW")
addTrans({"q", "eof"}, "Tmq", "Tmq", true)
addTrans({"ln", "eof"}, "FComm", "FComm", true)
local q0 = "q0"
local F = {FKW = 6, FNTmh = 5, FNTm = 4, FTm = 3, FWS = 2, FComm = 1} -- priority and ids

local file = io.open("input1.txt", "r")
local code = file:read("a")
-- print("PROGRAM:\n" .. code)


local fa = FiniteAutomaton(V, Q, q0, F, d)
fa:det()

local function symbol2factor(c)
	local b = string.byte(c)
	local lb = string.byte(string.lower(c))
	if c == "'" then
		return "h"
	elseif c == "\"" then
		return "q"
	elseif c == "$" then
		return "doll"
	elseif c  == "=" then
		return "eq"
	elseif c == "*" then
		return "ast"
	elseif c == "\n" then
		return "ln"
	elseif c == " " or c == "	" then
		return "ws"
	elseif c == string.char(27) then -- end of file
		return "eof"
	elseif  b >= string.byte("A") and b <= string.byte("Z") then
		if string.find("AXIOMNTERULPS", c) then
			return string.lower(c)
		else
			return "az"
		end
	elseif b >= string.byte("a") and b <= string.byte("z") then
		return "az"
	else
		return "oth"
	end
end
local function priority2tokenType(n)
	local p2t = {"COMMENT", "WS", "TERM", "NTERM", "NTERM", "KW"}
	return p2t[n]
end

require('Lexer')
local lexer = Lexer(fa, symbol2factor, code, priority2tokenType)

-- print("TOKENS:")
local tokens = {}
local token = lexer:nextToken()
while token do
	local toprint = token.domain .. " "
	toprint = toprint .. "(".. tostring(token.startLine) .. ", " .. tostring(token.startPos) .. ")-(" .. tostring(token.finishLine) .. ", " .. tostring(token.finishPos) .. ")"
	if token.value then toprint = toprint .. ": ".. token.value end
	print(toprint)
	table.insert(tokens, token)
	token = lexer:nextToken()
end
-- print("MESSAGES:")
-- for _, mess in ipairs(lexer.messages) do
-- 	print(mess)
-- end

require('csv2table')
local function cellFunction(cell)
	local tab = {}
	for c in string.gmatch(cell, "([^ ]+)") do
		table.insert(tab, c)
	end

	return tab
end
local ppt = csv2table("table.csv", cellFunction)

local rules = {}
local terms = {"$AXIOM", "$NTERM", "$TERM", "$RULE", "NTERM", "TERM", "ASSIGN", "NL", "END_OF_PROGRAM", "$EPS"}
local terms_map = list2map(terms)
local nterms = {}
for nterm, _ in pairs(ppt) do table.insert(nterms, nterm) end
local nterms_map = list2map(nterms)

local function topDownParse()
	local stack = {"END_OF_PROGRAM", "Grammar"}
	local token = tokens[1]
	local tokenIdx = 2
	while true do
		local x = stack[#stack]
		if terms_map[x] then
			if x == token.domain then
				stack[#stack] = nil
				token = tokens[tokenIdx]
				tokenIdx = tokenIdx + 1
			else
				error("error: line " .. token.line .. ", pos " .. token.pos)
			end
		elseif ppt[x][token.domain][1] == "ERROR" then
			error("error: line " .. token.line .. ", pos " .. token.pos)
		elseif ppt[x][token.domain][1] == "eps" then
			stack[#stack] = nil
			table.insert(rules, {left = x, right = ppt[x][token.domain]})
		else
			stack[#stack] = nil
			local right = ppt[x][token.domain]
			table.insert(rules, {left = x, right = right})
			for i = #right, 1, -1 do
				-- if right[i] ~= "eps" then
					table.insert(stack, right[i])
				-- end
			end
		end
		if x == "END_OF_PROGRAM" then break end
	end
end
topDownParse()

local tree = {}
local ruleIdx = 1
local tokenIdx = 1
local function buildParseSubtree()
	local node = {}
	local rule = rules[ruleIdx]
	ruleIdx = ruleIdx + 1
	node.name = rule.left
	node.subtree = {}
	for _, t in ipairs(rule.right) do
		if terms_map[t] then
			local token = tokens[tokenIdx]
			tokenIdx = tokenIdx + 1
			table.insert(node.subtree, token)
		elseif t ~= "eps" then
			table.insert(node.subtree, buildParseSubtree())
		end
	end

	return node
end
tree = buildParseSubtree()
local ast = {}
function createAST(tree)
	local ast = {axiom = tree.subtree[2], terms = {}, nterms = {}, rules = {}}
	local function addRec(node, list, func)
		func(node)
		if #termList.subtree == 0 then return end
		addRec(termList.subtree[1], termList.subtree[2], func)
	end
	addRec(tree.subtree[6], tree.subtree[7], function (node) 
		table.insert(ast.terms, node)
	end)
	addRec(tree.subtree[4].subtree[1], tree.subtree[4].subtree[2], function (node)
		table.insert(ast.nterms, node)
	end)
	local function addRule(node)
		ast.rules[] 
	end
	addRec(tree.subtree[9], tree.subtree[10], addRule)
end

local grammarRules = {}
local ruleNode = tree.subtree[9]
assert(ruleNode == "Rule")
function addRule(aRule)

end

for 
require('first')
local first = getFirst(rules)

print("end")

