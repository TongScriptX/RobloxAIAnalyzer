-- AI客户端：支持DeepSeek和OpenAI，支持工具调用和上下文管理
local AIClient = {}

local HttpService = game:GetService("HttpService")

-- 从全局获取依赖
local function getDeps()
    local deps = _G.AIAnalyzer or {}
    return deps.Config, deps.Http, deps.Tools, deps.Scanner, deps.Reader, deps.ContextManager, deps.UI, deps.Executor
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function startsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

local function buildRequestUrl(provider)
    local baseUrl = trim(provider.baseUrl)
    local endpoint = trim(provider.endpoint or "/v1/chat/completions")

    if baseUrl == "" then
        return endpoint
    end

    if startsWith(baseUrl, "http://") == false and startsWith(baseUrl, "https://") == false then
        baseUrl = "https://" .. baseUrl
    end

    if baseUrl:find("/chat/completions", 1, true) or baseUrl:find("/responses", 1, true) then
        return baseUrl
    end

    if endpoint == "" then
        return baseUrl
    end

    if baseUrl:sub(-1) == "/" then
        baseUrl = baseUrl:sub(1, -2)
    end
    if endpoint:sub(1, 1) ~= "/" then
        endpoint = "/" .. endpoint
    end

    return baseUrl .. endpoint
end

local function isDeepSeekProvider(provider)
    local baseUrl = trim(provider and provider.baseUrl or ""):lower()
    local model = trim(provider and provider.defaultModel or ""):lower()
    local name = trim(provider and provider.name or ""):lower()

    return baseUrl:find("deepseek", 1, true) ~= nil
        or model:find("deepseek", 1, true) ~= nil
        or name:find("deepseek", 1, true) ~= nil
end

local function formatRequestError(response)
    if not response then
        return "Request failed: no response"
    end

    local status = tostring(response.statusCode or 0)
    local detail = response.error or response.body

    if type(detail) == "string" and detail ~= "" then
        if #detail > 400 then
            detail = detail:sub(1, 400) .. "..."
        end
        return "HTTP " .. status .. ": " .. detail
    end

    return "HTTP " .. status
end

-- 创建请求体
local function createRequestBody(provider, messages, options, tools)
    local Config = getDeps()
    options = options or {}
    
    local body = {
        model = options.model or provider.defaultModel,
        messages = messages,
        max_tokens = options.maxTokens or (Config and Config.Settings and Config.Settings.maxTokens) or 8192,
        temperature = options.temperature or (Config and Config.Settings and Config.Settings.temperature) or 0.7,
        stream = false
    }
    
    -- 添加工具定义
    if options.includeTools ~= false and tools and #tools > 0 then
        body.tools = tools
        body.tool_choice = "auto"
    end
    
    return body
end

