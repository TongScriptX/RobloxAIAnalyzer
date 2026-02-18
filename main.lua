-- Roblox AI CLI v2.0.0
-- 用法: loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main/main.lua"))()

local App = {
    ver = "2.0.0",
    ready = false,
    exec = {}
}

-- 执行器检测
local function detectExecutor()
    local info = {
        name = "Unknown",
        canRequest = false,
        canExecute = false,
        canWrite = false,
        canDecompile = false,
        writefile = nil,
        readfile = nil,
        request = nil
    }
    
    -- 检查 identifyexecutor() 获取准确名称
    local executorName = nil
    if identifyexecutor then
        local ok, name = pcall(identifyexecutor)
        if ok and name then
            executorName = tostring(name):lower()
        end
    end
    
    -- 根据标识判断
    if executorName then
        if executorName:find("synapse") then
            info.name = "Synapse X"
            info.canDecompile = true
        elseif executorName:find("script%-ware") or executorName:find("scriptware") then
            info.name = "Script-Ware"
            info.canDecompile = true
        elseif executorName:find("delta") then
            info.name = "Delta"
        elseif executorName:find("krnl") then
            info.name = "KRNL"
        elseif executorName:find("fluxus") then
            info.name = "Fluxus"
        elseif executorName:find("electron") then
            info.name = "Electron"
        else
            info.name = executorName:gsub("^%l", string.upper)
        end
    end
    
    -- 设置函数
    if syn and syn.request then
        info.request = syn.request
        info.canRequest = true
        if syn.writefile then info.writefile = syn.writefile; info.canWrite = true end
        if syn.readfile then info.readfile = syn.readfile end
    elseif http_request then
        info.request = http_request
        info.canRequest = true
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
    elseif request and type(request) == "function" then
        info.request = request
        info.canRequest = true
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
    elseif krnl and krnl.request then
        info.request = krnl.request
        info.canRequest = true
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
    elseif fluxus and fluxus.request then
        info.request = fluxus.request
        info.canRequest = true
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
    elseif http and http.request then
        info.request = http.request
        info.canRequest = true
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
    end
    
    -- 检查通用函数
    if not info.canRequest and game.HttpGet then
        info.name = info.name .. " (HttpGet)"
        info.canRequest = true
    end
    
    if not info.writefile and writefile then
        info.writefile = writefile
        info.canWrite = true
    end
    
    if not info.readfile and readfile then
        info.readfile = readfile
    end
    
    -- 检查执行和反编译能力
    if loadstring and getgenv then
        info.canExecute = true
    end
    
    if decompile or (syn and syn.decompile) then
        info.canDecompile = true
    end
    
    return info
end

-- HTTP获取
local httpGet

local function getHttpFunc(exec)
    -- 优先使用 game:HttpGet，更可靠
    if game.HttpGet then
        return function(url) return game:HttpGet(url) end
    elseif exec.request then
        return function(url)
            local r = exec.request({Url = url, Method = "GET"})
            return r.Body or r.body, r.StatusCode or r.statusCode
        end
    end
    return nil
end

-- 模块加载 - 只用 GitHub raw，最可靠
local BASE_URL = "https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main"

local function loadModule(path)
    local url = BASE_URL .. "/" .. path
    
    -- 直接用 game:HttpGet，失败返回 nil
    local ok, res = pcall(httpGet, url)
    if ok and res and #res > 10 then
        local ok2, fn = pcall(loadstring, res)
        if ok2 and fn then
            local ok3, mod = pcall(fn)
            if ok3 then return mod end
        end
    end
    
    return nil
end

-- 脚本操作
local function saveScript(name, content)
    local cfg = _G.AIAnalyzer and _G.AIAnalyzer.Config
    local exec = App.exec
    
    if not exec.canWrite or not exec.writefile then
        return false, "不支持写入文件"
    end
    
    local dir = cfg and cfg.Settings.scriptDir or "workspace"
    local filename
    
    if dir == "workspace" or dir == "" then
        filename = name:gsub("[^%w_%.%-]", "_") .. ".lua"
    else
        filename = dir .. "/" .. name:gsub("[^%w_%.%-]", "_") .. ".lua"
    end
    
    if not filename:match("%.lua$") then
        filename = filename .. ".lua"
    end
    
    local ok, err = pcall(exec.writefile, filename, content)
    
    if ok then
        return true, filename
    else
        return false, tostring(err)
    end
