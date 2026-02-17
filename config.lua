--[[
    Roblox AI Resource Analyzer - Configuration
    Version: 1.0.0
    
    配置文件：包含API密钥、端点和各种设置
]]

local Config = {}

-- AI Provider 配置
Config.Providers = {
    DeepSeek = {
        name = "DeepSeek",
        baseUrl = "https://api.deepseek.com",
        endpoint = "/chat/completions",
        models = {
            "deepseek-chat",
            "deepseek-reasoner"
        },
        defaultModel = "deepseek-chat",
        apiKey = "" -- 用户需要填写自己的API Key
    },
    OpenAI = {
        name = "OpenAI",
        baseUrl = "https://api.openai.com",
        endpoint = "/v1/chat/completions",
        models = {
            "gpt-4o",
            "gpt-4o-mini",
            "gpt-4-turbo",
            "gpt-3.5-turbo"
        },
        defaultModel = "gpt-4o-mini",
        apiKey = "" -- 用户需要填写自己的API Key
    }
}

-- 默认配置
Config.Settings = {
    -- 当前使用的AI提供商
    currentProvider = "DeepSeek",
    
    -- HTTP请求超时时间（秒）
    timeout = 60,
    
    -- 最大生成token数
    maxTokens = 4096,
    
    -- 温度参数
    temperature = 0.7,
    
    -- 是否启用流式响应（游戏内暂不支持）
    stream = false,
    
    -- 资源扫描设置
    scan = {
        -- 扫描的最大深度
        maxDepth = 20,
        
        -- 每次扫描的最大对象数
        maxObjects = 5000,
        
        -- 是否扫描nil instances
        includeNilInstances = true,
        
        -- 要扫描的服务
        services = {
            "Workspace",
            "ReplicatedStorage", 
            "ReplicatedFirst",
            "Lighting",
            "ServerStorage",
            "ServerScriptService"
        },
        
        -- 要关注的实例类型
        focusTypes = {
            "RemoteEvent",
            "RemoteFunction",
            "LocalScript",
            "ModuleScript",
            "Script",
            "BindableEvent",
            "BindableFunction",
            "ValueBase",
            "Folder"
        }
    },
    
    -- UI设置
    ui = {
        -- 主题颜色
        theme = {
            background = Color3.fromRGB(30, 30, 35),
            backgroundSecondary = Color3.fromRGB(40, 40, 45),
            backgroundTertiary = Color3.fromRGB(50, 50, 55),
            accent = Color3.fromRGB(88, 166, 255),
            accentHover = Color3.fromRGB(108, 186, 255),
            text = Color3.fromRGB(240, 240, 240),
            textSecondary = Color3.fromRGB(180, 180, 180),
            success = Color3.fromRGB(76, 175, 80),
            warning = Color3.fromRGB(255, 193, 7),
            error = Color3.fromRGB(244, 67, 54)
        },
        
        -- 窗口大小
        windowSize = UDim2.new(0, 600, 0, 450),
        
        -- 字体大小
        fontSize = 14,
        
        -- 圆角大小
        cornerRadius = 8
    }
}

-- System Prompt 模板
Config.SystemPrompts = {
    -- 资源分析提示词
    analyzer = [[You are a Roblox game analysis expert. You help users understand and analyze game resources.

Your capabilities:
1. Analyze game objects, scripts, and RemoteEvents/RemoteFunctions
2. Explain game mechanics based on code structure
3. Help users find specific resources in the game
4. Generate Lua code snippets for interacting with game objects

When analyzing:
- Provide clear, structured explanations
- Include object paths and types
- Suggest practical code examples when appropriate
- Consider game security and best practices

Respond in the same language as the user's question.]],

    -- 代码生成提示词
    codeGenerator = [[You are a Roblox Lua expert. Generate clean, efficient, and safe code.

Rules:
1. Use proper Roblox API conventions
2. Include error handling where appropriate
3. Add brief comments for complex logic
4. Follow Lua style guidelines
5. Code should work with script executors (using getgenv, getnilinstances, etc. when needed)

Output only the code without markdown formatting unless the user asks for explanation.]]
}

-- 获取当前提供商配置
function Config:getCurrentProvider()
    return self.Providers[self.Settings.currentProvider]
end

-- 获取API Key
function Config:getApiKey(providerName)
    providerName = providerName or self.Settings.currentProvider
    local provider = self.Providers[providerName]
    return provider and provider.apiKey or ""
end

-- 设置API Key
function Config:setApiKey(providerName, apiKey)
    if self.Providers[providerName] then
        self.Providers[providerName].apiKey = apiKey
        return true
    end
    return false
end

-- 切换提供商
function Config:switchProvider(providerName)
    if self.Providers[providerName] then
        self.Settings.currentProvider = providerName
        return true
    end
    return false
end

-- 保存配置到全局（持久化）
function Config:save()
    local jsonData = game:GetService("HttpService"):JSONEncode({
        currentProvider = self.Settings.currentProvider,
        providers = {}
    })
    for name, provider in pairs(self.Providers) do
        jsonData.providers = jsonData.providers or {}
        jsonData.providers[name] = {
            apiKey = provider.apiKey
        }
    end
    getgenv().RobloxAIAnalyzerConfig = jsonData
end

-- 从全局加载配置
function Config:load()
    local saved = getgenv().RobloxAIAnalyzerConfig
    if saved then
        local data = game:GetService("HttpService"):JSONDecode(saved)
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
    end
end

return Config