local function pickToolsByName(definitions, names)
    local wanted = {}
    local selected = {}
    for _, name in ipairs(names or {}) do
        if name and not wanted[name] then
            wanted[name] = true
        end
    end
    for _, def in ipairs(definitions or {}) do
        local fn = def["function"]
        if fn and wanted[fn.name] then
            selected[#selected + 1] = def
        end
    end
    return selected
end

local function selectToolNamesForQuery(query)
    local text = tostring(query or ""):lower()
    local names = {
        "search_resources",
        "read_script",
        "search_in_script",
    }

    local function add(name)
        for _, existing in ipairs(names) do
            if existing == name then
                return
            end
        end
        names[#names + 1] = name
    end

    if text:find("remote", 1, true) or text:find("远程", 1, true) then
        add("list_remotes")
        add("get_remote_info")
        add("analyze_remote_usage")
        add("call_remote")
        add("remote_interceptor")
    end
    if text:find("ui", 1, true) or text:find("hud", 1, true) or text:find("gui", 1, true) or text:find("界面", 1, true) then
        add("inspect_ui_resources")
    end
    if text:find("folder", 1, true) or text:find("目录", 1, true) or text:find("文件夹", 1, true) or text:find("结构", 1, true) then
        add("inspect_resource_folder")
    end
    if text:find("保存", 1, true) or text:find("脚本库", 1, true) or text:find("临时脚本", 1, true) or text:find("reuse", 1, true) or text:find("cache", 1, true) then
        add("list_saved_scripts")
        add("get_saved_script")
        add("save_temp_script")
    end
    if text:find("执行", 1, true) or text:find("运行", 1, true) or text:find("调用", 1, true) then
        add("run_script")
        add("run_saved_script")
    end
    if text:find("控制台", 1, true) or text:find("日志", 1, true) or text:find("console", 1, true) then
        add("get_console_output")
    end
    if text:find("列出", 1, true) or text:find("全部", 1, true) or text:find("资源", 1, true) then
        add("list_resources")
    end

    return names
end

-- 创建请求头
local function createHeaders(provider)
    return {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. provider.apiKey
    }
end

local TOOL_DISPLAY_NAMES = {
    ["scan_resources"] = "扫描游戏资源",
    ["get_resource_info"] = "获取资源信息",
    ["read_script"] = "读取脚本",
    ["save_script"] = "保存脚本",
    ["list_saved_scripts"] = "列出临时脚本",
    ["get_saved_script"] = "读取临时脚本",
    ["save_temp_script"] = "保存临时脚本",
    ["run_saved_script"] = "执行临时脚本",
    ["list_remotes"] = "列出 Remotes",
    ["get_remote_info"] = "获取 Remote 信息",
    ["analyze_remote_usage"] = "分析 Remote 使用",
    ["call_remote"] = "调用 Remote",
    ["remote_interceptor"] = "Remote 拦截",
    ["inspect_resource_folder"] = "查看文件夹结构",
    ["inspect_ui_resources"] = "查看 UI/HUD 资源",
    ["search_in_script"] = "搜索脚本内容",
    ["run_script"] = "执行脚本",
    ["get_game_info"] = "获取游戏信息",
    ["list_instances"] = "列出实例",
    ["get_console_output"] = "读取控制台日志"
}

local function buildToolStatusMessage(toolName, toolArgs, result)
    local displayName = TOOL_DISPLAY_NAMES[toolName] or toolName
    local statusMsg = "🔧 **" .. displayName .. "**"

    if toolArgs then
        if toolArgs.path then
            statusMsg = statusMsg .. "\n📁 路径: `" .. tostring(toolArgs.path) .. "`"
        end
        if toolArgs.name then
            statusMsg = statusMsg .. "\n📛 名称: `" .. tostring(toolArgs.name) .. "`"
        end
        if toolArgs.output_path then
            statusMsg = statusMsg .. "\n💾 保存到: `" .. tostring(toolArgs.output_path) .. "`"
        end
        if toolArgs.query then
            statusMsg = statusMsg .. "\n🔍 查询: `" .. tostring(toolArgs.query):sub(1, 50) .. "`"
        end
        if toolArgs.pattern then
            statusMsg = statusMsg .. "\n🔎 模式: `" .. tostring(toolArgs.pattern) .. "`"
        end
        if toolArgs.text then
            statusMsg = statusMsg .. "\n🔎 文本: `" .. tostring(toolArgs.text):sub(1, 50) .. "`"
        end
        if toolArgs.action then
            statusMsg = statusMsg .. "\n🛠️ 操作: `" .. tostring(toolArgs.action) .. "`"
        end
        if toolArgs.mode then
            statusMsg = statusMsg .. "\n⚙️ 模式: `" .. tostring(toolArgs.mode) .. "`"
        end
        if toolArgs.start_line or toolArgs.end_line then
            statusMsg = statusMsg .. "\n📍 行范围: " .. tostring(toolArgs.start_line or 1) .. "-" .. tostring(toolArgs.end_line or "末尾")
        end
        if toolArgs.description then
            statusMsg = statusMsg .. "\n📝 描述: " .. tostring(toolArgs.description)
        end
    end

    if result then
        if result.error then
            statusMsg = statusMsg .. "\n❌ 错误: " .. tostring(result.error)
        elseif result.count then
            statusMsg = statusMsg .. "\n✅ 找到 " .. tostring(result.count) .. " 个结果"
        elseif result.totalMatches then
            statusMsg = statusMsg .. "\n✅ 匹配 " .. tostring(result.totalMatches) .. " 处"
        elseif result.lines then
            statusMsg = statusMsg .. "\n✅ 共 " .. tostring(result.lines) .. " 行"
        elseif result.success then
            statusMsg = statusMsg .. "\n✅ 执行成功"
        end
    end

    return displayName, statusMsg
end

function AIClient:generateSessionTitle(messages)
    local Config, Http = getDeps()
    if not Config then
        return nil, "Config module not loaded"
    end

    local provider = Config:getCurrentProvider()
    if not provider or not provider.apiKey or provider.apiKey == "" then
        return nil, "API Key not configured"
    end
    if not Http or not Http:canRequestExternal() then
        return nil, "External HTTP requests not supported"
    end

    local lines = {}
    for _, msg in ipairs(messages or {}) do
        if msg.role == "user" or msg.role == "assistant" then
            local role = msg.role == "user" and "用户" or "AI"
            local content = trim(msg.content or ""):gsub("%s+", " ")
            if content ~= "" then
                lines[#lines + 1] = role .. ": " .. content:sub(1, 180)
            end
        end
        if #lines >= 12 then
            break
        end
    end

    if #lines == 0 then
        return nil, "No usable messages"
    end

    local promptMessages = {
        {
            role = "system",
            content = "请根据对话内容生成一个简短会话标题。要求：只输出标题本身；中文；10到18个字；不要引号，不要标点结尾，不要前缀。"
        },
        {
            role = "user",
            content = table.concat(lines, "\n")
        }
    }

    local url = buildRequestUrl(provider)
    local headers = createHeaders(provider)
    local body = {
        model = provider.defaultModel,
        messages = promptMessages,
        max_tokens = 32,
        temperature = 0.3,
        stream = false
    }

    local response = Http:jsonRequest(url, "POST", body, headers)
    if not response.success or not response.data then
        return nil, formatRequestError(response)
    end

    local choice = response.data.choices and response.data.choices[1]
    local title = choice and choice.message and choice.message.content
    title = trim(title or ""):gsub("[\r\n]+", " ")
    if title == "" then
        return nil, "Empty title response"
    end

    if #title > 32 then
        title = title:sub(1, 32)
    end
    return title
end

-- 发送聊天请求（支持工具调用和上下文管理）
function AIClient:chat(userMessage, systemPrompt, options)
    local Config, Http, Tools, Scanner, Reader, ContextManager, UI, Executor = getDeps()
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
    local isDeepSeek = isDeepSeekProvider(provider)
    
    -- 设置当前模型（用于上下文限制，优先使用 provider 配置的 contextWindow）
    if ctx then
        ctx:setModel(currentModel, provider.contextWindow)
    end
    
    -- 准备消息（使用上下文管理器）
    local messages
    
    if ctx then
        -- 添加用户消息到历史
        ctx:addUserMessage(userMessage)
        -- 获取包含历史的消息列表
        messages = ctx:getMessagesForAPI(systemPrompt, {
            includeReasoningContent = isDeepSeek,
            pruneToolMessages = true,
            keepRecentToolMessages = 4
        })
    else
        -- 无上下文管理，单次对话
        messages = {}
        if systemPrompt then
            table.insert(messages, {role = "system", content = systemPrompt})
        end
        table.insert(messages, {role = "user", content = userMessage})
    end
    
    -- 获取工具定义
    local toolNames = options.selectedToolNames or selectToolNamesForQuery(userMessage)
    local tools = Tools and pickToolsByName(Tools.definitions, toolNames)
    
    local url = buildRequestUrl(provider)
    local body = createRequestBody(provider, messages, options, tools)
    local headers = createHeaders(provider)
    
    local response = Http:jsonRequest(url, "POST", body, headers)
    
    if not response.success then
        return nil, formatRequestError(response)
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
    
    -- 累计所有请求的token使用量
    local totalUsage = {
        prompt_tokens = 0,
        completion_tokens = 0,
        total_tokens = 0
    }
    
    -- 累加初始请求的usage
    if response.data.usage then
        totalUsage.prompt_tokens = totalUsage.prompt_tokens + (response.data.usage.prompt_tokens or 0)
        totalUsage.completion_tokens = totalUsage.completion_tokens + (response.data.usage.completion_tokens or 0)
        totalUsage.total_tokens = totalUsage.total_tokens + (response.data.usage.total_tokens or 0)
        -- DeepSeek 特殊字段：缓存命中的token
        if response.data.usage.prompt_cache_hit_tokens then
            totalUsage.cache_hit_tokens = (totalUsage.cache_hit_tokens or 0) + response.data.usage.prompt_cache_hit_tokens
        end
        -- 用真实 token 数更新上下文管理器
        if ctx then ctx:updateRealTokenCount(response.data.usage) end
    end
    
    -- 处理工具调用（循环处理多次工具调用，无限制直到AI返回最终回复）
    local maxIterations = 100  -- 设置一个较高的上限作为安全保护
    local iteration = 0
    local lastToolResults = {}

    while assistantMessage.tool_calls and #assistantMessage.tool_calls > 0 and iteration < maxIterations do
        iteration = iteration + 1
        local uiToolGroups = {}
        local function queueToolGroup(toolName, toolArgs, result)
            if not UI then
                return
            end
            local displayName, statusMsg = buildToolStatusMessage(toolName, toolArgs, result)
            local group = uiToolGroups[toolName]
            if not group then
                group = {
                    displayName = displayName,
                    count = 0,
                    items = {}
                }
                uiToolGroups[toolName] = group
            end
            group.count = group.count + 1
            table.insert(group.items, string.format("**第 %d 次**\n%s", group.count, statusMsg))
        end
        local function flushToolGroups()
            if not UI then
                return
            end
            for _, toolCall in ipairs(assistantMessage.tool_calls or {}) do
                local group = uiToolGroups[toolCall["function"].name]
                if group and not group.rendered then
                    group.rendered = true
                    UI:addSystemMessage(table.concat(group.items, "\n\n---\n\n"), {
                        collapsible = true,
                        title = string.format("%s x%d", group.displayName, group.count)
                    })
                end
            end
        end

        -- 添加助手消息到历史
        if ctx then
            local extra = { tool_calls = assistantMessage.tool_calls }
            if isDeepSeek and assistantMessage.reasoning_content ~= nil then
                extra.reasoning_content = assistantMessage.reasoning_content
            end
            ctx:addMessage("assistant", assistantMessage.content or "", extra)
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
            if UI then
                local statusMap = {
                    ["scan_resources"] = "🔍 正在扫描游戏资源...",
                    ["get_resource_info"] = "📦 正在获取资源信息...",
                    ["read_script"] = "📄 正在读取脚本...",
                    ["save_script"] = "💾 正在保存脚本...",
                    ["list_saved_scripts"] = "🗃️ 正在列出临时脚本...",
                    ["get_saved_script"] = "📄 正在读取临时脚本...",
                    ["save_temp_script"] = "💾 正在保存临时脚本...",
                    ["run_saved_script"] = "⚡ 正在执行临时脚本...",
                    ["list_remotes"] = "📡 正在列出 Remotes...",
                    ["get_remote_info"] = "📡 正在获取 Remote 信息...",
                    ["analyze_remote_usage"] = "🧭 正在分析 Remote 使用...",
                    ["call_remote"] = "⚡ 正在调用 Remote...",
                    ["remote_interceptor"] = "🛡️ 正在更新 Remote 拦截...",
                    ["inspect_resource_folder"] = "🗂️ 正在查看文件夹结构...",
                    ["inspect_ui_resources"] = "🖥️ 正在查看 UI/HUD 资源...",
                    ["search_in_script"] = "🔍 正在搜索脚本内容...",
                    ["run_script"] = "⚡ 正在执行脚本...",
                    ["get_game_info"] = "🎮 正在获取游戏信息...",
                    ["list_instances"] = "📋 正在列出实例...",
                    ["get_console_output"] = "📋 正在读取控制台日志..."
                }
                UI:updateToolStatus(statusMap[toolName] or ("🔧 执行: " .. toolName))
            end
            
            -- 执行工具（添加错误捕获，防止工具执行卡住）
            local result
            if Tools then
                local success, toolResult = pcall(function()
                    return Tools:execute(toolName, toolArgs, {
                        Scanner = Scanner,
                        Reader = Reader,
                        Executor = Executor
                    })
                end)
                
                if success then
                    result = toolResult
                else
                    result = {error = "Tool execution failed: " .. tostring(toolResult)}
                    print("[AI CLI] 工具执行错误: " .. tostring(toolResult))
                end
            else
                result = {error = "Tools module not loaded"}
            end
            
            -- 检查是否需要用户确认
            if result.needsConfirmation then
                print("[AI CLI] 需要用户确认运行脚本")
                -- 把当前 tool 结果存入上下文
                local resultText = Tools and Tools:formatResult(result) or HttpService:JSONEncode(result)
                if ctx then
                    ctx:addToolResult(toolCall.id, resultText, toolName)
                    -- 为本次迭代中尚未处理的其余 tool_calls 补充占位结果，
                    -- 保证 assistant tool_calls 与 tool 消息一一对应，防止 JSONEncode 失败
                    local foundCurrent = false
                    for _, otherCall in ipairs(assistantMessage.tool_calls) do
                        if otherCall.id == toolCall.id then
                            foundCurrent = true
                        elseif foundCurrent then
                            ctx:addToolResult(otherCall.id, "[pending: awaiting user confirmation]", otherCall["function"] and otherCall["function"].name or "tool")
                        end
                    end
                end
                queueToolGroup(toolName, toolArgs, result)
                flushToolGroups()
                self._needsUserConfirmation = true
                return {
                    needsConfirmation = true,
                    description = result.description,
                    code = result.code,
                    codePreview = result.codePreview,
                    toolCallId = toolCall.id,
                    provider = provider.name,
                    contextStatus = ctx and ctx:getStatus()
                }
            end
            
            -- 格式化结果
            local resultText = Tools and Tools:formatResult(result) or HttpService:JSONEncode(result)
            lastToolResults[toolName] = result
            
            print("[AI CLI] 工具结果: " .. resultText:sub(1, 100))
            queueToolGroup(toolName, toolArgs, result)
            
            -- 添加工具结果到消息
            if ctx then
                ctx:addToolResult(toolCall.id, resultText, toolName)
            else
                table.insert(messages, {
                    role = "tool",
                    tool_call_id = toolCall.id,
                    content = resultText
                })
            end
        end
        flushToolGroups()
        
        -- 再次请求AI处理工具结果
        local followUpMessages
        if ctx then
            followUpMessages = ctx:getMessagesForAPI(systemPrompt, {
                includeReasoningContent = isDeepSeek,
                pruneToolMessages = true,
                keepRecentToolMessages = 4
            })
        else
            followUpMessages = messages
        end

        print(string.format("[AI CLI] follow-up 请求，消息数=%d", #followUpMessages))
        local followUpBody = createRequestBody(provider, followUpMessages, options, tools)
        local followUpResponse = Http:jsonRequest(url, "POST", followUpBody, headers)
        
        if not followUpResponse.success then
            warn("[AI CLI] Follow-up request failed: HTTP " .. tostring(followUpResponse.statusCode) ..
                 " | error=" .. tostring(followUpResponse.error) ..
                 " | body=" .. tostring(followUpResponse.body):sub(1, 300))
            local fallbackContent = self:generateFallbackContent(lastToolResults)
            if fallbackContent then
                return {
                    content = fallbackContent,
                    usage = totalUsage,
                    provider = provider.name,
                    contextStatus = ctx and ctx:getStatus()
                }
            end
            return nil, "Tool execution completed but follow-up request failed: " .. formatRequestError(followUpResponse)
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
        
        -- 累加follow-up请求的usage
        if followUpResponse.data.usage then
            totalUsage.prompt_tokens = totalUsage.prompt_tokens + (followUpResponse.data.usage.prompt_tokens or 0)
            totalUsage.completion_tokens = totalUsage.completion_tokens + (followUpResponse.data.usage.completion_tokens or 0)
            totalUsage.total_tokens = totalUsage.total_tokens + (followUpResponse.data.usage.total_tokens or 0)
            if followUpResponse.data.usage.prompt_cache_hit_tokens then
                totalUsage.cache_hit_tokens = (totalUsage.cache_hit_tokens or 0) + followUpResponse.data.usage.prompt_cache_hit_tokens
            end
            -- 用真实 token 数更新上下文管理器
            if ctx then ctx:updateRealTokenCount(followUpResponse.data.usage) end
        end
        
        assistantMessage = followUpChoice.message
    end
    
    -- 达到最大迭代次数时，发送最终请求让AI生成回复
    if iteration >= maxIterations then
        warn("[AI CLI] Reached max tool call iterations, sending final request for summary")
        
        -- 添加提示让AI生成总结
        if ctx then
            ctx:addUserMessage("已达到最大工具调用次数，请根据已收集的信息生成最终回复。")
        else
            table.insert(messages, {role = "user", content = "已达到最大工具调用次数，请根据已收集的信息生成最终回复。"})
        end
        
        local finalMessages
        if ctx then
            finalMessages = ctx:getMessagesForAPI(systemPrompt, {
                includeReasoningContent = isDeepSeek,
                pruneToolMessages = true,
                keepRecentToolMessages = 4
            })
        else
            finalMessages = messages
        end
        
        local finalBody = createRequestBody(provider, finalMessages, options, nil) -- 不传tools，强制生成回复
        local finalResponse = Http:jsonRequest(url, "POST", finalBody, headers)
        
        if finalResponse.success and finalResponse.data and finalResponse.data.choices then
            local finalChoice = finalResponse.data.choices[1]
            if finalChoice and finalChoice.message then
                -- 更新变量，让后续代码正确处理
                response = finalResponse
                choice = finalChoice
                assistantMessage = finalChoice.message
                
                -- 累加最终请求的usage
                if finalResponse.data.usage then
                    totalUsage.prompt_tokens = totalUsage.prompt_tokens + (finalResponse.data.usage.prompt_tokens or 0)
                    totalUsage.completion_tokens = totalUsage.completion_tokens + (finalResponse.data.usage.completion_tokens or 0)
                    totalUsage.total_tokens = totalUsage.total_tokens + (finalResponse.data.usage.total_tokens or 0)
                end
            end
        else
            -- 最终请求失败，使用fallback
            local fallbackContent = self:generateFallbackContent(lastToolResults)
            if fallbackContent and fallbackContent ~= "" then
                return {
                    content = fallbackContent,
                    usage = totalUsage,
                    provider = provider.name,
                    contextStatus = ctx and ctx:getStatus()
                }
            end
            return nil, "达到最大迭代次数且无法生成回复"
        end
    end
    
    -- 获取内容：分别处理 reasoning_content 和 content
    local reasoning = assistantMessage.reasoning_content
    local content = assistantMessage.content
    
    -- 如果没有 content，使用 reasoning 作为 content
    if not content or content == "" then
        content = reasoning
        reasoning = nil
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
        local extra = nil
        if isDeepSeek and assistantMessage.reasoning_content ~= nil then
            extra = { reasoning_content = assistantMessage.reasoning_content }
        end
        ctx:addMessage("assistant", content, extra)
    end
    
    -- 检查是否被截断
    local truncated = false
    if choice and choice.finish_reason == "length" then
        truncated = true
        content = content .. "\n\n⚠️ **响应被截断，请继续提问以获取完整内容**"
    end
    
    return {
        content = content,
        reasoning = reasoning,  -- 思考过程（可选）
        model = response.data.model,
        usage = totalUsage,  -- 使用累计的token统计
        provider = provider.name,
        contextStatus = ctx and ctx:getStatus(),
        truncated = truncated
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
    local Config = getDeps()  -- 获取配置，其他依赖在chat中获取
    
    local systemPrompt = [[You are a Roblox game analysis expert.

Rules:
1. Use function tools when game data is needed. Never print fake tool calls as text.
2. Keep tool use efficient. Prefer 1-3 focused calls, avoid repeating the same search.
3. After tool results, answer directly in Chinese with analysis, not just raw listings.
4. When generating Lua, keep it safe for gameplay: use spawn/task.defer for heavy work, batch large loops with task.wait(), avoid tight infinite loops.
5. If generating executable code, stop after the code so the user can confirm or ask for edits.

Available tools:
- search_resources: Search by name/type (use specific keywords)
- read_script: Read script source code
- save_script: Save script or executor file to executor path
- list_saved_scripts: List cached AI-generated scripts
- get_saved_script: Read a cached AI-generated script
- save_temp_script: Save or update a cached script
- run_saved_script: Execute a cached script directly
- list_remotes: List remotes
- get_remote_info: Get Remote details
- analyze_remote_usage: Find scripts that reference a remote
- call_remote: Call a remote directly
- remote_interceptor: Start/stop/status remote interception
- inspect_resource_folder: Inspect a folder/container resource tree
- inspect_ui_resources: Inspect HUD/UI tree and properties
- list_resources: List all resources of a type
- search_in_script: Search text/code inside scripts
- get_console_output: Read console output logs

Be concise. Respond in Chinese.]]

    local contextSummary = ""
    if resourceContext then
        contextSummary = string.format(
            "Game: %s\nRemotes: %d | Scripts: %d\nUse tools efficiently, then respond directly.",
            resourceContext.gameName or "Unknown",
            #(resourceContext.remotes or {}),
            #(resourceContext.scripts or {})
        )
    end

    -- 注入已知资源摘要，防止 AI 重复查询同一资源
    local knownSummary = Tools and Tools:getKnownResourcesSummary()
    if knownSummary then
        systemPrompt = systemPrompt .. "\n\n" .. knownSummary
    end

    local userMessage
    if contextSummary ~= "" then
        userMessage = contextSummary .. "\n\n" .. query
    else
        userMessage = query
    end

    options = options or {}
    options.selectedToolNames = selectToolNamesForQuery(query)
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
    local _, _, Tools, _, _, ContextManager = getDeps()

    if not ContextManager then
        return false, "ContextManager not loaded"
    end

    ContextManager.reset()
    -- 同步清空工具资源缓存，新对话从零开始
    if Tools then Tools:clearCache() end
    return true, "上下文已清空"
end

-- 测试API连接
function AIClient:testConnection()
    local Config, Http = getDeps()
    local provider = Config and Config:getCurrentProvider()
    
    if not provider or not provider.apiKey or provider.apiKey == "" then
        return false, "API Key not configured"
    end

    if not Http or not Http:canRequestExternal() then
        return false, "External HTTP requests not supported"
    end

    local url = buildRequestUrl(provider)
    local headers = createHeaders(provider)
    local body = {
        model = provider.defaultModel,
        messages = {
            {
                role = "user",
                content = "Reply with OK."
            }
        },
        max_tokens = 16,
        temperature = 0,
        stream = false
    }

    local response = Http:jsonRequest(url, "POST", body, headers)
    if not response.success then
        return false, "Connection failed: " .. formatRequestError(response)
    end

    if not response.data or not response.data.choices or not response.data.choices[1] then
        return false, "Connection failed: invalid response payload"
    end

    return true, "Connection successful to " .. provider.name
end

return AIClient
