function csv2table(path, cellFunction)
	if not cellFunction then
		cellFunction = function (cell) return cell end
	end
	local file = io.open(path, "r")
	local csv = file:read("a")
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

	return result
end