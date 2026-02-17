--[[
    Roblox AI Resource Analyzer
    Version: 1.0.0
    
    使用方法：
    1. 在脚本执行器中运行此文件
    2. 在设置页面配置API Key
    3. 扫描游戏资源
    4. 在聊天界面与AI交互
]]

local BASE_URL = "https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main"

-- 主程序
local RobloxAIAnalyzer = {
    Version = "1.0.0",
    Initialized = false
}

-- 检测并获取HTTP请求函数
local function getHttpFunc()
    if game:FindService("HttpService") then
        -- 检查各种执行器的HTTP函数
        if syn and syn.request then
            return function(url)
                local resp = syn.request({Url = url, Method = "GET"})
                return resp.Body, resp.StatusCode
            end
        elseif request then
            return function(url)
                local resp = request({Url = url, Method = "GET"})
                return resp.Body or resp.body, resp.StatusCode or resp.statusCode
            end
        elseif http and http.request then
            return function(url)
                local resp = http.request({Url = url, Method = "GET"})
                return resp.Body or resp.body, resp.StatusCode or resp.statusCode
            end
        elseif http_request then
            return function(url)
                local resp = http_request({Url = url, Method = "GET"})
                return resp.Body or resp.body, resp.StatusCode or resp.statusCode
            end
        elseif fluxus and fluxus.request then
            return function(url)
                local resp = fluxus.request({Url = url, Method = "GET"})
                return resp.Body or resp.body, resp.StatusCode or resp.statusCode
            end
        end
    end
    return nil
end

local httpGet = getHttpFunc()

-- 从GitHub加载模块
local function loadFromGitHub(path)
    if not httpGet then
        warn("[AI Analyzer] HTTP请求不可用")
        return nil
    end
    
    local url = BASE_URL .. "/" .. path
    local success, result = pcall(httpGet, url)
    
    if success and result then
        local compileSuccess, compiled = pcall(loadstring, result)
        if compileSuccess and compiled then
            return compiled()
        else
            warn("[AI Analyzer] 模块编译失败: " .. path)
        end
    else
        warn("[AI Analyzer] 模块加载失败: " .. path)
    end
    
    return nil
end

print("[AI Analyzer] 正在加载模块...")

-- 加载所有模块
local Config = loadFromGitHub("config.lua")
local Http = loadFromGitHub("modules/http.lua")
local Scanner = loadFromGitHub("modules/scanner.lua")
local Reader = loadFromGitHub("modules/reader.lua")
local AIClient = loadFromGitHub("modules/ai_client.lua")
local Executor = loadFromGitHub("modules/executor.lua")
local UI = loadFromGitHub("modules/ui.lua")

-- 检查模块加载状态
local modulesLoaded = Config and Http and Scanner and Reader and AIClient and Executor and UI

if not modulesLoaded then
    warn("[AI Analyzer] 部分模块加载失败，使用内置备用模块...")
    -- 这里可以添加备用逻辑
end

-- 初始化函数
function RobloxAIAnalyzer:Init()
    if self.Initialized then
        return
    end
    
    print("[AI Analyzer] Initializing v" .. self.Version)
    
    if not UI then
        warn("[AI Analyzer] UI模块未加载，无法启动")
        return
    end
    
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
    UI:createMainWindow()
    
    UI:createSidebarButton("AI 对话", "💬", function()
        UI:showView("chat")
    end)
    
    UI:createSidebarButton("资源浏览", "📁", function()
        UI:showView("resources")
    end)
    
    UI:createSidebarButton("设置", "⚙️", function()
        UI:showView("settings")
    end)
    
    UI:createChatView()
    UI:createSettingsView()
    UI:createResourceView()
    
    UI:showView("chat")
    self:updateConnectionStatus()
end

