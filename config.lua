--[[
    Roblox AI CLI Config
    v1.1.0
]]

local Config = {}

local HttpService = game:GetService("HttpService")

-- AI providers
Config.Providers = {
    DeepSeek = {
        name = "DeepSeek",
        baseUrl = "https://api.deepseek.com",
        endpoint = "/chat/completions",
        models = {"deepseek-chat", "deepseek-reasoner"},
        defaultModel = "deepseek-chat",
        apiKey = ""
    },
    OpenAI = {
        name = "OpenAI",
        baseUrl = "https://api.openai.com",
        endpoint = "/v1/chat/completions",
        models = {"gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"},
        defaultModel = "gpt-4o-mini",
        apiKey = ""
    }
}

-- 执行器相关
Config.ExecutorConfig = {
    detectedExecutor = "Unknown",
    scriptDir = "",
    autoDetectedDir = "",
    canWriteFile = false,
    -- 常见执行器的默认保存目录
    knownDirs = {
        ["Synapse X"] = "workspace",
        ["Script-Ware"] = "workspace",
        ["KRNL"] = "workspace",
        ["Fluxus"] = "workspace",
        ["Electron"] = "workspace",
        ["Delta"] = "workspace",
        ["Codex"] = "workspace"
    }
}

-- 主配置
Config.Settings = {
    currentProvider = "DeepSeek",
    timeout = 60,
    maxTokens = 4096,
    temperature = 0.7,
    stream = false,
    
    -- 脚本相关
    autoExecute = false,
    confirmBeforeExecute = true,  -- 执行前确认，安全第一
    saveGeneratedScript = true,
    
    -- 历史记录
    maxHistorySize = 50,
    autoSaveHistory = true,
    
    -- 扫描配置
    scan = {
        maxDepth = 20,
        maxObjects = 5000,
        includeNilInstances = true,
        services = {"Workspace", "ReplicatedStorage", "ReplicatedFirst", "Lighting"},
        focusTypes = {"RemoteEvent", "RemoteFunction", "LocalScript", "ModuleScript", "Script", "BindableEvent", "BindableFunction", "Folder"}
    }
}

-- 历史记录
Config.History = {
    conversations = {},
    executedScripts = {},
    savedScripts = {}
}

-- AI提示词
Config.SystemPrompts = {
    analyzer = [[You are a Roblox game analysis expert and code assistant. You help users understand game resources and generate Lua code.

Your capabilities:
1. Analyze game objects, scripts, and RemoteEvents/RemoteFunctions
2. Explain game mechanics based on code structure
3. Generate working Lua code for script executors
4. Help debug and optimize code

Code Generation Rules:
- Always wrap code in ```lua code blocks
- Use executor-specific functions when needed (getgenv, getnilinstances, etc.)
- Include error handling with pcall
- Add brief comments for complex logic
- Make code ready to execute

Respond in the same language as the user's question.]],

    codeGenerator = [[You are a Roblox Lua code generator. Generate clean, executable code.

Rules:
1. Always wrap code in ```lua code blocks
2. Use proper Roblox API conventions
3. Include error handling with pcall
4. Use executor functions: getgenv, getnilinstances, hookfunction when needed
5. Add brief comments

Output format:
```lua
-- Your code here
```

Brief explanation after code block if needed.]]
}

-- 检测执行器
function Config:detectExecutor()
    local info = {name = "Unknown", canWrite = false, canExecute = false, scriptDir = ""}
    
    -- 逐个检测，没啥优雅的办法
    if syn then
        info.name = "Synapse X"
        info.canWrite = true
        info.canExecute = true
    elseif KRNL_LOADED then
        info.name = "KRNL"
        info.canWrite = true
        info.canExecute = true
    elseif fluxus then
        info.name = "Fluxus"
        info.canWrite = true
        info.canExecute = true
    elseif identifyexecutor then
        info.name = identifyexecutor()
        info.canWrite = true
        info.canExecute = true
    end
    
    -- 通用检测
    if writefile then info.canWrite = true end
    if loadstring then info.canExecute = true end
    
    self.ExecutorConfig.detectedExecutor = info.name
    self.ExecutorConfig.canWriteFile = info.canWrite
    
    return info
end

-- 获取脚本保存目录
function Config:getScriptDir()
    if self.ExecutorConfig.scriptDir ~= "" then
        return self.ExecutorConfig.scriptDir
    end
    
    local executor = self:detectExecutor()
    local knownDir = self.ExecutorConfig.knownDirs[executor.name]
    
    return knownDir or "workspace"
end

function Config:setScriptDir(dir)
    self.ExecutorConfig.scriptDir = dir
    self:save()
end

function Config:getCurrentProvider()
    return self.Providers[self.Settings.currentProvider]
end

