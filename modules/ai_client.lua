-- AI客户端：支持DeepSeek和OpenAI，支持工具调用和上下文压缩

local AIClient = {}

local HttpService = game:GetService("HttpService")

-- 从全局获取依赖
local function getDeps()
    local deps = _G.AIAnalyzer or {}
    return deps.Config, deps.Http, deps.Tools, deps.Scanner, deps.Reader, deps.ContextManager
end

-- 对话历史
AIClient.conversationHistory = {}
AIClient.maxHistoryLength = 50  -- 增加历史长度

-- 估算token数
local function estimateTokens(text)
    if not text then return 0 end
    local chineseCount = select(2, text:gsub("[\228-\233]", ""))
    local otherCount = #text - chineseCount
    return math.ceil(chineseCount / 1.5 + otherCount / 4)
end

-- 获取当前上下文使用情况
function AIClient:getContextUsage()
    local Config, _, _, _, _, ContextManager = getDeps()
    local provider = Config and Config:getCurrentProvider()
    local contextWindow = provider and provider.contextWindow or 64000
    
    local used = 0
    for _, msg in ipairs(self.conversationHistory) do
        used = used + estimateTokens(msg.content or "") + 10
    end
    
    return {
        used = used,
        total = contextWindow,
        percent = used / contextWindow,
        remaining = contextWindow - used
    }
end

-- 检查并执行上下文压缩
function AIClient:checkAndCompact()
    local Config, _, _, _, _, ContextManager = getDeps()
    local provider = Config and Config:getCurrentProvider()
    local ctxConfig = Config and Config.ContextConfig
    
    if not ctxConfig or not ctxConfig.autoCompact then
        return false
    end
    
    local usage = self:getContextUsage()
    
    -- 检查是否超过阈值
    if usage.percent >= (ctxConfig.compressionThreshold or 0.70) then
        -- 执行压缩
        self.conversationHistory = ContextManager:compact(
            self.conversationHistory, 
            ctxConfig,
            {}
        )
        
        return true
    end
    
    return false
end

-- 创建请求体
local function createRequestBody(provider, messages, options, tools)
    local Config = getDeps()
    options = options or {}
    
    local body = {
        model = options.model or provider.defaultModel,
        messages = messages,
        max_tokens = options.maxTokens or (Config and Config.Settings and Config.Settings.maxTokens) or 4096,
        temperature = options.temperature or (Config and Config.Settings and Config.Settings.temperature) or 0.7,
        stream = false
    }
    
    -- 添加工具定义
    if tools and #tools > 0 then
        body.tools = tools
        body.tool_choice = "auto"
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

-- 发送聊天请求（支持工具调用和自动压缩）
function AIClient:chat(userMessage, systemPrompt, options)
    local Config, Http, Tools, Scanner, Reader, ContextManager = getDeps()
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
    
    -- 添加用户消息到历史
    table.insert(self.conversationHistory, {role = "user", content = userMessage})
    
    -- 检查是否需要压缩
    self:checkAndCompact()
    
    -- 准备消息
    local messages = {}
    
    if systemPrompt then
        table.insert(messages, {role = "system", content = systemPrompt})
    end
    
    for _, msg in ipairs(self.conversationHistory) do
        table.insert(messages, msg)
    end
    
    -- 获取工具定义
    local tools = Tools and Tools.definitions
    
    local url = provider.baseUrl .. provider.endpoint
    local body = createRequestBody(provider, messages, options, tools)
    local headers = createHeaders(provider)
    
    local response = Http:jsonRequest(url, "POST", body, headers)
    
    if not response.success then
        return nil, response.error or "Request failed: " .. tostring(response.statusCode)
    end
    
    if not response.data then
        return nil, "Failed to parse response JSON"
    end
    
    local choice = response.data.choices and response.data.choices[1]
    if not choice then
        return nil, "No choices in response"
    end
    
    local assistantMessage = choice.message
    
    -- 处理工具调用
    if assistantMessage.tool_calls and #assistantMessage.tool_calls > 0 then
        -- 添加助手消息到历史
        table.insert(messages, assistantMessage)
        
        -- 执行工具调用
        for _, toolCall in ipairs(assistantMessage.tool_calls) do
            local toolName = toolCall["function"].name
            local toolArgs
            
            local ok, parsed = pcall(function()
                return HttpService:JSONDecode(toolCall["function"].arguments)
            end)
            toolArgs = ok and parsed or {}
            
            -- 执行工具
            local result
            if Tools then
                result = Tools:execute(toolName, toolArgs, {
                    Scanner = Scanner,
                    Reader = Reader
                })
            else
                result = {error = "Tools module not loaded"}
            end
            
            -- 格式化结果
            local resultText = Tools and Tools:formatResult(result) or HttpService:JSONEncode(result)
            
            -- 添加工具结果到消息
            table.insert(messages, {
                role = "tool",
                tool_call_id = toolCall.id,
                content = resultText
            })
        end
        
        -- 再次请求AI处理工具结果
        local followUpBody = createRequestBody(provider, messages, options, tools)
        local followUpResponse = Http:jsonRequest(url, "POST", followUpBody, headers)
        
        if followUpResponse.success and followUpResponse.data then
            local followUpChoice = followUpResponse.data.choices and followUpResponse.data.choices[1]
            if followUpChoice and followUpChoice.message then
                assistantMessage = followUpChoice.message
            end
        end
    end
    
    local content = assistantMessage and assistantMessage.content
    
    if not content then
        return nil, "No content in response"
    end
    
    -- 更新对话历史
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

