-- require('class')
-- require('FiniteAutomaton')
local V = {"d", "+", "-", "*", "/", "(", ")", "ws", "eof", "oth"}
local Q = {"q0", "FInt", "FKW", "FWS"}
local d = {
	q0 = {
        d = {"FInt"},
        ["+"] = {"FKW"},
        ["-"] = {"FKW"},
        ["*"] = {"FKW"},
        ["/"] = {"FKW"},
        ["("] = {"FKW"},
        [")"] = {"FKW"},
        ["ws"] = {"FWS"},
	},
    FInt = {
        d = {"FInt"},
    },
	FWS = {
		ws = {"FWS"},
	}
}

local q0 = "q0"
local F = {FKW = 3, FInt = 2, FWS = 1} -- priority and ids

local file = io.open(".\\calculator\\expr.txt", "r")
local code = file:read("a")

local fa = FiniteAutomaton(V, Q, q0, F, d)
fa:det()


local function symbol2factor(c)
	local b = string.byte(c)
	local lb = string.byte(string.lower(c))
	if c == "+" or c == "-" or c == "*" or c == "/" or "(" or ")" then
		return c
    elseif b >= string.byte("0") and b <= string.byte("9") then
        return "d"
	elseif c == " " or c == "	" then
		return "ws"
	elseif c == string.char(27) then -- end of file
		return "eof"
	else
		return "oth"
	end
end

local function priority2tokenType(n)
	local p2t = {"WS", "INTEGER", "KW"}
	return p2t[n]
end

require('calc_lexer')
local lexer = Calc_lexer(fa, symbol2factor, code, priority2tokenType)


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
print()