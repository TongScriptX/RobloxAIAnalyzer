-- UI模块 - Roblox AI Resource Analyzer
local UI = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- 主题配色
UI.Theme = {
    background = Color3.fromRGB(25, 25, 30),
    backgroundSecondary = Color3.fromRGB(35, 35, 42),
    backgroundTertiary = Color3.fromRGB(45, 45, 55),
    accent = Color3.fromRGB(88, 166, 255),
    accentHover = Color3.fromRGB(108, 186, 255),
    text = Color3.fromRGB(240, 240, 240),
    textSecondary = Color3.fromRGB(180, 180, 180),
    textMuted = Color3.fromRGB(120, 120, 120),
    success = Color3.fromRGB(76, 175, 80),
    warning = Color3.fromRGB(255, 193, 7),
    error = Color3.fromRGB(244, 67, 54),
    border = Color3.fromRGB(60, 60, 70)
}

-- 窗口配置
UI.WindowConfig = {
    widthRatio = 0.85,
    heightRatio = 0.75,
    minWidth = 450,
    minHeight = 350,
    maxWidth = 900,
    maxHeight = 700,
    sidebarMinWidth = 130,
    sidebarMaxWidth = 180,
    sidebarRatio = 0.22,
    titleBarHeight = 45,
    isMinimized = false,
    floatBtnSize = 50,
    floatBtnMargin = 20
}

-- 辅助函数
local function createCorner(parent, radius)
    local corner = Instance.new("UICorner", parent)
    corner.CornerRadius = UDim.new(0, radius or 8)
    return corner
end

local function createPadding(parent, padding)
    local pad = Instance.new("UIPadding", parent)
    pad.PaddingTop = UDim.new(0, padding)
    pad.PaddingBottom = UDim.new(0, padding)
    pad.PaddingLeft = UDim.new(0, padding)
    pad.PaddingRight = UDim.new(0, padding)
    return pad
end

function UI:getScreenSize()
    local viewportSize = workspace.CurrentCamera.ViewportSize
    return viewportSize.X, viewportSize.Y
end

-- 窗口尺寸计算
function UI:calculateWindowSize()
    local screenW, screenH = self:getScreenSize()
    local config = self.WindowConfig
    
    local winW = math.floor(screenW * config.widthRatio)
    local winH = math.floor(screenH * config.heightRatio)
    
    winW = math.clamp(winW, config.minWidth, config.maxWidth)
    winH = math.clamp(winH, config.minHeight, config.maxHeight)
    
    return winW, winH
end

function UI:calculateSidebarWidth()
    local winW = self.currentWidth or self:calculateWindowSize()
    local config = self.WindowConfig
    local sidebarW = math.floor(winW * config.sidebarRatio)
    return math.clamp(sidebarW, config.sidebarMinWidth, config.sidebarMaxWidth)
end

-- 创建主窗口
function UI:createMainWindow()
    -- 主ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RobloxAIAnalyzer"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    -- 计算窗口尺寸
    local winW, winH = self:calculateWindowSize()
    self.currentWidth = winW
    self.currentHeight = winH
    local sidebarW = self:calculateSidebarWidth()
    
    -- 获取屏幕尺寸用于悬浮按钮定位
    local screenW, screenH = self:getScreenSize()
    local config = self.WindowConfig
    local floatX = screenW - config.floatBtnSize - config.floatBtnMargin
    local floatY = screenH / 2 - config.floatBtnSize / 2
    
    -- 创建悬浮按钮
    local floatBtn = Instance.new("TextButton", screenGui)
    floatBtn.Name = "FloatButton"
    floatBtn.Size = UDim2.new(0, config.floatBtnSize, 0, config.floatBtnSize)
    floatBtn.Position = UDim2.new(0, floatX, 0, floatY)
    floatBtn.BackgroundColor3 = self.Theme.accent
    floatBtn.BorderSizePixel = 0
    floatBtn.Text = "AI"
    floatBtn.TextColor3 = Color3.new(1, 1, 1)
    floatBtn.TextSize = 16
    floatBtn.Font = Enum.Font.GothamBold
    floatBtn.Visible = false
    floatBtn.ZIndex = 100
    createCorner(floatBtn, config.floatBtnSize / 2)
    
    -- 悬浮按钮边框
    local floatStroke = Instance.new("UIStroke", floatBtn)
    floatStroke.Color = self.Theme.accentHover
    floatStroke.Thickness = 2
    
    -- 主框架
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, winW, 0, winH)
    mainFrame.Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2)
    mainFrame.BackgroundColor3 = self.Theme.background
    mainFrame.BorderSizePixel = 0
    createCorner(mainFrame, 12)
    
    -- 边框效果
    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Color = self.Theme.border
    stroke.Thickness = 1
    
    -- 标题栏
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, self.WindowConfig.titleBarHeight)
    titleBar.BackgroundColor3 = self.Theme.backgroundSecondary
    titleBar.BorderSizePixel = 0
    createCorner(titleBar, 12)
    
    -- 修正标题栏圆角（只保留上方）
    local fixCorner = Instance.new("Frame", titleBar)
    fixCorner.Size = UDim2.new(1, 0, 0, 20)
    fixCorner.Position = UDim2.new(0, 0, 1, -20)
    fixCorner.BackgroundColor3 = self.Theme.backgroundSecondary
    fixCorner.BorderSizePixel = 0
    
    -- 标题文本
    local titleText = Instance.new("TextLabel", titleBar)
    titleText.Name = "Title"
    titleText.Size = UDim2.new(1, -120, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "AI Resource Analyzer"
    titleText.TextColor3 = self.Theme.text
    titleText.TextSize = 16
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.TextScaled = true
    
    -- 状态指示器
    local statusIndicator = Instance.new("Frame", titleBar)
    statusIndicator.Name = "StatusIndicator"
    statusIndicator.Size = UDim2.new(0, 10, 0, 10)
    statusIndicator.Position = UDim2.new(1, -90, 0.5, -5)
    statusIndicator.BackgroundColor3 = self.Theme.warning
    statusIndicator.BorderSizePixel = 0
    createCorner(statusIndicator, 5)
    
    local statusText = Instance.new("TextLabel", titleBar)
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(0, 50, 1, 0)
    statusText.Position = UDim2.new(1, -75, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "未连接"
    statusText.TextColor3 = self.Theme.textSecondary
    statusText.TextSize = 11
    statusText.Font = Enum.Font.Gotham
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- 最小化按钮
    local minBtn = Instance.new("TextButton", titleBar)
    minBtn.Name = "MinButton"
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(1, -70, 0.5, -14)
    minBtn.BackgroundColor3 = self.Theme.warning
    minBtn.BorderSizePixel = 0
    minBtn.Text = "-"
    minBtn.TextColor3 = Color3.new(0, 0, 0)
    minBtn.TextSize = 18
    minBtn.Font = Enum.Font.GothamBold
    createCorner(minBtn, 6)
    
    -- 关闭按钮
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
    closeBtn.BackgroundColor3 = self.Theme.error
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    createCorner(closeBtn, 6)
    
    -- 内容区域
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, 0, 1, -self.WindowConfig.titleBarHeight)
    contentFrame.Position = UDim2.new(0, 0, 0, self.WindowConfig.titleBarHeight)
    contentFrame.BackgroundTransparency = 1
    
    -- 侧边栏
    local sidebar = Instance.new("Frame", contentFrame)
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, sidebarW, 1, -10)
    sidebar.Position = UDim2.new(0, 5, 0, 5)
    sidebar.BackgroundColor3 = self.Theme.backgroundSecondary
    sidebar.BorderSizePixel = 0
    createCorner(sidebar, 8)
    
    -- 主内容区
    local mainContent = Instance.new("Frame", contentFrame)
    mainContent.Name = "MainContent"
    mainContent.Size = UDim2.new(1, -sidebarW - 15, 1, -10)
    mainContent.Position = UDim2.new(0, sidebarW + 10, 0, 5)
    mainContent.BackgroundColor3 = self.Theme.backgroundSecondary
    mainContent.BorderSizePixel = 0
    createCorner(mainContent, 8)
    
    -- 保存引用
    self.screenGui = screenGui
    self.mainFrame = mainFrame
    self.titleBar = titleBar
    self.titleText = titleText
    self.statusIndicator = statusIndicator
    self.statusText = statusText
    self.sidebar = sidebar
    self.mainContent = mainContent
    self.contentFrame = contentFrame
    self.floatBtn = floatBtn
    
    -- 设置拖动
    self:setupDrag(titleBar, mainFrame)
    self:setupFloatDrag(floatBtn)
    
    -- 设置关闭/最小化
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    minBtn.MouseButton1Click:Connect(function()
        self:toggleMinimize()
    end)
    
    -- 悬浮按钮点击展开
    floatBtn.MouseButton1Click:Connect(function()
        self:toggleMinimize()
    end)
    
    -- 悬浮按钮悬停效果
    floatBtn.MouseEnter:Connect(function()
        TweenService:Create(floatBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = self.Theme.accentHover,
            Size = UDim2.new(0, self.WindowConfig.floatBtnSize + 5, 0, self.WindowConfig.floatBtnSize + 5)
        }):Play()
    end)
    
    floatBtn.MouseLeave:Connect(function()
        TweenService:Create(floatBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = self.Theme.accent,
            Size = UDim2.new(0, self.WindowConfig.floatBtnSize, 0, self.WindowConfig.floatBtnSize)
        }):Play()
    end)
    
    -- 监听屏幕尺寸变化
    self:setupResizeListener()
    
    return screenGui
