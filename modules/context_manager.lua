-- 上下文管理模块
-- 负责追踪token使用、自动压缩、对话总结

local ContextManager = {}

local HttpService = game:GetService("HttpService")

-- 初始化
function ContextManager:init()
    self.tokenCount = 0
    self.messageCount = 0
    self.lastCompactMessage = 0
    self.summary = nil
end

-- 估算文本token数（简单估算：约4字符=1token）
local function estimateTokens(text)
    if not text then return 0 end
    -- 中文约1.5字符/token，英文约4字符/token
    local chineseCount = select(2, text:gsub("[\228-\233]", ""))
    local otherCount = #text - chineseCount
    return math.ceil(chineseCount / 1.5 + otherCount / 4)
end

-- 估算消息token数
local function estimateMessageTokens(message)
    local total = 0
    
    if message.content then
        total = total + estimateTokens(message.content)
    end
    
    if message.role then
        total = total + 4  -- role约4 tokens
    end
    
    -- 工具调用
    if message.tool_calls then
        for _, tc in ipairs(message.tool_calls) do
            if tc.function and tc.function.arguments then
                total = total + estimateTokens(tc.function.arguments)
            end
        end
    end
    
    return total
end

-- 计算对话总token
function ContextManager:countConversationTokens(messages)
    local total = 0
    for _, msg in ipairs(messages) do
        total = total + estimateMessageTokens(msg)
    end
    return total
end

-- 检查是否需要压缩
function ContextManager:shouldCompact(messages, config, provider)
    if not config or not config.autoCompact then
        return false
    end
    
    local contextWindow = provider and provider.contextWindow or 64000
    local outputReserve = config.outputReserve or 8000
    local compactionReserve = config.compactionReserve or 4000
    local threshold = config.compressionThreshold or 0.70
    
    local availableForInput = contextWindow - outputReserve - compactionReserve
    local used = self:countConversationTokens(messages)
    
    -- 计算使用百分比
    local usagePercent = used / availableForInput
    
    -- 检查消息间隔
    local messageInterval = self.messageCount - self.lastCompactMessage
    local minInterval = config.minCompactInterval or 3
    
    return usagePercent >= threshold and messageInterval >= minInterval
end

-- 获取上下文使用信息
function ContextManager:getUsageInfo(messages, provider)
    local contextWindow = provider and provider.contextWindow or 64000
    local used = self:countConversationTokens(messages)
    local available = contextWindow - (self.outputReserve or 8000)
    
    return {
        used = used,
        available = available,
        total = contextWindow,
        percent = used / available,
        remaining = available - used
    }
end

-- 生成压缩摘要
function ContextManager:generateCompactPrompt(messages, focusHint)
    local prompt = [[You are creating a CONTEXT CHECKPOINT for a conversation that will be continued. Generate a detailed summary that allows seamless continuation.

Include these sections:

## Summary Title
A brief 5-10 word title describing the main topic

## Completed Work
- What tasks were accomplished
- Key code changes or decisions made

## Current State
- What is being worked on now
- Files or resources involved
- Any errors encountered and how they were fixed

## Next Steps
- Clear actions to take next
- Pending user requests

## Key Decisions & Constraints
- Important technical choices made
- User preferences or requirements to remember
- API keys or configuration (do NOT include actual API keys)

## Important Context
- Any critical information needed to continue
- Variable names, function signatures, or code patterns discussed

Be concise but preserve enough detail to continue without re-asking questions.

]]
    
    if focusHint then
        prompt = prompt .. "\n\nFocus on: " .. focusHint
    end
    
    return prompt
end

-- 执行压缩（返回新的消息列表）
function ContextManager:compact(messages, config, opts)
    opts = opts or {}
    local preserveRecent = config and config.preserveRecentMessages or 4
    
    -- 保留最近的消息
    local recentMessages = {}
    for i = math.max(1, #messages - preserveRecent + 1), #messages do
        table.insert(recentMessages, messages[i])
    end
    
    -- 创建摘要消息
    local summaryMessage = {
        role = "assistant",
        content = "[CONTEXT COMPACTED]\n" .. (self.summary or "Previous conversation has been summarized for context efficiency."),
        isSummary = true
    }
    
    -- 构建新消息列表
    local newMessages = {summaryMessage}
    for _, msg in ipairs(recentMessages) do
        table.insert(newMessages, msg)
    end
    
    self.lastCompactMessage = self.messageCount
    self.summary = nil
    
    return newMessages
end

-- 更新统计
function ContextManager:recordMessage(message)
    self.messageCount = self.messageCount + 1
    self.tokenCount = self.tokenCount + estimateMessageTokens(message)
end

-- 为Session生成标题
function ContextManager:generateSessionTitle(messages)
    -- 取第一条用户消息的前50个字符作为标题基础
    for _, msg in ipairs(messages) do
        if msg.role == "user" and msg.content then
            local content = msg.content
            -- 提取关键部分
            local title = content:gsub("\n", " "):sub(1, 50)
            if #title < #content then
                title = title .. "..."
            end
            return title
        end
    end
    return "新对话"
end

-- 总结对话用于session标题
function ContextManager:summarizeForTitle(messages, maxMessages)
    maxMessages = maxMessages or 6
    local parts = {}
    
    -- 收集最近的消息
    local startIdx = math.max(1, #messages - maxMessages + 1)
    for i = startIdx, #messages do
        local msg = messages[i]
        if msg.role == "user" then
            local content = msg.content or ""
            -- 提取前30字符
            local snippet = content:gsub("\n", " "):sub(1, 30)
            table.insert(parts, "用户: " .. snippet)
        end
    end
    
    if #parts > 0 then
        return parts[#parts]:gsub("^用户: ", "")
    end
    
    return "新对话"
end

-- 初始化
ContextManager:init()

return ContextManager
