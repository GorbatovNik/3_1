-- require('class')

Lexer = class("Lexer")
    :field("fa")
    :field("symbol2factor")
    :field("priority2tokenType")
    :field("code")
    :field("line", 1)  -- 1..l
    :field("pos", 1)   -- 1..p
    :field("index", 1) -- 1..i
    :field("messages", {})
:done()

function Lexer:_construct(aFa, aSymbol2factor, aCode, aPriority2tokenType)
    self.fa = aFa
    self.symbol2factor = aSymbol2factor
    self.code = aCode
    self.priority2tokenType = aPriority2tokenType
end

local function takeAny(t)
    if type(t) == "table" then
        for any, _ in pairs(t) do
            return any
        end
    end

    return t
end

function Lexer:nextToken()


    if self.index == string.len(self.code) + 2 then return end
    local startIndex = self.index
    local startLine = self.line
    local startPos = self.pos
    local currChar = (string.len(self.code) < self.index) and string.char(27) or string.sub(self.code, self.index, self.index)
    local currFactor = self.symbol2factor(currChar)
    local currState = self.fa.q0
    local lastFinishState = nil
    local lastFinishValue = nil
    local lastFinishLine = nil
    local lastFinishPos = nil
    local lastFinishIndex = nil
    local value = ""
    while self.fa.d[currState][currFactor] and self.fa.d[currState][currFactor] ~= "" do
        value = value .. currChar
        currState = takeAny(self.fa.d[currState][currFactor])
        if self.fa.F[currState] then
            lastFinishState = currState
            lastFinishValue = value
            lastFinishPos = self.pos
            lastFinishLine = self.line
            lastFinishIndex = self.index
        end
        self.index = self.index + 1
        self.pos = self.pos + 1
        if currChar == "\n" then
            self.line = self.line + 1
            self.pos = 1
        end
        currChar = (string.len(self.code) < self.index) and string.char(27) or string.sub(self.code, self.index, self.index)
        currFactor = self.symbol2factor(currChar)
    end
    if lastFinishState then
        local tokenType = self.priority2tokenType(self.fa.F[lastFinishState])
        local domain = tokenType
        if tokenType == "KW" then
            if value == "=" then
                domain = "ASSIGN"
            elseif value == string.char(27) then
                domain = "END_OF_PROGRAM"
            elseif value == "\n" then
                domain = "NL"
            else
                domain = value
            end
            value = nil
        elseif tokenType == "TERM" then
            value = string.sub(value, 2, string.len(value) - 1)
        end
        local token = {startPos = startPos, finishPos = lastFinishPos, startLine = startLine, finishLine = lastFinishLine, domain = domain, value = value}
        self.index = lastFinishIndex
        self.line = lastFinishLine
        self.pos = lastFinishPos
        if string.sub(self.code, self.index, self.index) == "\n" then
            self.line = self.line + 1
            self.pos = 1
        else
            self.pos = self.pos + 1
        end
        self.index = self.index + 1

        if tokenType == "WS" or tokenType == "COMMENT" then
            return self:nextToken()
        else
            return token
        end
    else
        table.insert(self.messages, "Error (" .. tostring(startLine) .. ", " .. tostring(startPos) .. "): unexpected '" .. string.sub(self.code, self.index, self.index) .. "' found")
        self.index = self.index + 1
        self.pos = self.pos + 1

        return self:nextToken()
    end
end