end

-- 切换最小化状态
function UI:toggleMinimize()
    local config = self.WindowConfig
    config.isMinimized = not config.isMinimized
    
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    if config.isMinimized then
        -- 缩小为悬浮按钮
        self.savedPosition = self.mainFrame.Position
        
        -- 获取屏幕尺寸
        local screenW, screenH = self:getScreenSize()
        local centerX = screenW / 2
        local centerY = screenH / 2
        
        -- 缩小动画
        local shrinkTween = TweenService:Create(self.mainFrame, tweenInfo, {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0, centerX, 0, centerY),
            BackgroundTransparency = 1
        })
        
        shrinkTween:Play()
        
        -- 窗口消失后显示悬浮按钮
        shrinkTween.Completed:Connect(function()
            self.mainFrame.Visible = false
            -- 设置悬浮按钮位置在屏幕右侧中间
            local floatX = screenW - config.floatBtnSize - config.floatBtnMargin
            local floatY = screenH / 2 - config.floatBtnSize / 2
            self.floatBtn.Position = UDim2.new(0, floatX, 0, floatY)
            self.floatBtn.Visible = true
        end)
    else
        -- 从悬浮按钮展开
        self.floatBtn.Visible = false
        self.mainFrame.Visible = true
        self.mainFrame.Size = UDim2.new(0, 0, 0, 0)
        self.mainFrame.BackgroundTransparency = 1
        self.mainFrame.Position = self.savedPosition or UDim2.new(0.5, -self.currentWidth/2, 0.5, -self.currentHeight/2)
        
        -- 展开动画
        TweenService:Create(self.mainFrame, tweenInfo, {
            Size = UDim2.new(0, self.currentWidth, 0, self.currentHeight),
            Position = UDim2.new(0.5, -self.currentWidth/2, 0.5, -self.currentHeight/2),
            BackgroundTransparency = 0
        }):Play()
    end
end

-- 设置悬浮按钮拖动
function UI:setupFloatDrag(floatBtn)
    local dragging = false
    local dragInput, dragStart, startPos
    local config = self.WindowConfig
    
    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = floatBtn.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    -- 吸附到边缘
                    self:snapFloatToEdge()
                end
            end)
        end
    end)
    
    floatBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y
            
            -- 限制在屏幕范围内
            local screenW = workspace.CurrentCamera.ViewportSize.X
            local screenH = workspace.CurrentCamera.ViewportSize.Y
            
            newX = math.clamp(newX, config.floatBtnMargin, screenW - config.floatBtnSize - config.floatBtnMargin)
            newY = math.clamp(newY, config.floatBtnMargin, screenH - config.floatBtnSize - config.floatBtnMargin)
            
            floatBtn.Position = UDim2.new(0, newX, 0, newY)
        end
    end)
end

