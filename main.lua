package.path = ".\\..\\?.lua;.\\calculator\\?.lua;" .. package.path

CFG_INPUT_GRAMMAR = "input1.txt" -- self-describing grammar
-- CFG_INPUT_GRAMMAR = "calc.txt" -- calculator grammar
CFG_USE_GENERATED_CSV = true
CFG_GENERATE_CSV = true
CFG_GENERATE_CALCULATOR_CODE = CFG_INPUT_GRAMMAR == "calc.txt"

-- lua54.exe calculator.lua calculator/expr.txt

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

local file = io.open(CFG_INPUT_GRAMMAR, "r")
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

local ppt
if CFG_USE_GENERATED_CSV then
	ppt = csv2table("generated_table.csv")
else
	ppt = csv2table("table.csv")
end
require('process')
-- process(process(process(process(process(process(ppt,tokens),tokens),tokens),tokens),tokens),tokens)

local ppt2 = process(ppt, tokens)
if CFG_GENERATE_CSV then
	table2csv(ppt2, "generated_table.csv")
end
if CFG_GENERATE_CALCULATOR_CODE then
	require('calc_generator')
	local calc_code = calc_generate(table2csvString(ppt2))
	file = io.open("calculator.lua", "w")
	file:write(calc_code)
	file:close()
	-- require('calc_lexer')
	-- require('calc_parser')
	-- calc_process(ppt2)
end