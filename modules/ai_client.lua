-- AI客户端：支持DeepSeek和OpenAI，支持工具调用和上下文管理
local AIClient = {}

local HttpService = game:GetService("HttpService")

-- 从全局获取依赖
local function getDeps()
    local deps = _G.AIAnalyzer or {}
    return deps.Config, deps.Http, deps.Tools, deps.Scanner, deps.Reader, deps.ContextManager
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

-- 发送聊天请求（支持工具调用和上下文管理）
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
    
    -- 获取当前使用的模型
    local currentModel = options.model or provider.defaultModel
    
    -- 获取或初始化上下文管理器
    local ctx = ContextManager and ContextManager.getInstance()
    
    -- 设置当前模型（用于上下文限制）
    if ctx then
        ctx:setModel(currentModel)
    end
    
    -- 准备消息（使用上下文管理器）
    local messages
    
    if ctx then
        -- 添加用户消息到历史
        ctx:addUserMessage(userMessage)
        -- 获取包含历史的消息列表
        messages = ctx:getMessagesForAPI(systemPrompt)
    else
        -- 无上下文管理，单次对话
        messages = {}
        if systemPrompt then
            table.insert(messages, {role = "system", content = systemPrompt})
        end
        table.insert(messages, {role = "user", content = userMessage})
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
        if ctx then
            ctx:addAssistantMessage(nil, assistantMessage.tool_calls)
        else
            table.insert(messages, assistantMessage)
        end
        
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
            if ctx then
                ctx:addToolResult(toolCall.id, resultText)
            else
                table.insert(messages, {
                    role = "tool",
                    tool_call_id = toolCall.id,
                    content = resultText
                })
            end
        end
        
        -- 再次请求AI处理工具结果
        local followUpMessages
        if ctx then
            followUpMessages = ctx:getMessagesForAPI(systemPrompt)
        else
            followUpMessages = messages
        end
        
        local followUpBody = createRequestBody(provider, followUpMessages, options, tools)
        local followUpResponse = Http:jsonRequest(url, "POST", followUpBody, headers)
        
        if not followUpResponse.success then
            warn("[AI CLI] Follow-up request failed: " .. tostring(followUpResponse.error))
            local fallbackContent = self:generateFallbackContent(lastToolResults)
            if fallbackContent then
                return {
                    content = fallbackContent,
                    provider = provider.name,
                    contextStatus = ctx and ctx:getStatus()
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
    
    -- 达到最大迭代次数时，返回工具结果汇总
    if iteration >= maxIterations then
        warn("[AI CLI] Reached max tool call iterations, returning tool results")
        local fallbackContent = self:generateFallbackContent(lastToolResults)
        if fallbackContent then
            return {
                content = fallbackContent,
                provider = provider.name,
                contextStatus = ctx and ctx:getStatus()
            }
        end
    end
    
    -- 获取内容：优先使用 content，其次使用 reasoning_content
    local content = assistantMessage.content
    if not content or content == "" then
        content = assistantMessage.reasoning_content
    end
    
    -- 如果仍然没有内容，尝试使用工具结果
    if not content or content == "" then
        warn("[AI CLI] No content in response, using tool results")
        content = self:generateFallbackContent(lastToolResults)
    end
    
    if not content or content == "" then
        warn("[AI CLI] No content in response. assistantMessage: " .. HttpService:JSONEncode(assistantMessage or {}):sub(1, 500))
        if choice.finish_reason then
            warn("[AI CLI] finish_reason: " .. tostring(choice.finish_reason))
        end
        return nil, "No content in response (finish_reason: " .. tostring(choice.finish_reason) .. ")"
    end
    
    -- 添加助手回复到历史
    if ctx then
        ctx:addAssistantMessage(content)
    end
    
    return {
        content = content,
        model = response.data.model,
        usage = response.data.usage,
        provider = provider.name,
        contextStatus = ctx and ctx:getStatus()
    }
end

-- 生成备用内容（当工具调用后API请求失败或达到最大迭代时）
function AIClient:generateFallbackContent(toolResults)
    local parts = {}
    local allResources = {}
    local allScripts = {}
    local allRemotes = {}
    
    -- 收集所有结果
    for toolName, result in pairs(toolResults) do
        if result.error then
            -- 忽略错误，继续处理其他结果
        elseif result.results then
            for _, r in ipairs(result.results) do
                if r.type == "LocalScript" or r.type == "Script" or r.type == "ModuleScript" then
                    allScripts[r.name] = r
                elseif r.type == "RemoteEvent" or r.type == "RemoteFunction" then
                    allRemotes[r.name] = r
                else
                    allResources[r.name] = r
                end
            end
        elseif result.source then
            allScripts[result.name] = {
                name = result.name,
                type = result.type,
                path = result.path,
                source = result.source
            }
        elseif result.example then
            allRemotes[result.name] = {
                name = result.name,
                type = result.type,
                path = result.path,
                example = result.example
            }
        elseif result.remotes then
            for _, r in ipairs(result.remotes) do
                allRemotes[r.name] = r
            end
        elseif result.scripts then
            for _, s in ipairs(result.scripts) do
                allScripts[s.name] = s
            end
        end
    end
    
    -- 生成汇总
    parts[#parts + 1] = "📋 **资源扫描完成**\n"
    
    local resourceCount = 0
    for _ in pairs(allResources) do resourceCount = resourceCount + 1 end
    local scriptCount = 0
    for _ in pairs(allScripts) do scriptCount = scriptCount + 1 end
    local remoteCount = 0
    for _ in pairs(allRemotes) do remoteCount = remoteCount + 1 end
    
    if remoteCount > 0 then
        parts[#parts + 1] = string.format("\n**发现 %d 个 Remote:**", remoteCount)
        local count = 0
        for name, r in pairs(allRemotes) do
            if count >= 10 then
                parts[#parts + 1] = "... 还有更多"
                break
            end
            parts[#parts + 1] = string.format("- %s [%s] %s", name, r.type, r.path or "")
            count = count + 1
        end
    end
    
    if scriptCount > 0 then
        parts[#parts + 1] = string.format("\n**发现 %d 个脚本:**", scriptCount)
        local count = 0
        for name, s in pairs(allScripts) do
            if count >= 10 then
                parts[#parts + 1] = "... 还有更多"
                break
            end
            parts[#parts + 1] = string.format("- %s [%s] %s", name, s.type, s.path or "")
            count = count + 1
        end
    end
    
    if resourceCount > 0 then
        parts[#parts + 1] = string.format("\n**发现 %d 个其他资源:**", resourceCount)
        local count = 0
        for name, r in pairs(allResources) do
            if count >= 10 then
                parts[#parts + 1] = "... 还有更多"
                break
            end
            parts[#parts + 1] = string.format("- %s [%s] %s", name, r.type, r.path or "")
            count = count + 1
        end
    end
    
    -- 如果找到了 Chest 相关资源，生成示例脚本
    local chestScripts = {}
    for name, s in pairs(allScripts) do
        if name:lower():find("chest") then
            chestScripts[#chestScripts + 1] = s
        end
    end
    
    if #chestScripts > 0 then
        parts[#parts + 1] = "\n\n**📦 宝箱相关脚本:**"
        for _, s in ipairs(chestScripts) do
            if s.source then
                parts[#parts + 1] = string.format("\n**%s:**", s.name)
                parts[#parts + 1] = "```lua"
                parts[#parts + 1] = s.source:sub(1, 1500)
                if #s.source > 1500 then
                    parts[#parts + 1] = "... (已截断)"
                end
                parts[#parts + 1] = "```"
            end
        end
    end
    
    parts[#parts + 1] = "\n\n💡 **提示:** 如需更详细的分析，请告诉我具体要查看哪个资源。"
    
    return table.concat(parts, "\n")
end

-- 分析游戏资源
function AIClient:analyzeResources(query, resourceContext, options)
    local Config = getDeps()
    
    local systemPrompt = [[You are a Roblox game analysis expert. You have access to tools to search and read game resources.

IMPORTANT RULES:
1. Use tools efficiently - limit to 3-4 tool calls max before responding
2. Don't repeat the same search multiple times
3. After getting info, respond directly with useful code/analysis
4. If you can't find something after 2 searches, tell the user

Available tools:
- search_resources: Search by name/type (use specific keywords)
- read_script: Read script source code
- get_remote_info: Get Remote details
- list_resources: List all resources of a type

Be concise. Generate working Lua code when asked. Respond in Chinese.]]

    local contextSummary = ""
    if resourceContext then
        contextSummary = string.format(
            "Game: %s\nRemotes: %d | Scripts: %d\nUse tools efficiently, then respond directly.",
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

-- 手动压缩上下文
function AIClient:compressContext()
    local _, _, _, _, _, ContextManager = getDeps()
    
    if not ContextManager then
        return false, "ContextManager not loaded"
    end
    
    local ctx = ContextManager.getInstance()
    return ctx:compress()
end

-- 获取上下文状态
function AIClient:getContextStatus()
    local _, _, _, _, _, ContextManager = getDeps()
    
    if not ContextManager then
        return nil
    end
    
    local ctx = ContextManager.getInstance()
    return ctx:getStatus()
end

-- 格式化上下文状态
function AIClient:formatContextStatus()
    local _, _, _, _, _, ContextManager = getDeps()
    
    if not ContextManager then
        return "上下文管理器未加载"
    end
    
    local ctx = ContextManager.getInstance()
    return ctx:formatStatus()
end

-- 清空上下文
function AIClient:clearContext()
    local _, _, _, _, _, ContextManager = getDeps()
    
    if not ContextManager then
        return false, "ContextManager not loaded"
    end
    
    ContextManager.reset()
    return true, "上下文已清空"
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