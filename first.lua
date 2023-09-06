local function TableConcat(t1, t2)
	local map = {}
	for _, t in ipairs(t1) do
		map[t] = true
	end
	for _, t in ipairs(t2) do
		map[t] = true
	end

	local res = {}

	for t, _ in pairs(map) do
		table.insert(res, t)
	end

	return res
end

local function haveEps(aFirst)
	for _, f in ipairs(aFirst) do
		if f == "$EPS" then return true end
	end

	return false
end

local function woEps(aFirst)
	local res = {}
	for _, f in ipairs(aFirst) do
		if f ~= "$EPS" then table.insert(res, f) end
	end

	return res
end

local first = {}
local follow = {}

function isTerm(str)
	return string.sub(str, 1, 1) == "\""
end

local function getFirstConcat(concat)
	if isTerm(concat) or concat == "$EPS" then
		return { concat }
	else
		return first[concat]
	end
end

function getFirstAltern(alternTree, idx)
	if not idx then idx = 1 end 
	if not alternTree.children then return {} end
	if #alternTree.children < idx then return {} end
	-- assert(#alternTree.children ~= 0) 
	local firstFirstConcat =  getFirstConcat(alternTree.children[idx])
	local otherFirstConcat =  getFirstAltern(alternTree, idx + 1)

	if not otherFirstConcat or #otherFirstConcat == 0 then
		return firstFirstConcat
	end
	
	if haveEps(firstFirstConcat) then
		return TableConcat(woEps(firstFirstConcat), otherFirstConcat)
	end

	return firstFirstConcat
end

local function getFirstExpr(exprTree)
	local firstList = {}
	for _, alternChild in ipairs(exprTree.children) do
		firstList = TableConcat(firstList, getFirstAltern(alternChild))
	end

	return firstList
end

-- local function isIncl(map1, map2)
-- 	for name, _ in pairs(map1) do
-- 		if not map2[name] then return false end
-- 	end

-- 	return true
-- end

local function isInclList(list1, list2)
	local map2 = {}
	for _, l2 in ipairs(list2) do
		map2[l2] = l2
	end
	for _, l1 in ipairs(list1) do
		if not map2[l1] then return false end
	end

	return true
end

function isDiff(list1, list2)
	return not (isInclList(list1, list2) and isInclList(list2, list1))
end

function getFirst(ast)
	first = {}
	
	for _, nterm in ipairs(ast.nterms) do
		first[nterm] = {}
	end
	
	local changed = true
	while changed do
		changed = false
		for left, right in pairs(ast.rules) do
			local firstExpr = getFirstExpr(right)

			if isDiff(first[left], firstExpr) then
				changed = true
				first[left] = firstExpr
			end
		end
	end
    
	for _, nterm in ipairs(ast.nterms) do
		-- expandFirst(nterm)
		local str = ""
		for _, el in ipairs(first[nterm]) do
			str = str .. el .. ", "
		end
		print(string.format("FIRST(%s) = {%s}", nterm, str))
	end

    return first
end

function getFollow(ast)
	folow = {}

	for _, nterm in ipairs(ast.nterms) do
		follow[nterm] = {}
	end
	table.insert(follow[ast.axiom], "$")

	for left, exprAstNode in pairs(ast.rules) do
		for _, altAstNode in ipairs(exprAstNode.children) do
			for i, el in ipairs(altAstNode.children) do
				if not isTerm(el) and el ~= "$EPS" then
					local firstV = getFirstAltern(altAstNode, i + 1)
					if not follow[el] then
						print()
					end
					follow[el] = TableConcat(follow[el], woEps(firstV))
				end
			end
		end
	end

	local changed = true
	while changed do
		changed = false
		for left, exprAstNode in pairs(ast.rules) do
			for _, altAstNode in ipairs(exprAstNode.children) do
				for i, el in ipairs(altAstNode.children) do
					if not isTerm(el) and el ~= "$EPS" then
						local firstV = getFirstAltern(altAstNode, i + 1)
						if haveEps(firstV) or #firstV == 0 then
							if not isInclList(follow[left], follow[el]) then
								changed = true
								follow[el] = TableConcat(follow[el], follow[left])
							end
						end
					end
				end
			end
		end
	end
	for _, nterm in ipairs(ast.nterms) do
		-- expandFirst(nterm)
		local str = ""
		for _, el in ipairs(follow[nterm]) do
			str = str .. el .. ", "
		end
		print(string.format("FOLLOW(%s) = {%s}", nterm, str))
	end

	return follow
end