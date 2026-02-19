-- AI客户端：支持DeepSeek和OpenAI，支持工具调用
local AIClient = {}

local HttpService = game:GetService("HttpService")

-- 从全局获取依赖
local function getDeps()
    local deps = _G.AIAnalyzer or {}
    return deps.Config, deps.Http, deps.Tools, deps.Scanner, deps.Reader
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

-- 发送聊天请求（支持工具调用）
function AIClient:chat(userMessage, systemPrompt, options)
    local Config, Http, Tools, Scanner, Reader = getDeps()
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
    
    -- 准备消息（不保留历史）
    local messages = {}
    
    if systemPrompt then
        table.insert(messages, {role = "system", content = systemPrompt})
    end
    
    table.insert(messages, {role = "user", content = userMessage})
    
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
        warn("[AI CLI] No choices in response. Raw response: " .. HttpService:JSONEncode(response.data):sub(1, 500))
        return nil, "No choices in response"
    end
    
    if not choice.message then
        warn("[AI CLI] No message in choice. Choice: " .. HttpService:JSONEncode(choice):sub(1, 300))
        return nil, "No message in response"
    end
    
    local assistantMessage = choice.message
    
    -- 处理工具调用（循环处理多次工具调用）
    local maxIterations = 10
    local iteration = 0
    local lastToolResults = {}
    
    while assistantMessage.tool_calls and #assistantMessage.tool_calls > 0 and iteration < maxIterations do
        iteration = iteration + 1
        
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
            
            print("[AI CLI] 执行工具: " .. toolName)
            
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
            lastToolResults[toolName] = result
            
            print("[AI CLI] 工具结果: " .. resultText:sub(1, 200))
            
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
        
        if not followUpResponse.success then
            warn("[AI CLI] Follow-up request failed: " .. tostring(followUpResponse.error))
            -- 尝试生成基于工具结果的回复
            local fallbackContent = self:generateFallbackContent(lastToolResults)
            if fallbackContent then
                return {
                    content = fallbackContent,
                    provider = provider.name
                }
            end
            return nil, "Tool execution completed but follow-up request failed"
        end
        
        if not followUpResponse.data then
            warn("[AI CLI] No data in follow-up response")
            return nil, "No data in follow-up response"
        end
        
        local followUpChoice = followUpResponse.data.choices and followUpResponse.data.choices[1]
        if not followUpChoice then
            warn("[AI CLI] No choices in follow-up response")
            return nil, "No choices in follow-up response"
        end
        
        if not followUpChoice.message then
            warn("[AI CLI] No message in follow-up choice")
            return nil, "No message in follow-up response"
        end
        
        assistantMessage = followUpChoice.message
    end
    
    if iteration >= maxIterations then
        warn("[AI CLI] Reached max tool call iterations")
    end
    
    -- 获取内容：优先使用 content，其次使用 reasoning_content
    local content = assistantMessage.content
    if not content or content == "" then
        content = assistantMessage.reasoning_content
    end
    
    if not content or content == "" then
        warn("[AI CLI] No content in response. assistantMessage: " .. HttpService:JSONEncode(assistantMessage or {}):sub(1, 500))
        if choice.finish_reason then
            warn("[AI CLI] finish_reason: " .. tostring(choice.finish_reason))
        end
        return nil, "No content in response (finish_reason: " .. tostring(choice.finish_reason) .. ")"
    end
    
    return {
        content = content,
        model = response.data.model,
        usage = response.data.usage,
        provider = provider.name
    }
end

-- 生成备用内容（当工具调用后API请求失败时）
function AIClient:generateFallbackContent(toolResults)
    local parts = {}
    
    for toolName, result in pairs(toolResults) do
        if result.error then
            parts[#parts + 1] = string.format("**%s 结果:** %s", toolName, result.error)
        elseif result.results then
            parts[#parts + 1] = string.format("**%s 找到 %d 个结果:**", toolName, result.count)
            for i, r in ipairs(result.results) do
                if i > 10 then
                    parts[#parts + 1] = "... 还有 " .. (result.count - 10) .. " 个"
                    break
                end
                parts[#parts + 1] = string.format("- %s [%s] %s", r.name, r.type, r.path or "")
            end
        elseif result.source then
            parts[#parts + 1] = string.format("**脚本 %s (%s):**", result.name, result.type)
            parts[#parts + 1] = string.format("路径: %s", result.path)
            parts[#parts + 1] = "```lua"
            parts[#parts + 1] = result.source:sub(1, 2000)
            if #result.source > 2000 then
                parts[#parts + 1] = "... (已截断)"
            end
            parts[#parts + 1] = "```"
        elseif result.example then
            parts[#parts + 1] = string.format("**Remote: %s (%s)**", result.name, result.type)
            parts[#parts + 1] = string.format("路径: %s", result.path)
            parts[#parts + 1] = "```lua"
            parts[#parts + 1] = result.example
            parts[#parts + 1] = "```"
        elseif result.remotes or result.scripts then
            if result.remotes and #result.remotes > 0 then
                parts[#parts + 1] = string.format("**Remotes (%d):**", result.remoteCount or #result.remotes)
                for i, r in ipairs(result.remotes) do
                    parts[#parts + 1] = string.format("- %s [%s]", r.name, r.type)
                end
            end
            if result.scripts and #result.scripts > 0 then
                parts[#parts + 1] = string.format("**Scripts (%d):**", result.scriptCount or #result.scripts)
                for i, s in ipairs(result.scripts) do
                    parts[#parts + 1] = string.format("- %s [%s]", s.name, s.type)
                end
            end
        end
    end
    
    if #parts > 0 then
        return "工具执行结果:\n\n" .. table.concat(parts, "\n")
    end
    
    return nil
end

-- 分析游戏资源
function AIClient:analyzeResources(query, resourceContext, options)
    local Config = getDeps()
    
    local systemPrompt = [[You are a Roblox game analysis expert. You have access to tools to search and read game resources.

IMPORTANT: Use tools to get information when needed, don't guess.

Available tools:
- search_resources: Search for resources by name/type
- read_script: Read script source code
- get_remote_info: Get Remote details
- list_resources: List available resources

Be concise and practical. Generate working Lua code when asked.]]

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