end

local function execScript(code)
    local exec = App.exec
    
    if not exec.canExecute then
        return false, "不支持执行脚本"
    end
    
    local fn, err = loadstring(code)
    if not fn then
        return false, "编译失败: " .. tostring(err)
    end
    
    local ok, res = pcall(fn)
    if ok then
        return true, res
    else
        return false, "执行错误: " .. tostring(res)
    end
end

function App:init()
    if self.ready then return end
    
    print("[AI CLI] v" .. self.ver .. " 启动中...")
    
    self.exec = detectExecutor()
    print("[AI CLI] 执行器: " .. self.exec.name)
    
    httpGet = getHttpFunc(self.exec)
    if not httpGet then
        warn("[AI CLI] 错误：无法获取HTTP函数")
        return
    end
    
    _G.AIAnalyzer = {Executor = self.exec}
    
    -- 显示加载中UI
    self:showLoadingUI()
    
    -- 所有模块列表
    local modules = {
        {name = "Config", path = "config.lua", key = "Config", required = true},
        {name = "Http", path = "modules/http.lua", key = "Http", required = true},
        {name = "Scanner", path = "modules/scanner.lua", key = "Scanner", required = true},
        {name = "Reader", path = "modules/reader.lua", key = "Reader", required = true},
        {name = "Executor", path = "modules/executor.lua", key = "Executor", required = false},
        {name = "UI", path = "modules/ui.lua", key = "UI", required = true},
        {name = "Tools", path = "modules/tools.lua", key = "Tools", required = false},
        {name = "ContextManager", path = "modules/context_manager.lua", key = "ContextManager", required = false},
        {name = "AIClient", path = "modules/ai_client.lua", key = "AIClient", required = false},
    }
    
    -- 同步加载所有模块
    for i, mod in ipairs(modules) do
        self:updateLoadingProgress(i, #modules, mod.name)
        local m = loadModule(mod.path)
        if m then
            _G.AIAnalyzer[mod.key] = m
        elseif mod.required then
            self:hideLoadingUI()
            warn("[AI CLI] " .. mod.name .. " 加载失败（必需模块）")
            return
        end
    end
    
    -- 加载配置和session
    local cfg = _G.AIAnalyzer.Config
    if cfg then
        if cfg.load then cfg:load() end
        if cfg.loadSessions then cfg:loadSessions() end
        if not cfg.CurrentSession then
            cfg:createSession()
        end
    end
    
    -- 隐藏加载UI
    self:hideLoadingUI()
    
    -- 创建主UI
    local ok, err = pcall(function()
        self:setupUI()
    end)
    if not ok then
        warn("[AI CLI] UI创建失败: " .. tostring(err))
        return
    end
    
    self:bindEvents()
    self:setupCallbacks()
    
    self.ready = true
    print("[AI CLI] 初始化完成")
    
    self:showWelcome()
end

-- 加载中UI
function App:showLoadingUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AILoadingUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(0, 280, 0, 100)
    frame.Position = UDim2.new(0.5, -140, 0.5, -50)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 12)
    
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "AI CLI 加载中..."
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    
    local progress = Instance.new("TextLabel", frame)
    progress.Name = "ProgressLabel"
    progress.Size = UDim2.new(1, 0, 0, 24)
    progress.Position = UDim2.new(0, 0, 0, 45)
    progress.BackgroundTransparency = 1
    progress.Text = "正在初始化..."
    progress.TextColor3 = Color3.fromRGB(180, 180, 180)
    progress.TextSize = 13
    progress.Font = Enum.Font.Gotham
    
    local barBg = Instance.new("Frame", frame)
    barBg.Size = UDim2.new(1, -40, 0, 6)
    barBg.Position = UDim2.new(0, 20, 1, -25)
    barBg.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    barBg.BorderSizePixel = 0
    
    local barCorner = Instance.new("UICorner", barBg)
    barCorner.CornerRadius = UDim.new(0, 3)
    
    local bar = Instance.new("Frame", barBg)
    bar.Name = "ProgressBar"
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(88, 166, 255)
    bar.BorderSizePixel = 0
    
    local barInnerCorner = Instance.new("UICorner", bar)
    barInnerCorner.CornerRadius = UDim.new(0, 3)
    
    self.loadingUI = screenGui
