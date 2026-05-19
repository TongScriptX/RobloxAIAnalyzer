-- 上下文管理模块
-- 管理对话历史、自动压缩、token计数

local ContextManager = {}

-- 模型上下文限制配置（tokens）- 基于2025年官方文档
local MODEL_LIMITS = {
    -- OpenAI
    ["gpt-4o"] = 128000,
    ["gpt-4o-mini"] = 128000,
    ["gpt-4-turbo"] = 128000,
    ["gpt-4"] = 8192,
    ["gpt-3.5-turbo"] = 16384,
    
    -- DeepSeek (API版本)
    ["deepseek-chat"] = 64000,
    ["deepseek-coder"] = 16000,
    ["deepseek-reasoner"] = 128000,
    ["deepseek-v3"] = 128000,
    ["deepseek-v3.2"] = 128000,
    ["deepseek-r1"] = 128000,
    
    -- GLM 智谱
    ["glm-4-plus"] = 128000,
    ["glm-4"] = 128000,
    ["glm-4-flash"] = 128000,
    ["glm-4.6"] = 200000,
    ["glm-4-long"] = 1000000,
    
    -- Qwen 通义千问
    ["qwen3-coder-plus"] = 256000,
    ["qwen3-max"] = 256000,
    ["qwen3-max-preview"] = 256000,
    ["qwen3-vl-plus"] = 128000,
    ["qwen-plus"] = 128000,
    
    -- Kimi 月之暗面
    ["kimi-k2"] = 200000,
    ["kimi-k2-0905"] = 200000,
    
    -- iFlow
    ["iflow-rome"] = 128000,
    
    -- 默认
    ["default"] = 32768
}

-- 压缩阈值（参考 Claude Code：85% 触发压缩）
local COMPRESS_THRESHOLD = 0.85

-- 工具输出最大字符数（超出则截断，保留头尾）
local TOOL_OUTPUT_MAX_CHARS = 30000

-- 初始化
function ContextManager:init()
    self.messages = {}  -- 对话历史
    self.summary = nil  -- 历史摘要
    self.totalTokens = 0
    self.maxTokens = MODEL_LIMITS["default"]
    
    return self
end

-- 获取模型上下文限制
function ContextManager:getModelLimit(modelName)
    if not modelName then return MODEL_LIMITS["default"] end
    
    local model = modelName:lower()
    
    -- 精确匹配
    if MODEL_LIMITS[model] then
        return MODEL_LIMITS[model]
    end
    
    -- 模糊匹配
    for pattern, limit in pairs(MODEL_LIMITS) do
        if model:find(pattern) then
            return limit
        end
    end
    
    return MODEL_LIMITS["default"]
end

-- 设置当前模型（contextWindow 可选，优先级高于内置表）
function ContextManager:setModel(modelName, contextWindow)
    if contextWindow and contextWindow > 0 then
        self.maxTokens = contextWindow
    else
        self.maxTokens = self:getModelLimit(modelName)
    end
    self.modelName = modelName
end

-- 估算token数量（参考 Claude Code：英文4字符/token，中文1.5字符/token）
function ContextManager:estimateTokens(text)
    if not text then return 0 end

    local chineseChars = 0
    -- 统计 UTF-8 三字节序列（中日韩字符范围 U+4E00–U+9FFF 等）
    for _ in text:gmatch("[\224-\239][\128-\191][\128-\191]") do
        chineseChars = chineseChars + 1
    end
    local otherChars = #text - chineseChars * 3  -- 剩余字节视为 ASCII/英文

    -- 中文约 1.5 字符/token，英文约 4 字符/token
    return math.ceil(chineseChars / 1.5 + math.max(0, otherChars) / 4)
end

-- 计算消息的token数
function ContextManager:countMessageTokens(message)
    local total = 0
    
    -- 角色开销
    total = total + 4  -- role + content 结构
    
    if message.role then
        total = total + self:estimateTokens(message.role)
    end
    
    if message.content then
        total = total + self:estimateTokens(message.content)
    end
    
    if message.name then
        total = total + self:estimateTokens(message.name)
    end
    
    -- 工具调用
    if message.tool_calls then
        for _, tc in ipairs(message.tool_calls) do
            if tc["function"] then
                total = total + self:estimateTokens(tc["function"].name)
                total = total + self:estimateTokens(tc["function"].arguments)
            end
        end
    end
    
    return total
end

-- 重新计算总token数
function ContextManager:recalculateTokens()
    self.totalTokens = 0
    
    for _, msg in ipairs(self.messages) do
        self.totalTokens = self.totalTokens + self:countMessageTokens(msg)
    end
    
    return self.totalTokens