-- 悬浮按钮吸附到屏幕边缘
function UI:snapFloatToEdge()
    local config = self.WindowConfig
    local screenW = workspace.CurrentCamera.ViewportSize.X
    local screenH = workspace.CurrentCamera.ViewportSize.Y
    local btnX = self.floatBtn.Position.X.Offset
    local btnY = self.floatBtn.Position.Y.Offset
    local screenCenter = screenW / 2
    
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    -- 吸附到左边或右边
    local targetX
    if btnX < screenCenter then
        targetX = config.floatBtnMargin
    else
        targetX = screenW - config.floatBtnSize - config.floatBtnMargin
    end
    
    -- 确保Y坐标在屏幕范围内
    local targetY = math.clamp(btnY, config.floatBtnMargin, screenH - config.floatBtnSize - config.floatBtnMargin)
    
    TweenService:Create(self.floatBtn, tweenInfo, {
        Position = UDim2.new(0, targetX, 0, targetY)
    }):Play()
end

-- 监听屏幕尺寸变化
function UI:setupResizeListener()
    local lastUpdate = 0
    
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local now = tick()
        if now - lastUpdate < 0.5 then return end -- 节流
        lastUpdate = now
        
        if not self.WindowConfig.isMinimized then
            self:resizeWindow()
        end
    end)
end

-- 调整窗口大小
function UI:resizeWindow()
    -- 最小化状态下不调整
    if self.WindowConfig.isMinimized then
        return
    end
    
    local winW, winH = self:calculateWindowSize()
    self.currentWidth = winW
    self.currentHeight = winH
    local sidebarW = self:calculateSidebarWidth()
    
    -- 动画调整大小
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    TweenService:Create(self.mainFrame, tweenInfo, {
        Size = UDim2.new(0, winW, 0, winH),
        Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2)
    }):Play()
    
    TweenService:Create(self.sidebar, tweenInfo, {
        Size = UDim2.new(0, sidebarW, 1, -10)
    }):Play()
    
    TweenService:Create(self.mainContent, tweenInfo, {
        Size = UDim2.new(1, -sidebarW - 15, 1, -10),
        Position = UDim2.new(0, sidebarW + 10, 0, 5)
    }):Play()
end

-- 创建侧边栏按钮
function UI:createSidebarButton(name, icon, callback)
    local btnCount = 0
    for _, child in pairs(self.sidebar:GetChildren()) do
        if child:IsA("TextButton") then
            btnCount = btnCount + 1
        end
    end
    
    local btn = Instance.new("TextButton", self.sidebar)
    btn.Name = name
    btn.Size = UDim2.new(1, -10, 0, 36)
    btn.Position = UDim2.new(0, 5, 0, btnCount * 40 + 5)
    btn.BackgroundColor3 = self.Theme.backgroundTertiary
    btn.BorderSizePixel = 0
    btn.Text = " " .. icon .. " " .. name
    btn.TextColor3 = self.Theme.text
    btn.TextSize = 13
    btn.Font = Enum.Font.Gotham
    btn.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(btn, 6)
    createPadding(btn, 8)
    
    btn.MouseButton1Click:Connect(callback)
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = self.Theme.accent}):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = self.Theme.backgroundTertiary}):Play()
    end)
    
    return btn
end

-- 创建聊天界面
function UI:createChatView()
    local chatFrame = Instance.new("Frame", self.mainContent)
    chatFrame.Name = "ChatView"
    chatFrame.Size = UDim2.new(1, 0, 1, 0)
    chatFrame.BackgroundTransparency = 1
    
    -- 消息显示区
    local messageArea = Instance.new("ScrollingFrame", chatFrame)
    messageArea.Name = "MessageArea"
    messageArea.Size = UDim2.new(1, -16, 1, -56)
    messageArea.Position = UDim2.new(0, 8, 0, 8)
    messageArea.BackgroundColor3 = self.Theme.backgroundTertiary
    messageArea.BorderSizePixel = 0
    messageArea.ScrollBarThickness = 5
    messageArea.ScrollBarImageColor3 = self.Theme.accent
    messageArea.CanvasSize = UDim2.new(0, 0, 0, 0)
    messageArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
    createCorner(messageArea, 8)
    
    local listLayout = Instance.new("UIListLayout", messageArea)
    listLayout.Padding = UDim.new(0, 6)
    
    -- 输入区域
    local inputFrame = Instance.new("Frame", chatFrame)
    inputFrame.Name = "InputFrame"
    inputFrame.Size = UDim2.new(1, -16, 0, 38)
    inputFrame.Position = UDim2.new(0, 8, 1, -46)
    inputFrame.BackgroundColor3 = self.Theme.backgroundTertiary
    inputFrame.BorderSizePixel = 0
    createCorner(inputFrame, 8)
    
    local inputBox = Instance.new("TextBox", inputFrame)
    inputBox.Name = "InputBox"
    inputBox.Size = UDim2.new(1, -50, 1, 0)
    inputBox.Position = UDim2.new(0, 8, 0, 0)
    inputBox.BackgroundTransparency = 1
    inputBox.PlaceholderText = "输入问题或指令..."
    inputBox.PlaceholderColor3 = self.Theme.textMuted
    inputBox.Text = ""
    inputBox.TextColor3 = self.Theme.text
    inputBox.TextSize = 13
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.TextWrapped = true
    
    local sendBtn = Instance.new("TextButton", inputFrame)
    sendBtn.Name = "SendButton"
    sendBtn.Size = UDim2.new(0, 36, 0, 28)
    sendBtn.Position = UDim2.new(1, -40, 0.5, -14)
    sendBtn.BackgroundColor3 = self.Theme.accent
    sendBtn.BorderSizePixel = 0
    sendBtn.Text = ">"
    sendBtn.TextColor3 = Color3.new(1, 1, 1)
    sendBtn.TextSize = 16
    sendBtn.Font = Enum.Font.GothamBold
    createCorner(sendBtn, 6)
    
    self.chatView = chatFrame
    self.messageArea = messageArea
    self.inputBox = inputBox
    self.sendBtn = sendBtn
    
    return chatFrame
end