end

function App:updateLoadingProgress(current, total, moduleName)
    if not self.loadingUI then return end
    
    local progress = self.loadingUI:FindFirstChild("ProgressLabel", true)
    local bar = self.loadingUI:FindFirstChild("ProgressBar", true)
    
    if progress then
        progress.Text = string.format("加载 %s (%d/%d)", moduleName, current, total)
    end
    
    if bar then
        bar.Size = UDim2.new(current / total, 0, 1, 0)
    end
end

function App:hideLoadingUI()
    if self.loadingUI then
        self.loadingUI:Destroy()
        self.loadingUI = nil
    end
end

function App:setupUI()
    local ui = _G.AIAnalyzer.UI
    
    ui:createMainWindow()
    
    ui:createSidebarButton("AI 对话", "💬", function()
        ui:showView("chat")
    end)
    
    ui:createSidebarButton("资源", "📁", function()
        ui:showView("resources")
    end)
    
    ui:createSidebarButton("设置", "⚙️", function()
        ui:showView("settings")
        self:loadSettings()
    end)
    
    -- 创建session列表
    ui:createSessionList()
    
    ui:createChatView()
    ui:createSettingsView()
    ui:createResourceView()
    
    -- 加载session列表
    self:refreshSessionList()
    
    ui:showView("chat")
    self:updateConnectionStatus()
end

function App:loadSettings()
    local ui = _G.AIAnalyzer.UI
    local cfg = _G.AIAnalyzer.Config
    
    ui:updateExecutorInfo({
        name = self.exec.name,
        canWrite = self.exec.canWrite,
        canExecute = self.exec.canExecute
    })
    
    if cfg then
        local p = cfg:getCurrentProvider()
        if p then
            ui.apiKeyInput.Text = p.apiKey or ""
        end
        ui.scriptDirInput.Text = cfg.Settings.scriptDir or ""
        ui:updateConfirmToggle(cfg.Settings.confirmBeforeExecute)
    end
end

function App:bindEvents()
    local ui = _G.AIAnalyzer.UI
    local cfg = _G.AIAnalyzer.Config
    
    ui.sendBtn.MouseButton1Click:Connect(function()
        self:sendMessage()
    end)
    
    ui.inputBox.FocusLost:Connect(function(enter)
        if enter then self:sendMessage() end
    end)
    
    ui.saveSettingsBtn.MouseButton1Click:Connect(function()
        self:saveSettings()
    end)
    
    ui.testConnectionBtn.MouseButton1Click:Connect(function()
        self:testConnection()
    end)
    
    ui.providerButtons.deepseek.MouseButton1Click:Connect(function()
        self:switchProvider("DeepSeek")
    end)
    
    ui.providerButtons.openai.MouseButton1Click:Connect(function()
        self:switchProvider("OpenAI")
    end)
    
    ui.confirmToggle.MouseButton1Click:Connect(function()
        if cfg then
            cfg.Settings.confirmBeforeExecute = not cfg.Settings.confirmBeforeExecute
            ui:updateConfirmToggle(cfg.Settings.confirmBeforeExecute)
        end
    end)
    
    ui.clearHistoryBtn.MouseButton1Click:Connect(function()
        self:clearCurrentSession()
    end)
    
    ui.exportHistoryBtn.MouseButton1Click:Connect(function()
        self:exportHistory()
    end)
    
    ui.resetTokenBtn.MouseButton1Click:Connect(function()
        ui:resetTokenStats()
        ui:addSystemMessage("✅ Token统计已重置")
    end)
    
    ui.scanBtn.MouseButton1Click:Connect(function()
        self:scanResources()
    end)
    
    ui.resourceSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self:searchResources(ui.resourceSearchBox.Text)
    end)
    
    -- Session相关事件
    ui.newSessionBtn.MouseButton1Click:Connect(function()
        self:newSession()
    end)
end

