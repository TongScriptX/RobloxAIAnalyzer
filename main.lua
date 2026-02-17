-- Roblox AI CLI v2.0.0
-- 用法: loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main/main.lua"))()

local BASE_URL = "https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main"

local App = {
    ver = "2.0.0",
    ready = false,
    exec = {},
    history = {}
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
    
    -- Synapse X
    if syn and syn.request then
        info.name = "Synapse X"
        info.canRequest = true
        info.request = syn.request
        if syn.writefile then info.writefile = syn.writefile; info.canWrite = true end
        if syn.readfile then info.readfile = syn.readfile end
        info.canExecute = true
        info.canDecompile = true
    -- Script-Ware
    elseif request and type(request) == "function" then
        info.name = "Script-Ware"
        info.canRequest = true
        info.request = request
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
        info.canExecute = true
        info.canDecompile = true
    -- KRNL
    elseif krnl and krnl.request then
        info.name = "KRNL"
        info.canRequest = true
        info.request = krnl.request
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
        info.canExecute = true
    -- Fluxus
    elseif fluxus and fluxus.request then
        info.name = "Fluxus"
        info.canRequest = true
        info.request = fluxus.request
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
        info.canExecute = true
    -- Electron
    elseif http and http.request then
        info.name = "Electron"
        info.canRequest = true
        info.request = http.request
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
        info.canExecute = true
    -- Delta / 其他
    elseif http_request then
        info.name = "Delta"
        info.canRequest = true
        info.request = http_request
        if writefile then info.writefile = writefile; info.canWrite = true end
        if readfile then info.readfile = readfile end
        info.canExecute = true
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
    
    -- 检查执行能力
    if not info.canExecute and (loadstring and getgenv) then
        info.canExecute = true
    end
    
    return info
end

-- HTTP获取
local httpGet

local function getHttpFunc(exec)
    if exec.request then
        return function(url)
            local r = exec.request({Url = url, Method = "GET"})
            return r.Body or r.body, r.StatusCode or r.statusCode
        end
    elseif game.HttpGet then
        return function(url) return game:HttpGet(url) end
    end
    return nil
end

-- 模块加载
local function loadModule(path)
    local url = BASE_URL .. "/" .. path
    local ok, res = pcall(httpGet, url)
    
    if ok and res and res ~= "" then
        local ok2, fn = pcall(loadstring, res)
        if ok2 and fn then
            local ok3, mod = pcall(fn)
            if ok3 then return mod end
        end
    end
    
    warn("[AI CLI] 加载失败: " .. path)
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

-- 历史记录
local function loadHistory()
    local cfg = _G.AIAnalyzer and _G.AIAnalyzer.Config
    if cfg and cfg.loadHistory then
        App.history = cfg:loadHistory()
    else
        App.history = {}
    end
end

local function saveHistory()
    local cfg = _G.AIAnalyzer and _G.AIAnalyzer.Config
    if cfg and cfg.saveHistory then
        cfg:saveHistory(App.history)
    end
end

local function addHistory(query, response)
    table.insert(App.history, {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        query = query,
        response = response:sub(1, 500)
    })
    
    -- 限制数量
    while #App.history > 50 do
        table.remove(App.history, 1)
    end
    
    saveHistory()
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
    
    -- 加载模块
    local cfg = loadModule("config.lua")
    if cfg then _G.AIAnalyzer.Config = cfg; print("[AI CLI] Config OK") end
    
    local http = loadModule("modules/http.lua")
    if http then _G.AIAnalyzer.Http = http; print("[AI CLI] Http OK") end
    
    local scanner = loadModule("modules/scanner.lua")
    if scanner then _G.AIAnalyzer.Scanner = scanner; print("[AI CLI] Scanner OK") end
    
    local reader = loadModule("modules/reader.lua")
    if reader then _G.AIAnalyzer.Reader = reader; print("[AI CLI] Reader OK") end
    
    local executor = loadModule("modules/executor.lua")
    if executor then _G.AIAnalyzer.Executor = executor; print("[AI CLI] Executor OK") end
    
    local ui = loadModule("modules/ui.lua")
    if ui then _G.AIAnalyzer.UI = ui; print("[AI CLI] UI OK") end
    
    local ai = loadModule("modules/ai_client.lua")
    if ai then _G.AIAnalyzer.AIClient = ai; print("[AI CLI] AIClient OK") end
    
    local cfg = _G.AIAnalyzer.Config
    if cfg and cfg.load then cfg:load() end
    loadHistory()
    
    self:setupUI()
    self:bindEvents()
    self:setupCallbacks()
    
    self.ready = true
    print("[AI CLI] 初始化完成")
    
    self:showWelcome()
end

function App:setupUI()
    local ui = _G.AIAnalyzer.UI
    
    ui:createMainWindow()
    
    ui:createSidebarButton("AI 对话", "💬", function()
        ui:showView("chat")
    end)
    
    ui:createSidebarButton("历史", "📜", function()
        self:showHistory()
    end)
    
    ui:createSidebarButton("资源", "📁", function()
        ui:showView("resources")
    end)
    
    ui:createSidebarButton("设置", "⚙️", function()
        ui:showView("settings")
        self:loadSettings()
    end)
    
    ui:createChatView()
    ui:createSettingsView()
    ui:createResourceView()
    
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
        self:clearHistory()
    end)
    
    ui.exportHistoryBtn.MouseButton1Click:Connect(function()
        self:exportHistory()
    end)
    
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
    
    self:sendToAI(text)
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

