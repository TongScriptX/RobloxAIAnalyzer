--[[
    Roblox AI Resource Analyzer
    Version: 1.0.0
    Author: AI Assistant
    
    主入口文件：整合所有模块，提供完整的AI资源分析功能
    
    使用方法：
    1. 在脚本执行器中运行此文件
    2. 在设置页面配置API Key
    3. 扫描游戏资源
    4. 在聊天界面与AI交互
]]

-- 主程序入口
local RobloxAIAnalyzer = {
    Version = "1.0.0",
    Initialized = false
}

-- 加载模块
local function loadModule(path)
    local success, module = pcall(function()
        return loadfile(path)()
    end)
    
    if success then
        return module
    else
        warn("Failed to load module: " .. path)
        return nil
    end
end

-- 模块引用
local Config = loadModule("config.lua")
local Http = loadModule("modules/http.lua")
local Scanner = loadModule("modules/scanner.lua")
local Reader = loadModule("modules/reader.lua")
local AIClient = loadModule("modules/ai_client.lua")
local Executor = loadModule("modules/executor.lua")
local UI = loadModule("modules/ui.lua")

-- 初始化函数
function RobloxAIAnalyzer:Init()
    if self.Initialized then
        return
    end
    
    print("[AI Analyzer] Initializing v" .. self.Version)
    
    -- 加载保存的配置
    if Config and Config.load then
        Config:load()
    end
    
    -- 创建UI
    self:createInterface()
    
    -- 绑定事件
    self:bindEvents()
    
    self.Initialized = true
    print("[AI Analyzer] Initialized successfully")
    
    -- 显示欢迎消息
    self:showWelcome()
end

-- 创建界面
function RobloxAIAnalyzer:createInterface()
    -- 创建主窗口
    UI:createMainWindow()
    
    -- 创建侧边栏按钮
    UI:createSidebarButton("AI 对话", "💬", function()
        UI:showView("chat")
    end)
    
    UI:createSidebarButton("资源浏览", "📁", function()
        UI:showView("resources")
    end)
    
    UI:createSidebarButton("设置", "⚙️", function()
        UI:showView("settings")
    end)
    
    -- 创建各个视图
    UI:createChatView()
    UI:createSettingsView()
    UI:createResourceView()
    
    -- 默认显示聊天视图
    UI:showView("chat")
    
    -- 更新状态
    self:updateConnectionStatus()
end

-- 绑定事件
function RobloxAIAnalyzer:bindEvents()
    -- 发送消息事件
    UI.sendBtn.MouseButton1Click:Connect(function()
        self:sendMessage()
    end)
    
    UI.inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            self:sendMessage()
        end
    end)
    
    -- 设置保存事件
    UI.saveSettingsBtn.MouseButton1Click:Connect(function()
        self:saveSettings()
    end)
    
    -- 测试连接事件
    UI.testConnectionBtn.MouseButton1Click:Connect(function()
        self:testConnection()
    end)
    
    -- Provider切换事件
    UI.providerButtons.deepseek.MouseButton1Click:Connect(function()
        self:switchProvider("DeepSeek")
    end)
    
    UI.providerButtons.openai.MouseButton1Click:Connect(function()
        self:switchProvider("OpenAI")
    end)
    
    -- 扫描按钮事件
    UI.scanBtn.MouseButton1Click:Connect(function()
        self:scanResources()
    end)
    
    -- 资源搜索事件
    UI.resourceSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self:searchResources(UI.resourceSearchBox.Text)
    end)
end

-- 显示欢迎消息
function RobloxAIAnalyzer:showWelcome()
    UI:clearMessages()
    
    UI:addMessage([[
🎮 Roblox AI Resource Analyzer v]] .. self.Version .. [[

欢迎使用！这是一个AI驱动的游戏资源分析工具。

功能介绍：
• 扫描游戏内所有资源（Remote、Script等）
• 使用AI分析脚本源码
• 根据需求生成代码
• 智能资源搜索和定位

使用步骤：
1. 点击"设置"配置API Key
2. 点击"资源浏览"扫描游戏
3. 在此界面与AI对话获取帮助

提示：输入"帮助"获取更多指令]], false)
end