function App:setupCallbacks()
    local ui = _G.AIAnalyzer.UI
    
    ui:onExecute(function(code, frame)
        local Config = _G.AIAnalyzer.Config
        local confirmBeforeExecute = Config and Config.Settings.confirmBeforeExecute
        
        if confirmBeforeExecute then
            local success, err = execScript(code)
            if success then
                self:addSystemMessage("✅ 脚本执行成功")
            else
                self:addSystemMessage("❌ 执行失败: " .. tostring(err))
            end
        else
            local success, err = execScript(code)
            if success then
                self:addSystemMessage("✅ 脚本执行成功")
            else
                self:addSystemMessage("❌ 执行失败: " .. tostring(err))
            end
        end
    end)
    
    ui:onSave(function(code, frame)
        local Config = _G.AIAnalyzer.Config
        local timestamp = os.date("%Y%m%d_%H%M%S")
        local name = "ai_script_" .. timestamp
        
        local success, result = saveScript(name, code)
        if success then
            self:addSystemMessage("✅ 脚本已保存: " .. result)
        else
            self:addSystemMessage("❌ 保存失败: " .. tostring(result))
        end
    end)
end

function App:addSystemMessage(text)
    local ui = _G.AIAnalyzer.UI
    ui:addMessage("ℹ️ " .. text, false)
end

function App:showWelcome()
    local ui = _G.AIAnalyzer.UI
    ui:clearMessages()
    
    ui:addMessage(string.format([[
🤖 Roblox AI CLI v%s

欢迎使用！这是一个AI驱动的Roblox游戏分析工具。

⚡ 快速开始:
• 配置API Key后即可与AI对话
• AI生成的代码可直接执行或保存
• 支持分析游戏资源和脚本源码

📌 命令:
• 帮助 - 显示帮助信息
• 扫描 - 扫描游戏资源
• 历史 - 查看对话历史
• 清除 - 清空对话

🔧 执行器: %s
📁 支持写入: %s]], 
        self.ver,
        self.exec.name,
        self.exec.canWrite and "是" or "否"
    ), false)
end

function App:sendMessage()
    local ui = _G.AIAnalyzer.UI
    local text = ui.inputBox.Text
    
    if text == "" or text:match("^%s*$") then return end
    
    ui.inputBox.Text = ""
    ui:addMessage(text, true)
    
    -- 处理特殊命令
    local cmd = text:lower():match("^%s*(.-)%s*$")
    
    if cmd == "帮助" or cmd == "help" then
        self:showHelp()
        return
    end
    
    if cmd == "扫描" or cmd == "scan" then
        self:scanResources()
        return
    end
    
    if cmd == "清除" or cmd == "clear" then
        ui:clearMessages()
        return
    end
    
    if cmd == "历史" or cmd == "history" then
        self:showHistory()
        return
    end
    
    if cmd == "/compress" or cmd == "压缩" then
        self:compressContext()
        return
    end
    
    self:sendToAI(text)
end

-- 手动压缩上下文
function App:compressContext()
    local ui = _G.AIAnalyzer.UI
    local ai = _G.AIAnalyzer.AIClient
    local ctxMgr = _G.AIAnalyzer.ContextManager
    local cfg = _G.AIAnalyzer.Config
    
    if not ai or not ai.conversationHistory or #ai.conversationHistory == 0 then
        ui:addMessage("⚠️ 对话历史为空", false)
        return
    end
    
    local before = #ai.conversationHistory
    
    if ctxMgr then
        local ctxConfig = cfg and cfg.ContextConfig or {}
        ai.conversationHistory = ctxMgr:compact(ai.conversationHistory, ctxConfig, {force = true})
    else
        -- 简单压缩：保留最近4条
        while #ai.conversationHistory > 8 do
            table.remove(ai.conversationHistory, 1)
        end
    end
    
    local after = #ai.conversationHistory
    ui:addMessage(string.format("✅ 上下文已压缩: %d → %d 条消息", before, after), false)
end

function App:showHelp()
    local ui = _G.AIAnalyzer.UI
    ui:addMessage([[
📖 帮助信息

📌 基础命令:
• 帮助/help - 显示此帮助
• 扫描/scan - 扫描游戏资源
• 历史/history - 查看对话历史
• 清除/clear - 清空对话
• /compress 或 压缩 - 手动压缩上下文

💡 AI使用示例:
• "分析 game.Players 的结构"
• "找到所有 RemoteEvent"
• "生成一个自动拾取金币的脚本"
• "解释这个脚本的作用: [粘贴代码]"

🔧 代码块操作:
• 复制 - 复制代码到剪贴板
• 执行 - 直接运行代码
• 保存 - 保存到执行器目录]], false)
end

