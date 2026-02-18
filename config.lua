-- Config模块 - Roblox AI CLI v1.1.0
local Config = {}

local HttpService = game:GetService("HttpService")

-- AI providers（包含上下文窗口大小）
Config.Providers = {
    DeepSeek = {
        name = "DeepSeek",
        baseUrl = "https://api.deepseek.com",
        endpoint = "/chat/completions",
        models = {"deepseek-chat", "deepseek-reasoner"},
        defaultModel = "deepseek-chat",
        contextWindow = 64000,  -- DeepSeek上下文窗口
        outputLimit = 4096,
        apiKey = ""
    },
    OpenAI = {
        name = "OpenAI",
        baseUrl = "https://api.openai.com",
        endpoint = "/v1/chat/completions",
        models = {"gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"},
        defaultModel = "gpt-4o-mini",
        contextWindow = 128000,  -- GPT-4上下文窗口
        outputLimit = 4096,
        apiKey = ""
    },
    iFlow = {
        name = "其他",
        baseUrl = "https://apis.iflow.cn",
        endpoint = "/v1/chat/completions",
        models = {
            "iflow-rome-30ba3b",
            "qwen3-coder-plus",
            "qwen3-max",
            "qwen3-vl-plus",
            "kimi-k2-0905",
            "qwen3-max-preview",
            "glm-4.6",
            "kimi-k2",
            "deepseek-v3.2",
            "deepseek-r1",
            "deepseek-v3"
        },
        defaultModel = "deepseek-v3",
        contextWindow = 128000,
        outputLimit = 4096,
        apiKey = "",
        description = "OpenAI 兼容接口"
    }
}