function Config:getApiKey(name)
    name = name or self.Settings.currentProvider
    local p = self.Providers[name]
    return p and p.apiKey or ""
end

function Config:setApiKey(name, key)
    if self.Providers[name] then
        self.Providers[name].apiKey = key
        return true
    end
    return false
end

function Config:switchProvider(name)
    if self.Providers[name] then
        self.Settings.currentProvider = name
        return true
    end
    return false
end

-- 历史记录相关
function Config:addToHistory(role, content)
    table.insert(self.History.conversations, {
        role = role,
        content = content,
        timestamp = os.time()
    })
    
    -- 限制大小，不然太占内存
    while #self.History.conversations > self.Settings.maxHistorySize * 2 do
        table.remove(self.History.conversations, 1)
    end
    
    if self.Settings.autoSaveHistory then
        self:saveHistory()
    end
end

function Config:clearHistory()
    self.History.conversations = {}
    self:saveHistory()
end

function Config:getConversationHistory()
    return self.History.conversations
end

function Config:addExecutedScript(script, success)
    table.insert(self.History.executedScripts, 1, {
        script = script:sub(1, 500),  -- 只保存前500字符，够用了
        success = success,
        timestamp = os.time()
    })
    
    while #self.History.executedScripts > 20 do
        table.remove(self.History.executedScripts)
    end
    
    self:saveHistory()
end

-- 保存脚本文件
function Config:saveScript(filename, content)
    if not writefile then
        return false, "writefile not available"
    end
    
    local path = filename
    if not filename:match("%.lua$") then
        path = filename .. ".lua"
    end
    
    local ok, err = pcall(function()
        writefile(path, content)
    end)
    
    if ok then
        table.insert(self.History.savedScripts, 1, {
            name = path,
            timestamp = os.time()
        })
        self:saveHistory()
        return true, path
    else
        return false, tostring(err)
    end
end

function Config:listSavedScripts()
    local list = {}
    for _, item in ipairs(self.History.savedScripts) do
        table.insert(list, item.name)
    end
    return list
end

-- 保存配置到getgenv
function Config:save()
    local data = {
        currentProvider = self.Settings.currentProvider,
        providers = {},
        executorConfig = {scriptDir = self.ExecutorConfig.scriptDir},
        settings = {
            autoExecute = self.Settings.autoExecute,
            confirmBeforeExecute = self.Settings.confirmBeforeExecute,
            saveGeneratedScript = self.Settings.saveGeneratedScript,
            maxHistorySize = self.Settings.maxHistorySize
        }
    }
    
    for name, p in pairs(self.Providers) do
        data.providers[name] = {apiKey = p.apiKey}
    end
    
    getgenv().RobloxAIAnalyzerConfig = HttpService:JSONEncode(data)
end

-- 保存历史
function Config:saveHistory()
    local data = {
        conversations = self.History.conversations,
        executedScripts = self.History.executedScripts,
        savedScripts = self.History.savedScripts
    }
    getgenv().RobloxAIAnalyzerHistory = HttpService:JSONEncode(data)
end

-- 加载历史（供外部调用）
function Config:loadHistory()
    local saved = getgenv().RobloxAIAnalyzerHistory
    if saved then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(saved)
        end)
        if ok and data then
            return data.conversations or {}
        end
    end
    return {}
end

-- 加载配置
function Config:load()
    local saved = getgenv().RobloxAIAnalyzerConfig
    if saved then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(saved)
        end)
        if ok and data then
            if data.currentProvider then
                self.Settings.currentProvider = data.currentProvider
            end
            if data.providers then
                for name, pData in pairs(data.providers) do
                    if self.Providers[name] and pData.apiKey then
                        self.Providers[name].apiKey = pData.apiKey
                    end
                end
            end
            if data.executorConfig and data.executorConfig.scriptDir then
                self.ExecutorConfig.scriptDir = data.executorConfig.scriptDir
            end
            if data.settings then
                -- 批量更新设置
                local s = data.settings
                if s.autoExecute ~= nil then self.Settings.autoExecute = s.autoExecute end
                if s.confirmBeforeExecute ~= nil then self.Settings.confirmBeforeExecute = s.confirmBeforeExecute end
                if s.saveGeneratedScript ~= nil then self.Settings.saveGeneratedScript = s.saveGeneratedScript end
            end
        end
    end
    
    -- 加载历史
    local savedHistory = getgenv().RobloxAIAnalyzerHistory
    if savedHistory then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(savedHistory)
        end)
        if ok and data then
            if data.conversations then self.History.conversations = data.conversations end
            if data.executedScripts then self.History.executedScripts = data.executedScripts end
            if data.savedScripts then self.History.savedScripts = data.savedScripts end
        end
    end
    
    self:detectExecutor()
end

return Config