end

-- 添加消息
function ContextManager:addMessage(role, content, extra)
    local message = {
        role = role,
        content = content
    }
    
    -- 添加额外字段
    if extra then
        for k, v in pairs(extra) do
            message[k] = v
        end
    end
    
    table.insert(self.messages, message)
    self.totalTokens = self.totalTokens + self:countMessageTokens(message)
    
    -- 检查是否需要压缩
    if self:shouldCompress() then
        self:autoCompress()
    end
    
    return message
end

-- 添加用户消息
function ContextManager:addUserMessage(content)
    return self:addMessage("user", content)
end

-- 添加助手消息
function ContextManager:addAssistantMessage(content, toolCalls)
    local extra = nil
    if toolCalls then
        extra = { tool_calls = toolCalls }
    end
    -- 当有 tool_calls 时 content 必须为字符串，否则部分 API 会返回 400
    return self:addMessage("assistant", content or "", extra)
end

-- 添加工具结果（超长输出自动截断，保留头尾）
function ContextManager:addToolResult(toolCallId, content)
    local text = tostring(content or "")
    if #text > TOOL_OUTPUT_MAX_CHARS then
        local head = text:sub(1, TOOL_OUTPUT_MAX_CHARS * 0.6)
        local tail = text:sub(-math.floor(TOOL_OUTPUT_MAX_CHARS * 0.3))
        text = head .. "\n...[output truncated]...\n" .. tail
    end
    return self:addMessage("tool", text, { tool_call_id = toolCallId })
end

-- 获取使用率
function ContextManager:getUsageRatio()
    if self.maxTokens <= 0 then return 0 end
    return self.totalTokens / self.maxTokens
end

-- 是否应该压缩
function ContextManager:shouldCompress()
    return self:getUsageRatio() >= COMPRESS_THRESHOLD
end

