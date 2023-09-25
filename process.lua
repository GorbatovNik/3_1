function process(ppt, tokens)
	-- У языка есть домены. У токена есть домен. У грамматики доменов нет. У грамматики есть терминалы и нетерминалы.
	-- Сейчас я рассматриваю язык описания грамматик LGD (Langauge of Grammar Description).
	-- Грамматику, описывающую язык LGD, я назову GLGD. Каждый домен LGD сопряжен с некоторым терминалом из GLGD.
	-- Домен отличается от терминала тем, что терминал начинается и заканчивается апострофами.
	-- Домену END_OG_PROGRAM не соответвует ни один терминал (хотя должен).

	local rules = {} -- здесь будут правила грамматики GLGD, и если их применять последовательно, то получится исходное слово
					 -- правильнее было бы здесь использовать терминалы, но гораздо удобнее заменить их доменами.
	local domains = {"$AXIOM", "$NTERM", "$TERM", "$RULE", "NTERM", "TERM", "ASSIGN", "NL", "END_OF_PROGRAM", "$EPS"}
	local domains_map = list2map(domains)
	local nterms = {}
	for nterm, _ in pairs(ppt) do table.insert(nterms, nterm) end
	local nterms_map = list2map(nterms)
	local function topDownParse()
		local stack = {"END_OF_PROGRAM", "Grammar"} -- в стеке тоже домены (хотя должны быть терминалы)
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

	-- Начинаю строить дерево разбора для слова языка LGD
	-- Вершинами будут нетерминалы, а листьями - токены
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

	-- а здесь уже не будет никаких токенов. Все листья в правилах - это списки из нетерминалов и терминалов.
	-- Причем эти нетерминалы и терминалы принадлежат новой грамматике, описанием которой на языке LGD является входное слово.
	-- Назовем новую грамматику NG (New Grammar). А язык, который эта грамматика описывет, - LNG
	local function createAST()
		local ast = {axiom = tree.subtree[2 + 1].value, terms = {}, nterms = {}, rules = {}}
		table.insert(ast.nterms, ast.axiom)
		local function addRec(node, list, func, subtreeNodeIdx, subtreeListIdx)
			func(node)
			if #list.subtree == 0 then return end
			if not subtreeNodeIdx then subtreeNodeIdx = 1 end
			if not subtreeListIdx then subtreeListIdx = 2 end
			addRec(list.subtree[subtreeNodeIdx], list.subtree[subtreeListIdx], func)
		end
		addRec(tree.subtree[7 + 1], tree.subtree[8 + 1], function (node)
			table.insert(ast.terms, node.value)
		end)
		if #tree.subtree[5 + 1].subtree>0 then
			addRec(tree.subtree[5 + 1].subtree[2].subtree[1], tree.subtree[5 + 1].subtree[2].subtree[2], function (node)
				table.insert(ast.nterms, node.value)
			end)
		end

		local function getAstAltern(rightSideAltNode)
			local astAltern = {name = "Altern", children = {}}
			if #rightSideAltNode.subtree == 1 then -- $EPS
				table.insert(astAltern.children, rightSideAltNode.subtree[1].domain)
			else
				addRec(rightSideAltNode.subtree[1], rightSideAltNode.subtree[2], function(node)
					table.insert(astAltern.children, node.subtree[1].value)
				end)
			end

			return astAltern
		end
		local function getAstExpr(ruleNode)
			local astExprNode = {name = "Expr", children = {}}
			addRec(ruleNode.subtree[4], ruleNode.subtree[6], function (rightSideAltNode)
				local astAlternNode = getAstAltern(rightSideAltNode)
				table.insert(astExprNode.children, astAlternNode)
			end, 1, 3)

			return astExprNode
		end
		-- local function
		local left
		local addRules
		local function addRSAListOrRuleListOrEnd(node)
			if #node.subtree == 0 then return end
			if #node.subtree == 1 then
				addRules(node.subtree[1])

				return
			end
			if #node.subtree == 2 then
				local astAltern = getAstAltern(node.subtree[1])
				table.insert(ast.rules[left].children, astAltern)
				if #node.subtree[2].subtree > 0 then  
					addRSAListOrRuleListOrEnd(node.subtree[2].subtree[3])
				end

				return
			end
		end
		addRules = function (rulesNode)
			local astExprNode = {name = "Expr", children = {}}
			left = rulesNode.subtree[2].value
			local astAltern = getAstAltern(rulesNode.subtree[4])
			table.insert(astExprNode.children, astAltern)
			ast.rules[left] = astExprNode
			if #rulesNode.subtree[5].subtree > 0 then  
				addRSAListOrRuleListOrEnd(rulesNode.subtree[5].subtree[3])
			end
		end
		addRules(tree.subtree[11 + 1])

		return ast
	end

	local ast = createAST()

	require('first')
	local first = getFirst(ast)
	local follow = getFollow(ast)

	local delta = {}
	for _, nterm in pairs(ast.nterms) do
		delta[nterm] = {}
		for _, term in pairs(ast.terms) do
			local domen =  string.sub(term, 2, string.len(term) - 1)
			delta[nterm][domen] = {"ERROR"}
		end
		delta[nterm]["END_OF_PROGRAM"] = {"ERROR"}
	end

	for x, uExpr in pairs(ast.rules) do
		for _, uAlt in ipairs(uExpr.children) do
			local u = uAlt.children
			local firstU = getFirstAltern(uAlt)
			local haveEps = false
			for _, a in ipairs(firstU) do
				-- local a = {domain = a.domain, value = a.value}
				if a == "$EPS" then
					haveEps = true
				else
					if isTerm(a) then
						a = string.sub(a, 2, string.len(a) - 1)
					end
					if #delta[x][a] ~= 1 or delta[x][a][1] ~= "ERROR" then
						error("not LL(1)")
					end
					delta[x][a] = u
				end
			end
			if haveEps then
				local followX = follow[x]
				for _, b in ipairs(followX) do
					if isTerm(b) then
						b = string.sub(b, 2, string.len(b) - 1)
					end
					if b == "$" then
						b = "END_OF_PROGRAM"
					end
					if #delta[x][b] ~= 1 or delta[x][b][1] ~= "ERROR" then
						error("not LL(1)")
					end
					delta[x][b] = u
				end
			end
		end
	end
	local ppt2 = {}
	for nterm, tab in pairs(delta) do
		ppt2[nterm] = {}
		for term, _ in pairs(tab) do
			ppt2[nterm][term] = {}
			for _, a in ipairs(delta[nterm][term]) do
				if a == "ERROR" or a == "$EPS" then
					ppt2[nterm][term] = (a == "ERROR") and {"ERROR"} or {"eps"}
					break
				end
				table.insert(ppt2[nterm][term], isTerm(a) and string.sub(a, 2, string.len(a) - 1) or a)
			end
		end
	end

	-- for nt1, nt1tab in pairs(ppt) do
	-- 	for t1, t1tab in pairs(nt1tab) do
	-- 		local t2tab = ppt2[nt1][t1]
	-- 		assert(#t1tab == #t2tab)
	-- 		if isDiff(t1tab, t2tab) then
	-- 			local bef = ""
	-- 			for _, el in ipairs(t1tab) do bef = bef .. el .. ", " end
	-- 			local aft = ""
	-- 			for _, el in ipairs(t2tab) do aft = aft .. el .. ", " end
	-- 			print(string.format("[%s][%s]:\nBEFORE: (%s)\nAFTER: (%s)", nt1, t1, bef, aft))
	-- 		end
	-- 	end
	-- end

	return ppt2
end