-- 发送消息
function RobloxAIAnalyzer:sendMessage()
    local text = UI.inputBox.Text
    if text == "" or text:match("^%s*$") then
        return
    end
    
    -- 清空输入框
    UI.inputBox.Text = ""
    
    -- 显示用户消息
    UI:addMessage(text, true)
    
    -- 处理特殊命令
    if text:lower() == "帮助" or text:lower() == "help" then
        self:showHelp()
        return
    end
    
    if text:lower() == "扫描" or text:lower() == "scan" then
        self:scanResources()
        return
    end
    
    if text:lower() == "清除" or text:lower() == "clear" then
        UI:clearMessages()
        return
    end
    
    -- 发送到AI
    self:sendToAI(text)
end

-- 显示帮助
function RobloxAIAnalyzer:showHelp()
    UI:addMessage([[
📖 帮助信息

特殊命令：
• 帮助/help - 显示此帮助
• 扫描/scan - 扫描游戏资源
• 清除/clear - 清空聊天记录

AI使用技巧：
• "分析Remote：XXX" - 分析指定的Remote
• "找到所有GUI" - 搜索特定类型资源
• "生成自动点击代码" - 让AI生成代码
• "解释这个脚本：路径" - 分析脚本功能

资源浏览：
• 点击侧边栏"资源浏览"
• 使用搜索框筛选资源
• 点击资源项查看详情]], false)
end

-- 发送到AI处理
function RobloxAIAnalyzer:sendToAI(query)
    -- 检查API配置
    local provider = Config:getCurrentProvider()
    if not provider.apiKey or provider.apiKey == "" then
        UI:addMessage("⚠️ 请先在设置页面配置API Key", false)
        return
    end
    
    -- 获取资源上下文
    local context = Scanner:toAIContext(50)
    
    -- 显示加载提示
    UI:addMessage("⏳ 正在思考...", false)
    local loadingMsg = UI.messageArea:FindFirstChildWhichIsA("Frame", true)
    
    -- 调用AI
    spawn(function()
        local result, err = AIClient:analyzeResources(query, context)
        
        -- 移除加载提示
        if loadingMsg then
            loadingMsg:Destroy()
        end
        
        if result then
            UI:addMessage(result.content, false)
        else
            UI:addMessage("❌ 错误: " .. tostring(err), false)
        end
    end)
end

-- 扫描资源
function RobloxAIAnalyzer:scanResources()
    UI:addMessage("🔍 正在扫描游戏资源...", false)
    
    spawn(function()
        local results = Scanner:scan()
        local stats = Scanner:getStats()
        
        UI:clearResourceList()
        
        -- 添加Remote资源
        for _, remote in ipairs(results.remotes) do
            UI:addResourceItem(remote.name, remote.className, remote.path, function()
                self:analyzeResource(remote)
            end)
        end
        
        -- 添加Script资源
        for _, script in ipairs(results.scripts) do
            UI:addResourceItem(script.name, script.className, script.path, function()
                self:analyzeScript(script)
            end)
        end
        
        UI:addMessage(string.format(
            "✅ 扫描完成！\n• 总对象: %d\n• Remote: %d\n• Script: %d",
            stats.totalObjects, stats.remoteCount, stats.scriptCount
        ), false)
    end)
end

-- 搜索资源
function RobloxAIAnalyzer:searchResources(query)
    if query == "" then
        return
    end
    
    local results = Scanner:search(query)
    
    UI:clearResourceList()
    
    for _, obj in ipairs(results) do
        UI:addResourceItem(obj.name, obj.className, obj.path, function()
            self:analyzeResource(obj)
        end)
    end
end

-- 分析资源
function RobloxAIAnalyzer:analyzeResource(resource)
    UI:showView("chat")
    
    local prompt = string.format(
        "请分析这个游戏资源：\n名称: %s\n类型: %s\n路径: %s\n\n请解释它的用途和使用方法。",
        resource.name, resource.className, resource.path
    )
    
    UI.inputBox.Text = prompt
    self:sendMessage()
end