-- 显示历史记录
function App:showHistory()
    local ui = _G.AIAnalyzer.UI
    ui:showView("chat")
    
    if #self.history == 0 then
        ui:addMessage("📜 暂无历史记录", false)
        return
    end
    
    ui:addMessage(string.format("📜 最近 %d 条记录:", #self.history), false)
    
    for i, entry in ipairs(self.history) do
        if i > 10 then break end
        ui:addMessage(string.format("[%s] %s", entry.time, entry.query:sub(1, 50)), false)
    end
end

-- 清除历史
function App:clearHistory()
    local ui = _G.AIAnalyzer.UI
    self.history = {}
    saveHistory()
    ui:addMessage("✅ 历史记录已清除", false)
end

-- 导出历史
function App:exportHistory()
    local ui = _G.AIAnalyzer.UI
    local HttpService = game:GetService("HttpService")
    
    if #self.history == 0 then
        ui:addMessage("⚠️ 暂无历史记录可导出", false)
        return
    end
    
    local json = HttpService:JSONEncode(self.history)
    local success, result = saveScript("history_export", json)
    
    if success then
        ui:addMessage("✅ 历史已导出: " .. result, false)
    else
        -- 复制到剪贴板
        if setclipboard then
            setclipboard(json)
            ui:addMessage("✅ 历史已复制到剪贴板", false)
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
            addHistory(query, result.content)
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
        
        ui:clearResourceList()
        
        for _, remote in ipairs(results.remotes) do
            ui:addResourceItem(remote.name, remote.className, remote.path, function()
                self:analyzeResource(remote)
            end)
        end
        
        for _, script in ipairs(results.scripts) do
            ui:addResourceItem(script.name, script.className, script.path, function()
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
    local Scanner = _G.AIAnalyzer.Scanner
    
    if query == "" or not Scanner then return end
    
    local results = Scanner:search(query)
    ui:clearResourceList()
    
    for _, obj in ipairs(results) do
        ui:addResourceItem(obj.name, obj.className, obj.path, function()
            self:analyzeResource(obj)
        end)
    end
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
            -- 查看源码
            if Reader and Reader:canDecompile() then
                local obj = game:FindFirstChild(resource.path, true)
                if obj then
                    local source = Reader:readScript(obj)
                    if source then
                        ui:showView("chat")
                        local prompt = string.format(
                            "脚本源码 (%s)：\n```\n%s\n```\n\n请分析这段代码的功能。",
                            resource.name, source.source or source
                        )
                        ui.inputBox.Text = prompt
                        self:sendMessage()
                        return
                    end
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
            
            if Reader and Reader:canDecompile() then
                local scripts = Reader:getAllScripts()
                for _, s in ipairs(scripts) do
                    if s.Name == scriptInfo.name then
                        local scriptData = Reader:readScript(s)
                        if scriptData then
                            local prompt = string.format(
                                "请分析这个脚本：\n名称: %s\n类型: %s\n路径: %s\n\n源码:\n```\n%s\n```",
                                scriptData.name, scriptData.className, scriptData.path,
                                scriptData.source:sub(1, 3000)
                            )
                            ui.inputBox.Text = prompt
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
            ui.inputBox.Text = prompt
            self:sendMessage()
        end,
        generateCode = function()
            ui:showView("chat")
            ui:addMessage("⚠️ 脚本类型资源不支持生成调用代码", false)
        end,
        viewSource = function()
            if Reader and Reader:canDecompile() then
                local obj = game:FindFirstChild(scriptInfo.path, true)
                if obj then
                    local source = Reader:readScript(obj)
                    if source then
                        ui:showView("chat")
                        ui:addMessage(string.format("📄 %s 源码:\n```\n%s\n```", 
                            scriptInfo.name, source.source or source), false)
                        return
                    end
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