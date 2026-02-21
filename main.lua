-- Roblox AI CLI v2.1.0
-- 用法: loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main/main.lua"))()

local App = {
    ver = "2.1.0",
    ready = false,
    exec = {}
}

-- 清理旧UI
function App:cleanupOldUI()
    local coreGui = game:GetService("CoreGui")
    local uiNames = {"RobloxAIAnalyzer", "AILoadingUI"}
    for _, name in ipairs(uiNames) do
        local existing = coreGui:FindFirstChild(name)
        if existing then existing:Destroy() end
    end
    if _G.AIAnalyzer then
        if _G.AIAnalyzer.UI and _G.AIAnalyzer.UI.screenGui then
            _G.AIAnalyzer.UI.screenGui:Destroy()
        end
        _G.AIAnalyzer = nil
    end
    self.ready = false
end

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
    
    local executorName = nil
    if identifyexecutor then
        local ok, name = pcall(identifyexecutor)
        if ok and name then
            executorName = tostring(name):lower()
        end
    end
    
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
    
    -- listfiles 功能
    if listfiles then
        info.listfiles = listfiles
        info.canListFiles = true
    elseif syn and syn.listfiles then
        info.listfiles = syn.listfiles
        info.canListFiles = true
    end
    
    -- isfile / isfolder 功能
    if isfile then info.isfile = isfile end
    if isfolder then info.isfolder = isfolder end
    if syn and syn.isfile then info.isfile = syn.isfile end
    if syn and syn.isfolder then info.isfolder = syn.isfolder end
    
    -- makefolder / delfolder / delfile 功能
    if makefolder then info.makefolder = makefolder end
    if delfolder then info.delfolder = delfolder end
    if delfile then info.delfile = delfile end
    
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

-- 模块加载
local BASE_URL = "https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main"
local CACHE_BUSTER = "?v=" .. tostring(os.time())

local function loadModule(path)
    local url = BASE_URL .. "/" .. path .. CACHE_BUSTER
    
    local ok, res = pcall(httpGet, url)
    if not ok or not res or type(res) ~= "string" or #res <= 10 then
        return nil
    end
    
    if res:sub(1, 1) == "<" then return nil end
    
    local fn, err = loadstring(res)
    if not fn then return nil end
    
    local ok3, mod = pcall(fn)
    if not ok3 then return nil end
    
    return mod
end

-- 脚本操作
local function saveScript(name, content)
    local cfg = _G.AIAnalyzer and _G.AIAnalyzer.Config
    local exec = App.exec
    
    if not exec.canWrite or not exec.writefile then
        return false, "不支持写入文件"
    end
    
    local dir = cfg and cfg.Settings and cfg.Settings.scriptDir or "AICli"
    local filename
    
    if dir == "" then
        dir = "AICli"
    end
    
    -- 所有文件都保存到 AICli 目录
    filename = "AICli/" .. name:gsub("[^%w_%.%-]", "_") .. ".lua"
    
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
    
    self:cleanupOldUI()
    
    print("[AI CLI] v" .. self.ver .. " 启动中...")
    
    self.exec = detectExecutor()
    print("[AI CLI] 执行器: " .. self.exec.name)
    
    httpGet = getHttpFunc(self.exec)
    if not httpGet then
        warn("[AI CLI] 错误：无法获取HTTP函数")
        return
    end
    
    _G.AIAnalyzer = {Executor = self.exec}
    
    self:showLoadingUI()
    
    local modules = {
        {name = "Config", path = "config.lua", key = "Config", required = true},
        {name = "Http", path = "modules/http.lua", key = "Http", required = true},
        {name = "Scanner", path = "modules/scanner.lua", key = "Scanner", required = true},
        {name = "Reader", path = "modules/reader.lua", key = "Reader", required = true},
        {name = "UI", path = "modules/ui.lua", key = "UI", required = true},
        {name = "Tools", path = "modules/tools.lua", key = "Tools", required = false},
        {name = "ContextManager", path = "modules/context_manager.lua", key = "ContextManager", required = false},
        {name = "AIClient", path = "modules/ai_client.lua", key = "AIClient", required = true},
    }
    
    for i, mod in ipairs(modules) do
        self:updateLoadingProgress(i, #modules, mod.name)
        local m = loadModule(mod.path)
        if m then
            _G.AIAnalyzer[mod.key] = m
        else
            if mod.required then
                self:hideLoadingUI()
                warn("[AI CLI] " .. mod.name .. " 加载失败（必需模块）")
                return
            end
        end
    end
    
    local cfg = _G.AIAnalyzer.Config
    if cfg and cfg.load then cfg:load() end
    
    self:hideLoadingUI()
    
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
    end)
    
    ui:createChatView()
    ui:createSettingsView()
    ui:createResourceView()
    
    ui:showView("chat")
    self:updateConnectionStatus()
    
    -- 初始化设置页面数据
    self:loadSettings()
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
        ui.scriptDirInput.Text = cfg.Settings and cfg.Settings.scriptDir or ""
        ui:updateConfirmToggle(cfg.Settings and cfg.Settings.confirmBeforeExecute)
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
    
    -- 监听输入框文本变化，检测@触发文件浏览器
    ui.inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        ui:checkFileBrowserTrigger()
    end)
    
    ui.saveSettingsBtn.MouseButton1Click:Connect(function()
        self:saveSettings()
    end)
    
    ui.testConnectionBtn.MouseButton1Click:Connect(function()
        self:testConnection()
    end)
    
    -- 动态绑定提供商按钮事件
    for key, btn in pairs(ui.providerButtons) do
        btn.MouseButton1Click:Connect(function()
            self:switchProvider(key)
        end)
    end
    
    -- 模型下拉框点击事件
    if ui.modelDropdown then
        ui.modelDropdown.MouseButton1Click:Connect(function()
            ui.modelListFrame.Visible = not ui.modelListFrame.Visible
        end)
    end
    
    ui.confirmToggle.MouseButton1Click:Connect(function()
        if cfg then
            cfg.Settings.confirmBeforeExecute = not cfg.Settings.confirmBeforeExecute
            ui:updateConfirmToggle(cfg.Settings.confirmBeforeExecute)
        end
    end)
    
    -- 运行模式按钮事件
    local Tools = _G.AIAnalyzer.Tools
    if ui.runModeButtons then
        for mode, btn in pairs(ui.runModeButtons) do
            btn.MouseButton1Click:Connect(function()
                if Tools and Tools.setRunMode then
                    Tools:setRunMode(mode)
                    ui:updateRunModeDisplay(mode)
                    ui:addMessage("✅ 运行模式已切换为: " .. mode, false)
                end
            end)
        end
    end
    
    ui.scanBtn.MouseButton1Click:Connect(function()
        self:scanResources()
    end)
    
    ui.resourceSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self:searchResources(ui.resourceSearchBox.Text)
    end)