-- 分析脚本
function RobloxAIAnalyzer:analyzeScript(scriptInfo)
    UI:showView("chat")
    
    -- 尝试读取脚本源码
    local scripts = Reader:getAllScripts()
    local targetScript = nil
    
    for _, s in ipairs(scripts) do
        if s.Name == scriptInfo.name then
            targetScript = s
            break
        end
    end
    
    if targetScript and Reader:canDecompile() then
        local scriptData = Reader:readScript(targetScript)
        if scriptData then
            local prompt = string.format(
                "请分析这个脚本：\n名称: %s\n类型: %s\n路径: %s\n\n源码:\n%s",
                scriptData.name, scriptData.className, scriptData.path,
                scriptData.source:sub(1, 3000)
            )
            
            UI.inputBox.Text = prompt
            self:sendMessage()
            return
        end
    end
    
    -- 无法读取源码时的处理
    local prompt = string.format(
        "请分析这个脚本资源：\n名称: %s\n类型: %s\n路径: %s\n\n（无法读取源码）",
        scriptInfo.name, scriptInfo.className, scriptInfo.path
    )
    
    UI.inputBox.Text = prompt
    self:sendMessage()
end

-- 保存设置
function RobloxAIAnalyzer:saveSettings()
    local apiKey = UI.apiKeyInput.Text
    local currentProvider = Config.Settings.currentProvider
    
    if apiKey and apiKey ~= "" then
        Config:setApiKey(currentProvider, apiKey)
        Config:save()
        
        UI:addMessage("✅ 设置已保存", false)
        self:updateConnectionStatus()
    else
        UI:addMessage("⚠️ 请输入有效的API Key", false)
    end
end

-- 测试连接
function RobloxAIAnalyzer:testConnection()
    UI:addMessage("🔍 正在测试API连接...", false)
    
    spawn(function()
        local success, message = AIClient:testConnection()
        
        if success then
            UI:addMessage("✅ " .. message, false)
            UI:updateStatus("已连接", UI.Theme.success)
        else
            UI:addMessage("❌ " .. message, false)
            UI:updateStatus("连接失败", UI.Theme.error)
        end
    end)
end

-- 切换提供商
function RobloxAIAnalyzer:switchProvider(providerName)
    Config:switchProvider(providerName)
    
    -- 更新按钮样式
    for name, btn in pairs(UI.providerButtons) do
        if name:lower() == providerName:lower() then
            btn.BackgroundColor3 = UI.Theme.accent
            btn.TextColor3 = Color3.new(1, 1, 1)
        else
            btn.BackgroundColor3 = UI.Theme.backgroundSecondary
            btn.TextColor3 = UI.Theme.text
        end
    end
    
    -- 更新API Key输入框
    local provider = Config:getCurrentProvider()
    UI.apiKeyInput.Text = provider.apiKey or ""
    
    self:updateConnectionStatus()
end

-- 更新连接状态
function RobloxAIAnalyzer:updateConnectionStatus()
    local provider = Config:getCurrentProvider()
    
    if provider.apiKey and provider.apiKey ~= "" then
        UI:updateStatus(provider.name, UI.Theme.accent)
    else
        UI:updateStatus("未配置", UI.Theme.warning)
    end
end

-- 执行代码（用于AI生成的代码）
function RobloxAIAnalyzer:executeCode(code)
    if not Executor:canExecute() then
        UI:addMessage("❌ 当前环境不支持代码执行", false)
        return
    end
    
    -- 验证代码
    local warnings = Executor:validateCode(code)
    if #warnings > 0 then
        UI:addMessage("⚠️ 代码安全警告:", false)
        for _, warning in ipairs(warnings) do
            UI:addMessage("  • [" .. warning.level .. "] " .. warning.message, false)
        end
    end
    
    -- 执行代码
    local success, result = Executor:safeExecute(code)
    
    if success then
        UI:addMessage("✅ 代码执行成功", false)
        if result then
            UI:addMessage("返回值: " .. tostring(result), false)
        end
    else
        UI:addMessage("❌ 执行失败: " .. tostring(result), false)
    end
end

-- 环境检测
function RobloxAIAnalyzer:detectEnvironment()
    local envInfo = {
        executor = Http:getExecutorInfo(),
        reader = Reader:getEnvInfo(),
        executorModule = Executor:getInfo()
    }
    
    return envInfo
end

-- 启动程序
RobloxAIAnalyzer:Init()

-- 返回模块引用
return RobloxAIAnalyzer
