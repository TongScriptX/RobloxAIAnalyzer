-- 上下文管理模块
-- 参考 Claude Code, OpenAI Codex, Gemini Code 的 token 优化策略
-- 核心原则：分层上下文、智能压缩、缓存友好

local ContextManager = {}

local HttpService = game:GetService("HttpService")

-- 配置
ContextManager.config = {
    -- 压缩阈值（70%使用时触发）
    compressionThreshold = 0.70,
    -- 输出预留
    outputReserve = 8000,
    -- 压缩预留
    compactionReserve = 4000,
    -- 保留最近消息数
    preserveRecentMessages = 4,
    -- 最小压缩间隔（消息数）
    minCompactInterval = 3,
    -- 自动压缩
    autoCompact = true
}

-- 状态
ContextManager.state = {
    tokenCount = 0,
    messageCount = 0,
    lastCompactMessage = 0,
    summary = nil,
    keyDecisions = {},
    completedTasks = {}
}

-- Token 估算（优化版）
local function estimateTokens(text)
    if not text then return 0 end
    if type(text) ~= "string" then return 0 end
    
    -- 中文约1.5字符/token，英文约4字符/token
    local chineseCount = select(2, text:gsub("[\228-\233]", ""))
    local otherCount = #text - chineseCount
    local tokens = math.ceil(chineseCount / 1.5 + otherCount / 4)
    
    return tokens
end

-- 估算消息token数（含工具调用）
local function estimateMessageTokens(message)
    local total = 10  -- 基础开销
    
    if message.content then
        total = total + estimateTokens(message.content)
    end
    
    -- 工具调用
    if message.tool_calls then
        for _, tc in ipairs(message.tool_calls) do
            total = total + 20  -- 工具调用开销
            if tc.function then
                if tc.function.name then
                    total = total + estimateTokens(tc.function.name)
                end
                if tc.function.arguments then
                    total = total + estimateTokens(tc.function.arguments)
                end
            end
        end
    end
    
    -- 工具结果
    if message.tool_call_id then
        total = total + 10
    end
    
    return total
end

-- 计算对话总token
function ContextManager:countTokens(messages)
    local total = 0
    for _, msg in ipairs(messages) do
        total = total + estimateMessageTokens(msg)
    end
    return total
end

-- 获取上下文使用情况
function ContextManager:getUsage(messages, provider)
    local contextWindow = provider and provider.contextWindow or 64000
    local available = contextWindow - self.config.outputReserve
    local used = self:countTokens(messages)
    
    return {
        used = used,
        total = contextWindow,
        available = available,
        percent = used / available,
        remaining = available - used
    }
end

-- 检查是否需要压缩
function ContextManager:shouldCompact(messages, config, provider)
    config = config or self.config
    
    if not config.autoCompact then
        return false
    end
    
    local usage = self:getUsage(messages, provider)
    
    -- 检查消息间隔，避免频繁压缩
    local interval = self.state.messageCount - self.state.lastCompactMessage
    if interval < (config.minCompactInterval or 3) then
        return false
    end
    
    return usage.percent >= (config.compressionThreshold or 0.70)
end

-- 智能压缩提示生成（参考 Claude Code）
function ContextManager:generateCompactPrompt(messages)
    return [[Create a CONTEXT CHECKPOINT to continue this conversation efficiently.

Format your response as:

## 📋 Summary
One sentence describing the conversation topic.

## ✅ Completed
- List completed tasks
- Key code/decisions made

## 🔄 Current
- What's being worked on
- Files/resources involved
- Errors encountered (and fixes)

## ➡️ Next
- Clear next steps
- Pending requests

## 📌 Key Info
- Important technical decisions
- User preferences
- Variable names/patterns discussed

Be concise. Preserve critical details for continuation.]]
end

-- 提取关键信息（用于压缩后保留）
function ContextManager:extractKeyInfo(messages)
    local keyInfo = {
        decisions = {},
        files = {},
        errors = {},
        userPrefs = {}
    }
    
    for _, msg in ipairs(messages) do
        local content = msg.content or ""
        
        -- 提取文件路径
        for path in content:gmatch("[%w_/]+%.lua") do
            table.insert(keyInfo.files, path)
        end
        
        -- 提取错误信息
        local err = content:match("[Ee]rror[:：]%s*([^\n]+)")
        if err then
            table.insert(keyInfo.errors, err)
        end
    end
    
    return keyInfo
end

-- 执行压缩
function ContextManager:compact(messages, config, opts)
    opts = opts or {}
    config = config or self.config
    
    local preserveCount = config.preserveRecentMessages or 4
    local force = opts.force
    
    -- 如果消息太少且非强制，不压缩
    if #messages <= preserveCount + 2 and not force then
        return messages
    end
    
    -- 提取关键信息
    local keyInfo = self:extractKeyInfo(messages)
    
    -- 构建摘要
    local summaryParts = {
        "[CONTEXT COMPACTED - Key info preserved]"
    }
    
    if #keyInfo.files > 0 then
        local filesStr = table.concat(keyInfo.files, ", "):sub(1, 200)
        summaryParts[#summaryParts + 1] = "Files: " .. filesStr
    end
    
    if self.state.summary then
        summaryParts[#summaryParts + 1] = "Previous: " .. self.state.summary
    end
    
    -- 保留最近的消息
    local recentMessages = {}
    local startIdx = math.max(1, #messages - preserveCount + 1)
    for i = startIdx, #messages do
        table.insert(recentMessages, messages[i])
    end
    
    -- 构建新消息列表
    local newMessages = {
        {
            role = "assistant",
            content = table.concat(summaryParts, "\n"),
            isSummary = true
        }
    }
    
    for _, msg in ipairs(recentMessages) do
        table.insert(newMessages, msg)
    end
    
    -- 更新状态
    self.state.lastCompactMessage = self.state.messageCount
    
    return newMessages
end

-- 记录消息
function ContextManager:recordMessage(message)
    self.state.messageCount = self.state.messageCount + 1
    self.state.tokenCount = self.state.tokenCount + estimateMessageTokens(message)
end

-- 生成会话标题
function ContextManager:generateSessionTitle(messages)
    -- 遍历找第一条用户消息
    for _, msg in ipairs(messages) do
        if msg.role == "user" and msg.content then
            local content = msg.content
            
            -- 清理命令前缀
            content = content:gsub("^/[%w]+%s*", "")
            
            -- 提取关键词
            local keywords = {}
            
            -- 提取中文词
            for word in content:gmatch("[%z\194-\244][\128-\191]*") do
                if #word >= 2 and #word <= 10 then
                    table.insert(keywords, word)
                end
            end
            
            -- 提取英文词
            for word in content:gmatch("%w+") do
                if #word >= 3 then
                    table.insert(keywords, word)
                end
            end
            
            -- 取前3个关键词
            local title = ""
            for i = 1, math.min(3, #keywords) do
                title = title .. keywords[i] .. " "
            end
            
            if title ~= "" then
                return title:sub(1, 25):gsub("%s+$", "")
            end
            
            -- 回退：截取前20字符
            return content:sub(1, 20):gsub("\n", " ") .. (#content > 20 and "..." or "")
        end
    end
    
    return "新对话"
end

-- 重置状态
function ContextManager:reset()
    self.state = {
        tokenCount = 0,
        messageCount = 0,
        lastCompactMessage = 0,
        summary = nil,
        keyDecisions = {},
        completedTasks = {}
    }
end

return ContextManager
