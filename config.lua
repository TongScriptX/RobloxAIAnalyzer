-- Config模块 - Roblox AI CLI v2.1.0
local Config = {}

local HttpService = game:GetService("HttpService")

-- AI providers
Config.Providers = {
    Custom = {
        name = "Custom",
        baseUrl = "",
        endpoint = "/v1/chat/completions",
        models = {""},
        defaultModel = "",
        contextWindow = 128000,
        outputLimit = 4096,
        apiKey = "",
        supportsFunctionCall = true
    }
}

-- 执行器相关
Config.ExecutorConfig = {
    detectedExecutor = "Unknown",
    scriptDir = "AICli",
    canWriteFile = false,
    knownDirs = {
        ["Synapse X"] = "AICli",
        ["Script-Ware"] = "AICli",
        ["KRNL"] = "AICli",
        ["Fluxus"] = "AICli",
        ["Electron"] = "AICli",
        ["Delta"] = "AICli",
        ["Codex"] = "AICli"
    }
}

-- 主配置
Config.Settings = {
    currentProvider = "Custom",
    maxTokens = 4096,
    temperature = 0.7,
    confirmBeforeExecute = true,
    scriptDir = "AICli",
    runMode = "default"
}

-- 检测执行器
function Config:detectExecutor()
    local info = {name = "Unknown", canWrite = false, canExecute = false, scriptDir = ""}

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

    if writefile then info.canWrite = true end
    if loadstring then info.canExecute = true end

    self.ExecutorConfig.detectedExecutor = info.name
    self.ExecutorConfig.canWriteFile = info.canWrite

    return info
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

function Config:setBaseUrl(name, url)
    if self.Providers[name] then
        self.Providers[name].baseUrl = url
        return true
    end
    return false
end

function Config:setModel(name, model)
    if self.Providers[name] then
        self.Providers[name].defaultModel = model
        self.Providers[name].models = {model}
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

-- 保存配置到文件
function Config:save()
    if not writefile then
        getgenv().RobloxAIAnalyzerConfig = HttpService:JSONEncode({
            currentProvider = self.Settings.currentProvider,
            providers = {[self.Settings.currentProvider] = {
                apiKey = self:getCurrentProvider().apiKey,
                baseUrl = self:getCurrentProvider().baseUrl,
                defaultModel = self:getCurrentProvider().defaultModel
            }}
        })
        return false
    end

    local data = {
        currentProvider = self.Settings.currentProvider,
        providers = {},
        executorConfig = {scriptDir = self.ExecutorConfig.scriptDir}
    }

    for name, p in pairs(self.Providers) do
        data.providers[name] = {
            apiKey = p.apiKey,
            baseUrl = p.baseUrl,
            defaultModel = p.defaultModel
        }
    end

    pcall(function()
        writefile("RobloxAIAnalyzer/config.json", HttpService:JSONEncode(data))
    end)

    return true
end

-- 加载配置
function Config:load()
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
                            if pData.baseUrl then
                                self.Providers[name].baseUrl = pData.baseUrl
                            end
                            if pData.defaultModel then
                                self.Providers[name].defaultModel = pData.defaultModel
                                self.Providers[name].models = {pData.defaultModel}
                            end
                        end
                    end
                end
                if data.executorConfig and data.executorConfig.scriptDir then
                    self.ExecutorConfig.scriptDir = data.executorConfig.scriptDir
                end
            end
        end
    else
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
                            if pData.baseUrl then
                                self.Providers[name].baseUrl = pData.baseUrl
                            end
                            if pData.defaultModel then
                                self.Providers[name].defaultModel = pData.defaultModel
                                self.Providers[name].models = {pData.defaultModel}
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