end

function App:setupCallbacks()
    local ui = _G.AIAnalyzer.UI
    
    ui:onExecute(function(code, frame)
        local Config = _G.AIAnalyzer.Config
        local success, err = execScript(code)
        if success then
            self:addSystemMessage("✅ 脚本执行成功")
        else
            self:addSystemMessage("❌ 执行失败: " .. tostring(err))
        end
    end)
    
    ui:onSave(function(code, frame)
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
    
    local cmd = text:lower():match("^%s*(.-)%s*$")
    
    -- 处理确认/取消命令
    if cmd == "/confirm" or cmd == "确认" or cmd == "y" or cmd == "yes" then
        self:confirmScriptExecution()
        return
    end
    
    if cmd == "/cancel" or cmd == "取消" or cmd == "n" or cmd == "no" then
        self:cancelScriptExecution()
        return
    end
    
    -- 设置运行模式
    if cmd == "/mode smart" or cmd == "智能模式" then
        self:setRunMode("smart")
        return
    end
    
    if cmd == "/mode default" or cmd == "默认模式" then
        self:setRunMode("default")
        return
    end
    
    if cmd == "/mode yolo" or cmd == "yolo模式" then
        self:setRunMode("yolo")
        return
    end
    
    -- 如果有待确认的脚本，其他输入视为取消
    if self.pendingConfirmation then
        ui:addMessage("⚠️ 有待确认的脚本，请输入 '确认' 或 '取消'", false)
        return
    end
    
    ui:addMessage(text, true)
    
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
    
    -- 压缩上下文
    if cmd == "/compress" or cmd == "压缩" then
        self:compressContext()
        return
    end
    
    -- 查看上下文状态
    if cmd == "/context" or cmd == "上下文" then
        self:showContextStatus()
        return
    end
    
    -- 清空上下文
    if cmd == "/reset" or cmd == "重置上下文" then
        self:resetContext()
        return
    end
    
    self:sendToAI(text)
end

-- 压缩上下文
function App:compressContext()
    local ui = _G.AIAnalyzer.UI
    local AIClient = _G.AIAnalyzer.AIClient
    
    if not AIClient then
        ui:addMessage("❌ AIClient模块未加载", false)
        return
    end
    
    local success, message = AIClient:compressContext()
    if success then
        ui:addMessage("✅ " .. message, false)
    else
        ui:addMessage("⚠️ " .. tostring(message), false)
    end
end

-- 显示上下文状态
function App:showContextStatus()
    local ui = _G.AIAnalyzer.UI
    local AIClient = _G.AIAnalyzer.AIClient
    
    if not AIClient then
        ui:addMessage("❌ AIClient模块未加载", false)
        return
    end
    
    local status = AIClient:formatContextStatus()
    ui:addMessage(status, false)
end

-- 重置上下文
function App:resetContext()
    local ui = _G.AIAnalyzer.UI
    local AIClient = _G.AIAnalyzer.AIClient
    
    if not AIClient then
        ui:addMessage("❌ AIClient模块未加载", false)
        return
    end
    
    local success, message = AIClient:clearContext()
    ui:addMessage("✅ " .. message, false)
end

-- 设置运行模式
function App:setRunMode(mode)
    local ui = _G.AIAnalyzer.UI
    local Tools = _G.AIAnalyzer.Tools
    
    if not Tools then
        ui:addMessage("❌ Tools模块未加载", false)
        return
    end
    
    Tools:setRunMode(mode)
    
    local modeNames = {
        smart = "智能模式（低风险自动执行）",
        default = "默认模式（每次询问）",
        yolo = "YOLO模式（从不询问）"
    }
    
    ui:addMessage("✅ 运行模式已设置为: " .. (modeNames[mode] or mode), false)
end

-- 确认脚本执行
function App:confirmScriptExecution()
    local ui = _G.AIAnalyzer.UI
    local Tools = _G.AIAnalyzer.Tools
    
    -- 检查是否是文件浏览器的脚本执行
    if ui.pendingFileExecution then
        local code = ui.pendingFileExecution
        local filePath = ui.fileBrowserSelectedFile or "未命名"
        ui.pendingFileExecution = nil
        self.pendingConfirmation = nil
        ui:hideConfirmationPrompt()
        
        ui:addMessage("✅ 已确认，正在执行脚本...", false)
        ui:executeFileCode(code, filePath)
        return
    end
    
    if not self.pendingConfirmation then
        ui:addMessage("⚠️ 没有待确认的脚本", false)
        return
    end
    
    if not Tools then
        ui:addMessage("❌ Tools模块未加载", false)
        self.pendingConfirmation = nil
        return
    end
    
    ui:addMessage("✅ 已确认，正在执行脚本...", false)
    
    -- 执行脚本
    local result = Tools:executeConfirmed()
    
    self.pendingConfirmation = nil
    
    -- 显示结果
    if result.success then
        local parts = {"✅ 脚本执行成功"}
        if result.executionTime then
            parts[#parts + 1] = string.format("耗时: %.3f秒", result.executionTime)
        end
        if result.result then
            parts[#parts + 1] = "返回值: " .. tostring(result.result)
        end
        if result.output and #result.output > 0 then
            parts[#parts + 1] = "输出:"
            for _, line in ipairs(result.output) do
                parts[#parts + 1] = "  " .. line
            end
        end
        ui:addMessage(table.concat(parts, "\n"), false)
    else
        ui:addMessage("❌ 脚本执行失败: " .. tostring(result.error or result.result), false)
    end
end

-- 取消脚本执行
function App:cancelScriptExecution()
    local ui = _G.AIAnalyzer.UI
    local Tools = _G.AIAnalyzer.Tools
    
    -- 清除文件浏览器的待执行脚本
    if ui.pendingFileExecution then
        ui.pendingFileExecution = nil
    end
    
    if not self.pendingConfirmation then
        ui:addMessage("⚠️ 没有待确认的脚本", false)
        return
    end
    
    if Tools then
        Tools:cancelExecution()
    end
    
    self.pendingConfirmation = nil
    ui:addMessage("⚠️ 脚本执行已取消", false)
end

function App:showHelp()
    local ui = _G.AIAnalyzer.UI
    
    -- 获取当前运行模式
    local Tools = _G.AIAnalyzer.Tools
    local currentMode = Tools and Tools:getRunMode() or "default"
    local modeNames = {
        smart = "智能",
        default = "默认",
        yolo = "YOLO"
    }
    
    ui:addMessage(string.format([[
📖 帮助信息

📌 基础命令:
• 帮助/help - 显示此帮助
• 扫描/scan - 扫描游戏资源
• 清除/clear - 清空对话
• /compress - 压缩上下文
• /context - 查看上下文状态
• /reset - 重置上下文

🔒 运行模式 (当前: %s):
• /mode smart - 智能模式（低风险自动执行）
• /mode default - 默认模式（每次询问）
• /mode yolo - YOLO模式（从不询问）

✅ 脚本确认:
• 确认/yes - 确认执行脚本
• 取消/no - 取消执行脚本

💡 AI使用示例:
• "分析 game.Players 的结构"
• "找到所有 RemoteEvent"
• "生成一个自动拾取金币的脚本"

🔧 代码块操作:
• 复制 - 复制代码到剪贴板
• 执行 - 直接运行代码
• 保存 - 保存到执行器目录]], modeNames[currentMode] or currentMode), false)
end

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
    
    local Scanner = _G.AIAnalyzer.Scanner
    
    -- 检查是否需要自动扫描
    local needsScan = not Scanner or not Scanner.cache or not Scanner.cache.objects or #Scanner.cache.objects == 0
    
    if needsScan then
        ui:addMessage("🔄 首次对话，正在自动扫描游戏资源...", false)
        self:scanResources()
    end
    
    local context = Scanner and Scanner:toAIContext(50) or {}
    
    -- 显示加载动画
    ui:showLoading()
    
    spawn(function()
        -- 使用 pcall 捕获错误，确保 UI 状态总是被重置
        local success, resultOrErr = pcall(function()
            return AIClient:analyzeResources(query, context)
        end)
        
        -- 隐藏加载动画（总是执行）
        ui:hideLoading()
        
        if not success then
            ui:addMessage("❌ 请求出错: " .. tostring(resultOrErr), false)
            return
        end
        
        local result, err = resultOrErr, nil
        -- pcall 返回的是单个值，需要检查是否是 nil, err 格式
        
        if result then
            -- 传递思考过程（如果存在）
            ui:addMessage(result.content, false, result.reasoning)
            if result.usage then
                ui:updateTokenDisplay(result.usage)
            end
            -- 显示上下文状态（如果接近阈值）
            if result.contextStatus and result.contextStatus.usageRatio and result.contextStatus.usageRatio > 0.5 then
                local status = result.contextStatus
                local warning = ""
                if status.usageRatio >= 0.7 then
                    warning = " ⚠️ 接近上限，建议使用 /compress 压缩"
                end
                ui:addMessage(string.format("📊 上下文: %.0f%% (%d/%d tokens)%s", 
                    status.usageRatio * 100, status.totalTokens, status.maxTokens, warning), false)
            end
            
            -- 检查是否需要确认脚本执行
            if result.needsConfirmation then
                self.pendingConfirmation = true
                -- 在输入栏显示确认提示
                ui:showConfirmationPrompt(result.description, result.codePreview)
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
        -- 增量扫描回调
        local lastCount = 0
        local results = Scanner:scan(function(count, typeCount, serviceName)
            -- 每扫描完一个服务就更新UI
            if count > lastCount then
                ui:refreshResourceList()
                lastCount = count
            end
        end)
        
        local stats = Scanner:getStats()
        
        -- 最终刷新
        ui:refreshResourceList()
        
        ui:addMessage(string.format(
            "✅ 扫描完成\n• 总对象: %d\n• 类型: %d",
            stats.totalObjects or #results.all,
            stats.totalTypes or 0
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
    
    ui:showResourceDialog(resource, {
        analyze = function()
            ui:showView("chat")
            local prompt = string.format(
                "请分析这个游戏资源：\n名称: %s\n类型: %s\n路径: %s\n\n请解释它的用途和使用方法。",
                resource.name, resource.className, resource.path
            )
            ui.inputBox.Text = prompt
            self:sendMessage()
        end,
        generateCode = function()
            ui:showView("chat")
            local prompt = string.format(
                "请为这个 Remote 生成调用代码：\n名称: %s\n类型: %s\n路径: %s",
                resource.name, resource.className, resource.path
            )
            ui.inputBox.Text = prompt
            self:sendMessage()
        end,
        viewSource = function()
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
    
    ui:showResourceDialog(scriptInfo, {
        analyze = function()
            ui:showView("chat")
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
                "请分析这个脚本资源：\n名称: %s\n类型: %s\n路径: %s",
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
            ui:addMessage("⚠️ 无法读取该脚本源码", false)
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
    
    Config.Settings.scriptDir = scriptDir ~= "" and scriptDir or "AICli"
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
    
    for key, btn in pairs(ui.providerButtons) do
        if key == providerName then
            btn.BackgroundColor3 = ui.Theme.accent
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.Font = Enum.Font.GothamBold
        else
            btn.BackgroundColor3 = ui.Theme.backgroundSecondary
            btn.TextColor3 = ui.Theme.text
            btn.Font = Enum.Font.Gotham
        end
    end
    
    if ui.updateModelDropdown then
        ui:updateModelDropdown(providerName)
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
