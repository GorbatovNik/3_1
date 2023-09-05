function process(ppt, tokens)
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
			if tokenIdx == 19 then
				print()
			end
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

	local function createAST()
		local ast = {axiom = tree.subtree[2 + 1], terms = {}, nterms = {}, rules = {}}
		table.insert(ast.nterms, ast.axiom)
		local function addRec(node, list, func, subtreeNodeIdx, subtreeListIdx)
			func(node)
			if #list.subtree == 0 then return end
			if not subtreeNodeIdx then subtreeNodeIdx = 1 end
			if not subtreeListIdx then subtreeListIdx = 2 end
			addRec(list.subtree[subtreeNodeIdx], list.subtree[subtreeListIdx], func)
		end
		addRec(tree.subtree[7 + 1], tree.subtree[8 + 1], function (node)
			table.insert(ast.terms, node)
		end)
		if #tree.subtree[5 + 1].subtree>0 then
			addRec(tree.subtree[5 + 1].subtree[2].subtree[1], tree.subtree[5 + 1].subtree[2].subtree[2], function (node)
				table.insert(ast.nterms, node)
			end)
		end

		local function getAstAltern(rightSideAltNode)
			local astAltern = {name = "Altern", children = {}}
			if #rightSideAltNode.subtree == 1 then -- $EPS
				table.insert(astAltern.children, rightSideAltNode.subtree[1])
			else
				addRec(rightSideAltNode.subtree[1], rightSideAltNode.subtree[2], function(node)
					table.insert(astAltern.children, node.subtree[1])
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
	for nterm, tab in pairs(ppt) do
		delta[nterm] = {}
		for term, _ in pairs(tab) do
			delta[nterm][term] = {"ERROR"}
		end
	end

	for x, uExpr in pairs(ast.rules) do
		for _, uAlt in ipairs(uExpr.children) do
			local u = uAlt.children
			local firstU = getFirstAltern(uAlt)
			local haveEps = false
			for _, a in ipairs(firstU) do
				local a = {domain = a.domain, value = a.value}
				if a.domain == "$EPS" then
					haveEps = true
				else
					if a.value == "$TERM_EPS" then
						a.value = "$EPS"
					end
					if x == "NLsOpt" and a.value == "NL" then
						print("1")
					end
					if #delta[x][a.value] ~= 1 or delta[x][a.value][1] ~= "ERROR" then
						error()
					end
					delta[x][a.value] = u
				end
			end
			if haveEps then
				local followX = follow[x]
				for _, b in ipairs(followX) do
					local b = {domain = b.domain, value = b.value}
					if b.domain == "$" then
						b = {domain = "END_OF_PROGRAM", value = "END_OF_PROGRAM"}
					end
					if b.value == "$TERM_EPS" then
						b.value = "$EPS"
					end
					if x == "NLsOpt" and b.value == "NL" then
						print("1")
					end
					if #delta[x][b.value] ~= 1 or delta[x][b.value][1] ~= "ERROR" then
						error()
					end
					delta[x][b.value] = u
				end
			end
		end
	end
	local ppt2 = {}
	for nterm, tab in pairs(ppt) do
		ppt2[nterm] = {}
		for term, _ in pairs(tab) do
			ppt2[nterm][term] = {}
			for _, a in ipairs(delta[nterm][term]) do
				if a == "ERROR" or a.domain == "$EPS" then
					ppt2[nterm][term] = (a == "ERROR") and {"ERROR"} or {"eps"}
					break
				end
				if a.domain == "TERM" and a.value == "$TERM_EPS" then
					table.insert(ppt2[nterm][term], "$EPS")
				else
					table.insert(ppt2[nterm][term], a.value)
				end
			end
		end
	end
	return ppt2
end
