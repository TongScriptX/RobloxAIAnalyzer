--[[
    Roblox AI Resource Analyzer - Script Reader Module
    Version: 1.0.0
    
    脚本读取模块：读取游戏内脚本源码
]]

local Reader = {}

-- 检测可用的反编译函数
local function detectDecompiler()
    -- 检查各种执行器的反编译函数
    if decompile then
        return "decompile", decompile
    end
    
    if getscriptcode then
        return "getscriptcode", getscriptcode
    end
    
    if getscriptfunction then
        return "getscriptfunction", function(script)
            local success, result = pcall(function()
                local func = getscriptfunction(script)
                if func then
                    return debug.getinfo(func, "s").source or "-- Unable to read source"
                end
            end)
            return success and result or "-- Decompile not available"
        end
    end
    
    return nil, nil
end

Reader.decompilerName, Reader.decompileFunc = detectDecompiler()

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

-- 脚本缓存
Reader.cache = {}

-- 获取所有脚本实例
function Reader:getAllScripts()
    local success, scripts = pcall(self.getScriptsFunc)
    if success then
        return scripts
    end
    return {}
end

-- 读取单个脚本源码
function Reader:readScript(scriptInstance)
    if not scriptInstance then
        return nil, "Invalid script instance"
    end
    
    -- 检查缓存
    local cacheKey = tostring(scriptInstance)
    if self.cache[cacheKey] then
        return self.cache[cacheKey]
    end
    
    -- 检查是否有反编译函数
    if not self.decompileFunc then
        return nil, "No decompiler available in this environment"
    end
    
    -- 尝试反编译
    local success, source = pcall(self.decompileFunc, scriptInstance)
    
    if success and source then
        self.cache[cacheKey] = {
            name = scriptInstance.Name,
            className = scriptInstance.ClassName,
            path = self:getScriptPath(scriptInstance),
            source = source,
            size = #source,
            lines = select(2, source:gsub("\n", "\n")) + 1
        }
        return self.cache[cacheKey]
    end
    
    return nil, "Failed to decompile: " .. tostring(source)
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
    return self.decompileFunc ~= nil
end

-- 获取环境信息
function Reader:getEnvInfo()
    return {
        hasDecompiler = self.decompileFunc ~= nil,
        decompilerName = self.decompilerName or "None",
        hasGetScripts = self.getScriptsFunc ~= nil
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
