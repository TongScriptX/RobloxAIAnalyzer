-- Reader模块 - 脚本读取
local Reader = {}

local HttpService = game:GetService("HttpService")

Reader.apiUrl = "https://api.lua.expert/decompile"
Reader.minRequestInterval = 0.6
Reader.lastRequestAt = 0
Reader.debug = true

local function debugLog(message)
    if Reader.debug then
        print("[Reader DEBUG] " .. tostring(message))
    end
end

local function base64Encode(data)
    local ok, encoded = pcall(function()
        return HttpService:Base64Encode(data)
    end)
    if ok and encoded then
        debugLog("base64 via HttpService:Base64Encode, inputBytes=" .. tostring(#data) .. ", outputLen=" .. tostring(#encoded))
        return encoded
    end

    if base64_encode then
        local result = base64_encode(data)
        debugLog("base64 via global base64_encode, inputBytes=" .. tostring(#data) .. ", outputLen=" .. tostring(#result))
        return result
    end

    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local result = ((data:gsub(".", function(char)
        local bits = ""
        local byte = char:byte()
        for i = 8, 1, -1 do
            bits = bits .. ((byte % 2^i - byte % 2^(i - 1) > 0) and "1" or "0")
        end
        return bits
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(chunk)
        if #chunk < 6 then
            return ""
        end

        local value = 0
        for i = 1, 6 do
            if chunk:sub(i, i) == "1" then
                value = value + 2^(6 - i)
            end
        end

        return alphabet:sub(value + 1, value + 1)
    end) .. ({ "", "==", "=" })[#data % 3 + 1])
    debugLog("base64 via Lua fallback, inputBytes=" .. tostring(#data) .. ", outputLen=" .. tostring(#result))
    return result
end

-- 检测字节码读取函数
local function detectBytecodeReader()
    if getscriptbytecode then
        return "getscriptbytecode", getscriptbytecode
    end

    if syn and syn.getscriptbytecode then
        return "syn.getscriptbytecode", syn.getscriptbytecode
    end

    return nil, nil
end

Reader.decompilerName, Reader.bytecodeFunc = detectBytecodeReader()

local function collectManualScripts()
    local scripts = {}
    local services = {
        game:GetService("Workspace"),
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterGui"),
        game:GetService("StarterPack"),
        game:GetService("StarterPlayer"),
        game:GetService("Players")
    }

    for _, service in ipairs(services) do
        for _, obj in ipairs(service:GetDescendants()) do
            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") or obj:IsA("Script") then
                table.insert(scripts, obj)
            end
        end
    end

    return scripts
end

-- 检测getscripts函数
local function detectGetScripts()
    return function()
        local merged = {}
        local seen = {}

        if getscripts then
            local ok, scriptList = pcall(getscripts)
            if ok and type(scriptList) == "table" then
                for _, script in ipairs(scriptList) do
                    if typeof(script) == "Instance" and not seen[script] then
                        seen[script] = true
                        table.insert(merged, script)
                    end
                end
            else
                debugLog("getscripts failed or returned non-table: " .. tostring(scriptList))
            end
        end

        for _, script in ipairs(collectManualScripts()) do
            if not seen[script] then
                seen[script] = true
                table.insert(merged, script)
            end
        end

        debugLog("getAllScripts merged count=" .. tostring(#merged))
        return merged
    end
end

Reader.getScriptsFunc = detectGetScripts()

Reader.cache = {}

function Reader:getAllScripts()
    local success, scripts = pcall(self.getScriptsFunc)
    if success then
        return scripts
    end
    return {}
end

function Reader:getHttpModule()
    return _G.AIAnalyzer and _G.AIAnalyzer.Http
end

function Reader:requestDecompile(encodedBytecode)
    local Http = self:getHttpModule()
    if not Http then
        debugLog("requestDecompile aborted: Http module not initialized")
        return nil, "Http module not initialized"
    end

    if not Http:canRequestExternal() then
        debugLog("requestDecompile aborted: executor cannot request external URLs")
        return nil, "Executor does not support external HTTP requests"
    end

    local body = HttpService:JSONEncode({
        script = encodedBytecode
    })
    debugLog("POST " .. self.apiUrl .. " bodyLen=" .. tostring(#body))

    local response = Http:request({
        Url = self.apiUrl,
        Method = "POST",
        Headers = {
            ["content-type"] = "application/json"
        },
        Body = body
    })

    debugLog("response status=" .. tostring(response and response.statusCode or "nil")
        .. " bodyLen=" .. tostring(response and response.body and #tostring(response.body) or 0))

    if not response or response.statusCode ~= 200 then
        return nil, (response and response.body) or "no response"
    end

    return response.body
end

function Reader:extractBytecode(scriptInstance)
    if not self.bytecodeFunc then
        debugLog("extractBytecode aborted: no bytecode reader")
        return nil, "No bytecode reader available"
    end

    debugLog("extractBytecode start: " .. tostring(scriptInstance:GetFullName()))
    local success, bytecode = pcall(self.bytecodeFunc, scriptInstance)
    if not success then
        debugLog("extractBytecode failed: " .. tostring(bytecode))
        return nil, "Failed to read bytecode: " .. tostring(bytecode)
    end

    if not bytecode or bytecode == "" then
        debugLog("extractBytecode returned empty bytecode")
        return nil, "Empty bytecode"
    end

    debugLog("extractBytecode ok: bytes=" .. tostring(#bytecode))
    return bytecode
end

function Reader:fetchDecompiledSource(scriptInstance)
    debugLog("fetchDecompiledSource start: " .. tostring(scriptInstance:GetFullName()))
    local bytecode, bytecodeErr = self:extractBytecode(scriptInstance)
    if not bytecode then
        debugLog("fetchDecompiledSource abort: " .. tostring(bytecodeErr))
        return nil, bytecodeErr
    end

    local elapsed = os.clock() - self.lastRequestAt
    if elapsed < self.minRequestInterval then
        debugLog(string.format("rate limit wait: %.3fs", self.minRequestInterval - elapsed))
        task.wait(self.minRequestInterval - elapsed)
    end

    local encoded = base64Encode(bytecode)
    local source, requestErr = self:requestDecompile(encoded)
    self.lastRequestAt = os.clock()

    if not source or source == "" then
        debugLog("fetchDecompiledSource failed: " .. tostring(requestErr))
        return nil, "lua.expert request failed: " .. tostring(requestErr)
    end

    debugLog("fetchDecompiledSource ok: sourceLen=" .. tostring(#source))
    return source
end

function Reader:readScript(scriptInstance)
    if not scriptInstance then
        return nil, "Invalid script instance"
    end
    
    local cacheKey = tostring(scriptInstance)
    if self.cache[cacheKey] then
        debugLog("readScript cache hit: " .. tostring(scriptInstance:GetFullName()))
        return self.cache[cacheKey]
    end

    local source, err = self:fetchDecompiledSource(scriptInstance)
    if source and #source > 0 then
        local result = {
            name = scriptInstance.Name,
            className = scriptInstance.ClassName,
            path = self:getScriptPath(scriptInstance),
            source = source,
            size = #source,
            lines = select(2, source:gsub("\n", "\n")) + 1
        }
        self.cache[cacheKey] = result
        debugLog("readScript cached: " .. tostring(result.path) .. " lines=" .. tostring(result.lines))
        return result
    end

    debugLog("readScript failed: " .. tostring(err))
    return nil, err or "Failed to decompile script"
end

-- 获取脚本路径
function Reader:getScriptPath(scriptInstance)
    local path = scriptInstance.Name
    local current = scriptInstance.Parent
    
    while current and current ~= game do
        path = current.Name .. "." .. path
        current = current.Parent
    end
    
    return path
end

-- 批量读取脚本
function Reader:readMultipleScripts(scriptInstances, maxCount)
    maxCount = maxCount or 50
    local results = {}
    local errors = {}
    
    local count = 0
    for _, scriptInstance in ipairs(scriptInstances) do
        if count >= maxCount then
            break
        end
        
        local result, err = self:readScript(scriptInstance)
        if result then
            table.insert(results, result)
            count = count + 1
        else
            table.insert(errors, {
                name = scriptInstance.Name,
                error = err
            })
        end
    end
    
    return results, errors
end

-- 按名称搜索脚本
function Reader:findScriptsByName(namePattern)
    local scripts = self:getAllScripts()
    local matches = {}
    local pattern = namePattern:lower()
    
    for _, script in ipairs(scripts) do
        if script.Name:lower():find(pattern) then
            table.insert(matches, script)
        end
    end
    
    return matches
end

-- 按路径搜索脚本
function Reader:findScriptsByPath(pathPattern)
    local scripts = self:getAllScripts()
    local matches = {}
    local pattern = pathPattern:lower()
    
    for _, script in ipairs(scripts) do
        local path = self:getScriptPath(script)
        if path:lower():find(pattern) then
            table.insert(matches, script)
        end
    end
    
    return matches
end

-- 搜索脚本内容
function Reader:searchInScripts(query, maxScripts)
    maxScripts = maxScripts or 30
    local results = {}
    local scripts = self:getAllScripts()
    
    for _, scriptInstance in ipairs(scripts) do
        if #results >= maxScripts then
            break
        end
        
        local scriptInfo, err = self:readScript(scriptInstance)
        if scriptInfo and scriptInfo.source then
            local found = scriptInfo.source:lower():find(query:lower())
            if found then
                -- 提取匹配行
                local lines = {}
                local lineNum = 0
                for line in scriptInfo.source:gmatch("[^\n]+") do
                    lineNum = lineNum + 1
                    if line:lower():find(query:lower()) then
                        table.insert(lines, {
                            lineNum = lineNum,
                            content = line:sub(1, 200) -- 限制行长度
                        })
                    end
                end
                
                if #lines > 0 then
                    table.insert(results, {
                        script = scriptInfo,
                        matches = lines
                    })
                end
            end
        end
    end
    
    return results
end

-- 获取脚本信息（不包含源码）
function Reader:getScriptInfo(scriptInstance)
    return {
        name = scriptInstance.Name,
        className = scriptInstance.ClassName,
        path = self:getScriptPath(scriptInstance),
        disabled = scriptInstance.Disabled
    }
end

-- 获取所有脚本信息列表
function Reader:getScriptsList()
    local scripts = self:getAllScripts()
    local list = {}
    
    for _, script in ipairs(scripts) do
        table.insert(list, self:getScriptInfo(script))
    end
    
    return list
end

-- 清除缓存
function Reader:clearCache()
    self.cache = {}
end

-- 检查是否支持反编译
function Reader:canDecompile()
    local Http = self:getHttpModule()
    return self.bytecodeFunc ~= nil and Http ~= nil and Http:canRequestExternal()
end

-- 获取环境信息
function Reader:getEnvInfo()
    local Http = self:getHttpModule()
    return {
        hasDecompiler = self:canDecompile(),
        decompilerName = self.decompilerName or "None",
        hasGetScripts = self.getScriptsFunc ~= nil,
        hasBytecodeReader = self.bytecodeFunc ~= nil,
        usesExternalDecompiler = true,
        decompilerApiUrl = self.apiUrl,
        hasExternalHttp = Http and Http:canRequestExternal() or false
    }
end

-- 为AI准备脚本上下文
function Reader:prepareAIContext(scripts, maxLength)
    maxLength = maxLength or 50000
    local context = {
        scripts = {},
        totalChars = 0
    }
    
    for _, scriptInfo in ipairs(scripts) do
        if context.totalChars >= maxLength then
            break
        end
        
        local entry = {
            name = scriptInfo.name,
            type = scriptInfo.className,
            path = scriptInfo.path,
            source = scriptInfo.source
        }
        
        -- 如果源码太长，截断
        if #entry.source > 10000 then
            entry.source = entry.source:sub(1, 10000) .. "\n... [TRUNCATED]"
        end
        
        context.totalChars = context.totalChars + #entry.source
        table.insert(context.scripts, entry)
    end
    
    return context
end

return Reader
