local function TableConcat(t1, t2)
	for i = 1, #t2 do
		t1[#t1+1] = t2[i]
	end

	return t1
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

local function getFirstConcat(concatTree)
	assert(#concatTree.children ~=0 )
	if concatTree.children[1].name == "Option" then
		local f = getFirstExpr(concatTree.children[1].children[2])
		if not haveEps(f) then
			return TableConcat(f, {{domain = "$EPS", value = "$EPS"}})
		else
			return f
		end
	elseif concatTree.children[1].name == "Grouping" then
		return getFirstExpr(concatTree.children[1].children[2])
	end
	if not concatTree.children[1].domain then return {} end
	if concatTree.children[1].domain == "NTERM" or concatTree.children[1].domain == "TERM" then
		return { concatTree.children[1] }
	elseif concatTree.children[1].domain == "LPAREN" or concatTree.children[1].domain == "LPAREN_CURVE" then
		return getFirstExpr(concatTree.children[2])
	end
end

local function getFirstAltern(alternTree, idx)
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


local function union(set1, set2)
	local set = {}
	for key, value in pairs(set1) do
		set[key] = value
	end
	for key, value in pairs(set2) do
		set[key] = value
	end

	return set
end

local function expandFirst(symb, first, expandedFirst)
	if expandedFirst[symb] then
		return
	end

	expandedFirst[symb] = {}
	local productions = first[symb]
	for _, prod in ipairs(productions) do
		if prod.domain == "TERM" or prod.domain == "$EPS" then
			expandedFirst[symb][prod.value] = true
		elseif prod.domain == "NTERM" then
			expandFirst(prod.value, first, expandedFirst)
			expandedFirst[symb] = union(expandedFirst[symb], expandedFirst[prod.value])
		end
	end
end


function getFirst(ast)

    local first = {}

    for left, right in pairs(ast.rules) do
        first[left] = getFirstExpr(right)
    end

    local expandedFirst = {}

    for _, nterm in ipairs(ast.nterms) do
        expandFirst(nterm, first, expandedFirst)
        local str = ""
        for name, _ in pairs(expandedFirst[nterm]) do
            str = str .. "\"" .. name .. "\", "
        end
        print(string.format("FIRST(%s) = {%s}", nterm, str))
    end

    return expandedFirst
end