-- Markdown解析（主要处理代码块）
local function parseMarkdown(text)
    local blocks = {}
    local pos = 1
    local len = #text
    
    while pos <= len do
        local codeStart = text:find("```", pos)
        
        if codeStart then
            -- 代码块前的文本
            if codeStart > pos then
                local beforeText = text:sub(pos, codeStart - 1)
                if beforeText:match("%S") then
                    table.insert(blocks, {type = "text", content = beforeText})
                end
            end
            
            -- 提取语言标识
            local afterStart = text:sub(codeStart + 3)
            local langEnd = afterStart:find("\n") or 1
            local lang = afterStart:sub(1, langEnd - 1):match("^%s*(%w*)%s*$") or ""
            
            -- 提取代码内容
            local codeContentStart = codeStart + 3 + langEnd
            local codeEnd = text:find("```", codeContentStart)
            
            if codeEnd then
                local code = text:sub(codeContentStart, codeEnd - 1)
                table.insert(blocks, {type = "code", language = lang, content = code})
                pos = codeEnd + 3
            else
                table.insert(blocks, {type = "text", content = text:sub(pos)})
                break
            end
        else
            -- 剩余文本
            local remaining = text:sub(pos)
            if remaining:match("%S") then
                table.insert(blocks, {type = "text", content = remaining})
            end
            break
        end
    end
    
    if #blocks == 0 then
        return {{type = "text", content = text}}
    end
    
    return blocks
end

-- 剪贴板（兼容多执行器）
local function setClipboard(text)
    if setclipboard then
        setclipboard(text)
        return true
    elseif syn and syn.write_clipboard then
        syn.write_clipboard(text)
        return true
    elseif toclipboard then
        toclipboard(text)
        return true
    end
    return false
end

UI.messageCallbacks = {}

function UI:onExecute(callback)
    self.messageCallbacks.onExecute = callback
end

function UI:onSave(callback)
    self.messageCallbacks.onSave = callback
end

