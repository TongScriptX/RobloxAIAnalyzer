--[[
    Roblox AI Resource Analyzer
    Version: 1.0.0
    
    使用方法：
    loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main/main.lua"))()
]]

local BASE_URL = "https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main"

-- 主程序
local RobloxAIAnalyzer = {
    Version = "1.0.0",
    Initialized = false
}

-- 检测并获取HTTP请求函数
local function getHttpFunc()
    -- Synapse X
    if syn and syn.request then
        return function(url)
            local resp = syn.request({Url = url, Method = "GET"})
            return resp.Body, resp.StatusCode
        end
    end
    -- Script-Ware / 通用
    if request then
        return function(url)
            local resp = request({Url = url, Method = "GET"})
            return resp.Body or resp.body, resp.StatusCode or resp.statusCode
        end
    end
    -- Electron
    if http and http.request then
        return function(url)
            local resp = http.request({Url = url, Method = "GET"})
            return resp.Body or resp.body, resp.StatusCode or resp.statusCode
        end
    end
    -- http_request 全局
    if http_request then
        return function(url)
            local resp = http_request({Url = url, Method = "GET"})
            return resp.Body or resp.body, resp.StatusCode or resp.statusCode
        end
    end
    -- Fluxus
    if fluxus and fluxus.request then
        return function(url)
            local resp = fluxus.request({Url = url, Method = "GET"})
            return resp.Body or resp.body, resp.StatusCode or resp.statusCode
        end
    end
    -- KRNL
    if krnl and krnl.request then
        return function(url)
            local resp = krnl.request({Url = url, Method = "GET"})
            return resp.Body or resp.body, resp.StatusCode or resp.statusCode
        end
    end
    -- game:HttpGet (部分执行器支持)
    if game.HttpGet then
        return function(url)
            return game:HttpGet(url)
        end
    end
    
    return nil
end

local httpGet = getHttpFunc()

if not httpGet then
    warn("[AI Analyzer] 错误：无法检测到HTTP请求函数")
    return
end

print("[AI Analyzer] HTTP函数已就绪")

-- 从GitHub加载模块
local function loadFromGitHub(path)
    local url = BASE_URL .. "/" .. path
    local success, result = pcall(httpGet, url)
    
    if success and result and result ~= "" then
        local compileSuccess, compiled = pcall(loadstring, result)
        if compileSuccess and compiled then
            local runSuccess, module = pcall(compiled)
            if runSuccess then
                return module
            else
                warn("[AI Analyzer] 模块运行失败: " .. path .. " - " .. tostring(module))
            end
        else
            warn("[AI Analyzer] 模块编译失败: " .. path)
        end
    else
        warn("[AI Analyzer] 模块下载失败: " .. path .. " - " .. tostring(result))
    end
    
    return nil
end

print("[AI Analyzer] 正在加载模块...")

-- 初始化全局依赖表
_G.AIAnalyzer = {}

-- 1. 先加载Config
local Config = loadFromGitHub("config.lua")
if Config then
    _G.AIAnalyzer.Config = Config
    print("[AI Analyzer] Config 加载成功")
else
    warn("[AI Analyzer] Config 加载失败")
end

-- 2. 加载Http模块
local Http = loadFromGitHub("modules/http.lua")
if Http then
    _G.AIAnalyzer.Http = Http
    print("[AI Analyzer] Http 加载成功")
else
    warn("[AI Analyzer] Http 加载失败")
end

-- 3. 加载其他独立模块
local Scanner = loadFromGitHub("modules/scanner.lua")
local Reader = loadFromGitHub("modules/reader.lua")
local Executor = loadFromGitHub("modules/executor.lua")
local UI = loadFromGitHub("modules/ui.lua")

if Scanner then _G.AIAnalyzer.Scanner = Scanner; print("[AI Analyzer] Scanner 加载成功") end
if Reader then _G.AIAnalyzer.Reader = Reader; print("[AI Analyzer] Reader 加载成功") end
if Executor then _G.AIAnalyzer.Executor = Executor; print("[AI Analyzer] Executor 加载成功") end
if UI then _G.AIAnalyzer.UI = UI; print("[AI Analyzer] UI 加载成功") end

-- 4. 最后加载AIClient（依赖Config和Http）
local AIClient = loadFromGitHub("modules/ai_client.lua")
if AIClient then
    _G.AIAnalyzer.AIClient = AIClient
    print("[AI Analyzer] AIClient 加载成功")
end

-- 检查核心模块
if not UI then
    warn("[AI Analyzer] UI模块未加载，无法启动界面")
    return
end

-- 初始化函数
function RobloxAIAnalyzer:Init()
    if self.Initialized then return end
    
    print("[AI Analyzer] Initializing v" .. self.Version)
    
    -- 加载保存的配置
    if Config and Config.load then
        Config:load()
    end
    
    self:createInterface()
    self:bindEvents()
    
    self.Initialized = true
    print("[AI Analyzer] 初始化完成")
    
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
    if text == "" or text:match("^%s*$") then return end
    
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
• "生成自动点击代码" - 让AI生成代码]], false)
end

-- 发送到AI处理
function RobloxAIAnalyzer:sendToAI(query)
    if not AIClient then
        UI:addMessage("❌ AIClient模块未加载", false)
        return
    end
    
    if not Config then
        UI:addMessage("❌ Config模块未加载", false)
        return
    end
    
    local provider = Config:getCurrentProvider()
    if not provider.apiKey or provider.apiKey == "" then
        UI:addMessage("⚠️ 请先在设置页面配置API Key", false)
        return
    end
    
    local context = Scanner and Scanner:toAIContext(50) or {}
    
    UI:addMessage("⏳ 正在思考...", false)
    
    spawn(function()
        local result, err = AIClient:analyzeResources(query, context)
        
        -- 移除最后一条消息（加载提示）
        local children = UI.messageArea:GetChildren()
        for i = #children, 1, -1 do
            if children[i]:IsA("Frame") then
                local label = children[i]:FindFirstChildWhichIsA("TextLabel")
                if label and label.Text:find("正在思考") then
                    children[i]:Destroy()
                    break
                end
            end
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
    
    if Reader and Reader:canDecompile() then
        local scripts = Reader:getAllScripts()
        for _, s in ipairs(scripts) do
            if s.Name == scriptInfo.name then
                local scriptData = Reader:readScript(s)
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
    if provider and provider.apiKey and provider.apiKey ~= "" then
        UI:updateStatus(provider.name, UI.Theme.accent)
    else
        UI:updateStatus("未配置", UI.Theme.warning)
    end
end

-- 启动
RobloxAIAnalyzer:Init()

return RobloxAIAnalyzer
