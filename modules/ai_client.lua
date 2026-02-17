--[[
    Roblox AI Resource Analyzer - AI Client Module
    Version: 1.0.0
    
    AI API客户端：支持DeepSeek和OpenAI
]]

local AIClient = {}

local HttpService = game:GetService("HttpService")

-- 加载依赖模块
local HttpModule = loadfile("modules/http.lua")()
local Config = loadfile("config.lua")()

-- 对话历史
AIClient.conversationHistory = {}

-- 最大历史消息数
AIClient.maxHistoryLength = 20

-- 创建请求体
local function createRequestBody(provider, messages, options)
    options = options or {}
    
    local body = {
        model = options.model or provider.defaultModel,
        messages = messages,
        max_tokens = options.maxTokens or Config.Settings.maxTokens,
        temperature = options.temperature or Config.Settings.temperature,
        stream = false
    }
    
    -- DeepSeek特有参数
    if provider.name == "DeepSeek" then
        -- 可以添加DeepSeek特有参数
    end
    
    return body
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
    options = options or {}
    
    -- 获取当前提供商配置
    local provider = Config:getCurrentProvider()
    
    -- 检查API Key
    if not provider.apiKey or provider.apiKey == "" then
        return nil, "API Key not configured for " .. provider.name
    end
    
    -- 检查HTTP支持
    if not HttpModule:canRequestExternal() then
        return nil, "External HTTP requests not supported in this environment (" .. HttpModule.executor.name .. ")"
    end
    
    -- 构建消息列表
    local messages = {}
    
    -- 添加系统提示词
    if systemPrompt then
        table.insert(messages, {
            role = "system",
            content = systemPrompt
        })
    end
    
    -- 添加历史对话
    for _, msg in ipairs(self.conversationHistory) do
        table.insert(messages, msg)
    end
    
    -- 添加用户消息
    table.insert(messages, {
        role = "user",
        content = userMessage
    })
    
    -- 创建请求
    local url = provider.baseUrl .. provider.endpoint
    local body = createRequestBody(provider, messages, options)
    local headers = createHeaders(provider)
    
    -- 发送请求
    local response = HttpModule:jsonRequest(url, "POST", body, headers)
    
    if not response.success then
        return nil, response.error or "Request failed: " .. tostring(response.statusCode)
    end
    
    if not response.data then
        return nil, "Failed to parse response JSON"
    end
    
    -- 提取响应内容
    local content = response.data.choices and 
                    response.data.choices[1] and 
                    response.data.choices[1].message and 
                    response.data.choices[1].message.content
    
    if not content then
        return nil, "No content in response"
    end
    
    -- 更新对话历史
    table.insert(self.conversationHistory, {
        role = "user",
        content = userMessage
    })
    table.insert(self.conversationHistory, {
        role = "assistant",
        content = content
    })
    
    -- 限制历史长度
    while #self.conversationHistory > self.maxHistoryLength * 2 do
        table.remove(self.conversationHistory, 1)
    end
    
    -- 返回完整响应
    return {
        content = content,
        model = response.data.model,
        usage = response.data.usage,
        provider = provider.name
    }
end

-- 分析游戏资源
function AIClient:analyzeResources(query, resourceContext, options)
    -- 构建系统提示词
    local systemPrompt = Config.SystemPrompts.analyzer
    
    -- 构建用户消息
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
    for i, script in ipairs(scriptsContext.scripts or {}) do
        scriptsInfo = scriptsInfo .. string.format(
            "\n--- %s (%s) ---\nPath: %s\n\n%s\n",
            script.name,
            script.type,
            script.path,
            script.source or "[No source]"
        )
    end
    
    local userMessage = string.format(
        [[Scripts to analyze:
%s

Question: %s]],
        scriptsInfo,
        query
    )
    
    return self:chat(userMessage, systemPrompt, options)
end

-- 生成代码
function AIClient:generateCode(prompt, context, options)
    local systemPrompt = Config.SystemPrompts.codeGenerator
    
    local userMessage = prompt
    if context then
        userMessage = string.format(
            [[Context:
%s

Task: %s]],
            HttpService:JSONEncode(context),
            prompt
        )
    end
    
    return self:chat(userMessage, systemPrompt, options)
end

-- 清除对话历史
function AIClient:clearHistory()
    self.conversationHistory = {}
end

-- 设置历史长度
function AIClient:setMaxHistory(length)
    self.maxHistoryLength = length or 20
end

-- 获取当前提供商信息
function AIClient:getProviderInfo()
    local provider = Config:getCurrentProvider()
    return {
        name = provider.name,
        defaultModel = provider.defaultModel,
        models = provider.models,
        hasApiKey = provider.apiKey ~= nil and provider.apiKey ~= ""
    }
end

-- 测试API连接
function AIClient:testConnection()
    local provider = Config:getCurrentProvider()
    
    if not provider.apiKey or provider.apiKey == "" then
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