-- 上下文压缩配置
Config.ContextConfig = {
    -- 压缩阈值：当使用超过此百分比时触发
    compressionThreshold = 0.70,  -- 70%
    -- 输出预留空间（tokens）
    outputReserve = 8000,
    -- 压缩预留空间（用于生成摘要）
    compactionReserve = 4000,
    -- 是否启用自动压缩
    autoCompact = true,
    -- 保留最近N条完整消息（不被压缩）
    preserveRecentMessages = 4,
    -- 最小压缩间隔（避免频繁压缩）
    minCompactInterval = 3,  -- 消息数
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

-- Session形式的历史记录
Config.Sessions = {}
Config.CurrentSession = nil

-- 创建新session
function Config:createSession()
    local session = {
        id = tostring(os.time()),
        title = "新对话",
        time = os.date("%m/%d %H:%M"),
        messages = {},
        createdAt = os.time()
    }
    
    -- 添加到列表开头
    table.insert(self.Sessions, 1, session)
    
    -- 限制数量
    while #self.Sessions > 20 do
        table.remove(self.Sessions)
    end
    
    self.CurrentSession = session
    self:saveSessions()
    
    return session
end

-- 获取或创建当前session
function Config:getCurrentSession()
    if not self.CurrentSession then
        self.CurrentSession = self:createSession()
    end
    return self.CurrentSession
end

-- 切换session
function Config:switchSession(sessionId)
    for _, session in ipairs(self.Sessions) do
        if session.id == sessionId then
            self.CurrentSession = session
            self:saveSessions()
            return session
        end
    end
    return nil
end

-- 删除session
function Config:deleteSession(sessionId)
    for i, session in ipairs(self.Sessions) do
        if session.id == sessionId then
            table.remove(self.Sessions, i)
            if self.CurrentSession and self.CurrentSession.id == sessionId then
                self.CurrentSession = #self.Sessions > 0 and self.Sessions[1] or nil
            end
            self:saveSessions()
            return true
        end
    end
    return false
end

-- 添加消息到当前session
function Config:addMessage(role, content)
    local session = self:getCurrentSession()
    
    table.insert(session.messages, {
        role = role,
        content = content,
        time = os.time()
    })
    
    -- 使用ContextManager生成标题
    if role == "user" and (session.title == "新对话" or not session.title) then
        local ContextManager = _G.AIAnalyzer and _G.AIAnalyzer.ContextManager
        if ContextManager then
            session.title = ContextManager:generateSessionTitle(session.messages)
        else
            session.title = content:sub(1, 20) .. (#content > 20 and "..." or "")
        end
    end
    
    session.time = os.date("%m/%d %H:%M")
    self:saveSessions()
end

-- 获取当前session的消息历史
function Config:getMessages()
    local session = self:getCurrentSession()
    return session.messages or {}
end

-- 清空当前session
function Config:clearCurrentSession()
    local session = self:getCurrentSession()
    session.messages = {}
    session.title = "新对话"
    self:saveSessions()
end

-- 获取所有session列表
function Config:getSessionList()
    return self.Sessions
end

-- 保存sessions到文件
function Config:saveSessions()
    if not writefile then
        getgenv().RobloxAIAnalyzerSessions = HttpService:JSONEncode(self.Sessions)
        return false
    end
    
    pcall(function()
        writefile("RobloxAIAnalyzer/sessions.json", HttpService:JSONEncode(self.Sessions))
    end)
    
    return true
end

-- 加载sessions
function Config:loadSessions()
    if readfile then
        local ok, content = pcall(function()
            return readfile("RobloxAIAnalyzer/sessions.json")
        end)
        
        if ok and content then
            local ok2, data = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if ok2 and data then
                self.Sessions = data
                if #data > 0 then
                    self.CurrentSession = data[1]
                end
                return true
            end
        end
    end
    
    -- 回退到getgenv
    local saved = getgenv().RobloxAIAnalyzerSessions
    if saved then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(saved)
        end)
        if ok and data then
            self.Sessions = data
            if #data > 0 then
                self.CurrentSession = data[1]
            end
        end
    end
    
    return false
end

-- 兼容旧版API
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

-- 保存配置到文件
function Config:save()
    if not writefile then
        -- 回退到 getgenv
        getgenv().RobloxAIAnalyzerConfig = HttpService:JSONEncode({
            currentProvider = self.Settings.currentProvider,
            providers = {[self.Settings.currentProvider] = {apiKey = self:getCurrentProvider().apiKey}}
        })
        return false
    end
    
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
        data.providers[name] = {
            apiKey = p.apiKey,
            defaultModel = p.defaultModel
        }
    end
    
    pcall(function()
        writefile("RobloxAIAnalyzer/config.json", HttpService:JSONEncode(data))
    end)
    
    return true
end

-- 保存历史到文件
function Config:saveHistory()
    if not writefile then
        getgenv().RobloxAIAnalyzerHistory = HttpService:JSONEncode({
            conversations = self.History.conversations
        })
        return false
    end
    
    local data = {
        conversations = self.History.conversations,
        executedScripts = self.History.executedScripts,
        savedScripts = self.History.savedScripts
    }
    
    pcall(function()
        writefile("RobloxAIAnalyzer/history.json", HttpService:JSONEncode(data))
    end)
    
    return true
end

-- 加载历史
function Config:loadHistory()
    if readfile then
        local ok, content = pcall(function()
            return readfile("RobloxAIAnalyzer/history.json")
        end)
        if ok and content then
            local ok2, data = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if ok2 and data then
                return data.conversations or {}
            end
        end
    end
    
    -- 回退到 getgenv
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
    -- 先尝试从文件加载
    if readfile then
        local ok, content = pcall(function()
            return readfile("RobloxAIAnalyzer/config.json")
        end)
        
        if ok and content then
            local ok2, data = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            
            if ok2 and data then
                if data.currentProvider then
                    self.Settings.currentProvider = data.currentProvider
                end
                if data.providers then
                    for name, pData in pairs(data.providers) do
                        if self.Providers[name] then
                            if pData.apiKey then
                                self.Providers[name].apiKey = pData.apiKey
                            end
                            if pData.defaultModel then
                                self.Providers[name].defaultModel = pData.defaultModel
                            end
                        end
                    end
                end
                if data.executorConfig and data.executorConfig.scriptDir then
                    self.ExecutorConfig.scriptDir = data.executorConfig.scriptDir
                end
                if data.settings then
                    local s = data.settings
                    if s.autoExecute ~= nil then self.Settings.autoExecute = s.autoExecute end
                    if s.confirmBeforeExecute ~= nil then self.Settings.confirmBeforeExecute = s.confirmBeforeExecute end
                    if s.saveGeneratedScript ~= nil then self.Settings.saveGeneratedScript = s.saveGeneratedScript end
                end
            end
        end
        
        -- 加载历史
        local ok3, historyContent = pcall(function()
            return readfile("RobloxAIAnalyzer/history.json")
        end)
        
        if ok3 and historyContent then
            local ok4, data = pcall(function()
                return HttpService:JSONDecode(historyContent)
            end)
            if ok4 and data then
                if data.conversations then self.History.conversations = data.conversations end
                if data.executedScripts then self.History.executedScripts = data.executedScripts end
                if data.savedScripts then self.History.savedScripts = data.savedScripts end
            end
        end
    else
        -- 回退到 getgenv
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
                        if self.Providers[name] then
                            if pData.apiKey then
                                self.Providers[name].apiKey = pData.apiKey
                            end
                            if pData.defaultModel then
                                self.Providers[name].defaultModel = pData.defaultModel
                            end
                        end
                    end
                end
            end
        end
    end
    
    self:detectExecutor()
end

return Config
