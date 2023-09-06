-- require('class')
-- require('FiniteAutomaton')
local V = {"d", "+", "-", "*", "/", "(", ")", "ws", "eof", "oth"}
local Q = {"q0", "FInt", "FKW", "FWS"}
local d = {
	q0 = {
        d = {"FInt"},
        eof = {"FKW"},
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
	if c == "+" or c == "-" or c == "*" or c == "/" or c == "(" or c == ")" then
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

function calc_process(ppt)
	local rules = {}
	local domains = {"+", "-", "*", "/", "(", ")", "INTEGER", "END_OF_PROGRAM"}
	local domains_map = list2map(domains)
	local nterms = {}
	for nterm, _ in pairs(ppt) do table.insert(nterms, nterm) end
	local nterms_map = list2map(nterms)
	local function topDownParse()
		local stack = {"END_OF_PROGRAM", "E"}
		local token = tokens[1]
		local tokenIdx = 2
		while true do
			local x = stack[#stack]
			if tokenIdx == 19 then
				print()
			end
			if domains_map[x] then
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
			if domains_map[t] then
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
	local evalE, evalEh, evalT, evalTh, evalF
	evalE = function (node)
		local Eh = evalEh(node.subtree[2])
		local T = evalT(node.subtree[1])
		if Eh then
			return Eh.op(T, Eh.val)
		else 
			return T
		end
	end
	evalEh = function (node)
		if #node.subtree == 0 then return end
		local Eh = evalEh(node.subtree[3])
		local T = evalT(node.subtree[2])
		local op = node.subtree[1].domain == "+" and function (a, b) return a+b end
										  or  function (a, b) return a-b end
		if Eh then
			return { op = op, val = Eh.op(T, Eh.val) }
		else
			return { op = op, val = T }
		end
	end
	evalT = function (node)
		local F = evalF(node.subtree[1])
		local Th = evalTh(node.subtree[2])
		if Th then
			return Th.op(F, Th.val)
		else
			return F
		end
	end
	evalTh = function (node)
		if #node.subtree == 0 then return end
		local Th = evalEh(node.subtree[3])
		local F = evalF(node.subtree[2])
		local op = node.subtree[1].domain == "*" and function (a, b) return a*b end
										  or  function (a, b) return a/b end
		if Th then
			return { op = op, val = Th.op(F, Th.val) }
		else
			return { op = op, val = F }
		end
	end
	evalF = function (node)
		if #node.subtree == 1 then
			return node.subtree[1].value
		else
			return evalE(node.subtree[2])
		end
	end

	print(string.format("%s = %f", code, evalE(tree)))
end