-- 添加消息气泡（支持Markdown）
function UI:addMessage(text, isUser)
    local blocks = parseMarkdown(text)
    
    local msgFrame = Instance.new("Frame", self.messageArea)
    msgFrame.Size = UDim2.new(1, -12, 0, 0)
    msgFrame.Position = UDim2.new(0, 6, 0, 0)
    msgFrame.BackgroundColor3 = isUser and self.Theme.accent or self.Theme.backgroundSecondary
    msgFrame.BorderSizePixel = 0
    createCorner(msgFrame, 6)
    
    -- 内容容器
    local container = Instance.new("Frame", msgFrame)
    container.Name = "Container"
    container.Size = UDim2.new(1, -12, 0, 0)
    container.Position = UDim2.new(0, 6, 0, 6)
    container.BackgroundTransparency = 1
    container.AutomaticSize = Enum.AutomaticSize.Y
    
    local listLayout = Instance.new("UIListLayout", container)
    listLayout.Padding = UDim.new(0, 6)
    
    -- 存储所有代码块用于操作
    local codeBlocks = {}
    
    for _, block in ipairs(blocks) do
        if block.type == "text" and block.content:match("%S") then
            -- 文本块
            local textLabel = Instance.new("TextLabel", container)
            textLabel.Size = UDim2.new(1, 0, 0, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.Text = block.content
            textLabel.TextColor3 = isUser and Color3.new(1, 1, 1) or self.Theme.text
            textLabel.TextSize = 13
            textLabel.Font = Enum.Font.Gotham
            textLabel.TextWrapped = true
            textLabel.TextXAlignment = Enum.TextXAlignment.Left
            textLabel.AutomaticSize = Enum.AutomaticSize.Y
        elseif block.type == "code" then
            -- 代码块
            local codeFrame = Instance.new("Frame", container)
            codeFrame.Size = UDim2.new(1, 0, 0, 0)
            codeFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            codeFrame.BorderSizePixel = 0
            codeFrame.AutomaticSize = Enum.AutomaticSize.Y
            createCorner(codeFrame, 6)
            
            -- 代码头部（语言标签 + 按钮）
            local codeHeader = Instance.new("Frame", codeFrame)
            codeHeader.Name = "Header"
            codeHeader.Size = UDim2.new(1, 0, 0, 28)
            codeHeader.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            codeHeader.BorderSizePixel = 0
            createCorner(codeHeader, 6)
            
            -- 语言标签
            local langLabel = Instance.new("TextLabel", codeHeader)
            langLabel.Size = UDim2.new(0, 60, 1, 0)
            langLabel.Position = UDim2.new(0, 8, 0, 0)
            langLabel.BackgroundTransparency = 1
            langLabel.Text = block.language:upper()
            langLabel.TextColor3 = self.Theme.accent
            langLabel.TextSize = 11
            langLabel.Font = Enum.Font.GothamBold
            langLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            -- 按钮容器
            local btnContainer = Instance.new("Frame", codeHeader)
            btnContainer.Size = UDim2.new(0, 180, 1, 0)
            btnContainer.Position = UDim2.new(1, -185, 0, 0)
            btnContainer.BackgroundTransparency = 1
            
            -- 复制按钮
            local copyBtn = Instance.new("TextButton", btnContainer)
            copyBtn.Name = "CopyBtn"
            copyBtn.Size = UDim2.new(0, 55, 0, 22)
            copyBtn.Position = UDim2.new(0, 0, 0.5, -11)
            copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            copyBtn.BorderSizePixel = 0
            copyBtn.Text = "复制"
            copyBtn.TextColor3 = self.Theme.text
            copyBtn.TextSize = 11
            copyBtn.Font = Enum.Font.Gotham
            createCorner(copyBtn, 4)
            
            -- 执行按钮
            local execBtn = Instance.new("TextButton", btnContainer)
            execBtn.Name = "ExecBtn"
            execBtn.Size = UDim2.new(0, 55, 0, 22)
            execBtn.Position = UDim2.new(0, 60, 0.5, -11)
            execBtn.BackgroundColor3 = self.Theme.success
            execBtn.BorderSizePixel = 0
            execBtn.Text = "执行"
            execBtn.TextColor3 = Color3.new(1, 1, 1)
            execBtn.TextSize = 11
            execBtn.Font = Enum.Font.GothamBold
            createCorner(execBtn, 4)
            
            -- 保存按钮
            local saveBtn = Instance.new("TextButton", btnContainer)
            saveBtn.Name = "SaveBtn"
            saveBtn.Size = UDim2.new(0, 55, 0, 22)
            saveBtn.Position = UDim2.new(0, 120, 0.5, -11)
            saveBtn.BackgroundColor3 = self.Theme.accent
            saveBtn.BorderSizePixel = 0
            saveBtn.Text = "保存"
            saveBtn.TextColor3 = Color3.new(1, 1, 1)
            saveBtn.TextSize = 11
            saveBtn.Font = Enum.Font.GothamBold
            createCorner(saveBtn, 4)
            
            -- 代码内容
            local codeContent = Instance.new("TextLabel", codeFrame)
            codeContent.Name = "Code"
            codeContent.Size = UDim2.new(1, -16, 0, 0)
            codeContent.Position = UDim2.new(0, 8, 0, 30)
            codeContent.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            codeContent.BorderSizePixel = 0
            codeContent.Text = block.content
            codeContent.TextColor3 = Color3.fromRGB(200, 200, 200)
            codeContent.TextSize = 12
            codeContent.Font = Enum.Font.Code
            codeContent.TextXAlignment = Enum.TextXAlignment.Left
            codeContent.TextYAlignment = Enum.TextYAlignment.Top
            codeContent.TextWrapped = true
            codeContent.AutomaticSize = Enum.AutomaticSize.Y
            createCorner(codeContent, 4)
            
            -- 存储代码
            table.insert(codeBlocks, {
                frame = codeFrame,
                code = block.content,
                copyBtn = copyBtn,
                execBtn = execBtn,
                saveBtn = saveBtn
            })
            
            -- 按钮事件
            copyBtn.MouseButton1Click:Connect(function()
                if setClipboard(block.content) then
                    copyBtn.Text = "已复制!"
                    task.delay(1, function()
                        copyBtn.Text = "复制"
                    end)
                else
                    copyBtn.Text = "失败"
                    task.delay(1, function()
                        copyBtn.Text = "复制"
                    end)
                end
            end)
            
            execBtn.MouseButton1Click:Connect(function()
                if self.messageCallbacks.onExecute then
                    self.messageCallbacks.onExecute(block.content, codeFrame)
                end
            end)
            
            saveBtn.MouseButton1Click:Connect(function()
                if self.messageCallbacks.onSave then
                    self.messageCallbacks.onSave(block.content, codeFrame)
                end
            end)
        end
    end
    
    msgFrame.AutomaticSize = Enum.AutomaticSize.Y
    
    -- 自动滚动到底部
    task.wait()
    self.messageArea.CanvasSize = UDim2.new(0, 0, 0, self.messageArea.UIListLayout.AbsoluteContentSize.Y)
    self.messageArea.CanvasPosition = Vector2.new(0, self.messageArea.UIListLayout.AbsoluteContentSize.Y)
    
    return msgFrame, codeBlocks
end

-- 创建设置界面
function UI:createSettingsView()
    local settingsFrame = Instance.new("Frame", self.mainContent)
    settingsFrame.Name = "SettingsView"
    settingsFrame.Size = UDim2.new(1, 0, 1, 0)
    settingsFrame.BackgroundTransparency = 1
    
    -- 创建滚动容器
    local scrollFrame = Instance.new("ScrollingFrame", settingsFrame)
    scrollFrame.Name = "SettingsScroll"
    scrollFrame.Size = UDim2.new(1, -8, 1, 0)
    scrollFrame.Position = UDim2.new(0, 4, 0, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = self.Theme.accent
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 500)
    
    local layout = Instance.new("UIListLayout", scrollFrame)
    layout.Padding = UDim.new(0, 8)
    
    -- ========== 执行器信息 ==========
    local executorSection = Instance.new("TextLabel", scrollFrame)
    executorSection.Size = UDim2.new(1, -8, 0, 20)
    executorSection.BackgroundTransparency = 1
    executorSection.Text = "── 执行器信息 ──"
    executorSection.TextColor3 = self.Theme.textSecondary
    executorSection.TextSize = 12
    executorSection.Font = Enum.Font.GothamBold
    
    local executorInfo = Instance.new("Frame", scrollFrame)
    executorInfo.Size = UDim2.new(1, -8, 0, 50)
    executorInfo.BackgroundColor3 = self.Theme.backgroundTertiary
    executorInfo.BorderSizePixel = 0
    createCorner(executorInfo, 6)
    
    local executorLabel = Instance.new("TextLabel", executorInfo)
    executorLabel.Size = UDim2.new(1, -12, 1, 0)
    executorLabel.Position = UDim2.new(0, 6, 0, 0)
    executorLabel.BackgroundTransparency = 1
    executorLabel.Text = "检测中..."
    executorLabel.TextColor3 = self.Theme.text
    executorLabel.TextSize = 12
    executorLabel.Font = Enum.Font.Gotham
    executorLabel.TextXAlignment = Enum.TextXAlignment.Left
    executorLabel.TextYAlignment = Enum.TextYAlignment.Top
    executorLabel.TextWrapped = true
    
    -- ========== API 配置 ==========
    local apiSection = Instance.new("TextLabel", scrollFrame)
    apiSection.Size = UDim2.new(1, -8, 0, 20)
    apiSection.BackgroundTransparency = 1
    apiSection.Text = "── API 配置 ──"
    apiSection.TextColor3 = self.Theme.textSecondary
    apiSection.TextSize = 12
    apiSection.Font = Enum.Font.GothamBold
    
    -- API Key
    local apiLabel = Instance.new("TextLabel", scrollFrame)
    apiLabel.Size = UDim2.new(1, -8, 0, 16)
    apiLabel.BackgroundTransparency = 1
    apiLabel.Text = "API Key"
    apiLabel.TextColor3 = self.Theme.text
    apiLabel.TextSize = 12
    apiLabel.Font = Enum.Font.GothamBold
    apiLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local apiInput = Instance.new("TextBox", scrollFrame)
    apiInput.Name = "ApiKeyInput"
    apiInput.Size = UDim2.new(1, -8, 0, 28)
    apiInput.BackgroundColor3 = self.Theme.backgroundTertiary
    apiInput.BorderSizePixel = 0
    apiInput.PlaceholderText = "输入你的API Key..."
    apiInput.PlaceholderColor3 = self.Theme.textMuted
    apiInput.Text = ""
    apiInput.TextColor3 = self.Theme.text
    apiInput.TextSize = 12
    apiInput.Font = Enum.Font.Gotham
    apiInput.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(apiInput, 6)
    
    -- Provider
    local providerLabel = Instance.new("TextLabel", scrollFrame)
    providerLabel.Size = UDim2.new(1, -8, 0, 16)
    providerLabel.BackgroundTransparency = 1
    providerLabel.Text = "AI Provider"
    providerLabel.TextColor3 = self.Theme.text
    providerLabel.TextSize = 12
    providerLabel.Font = Enum.Font.GothamBold
    providerLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local providerFrame = Instance.new("Frame", scrollFrame)
    providerFrame.Size = UDim2.new(1, -8, 0, 32)
    providerFrame.BackgroundColor3 = self.Theme.backgroundTertiary
    providerFrame.BorderSizePixel = 0
    createCorner(providerFrame, 6)
    
    local deepseekBtn = Instance.new("TextButton", providerFrame)
    deepseekBtn.Name = "DeepSeek"
    deepseekBtn.Size = UDim2.new(0.5, -4, 1, -8)
    deepseekBtn.Position = UDim2.new(0, 4, 0, 4)
    deepseekBtn.BackgroundColor3 = self.Theme.accent
    deepseekBtn.BorderSizePixel = 0
    deepseekBtn.Text = "DeepSeek"
    deepseekBtn.TextColor3 = Color3.new(1, 1, 1)
    deepseekBtn.TextSize = 11
    deepseekBtn.Font = Enum.Font.GothamBold
    createCorner(deepseekBtn, 4)
    
    local openaiBtn = Instance.new("TextButton", providerFrame)
    openaiBtn.Name = "OpenAI"
    openaiBtn.Size = UDim2.new(0.5, -4, 1, -8)
    openaiBtn.Position = UDim2.new(0.5, 0, 0, 4)
    openaiBtn.BackgroundColor3 = self.Theme.backgroundSecondary
    openaiBtn.BorderSizePixel = 0
    openaiBtn.Text = "OpenAI"
    openaiBtn.TextColor3 = self.Theme.text
    openaiBtn.TextSize = 11
    openaiBtn.Font = Enum.Font.Gotham
    createCorner(openaiBtn, 4)
    
    -- ========== 脚本设置 ==========
    local scriptSection = Instance.new("TextLabel", scrollFrame)
    scriptSection.Size = UDim2.new(1, -8, 0, 20)
    scriptSection.BackgroundTransparency = 1
    scriptSection.Text = "── 脚本设置 ──"
    scriptSection.TextColor3 = self.Theme.textSecondary
    scriptSection.TextSize = 12
    scriptSection.Font = Enum.Font.GothamBold
    
    -- 脚本保存目录
    local dirLabel = Instance.new("TextLabel", scrollFrame)
    dirLabel.Size = UDim2.new(1, -8, 0, 16)
    dirLabel.BackgroundTransparency = 1
    dirLabel.Text = "脚本保存目录 (留空使用默认)"
    dirLabel.TextColor3 = self.Theme.text
    dirLabel.TextSize = 12
    dirLabel.Font = Enum.Font.GothamBold
    dirLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local dirInput = Instance.new("TextBox", scrollFrame)
    dirInput.Name = "ScriptDirInput"
    dirInput.Size = UDim2.new(1, -8, 0, 28)
    dirInput.BackgroundColor3 = self.Theme.backgroundTertiary
    dirInput.BorderSizePixel = 0
    dirInput.PlaceholderText = "例如: workspace 或自定义路径"
    dirInput.PlaceholderColor3 = self.Theme.textMuted
    dirInput.Text = ""
    dirInput.TextColor3 = self.Theme.text
    dirInput.TextSize = 12
    dirInput.Font = Enum.Font.Gotham
    dirInput.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(dirInput, 6)
    
    -- 选项：执行前确认
    local confirmBtn = Instance.new("TextButton", scrollFrame)
    confirmBtn.Name = "ConfirmToggle"
    confirmBtn.Size = UDim2.new(1, -8, 0, 28)
    confirmBtn.BackgroundColor3 = self.Theme.backgroundTertiary
    confirmBtn.BorderSizePixel = 0
    confirmBtn.Text = "  执行前确认: 开启"
    confirmBtn.TextColor3 = self.Theme.text
    confirmBtn.TextSize = 12
    confirmBtn.Font = Enum.Font.Gotham
    confirmBtn.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(confirmBtn, 6)
    
    -- ========== 历史记录 ==========
    local historySection = Instance.new("TextLabel", scrollFrame)
    historySection.Size = UDim2.new(1, -8, 0, 20)
    historySection.BackgroundTransparency = 1
    historySection.Text = "── 历史记录 ──"
    historySection.TextColor3 = self.Theme.textSecondary
    historySection.TextSize = 12
    historySection.Font = Enum.Font.GothamBold
    
    -- 历史记录按钮容器
    local historyBtns = Instance.new("Frame", scrollFrame)
    historyBtns.Size = UDim2.new(1, -8, 0, 28)
    historyBtns.BackgroundTransparency = 1
    
    local clearHistoryBtn = Instance.new("TextButton", historyBtns)
    clearHistoryBtn.Name = "ClearHistory"
    clearHistoryBtn.Size = UDim2.new(0.5, -2, 1, 0)
    clearHistoryBtn.BackgroundColor3 = self.Theme.warning
    clearHistoryBtn.BorderSizePixel = 0
    clearHistoryBtn.Text = "清除历史"
    clearHistoryBtn.TextColor3 = Color3.new(0, 0, 0)
    clearHistoryBtn.TextSize = 12
    clearHistoryBtn.Font = Enum.Font.GothamBold
    createCorner(clearHistoryBtn, 4)
    
    local exportHistoryBtn = Instance.new("TextButton", historyBtns)
    exportHistoryBtn.Name = "ExportHistory"
    exportHistoryBtn.Size = UDim2.new(0.5, -2, 1, 0)
    exportHistoryBtn.Position = UDim2.new(0.5, 2, 0, 0)
    exportHistoryBtn.BackgroundColor3 = self.Theme.accent
    exportHistoryBtn.BorderSizePixel = 0
    exportHistoryBtn.Text = "导出历史"
    exportHistoryBtn.TextColor3 = Color3.new(1, 1, 1)
    exportHistoryBtn.TextSize = 12
    exportHistoryBtn.Font = Enum.Font.GothamBold
    createCorner(exportHistoryBtn, 4)
    
    -- ========== 操作按钮 ==========
    local actionSection = Instance.new("TextLabel", scrollFrame)
    actionSection.Size = UDim2.new(1, -8, 0, 20)
    actionSection.BackgroundTransparency = 1
    actionSection.Text = "── 操作 ──"
    actionSection.TextColor3 = self.Theme.textSecondary
    actionSection.TextSize = 12
    actionSection.Font = Enum.Font.GothamBold
    
    local actionBtns = Instance.new("Frame", scrollFrame)
    actionBtns.Size = UDim2.new(1, -8, 0, 32)
    actionBtns.BackgroundTransparency = 1
    
    local saveBtn = Instance.new("TextButton", actionBtns)
    saveBtn.Name = "SaveButton"
    saveBtn.Size = UDim2.new(0.5, -2, 1, 0)
    saveBtn.BackgroundColor3 = self.Theme.success
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "保存设置"
    saveBtn.TextColor3 = Color3.new(1, 1, 1)
    saveBtn.TextSize = 12
    saveBtn.Font = Enum.Font.GothamBold
    createCorner(saveBtn, 4)
    
    local testBtn = Instance.new("TextButton", actionBtns)
    testBtn.Name = "TestButton"
    testBtn.Size = UDim2.new(0.5, -2, 1, 0)
    testBtn.Position = UDim2.new(0.5, 2, 0, 0)
    testBtn.BackgroundColor3 = self.Theme.accent
    testBtn.BorderSizePixel = 0
    testBtn.Text = "测试连接"
    testBtn.TextColor3 = Color3.new(1, 1, 1)
    testBtn.TextSize = 12
    testBtn.Font = Enum.Font.GothamBold
    createCorner(testBtn, 4)
    
    -- 保存引用
    self.settingsView = settingsFrame
    self.settingsScroll = scrollFrame
    self.executorLabel = executorLabel
    self.apiKeyInput = apiInput
    self.scriptDirInput = dirInput
    self.confirmToggle = confirmBtn
    self.providerButtons = {
        deepseek = deepseekBtn,
        openai = openaiBtn
    }
    self.saveSettingsBtn = saveBtn
    self.testConnectionBtn = testBtn
    self.clearHistoryBtn = clearHistoryBtn
    self.exportHistoryBtn = exportHistoryBtn
    
    return settingsFrame
end

-- 更新执行器信息显示
function UI:updateExecutorInfo(info)
    if self.executorLabel then
        local text = string.format(
            "执行器: %s\n支持写入: %s | 支持执行: %s",
            info.name or "Unknown",
            info.canWrite and "是" or "否",
            info.canExecute and "是" or "否"
        )
        self.executorLabel.Text = text
    end
end

-- 更新确认开关状态
function UI:updateConfirmToggle(enabled)
    if self.confirmToggle then
        self.confirmToggle.Text = "  执行前确认: " .. (enabled and "开启" or "关闭")
        self.confirmToggle:SetAttribute("confirmEnabled", enabled)
    end
end

-- 资源浏览器
function UI:createResourceView()
    local resourceFrame = Instance.new("Frame", self.mainContent)
    resourceFrame.Name = "ResourceView"
    resourceFrame.Size = UDim2.new(1, 0, 1, 0)
    resourceFrame.BackgroundTransparency = 1
    
    local toolbar = Instance.new("Frame", resourceFrame)
    toolbar.Name = "Toolbar"
    toolbar.Size = UDim2.new(1, -16, 0, 32)
    toolbar.Position = UDim2.new(0, 8, 0, 8)
    toolbar.BackgroundTransparency = 1
    
    local searchBox = Instance.new("TextBox", toolbar)
    searchBox.Name = "SearchBox"
    searchBox.Size = UDim2.new(1, -180, 1, 0)
    searchBox.BackgroundColor3 = self.Theme.backgroundTertiary
    searchBox.BorderSizePixel = 0
    searchBox.PlaceholderText = "搜索资源..."
    searchBox.PlaceholderColor3 = self.Theme.textMuted
    searchBox.Text = ""
    searchBox.TextColor3 = self.Theme.text
    searchBox.TextSize = 12
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(searchBox, 6)
    
    local filterBtns = Instance.new("Frame", toolbar)
    filterBtns.Size = UDim2.new(0, 90, 1, 0)
    filterBtns.Position = UDim2.new(1, -90, 0, 0)
    filterBtns.BackgroundTransparency = 1
    
    local scanBtn = Instance.new("TextButton", toolbar)
    scanBtn.Name = "ScanButton"
    scanBtn.Size = UDim2.new(0, 60, 1, 0)
    scanBtn.Position = UDim2.new(1, -160, 0, 0)
    scanBtn.BackgroundColor3 = self.Theme.accent
    scanBtn.BorderSizePixel = 0
    scanBtn.Text = "扫描"
    scanBtn.TextColor3 = Color3.new(1, 1, 1)
    scanBtn.TextSize = 12
    scanBtn.Font = Enum.Font.GothamBold
    createCorner(scanBtn, 6)
    
    -- 资源列表
    local resourceList = Instance.new("ScrollingFrame", resourceFrame)
    resourceList.Name = "ResourceList"
    resourceList.Size = UDim2.new(1, -16, 1, -48)
    resourceList.Position = UDim2.new(0, 8, 0, 44)
    resourceList.BackgroundColor3 = self.Theme.backgroundTertiary
    resourceList.BorderSizePixel = 0
    resourceList.ScrollBarThickness = 5
    resourceList.ScrollBarImageColor3 = self.Theme.accent
    resourceList.CanvasSize = UDim2.new(0, 0, 0, 0)
    resourceList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    createCorner(resourceList, 8)
    
    local listLayout = Instance.new("UIListLayout", resourceList)
    listLayout.Padding = UDim.new(0, 2)
    
    -- 资源分类数据
    self.resourceCategories = {
        remotes = {},
        scripts = {},
        others = {}
    }
    
    self.resourceView = resourceFrame
    self.resourceSearchBox = searchBox
    self.resourceList = resourceList
    self.scanBtn = scanBtn
    
    return resourceFrame
end

-- 添加分类标题
function UI:addCategoryHeader(title, count)
    local header = Instance.new("TextLabel", self.resourceList)
    header.Size = UDim2.new(1, -8, 0, 24)
    header.BackgroundColor3 = self.Theme.backgroundSecondary
    header.BorderSizePixel = 0
    header.Text = "  " .. title .. " (" .. count .. ")"
    header.TextColor3 = self.Theme.accent
    header.TextSize = 11
    header.Font = Enum.Font.GothamBold
    header.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(header, 4)
    return header
end

-- 资源操作弹窗
function UI:showResourceDialog(resource, callbacks)
    local overlay = Instance.new("Frame", self.screenGui)
    overlay.Name = "ResourceDialogOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.ZIndex = 200
    
    local dialog = Instance.new("Frame", overlay)
    dialog.Name = "Dialog"
    dialog.Size = UDim2.new(0, 300, 0, 200)
    dialog.Position = UDim2.new(0.5, -150, 0.5, -100)
    dialog.BackgroundColor3 = self.Theme.background
    dialog.BorderSizePixel = 0
    dialog.ZIndex = 201
    createCorner(dialog, 12)
    
    local stroke = Instance.new("UIStroke", dialog)
    stroke.Color = self.Theme.border
    stroke.Thickness = 1
    
    local title = Instance.new("TextLabel", dialog)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = resource.name
    title.TextColor3 = self.Theme.text
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    
    local info = Instance.new("TextLabel", dialog)
    info.Size = UDim2.new(1, -20, 0, 20)
    info.Position = UDim2.new(0, 10, 0, 40)
    info.BackgroundTransparency = 1
    info.Text = "类型: " .. resource.className .. " | 路径: " .. resource.path
    info.TextColor3 = self.Theme.textSecondary
    info.TextSize = 11
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextTruncate = Enum.TextTruncate.AtEnd
    
    local btnContainer = Instance.new("Frame", dialog)
    btnContainer.Size = UDim2.new(1, -20, 0, 100)
    btnContainer.Position = UDim2.new(0, 10, 0, 70)
    btnContainer.BackgroundTransparency = 1
    
    local btnY = 0
    local function addBtn(text, callback, color)
        local btn = Instance.new("TextButton", btnContainer)
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.Position = UDim2.new(0, 0, 0, btnY)
        btn.BackgroundColor3 = color or self.Theme.accent
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        createCorner(btn, 6)
        
        btn.MouseButton1Click:Connect(function()
            overlay:Destroy()
            if callback then callback() end
        end)
        
        btnY = btnY + 32
    end
    
    -- 根据类型显示不同操作
    addBtn("📝 让AI分析此资源", callbacks.analyze, self.Theme.accent)
    
    if resource.className:find("Remote") then
        addBtn("🔧 生成调用代码", callbacks.generateCode, self.Theme.success)
    end
    
    if resource.className:find("Script") then
        addBtn("📄 查看源码", callbacks.viewSource, Color3.fromRGB(100, 100, 200))
    end
    
    local closeBtn = Instance.new("TextButton", dialog)
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -30, 0, 8)
    closeBtn.BackgroundColor3 = self.Theme.error
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 202
    createCorner(closeBtn, 4)
    
    closeBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    -- 点击背景关闭
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            overlay:Destroy()
        end
    end)
    
    return dialog