-- Session管理
function App:newSession()
    local ui = _G.AIAnalyzer.UI
    local cfg = _G.AIAnalyzer.Config
    
    if cfg then
        cfg:createSession()
        ui:clearMessages()
        self:refreshSessionList()
        ui:addMessage("🆕 新对话已创建", false)
    end
end

function App:switchSession(session)
    local ui = _G.AIAnalyzer.UI
    local cfg = _G.AIAnalyzer.Config
    
    if cfg then
        cfg:switchSession(session.id)
        self:refreshSessionList()
        
        -- 显示当前session的消息
        ui:clearMessages()
        local messages = cfg:getMessages()
        for _, msg in ipairs(messages) do
            ui:addMessage(msg.content, msg.role == "user")
        end
    end
end

function App:deleteSession(session)
    local ui = _G.AIAnalyzer.UI
    local cfg = _G.AIAnalyzer.Config
    
    if cfg then
        cfg:deleteSession(session.id)
        self:refreshSessionList()
        
        -- 如果删除的是当前session，显示新的空session
        if not cfg.CurrentSession then
            cfg:createSession()
            ui:clearMessages()
            self:refreshSessionList()
        end
    end
end

function App:refreshSessionList()
    local ui = _G.AIAnalyzer.UI
    local cfg = _G.AIAnalyzer.Config
    
    if cfg then
        local sessions = cfg:getSessionList()
        local currentId = cfg.CurrentSession and cfg.CurrentSession.id
        
        ui:refreshSessionList(
            sessions,
            function(s) self:switchSession(s) end,
            function(s) self:deleteSession(s) end,
            currentId
        )
    end
end

-- 清空当前session
function App:clearCurrentSession()
    local ui = _G.AIAnalyzer.UI
    local cfg = _G.AIAnalyzer.Config
    
    if cfg then
        cfg:clearCurrentSession()
        ui:clearMessages()
        ui:addMessage("✅ 当前对话已清空", false)
    end
end

-- 导出历史
function App:exportHistory()
    local ui = _G.AIAnalyzer.UI
    local cfg = _G.AIAnalyzer.Config
    local HttpService = game:GetService("HttpService")
    
    if not cfg or not cfg.CurrentSession then
        ui:addMessage("⚠️ 暂无对话可导出", false)
        return
    end
    
    local messages = cfg:getMessages()
    if #messages == 0 then
        ui:addMessage("⚠️ 当前对话为空", false)
        return
    end
    
    local json = HttpService:JSONEncode({
        title = cfg.CurrentSession.title,
        messages = messages
    })
    
    local success, result = saveScript("session_export", json)
    
    if success then
        ui:addMessage("✅ 对话已导出: " .. result, false)
    else
        if setclipboard then
            setclipboard(json)
            ui:addMessage("✅ 对话已复制到剪贴板", false)
        else
            ui:addMessage("❌ 导出失败: " .. tostring(result), false)
        end
    end
end

-- AI交互
function App:sendToAI(query)
    local ui = _G.AIAnalyzer.UI
    local AIClient = _G.AIAnalyzer.AIClient
    local Config = _G.AIAnalyzer.Config
    
    if not AIClient then
        ui:addMessage("❌ AIClient模块未加载", false)
        return
    end
    
    if not Config then
        ui:addMessage("❌ Config模块未加载", false)
        return
    end
    
    local provider = Config:getCurrentProvider()
    if not provider.apiKey or provider.apiKey == "" then
        ui:addMessage("⚠️ 请先在设置页面配置API Key", false)
        ui:showView("settings")
        return
    end
    
    -- 保存用户消息
    Config:addMessage("user", query)
    self:refreshSessionList()
    
    local Scanner = _G.AIAnalyzer.Scanner
    local context = Scanner and Scanner:toAIContext(50) or {}
    
    ui:addMessage("⏳ 正在思考...", false)
    
    spawn(function()
        local result, err = AIClient:analyzeResources(query, context)
        
        -- 移除加载提示
        local children = ui.messageArea:GetChildren()
        for i = #children, 1, -1 do
            if children[i]:IsA("Frame") then
                local label = children[i]:FindFirstChildWhichIsA("TextLabel", true)
                if label and label.Text and label.Text:find("正在思考") then
                    children[i]:Destroy()
                    break
                end
            end
        end
        
        if result then
            ui:addMessage(result.content, false)
            Config:addMessage("assistant", result.content)
            self:refreshSessionList()
            
            -- 更新Token统计
            if result.usage then
                ui:updateTokenDisplay(result.usage)
            end
        else
            ui:addMessage("❌ 错误: " .. tostring(err), false)
        end
    end)
