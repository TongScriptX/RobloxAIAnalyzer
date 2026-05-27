-- Reader模块 - 脚本读取
local Reader = {}

local HttpService = game:GetService("HttpService")

Reader.apiUrl = "https://api.lua.expert/decompile"
Reader.minRequestInterval = 0.6
Reader.lastRequestAt = 0

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

-- 检测getscripts函数
local function detectGetScripts()
    if getscripts then
        return getscripts
    end
    
    -- 手动收集所有脚本
    return function()
        local scripts = {}
        local services = {
            game:GetService("Workspace"),
            game:GetService("ReplicatedStorage"),
            game:GetService("ReplicatedFirst"),
            game:GetService("StarterGui"),
            game:GetService("StarterPack"),
            game:GetService("StarterPlayer")
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

function Reader:extractBytecode(scriptInstance)
    if not self.bytecodeFunc then
        return nil, "No bytecode reader available"
    end

    local success, bytecode = pcall(self.bytecodeFunc, scriptInstance)
    if not success then
        return nil, "Failed to read bytecode: " .. tostring(bytecode)
    end

    if not bytecode or bytecode == "" then
        return nil, "Empty bytecode"
    end

    return bytecode
end

function Reader:decodeRemoteSource(response)
    if not response then
        return nil, "No response"
    end

    if response.success and response.body and response.body ~= "" then
        return response.body
    end

    if response.data then
        if type(response.data) == "table" then
            return response.data.source or response.data.code or response.data.result
        end
        if type(response.data) == "string" and response.data ~= "" then
            return response.data
        end
    end

    local detail = response.error or response.body or ("HTTP " .. tostring(response.statusCode or 0))
    return nil, tostring(detail)
end

function Reader:fetchDecompiledSource(scriptInstance)
    local Http = self:getHttpModule()
    if not Http then
        return nil, "Http module not initialized"
    end

    if not Http:canRequestExternal() then
        return nil, "Executor does not support external HTTP requests"
    end

    local bytecode, bytecodeErr = self:extractBytecode(scriptInstance)
    if not bytecode then
        return nil, bytecodeErr
    end

    local elapsed = os.clock() - self.lastRequestAt
    if elapsed < self.minRequestInterval then
        task.wait(self.minRequestInterval - elapsed)
    end

    local encoded = HttpService:Base64Encode(bytecode)
    local response = Http:jsonRequest(self.apiUrl, "POST", {
        script = encoded
    })
    self.lastRequestAt = os.clock()

    local source, responseErr = self:decodeRemoteSource(response)
    if not source or source == "" then
        return nil, "lua.expert request failed: " .. tostring(responseErr)
    end

    return source
end

function Reader:readScript(scriptInstance)
    if not scriptInstance then
        return nil, "Invalid script instance"
    end
    
    local cacheKey = tostring(scriptInstance)
    if self.cache[cacheKey] then
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
        return result
    end

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