end

-- 资源列表项
function UI:addResourceItem(name, className, path, onClick)
    local typeColor = self.Theme.textSecondary
    if className:find("Remote") then
        typeColor = Color3.fromRGB(255, 180, 100)
    elseif className:find("Script") then
        typeColor = Color3.fromRGB(100, 200, 255)
    end
    
    local item = Instance.new("TextButton", self.resourceList)
    item.Size = UDim2.new(1, -8, 0, 26)
    item.BackgroundColor3 = self.Theme.backgroundSecondary
    item.BorderSizePixel = 0
    item.Text = ""
    createCorner(item, 4)
    
    -- 类型图标
    local icon = "📄"
    if className:find("RemoteEvent") then
        icon = "📤"
    elseif className:find("RemoteFunction") then
        icon = "📥"
    elseif className:find("LocalScript") then
        icon = "📜"
    elseif className:find("ModuleScript") then
        icon = "📦"
    elseif className:find("Script") then
        icon = "📝"
    end
    
    local nameText = Instance.new("TextLabel", item)
    nameText.Size = UDim2.new(0.5, 0, 1, 0)
    nameText.Position = UDim2.new(0, 8, 0, 0)
    nameText.BackgroundTransparency = 1
    nameText.Text = icon .. " " .. name
    nameText.TextColor3 = self.Theme.text
    nameText.TextSize = 12
    nameText.Font = Enum.Font.GothamSemibold
    nameText.TextXAlignment = Enum.TextXAlignment.Left
    nameText.TextTruncate = Enum.TextTruncate.AtEnd
    
    local classText = Instance.new("TextLabel", item)
    classText.Size = UDim2.new(0.4, 0, 1, 0)
    classText.Position = UDim2.new(0.55, 0, 0, 0)
    classText.BackgroundTransparency = 1
    classText.Text = className
    classText.TextColor3 = typeColor
    classText.TextSize = 10
    classText.Font = Enum.Font.Gotham
    classText.TextXAlignment = Enum.TextXAlignment.Left
    classText.TextTruncate = Enum.TextTruncate.AtEnd
    
    item.MouseButton1Click:Connect(onClick)
    
    item.MouseEnter:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.15), {BackgroundColor3 = self.Theme.accent}):Play()
    end)
    
    item.MouseLeave:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.15), {BackgroundColor3 = self.Theme.backgroundSecondary}):Play()
    end)
    
    return item
end

-- 设置拖动功能
function UI:setupDrag(dragFrame, moveFrame)
    local dragging = false
    local dragInput, dragStart, startPos
    
    dragFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = moveFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    dragFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            moveFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- 更新状态指示器
function UI:updateStatus(status, color)
    self.statusText.Text = status
    self.statusIndicator.BackgroundColor3 = color or self.Theme.warning
end

-- 显示视图
function UI:showView(viewName)
    if self.chatView then self.chatView.Visible = false end
    if self.settingsView then self.settingsView.Visible = false end
    if self.resourceView then self.resourceView.Visible = false end
    
    if viewName == "chat" and self.chatView then
        self.chatView.Visible = true
    elseif viewName == "settings" and self.settingsView then
        self.settingsView.Visible = true
    elseif viewName == "resources" and self.resourceView then
        self.resourceView.Visible = true
    end
end

-- 清空消息
function UI:clearMessages()
    for _, child in ipairs(self.messageArea:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

-- 清空资源列表
function UI:clearResourceList()
    for _, child in ipairs(self.resourceList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

-- 销毁UI
function UI:destroy()
    if self.screenGui then
        self.screenGui:Destroy()
    end
end

return UI