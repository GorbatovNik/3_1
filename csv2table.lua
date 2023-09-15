function csv2table(path)
	local file = io.open(path, "r")
	local csv = file:read("a")

	return csvString2Table(csv)
end

function csvString2Table(csv)
	local function cellFunction(cell)
		local tab = {}
		for c in string.gmatch(cell, "([^ ]+)") do
			table.insert(tab, c)
		end

		return tab
	end
	csv = csv .. "\n"
	local firstLine = string.match(csv, "([^\n]*)\n")
	local columns = {}
	local result = {}
	local function addColumn(name) table.insert(columns, name) end
	string.gsub(firstLine, ";([^;]+)", addColumn)
	local i = 1
	for line in string.gmatch(csv, "([^\n]*)\n") do
		line = line .. ";"
		if i > 1 then
			local j = 1
			local row
			for cell in string.gmatch(line, "([^;]+);") do
				if j == 1 then
					result[cell] = {}
					row = cell
				else
					result[row][columns[j - 1]] = cellFunction(cell)
				end
				j = j + 1
			end
		end

		i = i + 1
	end

	return result, columns
end

function table2csvString(ppt)
	local num = 1
	local columnsNum = {}
	local columnsList = {}
	for nterm, cont in pairs(ppt) do
		for colName, ccont in pairs(cont) do
			columnsNum[colName] = num
			table.insert(columnsList, colName)
			num = num + 1
		end
		break
	end
	local csvString = ""
	for _, col in ipairs(columnsList) do
		csvString = csvString .. ";" .. col
	end
	csvString = csvString .. "\n"
	for nterm, cont in pairs(ppt) do
		local str = nterm .. ";"
		local row = {}
		for colName, ccont in pairs(cont) do
			local cellStr = ""
			for _, cellEl in ipairs(ccont) do
				cellStr = cellStr .. cellEl .. " "
			end
			cellStr = string.sub(cellStr, 1, #cellStr - 1)
			row[columnsNum[colName]] = cellStr
		end
		for _, rcont in ipairs(row) do
			str = str .. rcont .. ";"
		end
		str = string.sub(str, 1, #str - 1)
		csvString = csvString  .. str .. "\n"
	end

	return csvString
end

function table2csv(ppt, path)
	local file = io.open(path, "w")
	local stri = table2csvString(ppt)
	stri = string.sub(stri, 1, #stri - 1)
	file:write(stri)
	file:close()
end