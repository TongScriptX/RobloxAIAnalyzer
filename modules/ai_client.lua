--[[
    Roblox AI Resource Analyzer - AI Client Module
    Version: 1.0.0
    
    AI API客户端：支持DeepSeek和OpenAI
    依赖：Config, Http (通过全局 _G.AIAnalyzer 传递)
]]

local AIClient = {}

local HttpService = game:GetService("HttpService")

-- 从全局获取依赖（由main.lua设置）
local function getDeps()
    local deps = _G.AIAnalyzer or {}
    return deps.Config, deps.Http
end

-- 对话历史
AIClient.conversationHistory = {}
AIClient.maxHistoryLength = 20

-- 创建请求体
local function createRequestBody(provider, messages, options)
    local Config = getDeps()
    options = options or {}
    
    return {
        model = options.model or provider.defaultModel,
        messages = messages,
        max_tokens = options.maxTokens or (Config and Config.Settings and Config.Settings.maxTokens) or 4096,
        temperature = options.temperature or (Config and Config.Settings and Config.Settings.temperature) or 0.7,
        stream = false
    }
end

-- 创建请求头
local function createHeaders(provider)
    return {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. provider.apiKey
    }
end

-- 发送聊天请求
function AIClient:chat(userMessage, systemPrompt, options)
    local Config, Http = getDeps()
    options = options or {}
    
    if not Config then
        return nil, "Config module not loaded"
    end
    
    local provider = Config:getCurrentProvider()
    
    if not provider.apiKey or provider.apiKey == "" then
        return nil, "API Key not configured for " .. provider.name
    end
    
    if not Http or not Http:canRequestExternal() then
        return nil, "External HTTP requests not supported"
    end
    
    local messages = {}
    
    if systemPrompt then
        table.insert(messages, {role = "system", content = systemPrompt})
    end
    
    for _, msg in ipairs(self.conversationHistory) do
        table.insert(messages, msg)
    end
    
    table.insert(messages, {role = "user", content = userMessage})
    
    local url = provider.baseUrl .. provider.endpoint
    local body = createRequestBody(provider, messages, options)
    local headers = createHeaders(provider)
    
    local response = Http:jsonRequest(url, "POST", body, headers)
    
    if not response.success then
        return nil, response.error or "Request failed: " .. tostring(response.statusCode)
    end
    
    if not response.data then
        return nil, "Failed to parse response JSON"
    end
    
    local content = response.data.choices and 
                    response.data.choices[1] and 
                    response.data.choices[1].message and 
                    response.data.choices[1].message.content
    
    if not content then
        return nil, "No content in response"
    end
    
    table.insert(self.conversationHistory, {role = "user", content = userMessage})
    table.insert(self.conversationHistory, {role = "assistant", content = content})
    
    while #self.conversationHistory > self.maxHistoryLength * 2 do
        table.remove(self.conversationHistory, 1)
    end
    
    return {
        content = content,
        model = response.data.model,
        usage = response.data.usage,
        provider = provider.name
    }
end

-- 分析游戏资源
function AIClient:analyzeResources(query, resourceContext, options)
    local Config = getDeps()
    local systemPrompt = Config and Config.SystemPrompts and Config.SystemPrompts.analyzer or "You are a helpful AI assistant."
    
    local userMessage = query
    
    if resourceContext then
        userMessage = string.format(
            [[Game: %s (PlaceId: %s)

Available Resources:
%s

User Query: %s]],
            resourceContext.gameName or "Unknown",
            tostring(resourceContext.placeId or 0),
            HttpService:JSONEncode({
                remotes = resourceContext.remotes or {},
                scripts = resourceContext.scripts or {},
                services = resourceContext.services or {}
            }),
            query
        )
    end
    
    return self:chat(userMessage, systemPrompt, options)
end

-- 分析脚本源码
function AIClient:analyzeScripts(query, scriptsContext, options)
    local systemPrompt = [[You are a Roblox Lua code analyst. Analyze the provided script source code and answer questions about it.

Focus on:
1. What the script does
2. Key functions and their purposes
3. RemoteEvent/RemoteFunction usage
4. Potential issues or improvements
5. Security considerations

Be concise and practical in your analysis.]]

    local scriptsInfo = ""
    for _, script in ipairs(scriptsContext.scripts or {}) do
        scriptsInfo = scriptsInfo .. string.format(
            "\n--- %s (%s) ---\nPath: %s\n\n%s\n",
            script.name, script.type, script.path,
            script.source or "[No source]"
        )
    end
    
    local userMessage = string.format(
        [[Scripts to analyze:
%s

Question: %s]],
        scriptsInfo, query
    )
    
    return self:chat(userMessage, systemPrompt, options)
end

-- 生成代码
function AIClient:generateCode(prompt, context, options)
    local Config = getDeps()
    local systemPrompt = Config and Config.SystemPrompts and Config.SystemPrompts.codeGenerator or "You are a code generator."
    
    local userMessage = prompt
    if context then
        userMessage = string.format(
            [[Context:
%s

Task: %s]],
            HttpService:JSONEncode(context), prompt
        )
    end
    
    return self:chat(userMessage, systemPrompt, options)
end

-- 清除对话历史
function AIClient:clearHistory()
    self.conversationHistory = {}
end

-- 测试API连接
function AIClient:testConnection()
    local Config = getDeps()
    local provider = Config and Config:getCurrentProvider()
    
    if not provider or not provider.apiKey or provider.apiKey == "" then
        return false, "API Key not configured"
    end
    
    local result, err = self:chat("Hello, please respond with 'OK' to confirm connection.")
    
    if result then
        return true, "Connection successful to " .. provider.name
    else
        return false, "Connection failed: " .. tostring(err)
    end
end

return AIClient