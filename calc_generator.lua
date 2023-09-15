function getCode(path)
    print(path)
    local file = io.open(path, "r")
    local code = file:read("*all")
    file:close()

    return "-- " .. path .. ":\n" .. code .. "\n"
end

function calc_generate(csvStringForParser)
    local classCode = getCode(".\\..\\class.lua")
    local automatCode = getCode(".\\..\\FiniteAutomaton.lua")
    local lexerCode = getCode(".\\calculator\\calc_lexer.lua")
    local parserCode = getCode(".\\calculator\\calc_parser.lua")
    local csv2tableCode = getCode("csv2table.lua")
    local mainCode = [==[
csvStringForParser = [[]==] .. csvStringForParser .. [==[]]
print("expr filename = " .. arg[1])
file = io.open(arg[1], "r")
if file then
	print(file:read("a"))
else
	error("file cannot found")
end
ppt = csvString2Table(csvStringForParser)
print("ppt is nil = " .. tostring(ppt))
calc_process(ppt, arg[1])
]==]
    local code = classCode .. automatCode .. lexerCode .. parserCode .. csv2tableCode .. mainCode

    return code
end