-- 自动压缩（参考 Claude Code：保留 summary + 最近 4 条消息）
function ContextManager:autoCompress()
    local keepCount = 4  -- 保留最近 2 轮对话

    if #self.messages <= keepCount then
        return false, "消息数量太少，无需压缩"
    end

    -- 安全截断：cutAt 之后的第一条消息不能是 tool（避免破坏 tool_calls/tool 配对）
    local cutAt = #self.messages - keepCount
    while cutAt > 0 and self.messages[cutAt + 1] and self.messages[cutAt + 1].role == "tool" do
        cutAt = cutAt - 1
    end

    if cutAt <= 0 then
        return false, "无法安全截断，跳过压缩"
    end

    local toCompress = {}
    for i = 1, cutAt do
        table.insert(toCompress, self.messages[i])
    end

    self.summary = self:generateSummary(toCompress, self.summary)

    for i = 1, #toCompress do
        table.remove(self.messages, 1)
    end

    self:recalculateTokens()

    return true, string.format("已压缩 %d 条消息", #toCompress)
end

-- 生成摘要（记录用户问题、AI 结论、工具调用、生成代码）
function ContextManager:generateSummary(messages, oldSummary)
    local parts = {}

    if oldSummary then
        table.insert(parts, "【历史摘要】")
        table.insert(parts, oldSummary)
        table.insert(parts, "")
        table.insert(parts, "【新增对话】")
    end

    local userQueries = {}
    local aiConclusions = {}
    local toolsUsed = {}
    local codeGenerated = {}

    for _, msg in ipairs(messages) do
        if msg.role == "user" then
            table.insert(userQueries, msg.content)
        elseif msg.role == "assistant" then
            if msg.content and msg.content ~= "" then
                -- 取前 150 字作为结论摘要
                table.insert(aiConclusions, msg.content:sub(1, 150))
                local code = msg.content:match("```lua\n(.-)```")
                if code then
                    table.insert(codeGenerated, code:sub(1, 200))
                end
            end
            if msg.tool_calls then
                for _, tc in ipairs(msg.tool_calls) do
                    if tc["function"] then
                        table.insert(toolsUsed, tc["function"].name)
                    end
                end
            end
        end
    end

    if #userQueries > 0 then
        table.insert(parts, "用户问题:")
        for i, q in ipairs(userQueries) do
            if i <= 5 then
                table.insert(parts, "  - " .. q:sub(1, 120))
            end
        end
    end

    if #aiConclusions > 0 then
        table.insert(parts, "AI 回复要点:")
        for i, c in ipairs(aiConclusions) do
            if i <= 3 then
                table.insert(parts, "  - " .. c:gsub("\n", " "))
            end
        end
    end

    if #toolsUsed > 0 then
        -- 去重
        local seen = {}
        local unique = {}
        for _, t in ipairs(toolsUsed) do
            if not seen[t] then seen[t] = true; table.insert(unique, t) end
        end
        table.insert(parts, "使用工具: " .. table.concat(unique, ", "))
    end

    if #codeGenerated > 0 then
        table.insert(parts, "生成了 " .. #codeGenerated .. " 段代码")
    end

    return table.concat(parts, "\n")
end

-- 用 API 返回的真实 token 数更新计数（覆盖本地估算值）
function ContextManager:updateRealTokenCount(usage)
    if not usage then return end
    local real = usage.total_tokens or usage.prompt_tokens
    if real and real > 0 then
        self.totalTokens = real
    end
end

-- 手动压缩
function ContextManager:compress()
    return self:autoCompress()
end

-- 清空历史
function ContextManager:clear()
    self.messages = {}
    self.summary = nil
    self.totalTokens = 0
end

-- 净化单条消息，只保留 API 需要的字段，防止 JSONEncode 失败
local function sanitizeMessage(msg)
    local clean = {
        role = tostring(msg.role or ""),
        content = msg.content ~= nil and tostring(msg.content) or nil,
    }
    -- tool 消息
    if msg.tool_call_id then
        clean.tool_call_id = tostring(msg.tool_call_id)
    end
    -- assistant 消息的 tool_calls
    if msg.tool_calls then
        clean.tool_calls = {}
        for _, tc in ipairs(msg.tool_calls) do
            local cleanTc = { id = tostring(tc.id or ""), type = tostring(tc.type or "function") }
            if tc["function"] then
                cleanTc["function"] = {
                    name = tostring(tc["function"].name or ""),
                    arguments = tostring(tc["function"].arguments or "{}")
                }
            end
            table.insert(clean.tool_calls, cleanTc)
        end
    end
    -- DeepSeek 思考模式：reasoning_content 必须原样传回
    if msg.reasoning_content ~= nil then
        clean.reasoning_content = tostring(msg.reasoning_content)
    end
    return clean
end

-- 获取用于API的消息列表
function ContextManager:getMessagesForAPI(systemPrompt)
    local result = {}

    -- 系统提示
    if systemPrompt then
        table.insert(result, {
            role = "system",
            content = systemPrompt
        })
    end

    -- 如果有摘要，添加摘要作为上下文
    if self.summary then
        table.insert(result, {
            role = "system",
            content = "【对话历史摘要】\n" .. self.summary
        })
    end

    -- 添加对话历史（净化后再加入，防止 JSONEncode 失败）
    for _, msg in ipairs(self.messages) do
        table.insert(result, sanitizeMessage(msg))
    end

    return result
end

-- 获取状态信息
function ContextManager:getStatus()
    return {
        messageCount = #self.messages,
        totalTokens = self.totalTokens,
        maxTokens = self.maxTokens,
        usageRatio = self:getUsageRatio(),
        usagePercent = math.floor(self:getUsageRatio() * 100),
        hasSummary = self.summary ~= nil,
        modelName = self.modelName
    }
end

-- 格式化状态显示
function ContextManager:formatStatus()
    local status = self:getStatus()
    local bar = self:generateProgressBar(status.usageRatio)
    
    return string.format(
        "📊 上下文状态\n" ..
        "模型: %s\n" ..
        "消息: %d 条\n" ..
        "Token: %d / %d (%.1f%%)\n" ..
        "使用: [%s]\n" ..
        "摘要: %s",
        status.modelName or "未知",
        status.messageCount,
        status.totalTokens,
        status.maxTokens,
        status.usagePercent,
        bar,
        status.hasSummary and "已生成" or "无"
    )
end

-- 生成进度条
function ContextManager:generateProgressBar(ratio)
    local width = 20
    local filled = math.floor(ratio * width)
    local empty = width - filled
    
    local bar = string.rep("█", filled) .. string.rep("░", empty)
    
    -- 颜色标记（使用符号表示）
    if ratio < 0.5 then
        return bar .. " 🟢"
    elseif ratio < 0.7 then
        return bar .. " 🟡"
    else
        return bar .. " 🔴"
    end
end

-- 创建单例
local instance = nil

function ContextManager.getInstance()
    if not instance then
        instance = ContextManager:init()
    end
    return instance
end

-- 重置实例
function ContextManager.reset()
    instance = nil
    return ContextManager.getInstance()
end

return ContextManager