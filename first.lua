local function TableConcat(t1, t2)
	local map = {}
	for _, t in ipairs(t1) do
		map[t.value] = t
	end
	for _, t in ipairs(t2) do
		map[t.value] = t
	end

	local res = {}

	for _, t in pairs(map) do
		table.insert(res, t)
	end

	return res
end

local function haveEps(aFirst)
	for _, f in ipairs(aFirst) do
		if f.domain == "$EPS" then return true end
	end

	return false
end

local function woEps(aFirst)
	local res = {}
	for _, f in ipairs(aFirst) do
		if f.domain ~= "$EPS" then table.insert(res, f) end
	end

	return res
end

local first = {}
local follow = {}

local function getFirstConcat(concatTree)
	if not concatTree.domain then return {} end
	if concatTree.domain == "$EPS" then
		return { {domain = "$EPS", value = "$EPS"} }
	elseif concatTree.domain == "TERM" then
		return { concatTree }
	elseif concatTree.domain == "NTERM" then
		return first[concatTree.value]
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

local function isIncl(map1, map2)
	for name, _ in pairs(map1) do
		if not map2[name] then return false end
	end

	return true
end

local function isInclList(list1, list2)
	local map2 = {}
	for _, l2 in ipairs(list2) do
		map2[l2.value] = l2
	end
	for _, l1 in ipairs(list1) do
		if not map2[l1.value] then return false end
	end

	return true
end

local woRepT2 = {}
local function isDiff(t1, t2)
	if type(t1) ~= "table" then return false end
	local valmap1 = {}
	for _, dom in ipairs(t1) do
		valmap1[dom.value] = true
	end
	local valmap2 = {}
	woRepT2 = {}
	for _, dom in ipairs(t2) do
		if not valmap2[dom.value] then
			valmap2[dom.value] = true
			table.insert(woRepT2, dom)
		end
	end

	return not (isIncl(valmap1, valmap2) and isIncl(valmap2, valmap1))
end

function getFirst(ast)
	first = {}
	
	for _, nterm in ipairs(ast.nterms) do
		first[nterm.value] = {}
	end
	
	local changed = true
	while changed do
		changed = false
		for left, right in pairs(ast.rules) do
			local firstExpr = getFirstExpr(right)

			if isDiff(first[left], firstExpr) then
				changed = true
				first[left] = woRepT2
			end
		end
	end
    
	for _, nterm in ipairs(ast.nterms) do
		-- expandFirst(nterm)
		local str = ""
		for _, dom in ipairs(first[nterm.value]) do
			if dom.domain == "TERM" then
				str = str .. "\"" .. dom.value .. "\", "
			else
				str = str .. dom.value .. ", "
			end
		end
		print(string.format("FIRST(%s) = {%s}", nterm.value, str))
	end

    return first
end

function getFollow(ast)
	folow = {}

	for _, nterm in ipairs(ast.nterms) do
		follow[nterm.value] = {}
	end
	table.insert(follow[ast.axiom.value], { domain = "$", value = "$" })

	for left, exprAstNode in pairs(ast.rules) do
		for _, altAstNode in ipairs(exprAstNode.children) do
			for i, dom in ipairs(altAstNode.children) do
				if dom.domain == "NTERM" then
					local firstV = getFirstAltern(altAstNode, i + 1)
					follow[dom.value] = TableConcat(follow[dom.value], woEps(firstV))
				end
			end
		end
	end

	local changed = true
	while changed do
		changed = false
		for left, exprAstNode in pairs(ast.rules) do
			for _, altAstNode in ipairs(exprAstNode.children) do
				for i, dom in ipairs(altAstNode.children) do
					if dom.domain == "NTERM" then
						local firstV = getFirstAltern(altAstNode, i + 1)
						if haveEps(firstV) or #firstV == 0 then
							if not isInclList(follow[left], follow[dom.value]) then
								changed = true
								follow[dom.value] = TableConcat(follow[dom.value], follow[left])
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
		for _, dom in ipairs(follow[nterm.value]) do
			if dom.domain == "TERM" then
				str = str .. "\"" .. dom.value .. "\", "
			else
				str = str .. dom.value .. ", "
			end
		end
		print(string.format("FOLLOW(%s) = {%s}", nterm.value, str))
	end

	return follow
end