-- 绑定事件
function RobloxAIAnalyzer:bindEvents()
    UI.sendBtn.MouseButton1Click:Connect(function()
        self:sendMessage()
    end)
    
    UI.inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            self:sendMessage()
        end
    end)
    
    UI.saveSettingsBtn.MouseButton1Click:Connect(function()
        self:saveSettings()
    end)
    
    UI.testConnectionBtn.MouseButton1Click:Connect(function()
        self:testConnection()
    end)
    
    UI.providerButtons.deepseek.MouseButton1Click:Connect(function()
        self:switchProvider("DeepSeek")
    end)
    
    UI.providerButtons.openai.MouseButton1Click:Connect(function()
        self:switchProvider("OpenAI")
    end)
    
    UI.scanBtn.MouseButton1Click:Connect(function()
        self:scanResources()
    end)
    
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
    
    UI.inputBox.Text = ""
    UI:addMessage(text, true)
    
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
• "解释这个脚本：路径" - 分析脚本功能]], false)
end

-- 发送到AI处理
function RobloxAIAnalyzer:sendToAI(query)
    if not Config or not AIClient then
        UI:addMessage("❌ 模块未正确加载", false)
        return
    end
    
    local provider = Config:getCurrentProvider()
    if not provider.apiKey or provider.apiKey == "" then
        UI:addMessage("⚠️ 请先在设置页面配置API Key", false)
        return
    end
    
    local context = Scanner and Scanner:toAIContext(50) or {}
    
    UI:addMessage("⏳ 正在思考...", false)
    local loadingMsg = UI.messageArea:FindFirstChildWhichIsA("Frame", true)
    
    spawn(function()
        local result, err = AIClient:analyzeResources(query, context)
        
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
    if not Scanner then
        UI:addMessage("❌ Scanner模块未加载", false)
        return
    end
    
    UI:addMessage("🔍 正在扫描游戏资源...", false)
    
    spawn(function()
        local results = Scanner:scan()
        local stats = Scanner:getStats()
        
        UI:clearResourceList()
        
        for _, remote in ipairs(results.remotes) do
            UI:addResourceItem(remote.name, remote.className, remote.path, function()
                self:analyzeResource(remote)
            end)
        end
        
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
    if query == "" or not Scanner then return end
    
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
    
    local scripts = Reader and Reader:getAllScripts() or {}
    local targetScript = nil
    
    for _, s in ipairs(scripts) do
        if s.Name == scriptInfo.name then
            targetScript = s
            break
        end
    end
    
    if targetScript and Reader and Reader:canDecompile() then
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
    
    local prompt = string.format(
        "请分析这个脚本资源：\n名称: %s\n类型: %s\n路径: %s\n\n（无法读取源码）",
        scriptInfo.name, scriptInfo.className, scriptInfo.path
    )
    
    UI.inputBox.Text = prompt
    self:sendMessage()
end

-- 保存设置
function RobloxAIAnalyzer:saveSettings()
    if not Config then
        UI:addMessage("❌ Config模块未加载", false)
        return
    end
    
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
    if not AIClient then
        UI:addMessage("❌ AIClient模块未加载", false)
        return
    end
    
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
    if not Config then return end
    
    Config:switchProvider(providerName)
    
    for name, btn in pairs(UI.providerButtons) do
        if name:lower() == providerName:lower() then
            btn.BackgroundColor3 = UI.Theme.accent
            btn.TextColor3 = Color3.new(1, 1, 1)
        else
            btn.BackgroundColor3 = UI.Theme.backgroundSecondary
            btn.TextColor3 = UI.Theme.text
        end
    end
    
    local provider = Config:getCurrentProvider()
    UI.apiKeyInput.Text = provider.apiKey or ""
    
    self:updateConnectionStatus()
end

-- 更新连接状态
function RobloxAIAnalyzer:updateConnectionStatus()
    if not Config then return end
    
    local provider = Config:getCurrentProvider()
    
    if provider.apiKey and provider.apiKey ~= "" then
        UI:updateStatus(provider.name, UI.Theme.accent)
    else
        UI:updateStatus("未配置", UI.Theme.warning)
    end
end

-- 启动程序
RobloxAIAnalyzer:Init()

return RobloxAIAnalyzer