end

-- 资源管理
function App:scanResources()
    local ui = _G.AIAnalyzer.UI
    local Scanner = _G.AIAnalyzer.Scanner
    
    if not Scanner then
        ui:addMessage("❌ Scanner模块未加载", false)
        return
    end
    
    ui:addMessage("🔍 正在扫描游戏资源...", false)
    
    spawn(function()
        local results = Scanner:scan()
        local stats = Scanner:getStats()
        
        -- 清空资源数据（保持与 ui.lua 结构一致）
        ui.allResources = {
            all = {},
            remotes = {},
            localscripts = {},
            serverscripts = {},
            modulescripts = {},
            others = {}
        }
        ui:clearResourceList()
        
        -- 添加资源到分类
        for _, remote in ipairs(results.remotes) do
            ui:addResourceToCategory(remote.name, remote.className, remote.path, function()
                self:analyzeResource(remote)
            end)
        end
        
        for _, script in ipairs(results.scripts) do
            ui:addResourceToCategory(script.name, script.className, script.path, function()
                self:analyzeScript(script)
            end)
        end
        
        ui:addMessage(string.format(
            "✅ 扫描完成\n• 总对象: %d\n• Remote: %d\n• Script: %d",
            stats.totalObjects, stats.remoteCount, stats.scriptCount
        ), false)
    end)
end

function App:searchResources(query)
    local ui = _G.AIAnalyzer.UI
    ui:refreshResourceList()
end

function App:analyzeResource(resource)
    local ui = _G.AIAnalyzer.UI
    local Reader = _G.AIAnalyzer.Reader
    
    -- 显示弹窗让用户选择操作
    ui:showResourceDialog(resource, {
        analyze = function()
            ui:showView("chat")
            local prompt = string.format(
                "请分析这个游戏资源：\n名称: %s\n类型: %s\n路径: %s\n\n请解释它的用途和使用方法，如果可能给出示例代码。",
                resource.name, resource.className, resource.path
            )
            ui.inputBox.Text = prompt
            self:sendMessage()
        end,
        generateCode = function()
            ui:showView("chat")
            local prompt = string.format(
                "请为这个 Remote 生成调用代码：\n名称: %s\n类型: %s\n路径: %s\n\n请给出完整的调用示例代码，包括参数说明。",
                resource.name, resource.className, resource.path
            )
            ui.inputBox.Text = prompt
            self:sendMessage()
        end,
        viewSource = function()
            -- 使用实例引用查看源码
            local instance = resource.instance
            if instance and Reader and Reader:canDecompile() then
                local source = Reader:readScript(instance)
                if source and source.source then
                    ui:showView("chat")
                    local prompt = string.format(
                        "脚本源码 (%s)：\n```lua\n%s\n```\n\n请分析这段代码的功能。",
                        resource.name, source.source:sub(1, 4000)
                    )
                    ui.inputBox.Text = prompt
                    self:sendMessage()
                    return
                end
            end
            ui:addMessage("⚠️ 无法读取该资源源码", false)
        end
    })
end