-- 分析游戏资源（优化版：按需传递上下文）
function AIClient:analyzeResources(query, resourceContext, options)
    local Config = getDeps()
    
    -- 精简的系统提示
    local systemPrompt = [[You are a Roblox game analysis expert. You have access to tools to search and read game resources.

IMPORTANT: Use tools to get information when needed, don't guess.

Available tools:
- search_resources: Search for resources by name/type
- read_script: Read script source code
- get_remote_info: Get Remote details
- list_resources: List available resources

Be concise and practical. Generate working Lua code when asked.]]

    -- 只传递摘要信息，不传递完整资源列表
    local contextSummary = ""
    if resourceContext then
        contextSummary = string.format(
            "Game: %s\nRemotes available: %d\nScripts available: %d\nUse tools to get details.",
            resourceContext.gameName or "Unknown",
            #(resourceContext.remotes or {}),
            #(resourceContext.scripts or {})
        )
    end
    
    local userMessage
    if contextSummary ~= "" then
        userMessage = contextSummary .. "\n\n" .. query
    else
        userMessage = query
    end
    
    return self:chat(userMessage, systemPrompt, options)
end

-- 分析脚本源码
function AIClient:analyzeScripts(query, scriptsContext, options)
    local systemPrompt = [[You are a Roblox Lua code analyst. Analyze scripts and answer questions.

Focus on:
1. What the script does
2. Key functions and variables
3. RemoteEvent/RemoteFunction usage
4. Security considerations

Be concise.]]

    local scriptsInfo = ""
    for _, script in ipairs(scriptsContext.scripts or {}) do
        scriptsInfo = scriptsInfo .. string.format(
            "\n--- %s (%s) ---\nPath: %s\n\n%s\n",
            script.name, script.type, script.path,
            (script.source or "[No source]"):sub(1, 3000)
        )
    end
    
    local userMessage = string.format(
        "Scripts:\n%s\n\nQuestion: %s",
        scriptsInfo, query
    )
    
    return self:chat(userMessage, systemPrompt, options)
end

-- 生成代码
function AIClient:generateCode(prompt, context, options)
    local Config = getDeps()
    
    local systemPrompt = [[You are a Roblox Lua code generator. Generate clean, executable code.

Rules:
- Wrap code in ```lua blocks
- Use pcall for error handling
- Include brief comments
- Use executor functions when needed (getgenv, etc.)]]

    local userMessage = prompt
    if context then
        userMessage = "Context: " .. HttpService:JSONEncode(context):sub(1, 2000) .. "\n\nTask: " .. prompt
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
    
    local result, err = self:chat("Hello, respond with 'OK' to confirm connection.")
    
    if result then
        return true, "Connection successful to " .. provider.name
    else
        return false, "Connection failed: " .. tostring(err)
    end
end

return AIClient