function App:analyzeScript(scriptInfo)
    local ui = _G.AIAnalyzer.UI
    local Reader = _G.AIAnalyzer.Reader
    
    -- 显示弹窗让用户选择操作
    ui:showResourceDialog(scriptInfo, {
        analyze = function()
            ui:showView("chat")
            
            -- 使用实例引用读取源码
            local instance = scriptInfo.instance
            if instance and Reader and Reader:canDecompile() then
                local scriptData = Reader:readScript(instance)
                if scriptData and scriptData.source then
                    local prompt = string.format(
                        "请分析这个脚本：\n名称: %s\n类型: %s\n路径: %s\n\n源码:\n```lua\n%s\n```",
                        scriptData.name, scriptData.className, scriptData.path,
                        scriptData.source:sub(1, 4000)
                    )
                    ui.inputBox.Text = prompt
                    self:sendMessage()
                    return
                end
            end
            
            local prompt = string.format(
                "请分析这个脚本资源：\n名称: %s\n类型: %s\n路径: %s\n\n（无法读取源码，可能需要支持反编译的执行器）",
                scriptInfo.name, scriptInfo.className, scriptInfo.path
            )
            ui.inputBox.Text = prompt
            self:sendMessage()
        end,
        generateCode = function()
            ui:showView("chat")
            ui:addMessage("⚠️ 脚本类型资源不支持生成调用代码", false)
        end,
        viewSource = function()
            local instance = scriptInfo.instance
            if instance and Reader and Reader:canDecompile() then
                local source = Reader:readScript(instance)
                if source and source.source then
                    ui:showView("chat")
                    ui:addMessage(string.format("📄 %s 源码:\n```lua\n%s\n```", 
                        scriptInfo.name, source.source), false)
                    return
                end
            end
            ui:addMessage("⚠️ 无法读取该脚本源码，可能需要支持反编译的执行器", false)
        end,
        sendToAI = function()
            -- 发送源码给AI分析
            ui:showView("chat")
            local instance = scriptInfo.instance
            if instance and Reader and Reader:canDecompile() then
                local scriptData = Reader:readScript(instance)
                if scriptData and scriptData.source then
                    local prompt = string.format(
                        "请详细分析这段脚本的功能和逻辑：\n名称: %s\n路径: %s\n\n```lua\n%s\n```\n\n请解释：\n1. 这段代码的主要功能\n2. 关键变量和函数的作用\n3. 可能的用途或调用场景",
                        scriptData.name, scriptData.path,
                        scriptData.source:sub(1, 5000)
                    )
                    ui.inputBox.Text = prompt
                    self:sendMessage()
                    return
                end
            end
            ui:addMessage("⚠️ 无法读取源码", false)
        end
    })
end

-- 设置管理
function App:saveSettings()
    local ui = _G.AIAnalyzer.UI
    local Config = _G.AIAnalyzer.Config
    
    if not Config then
        ui:addMessage("❌ Config模块未加载", false)
        return
    end
    
    local apiKey = ui.apiKeyInput.Text
    local scriptDir = ui.scriptDirInput.Text
    local currentProvider = Config.Settings.currentProvider
    
    if apiKey and apiKey ~= "" then
        Config:setApiKey(currentProvider, apiKey)
    end
    
    Config.Settings.scriptDir = scriptDir ~= "" and scriptDir or "workspace"
    Config:save()
    
    ui:addMessage("✅ 设置已保存", false)
    self:updateConnectionStatus()
end

function App:testConnection()
    local ui = _G.AIAnalyzer.UI
    local AIClient = _G.AIAnalyzer.AIClient
    
    if not AIClient then
        ui:addMessage("❌ AIClient模块未加载", false)
        return
    end
    
    ui:addMessage("🔍 正在测试API连接...", false)
    
    spawn(function()
        local success, message = AIClient:testConnection()
        
        if success then
            ui:addMessage("✅ " .. message, false)
            ui:updateStatus("已连接", ui.Theme.success)
        else
            ui:addMessage("❌ " .. message, false)
            ui:updateStatus("失败", ui.Theme.error)
        end
    end)
end

function App:switchProvider(providerName)
    local ui = _G.AIAnalyzer.UI
    local Config = _G.AIAnalyzer.Config
    
    if not Config then return end
    
    Config:switchProvider(providerName)
    
    for name, btn in pairs(ui.providerButtons) do
        if name:lower() == providerName:lower() then
            btn.BackgroundColor3 = ui.Theme.accent
            btn.TextColor3 = Color3.new(1, 1, 1)
        else
            btn.BackgroundColor3 = ui.Theme.backgroundSecondary
            btn.TextColor3 = ui.Theme.text
        end
    end
    
    local provider = Config:getCurrentProvider()
    ui.apiKeyInput.Text = provider.apiKey or ""
    self:updateConnectionStatus()
end

function App:updateConnectionStatus()
    local ui = _G.AIAnalyzer.UI
    local Config = _G.AIAnalyzer.Config
    
    if not Config then return end
    
    local provider = Config:getCurrentProvider()
    if provider and provider.apiKey and provider.apiKey ~= "" then
        ui:updateStatus(provider.name, ui.Theme.accent)
    else
        ui:updateStatus("未配置", ui.Theme.warning)
    end
end

-- 启动
App:init()

return App