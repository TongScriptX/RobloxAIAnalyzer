-- UI模块 - Roblox AI Resource Analyzer
local UI = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- 加载状态
UI.isLoading = false
UI.loadingConnection = nil
UI.loadingDots = 0

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
    titleText.Size = UDim2.new(1, -200, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "AI Resource Analyzer"
    titleText.TextColor3 = self.Theme.text
    titleText.TextSize = 16
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.TextScaled = true
    
    -- Token显示区域
    local tokenDisplay = Instance.new("Frame", titleBar)
    tokenDisplay.Name = "TokenDisplay"
    tokenDisplay.Size = UDim2.new(0, 80, 0, 22)
    tokenDisplay.Position = UDim2.new(1, -175, 0.5, -11)
    tokenDisplay.BackgroundColor3 = self.Theme.backgroundTertiary
    tokenDisplay.BorderSizePixel = 0
    createCorner(tokenDisplay, 4)
    
    local tokenIcon = Instance.new("TextLabel", tokenDisplay)
    tokenIcon.Size = UDim2.new(0, 20, 1, 0)
    tokenIcon.BackgroundTransparency = 1
    tokenIcon.Text = "⚡"
    tokenIcon.TextSize = 12
    tokenIcon.Font = Enum.Font.Gotham
    
    local tokenText = Instance.new("TextLabel", tokenDisplay)
    tokenText.Name = "TokenText"
    tokenText.Size = UDim2.new(1, -22, 1, 0)
    tokenText.Position = UDim2.new(0, 20, 0, 0)
    tokenText.BackgroundTransparency = 1
    tokenText.Text = "0 tokens"
    tokenText.TextColor3 = self.Theme.textSecondary
    tokenText.TextSize = 10
    tokenText.Font = Enum.Font.Gotham
    tokenText.TextXAlignment = Enum.TextXAlignment.Left
    
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
    self.tokenDisplay = tokenDisplay
    self.tokenText = tokenText
    self.sidebar = sidebar
    self.mainContent = mainContent
    self.contentFrame = contentFrame
    self.floatBtn = floatBtn
    
    -- Token统计
    self.tokenStats = {
        total = 0,
        prompt = 0,
        completion = 0,
        requests = 0,
        cacheHit = 0  -- 缓存命中token数
    }
    
    -- 设置拖动
    self:setupDrag(titleBar, mainFrame)
    self:setupFloatDrag(floatBtn)
    
    -- 保存引用
    self.screenGui = screenGui
    self.floatBtn = floatBtn
    self.mainFrame = mainFrame
    
    -- 设置关闭/最小化
    closeBtn.MouseButton1Click:Connect(function()
        if self.screenGui then
            self.screenGui:Destroy()
            self.screenGui = nil
            self.floatBtn = nil
            self.mainFrame = nil
        end
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

-- 侧边栏按钮
function UI:createSidebarButton(name, icon, callback)
    local btnCount = 0
    for _, child in pairs(self.sidebar:GetChildren()) do
        if child:IsA("TextButton") and not child.Name:find("Session") then
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

-- 创建session列表区域（已禁用）
function UI:createSessionList()
    -- 不再显示 session 列表
end

-- 刷新session列表（已禁用）
function UI:refreshSessionList(sessions, onSwitch, onDelete, currentId)
    -- 不再需要
end

-- 添加session项（已禁用）
function UI:addSessionItem(session, onClick, onDelete)
    -- 不再需要
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

-- 显示加载动画
function UI:showLoading()
    if self.isLoading then return end
    self.isLoading = true
    self.loadingDots = 0
    self.lastDotTime = 0
    
    -- 禁用输入
    self.inputBox.PlaceholderText = ""
    self.sendBtn.Text = "..."
    self.sendBtn.BackgroundColor3 = self.Theme.textMuted
    
    -- 启动动画（每0.4秒更新一次）
    if self.loadingConnection then
        self.loadingConnection:Disconnect()
    end
    
    self.loadingConnection = RunService.Heartbeat:Connect(function()
        if not self.isLoading then return end
        
        local now = os.clock()
        if now - self.lastDotTime < 0.4 then return end
        self.lastDotTime = now
        
        self.loadingDots = (self.loadingDots + 1) % 4
        local dots = string.rep("●", self.loadingDots + 1) .. string.rep("○", 3 - self.loadingDots)
        self.inputBox.PlaceholderText = "思考中 " .. dots
    end)
end

-- 隐藏加载动画
function UI:hideLoading()
    self.isLoading = false
    
    -- 停止动画
    if self.loadingConnection then
        self.loadingConnection:Disconnect()
        self.loadingConnection = nil
    end
    
    -- 恢复输入
    self.inputBox.PlaceholderText = "输入问题或指令..."
    self.sendBtn.Text = ">"
    self.sendBtn.BackgroundColor3 = self.Theme.accent
end

-- 更新状态显示（用于工具执行时）
function UI:updateStatus(statusText)
    if not self.isLoading then return end
    self.currentStatus = statusText or ""
    -- 直接更新占位符文字
    self.inputBox.PlaceholderText = statusText
end

-- 显示脚本确认提示
function UI:showConfirmationPrompt(description, codePreview)
    self.isConfirming = true
    
    -- 修改输入框显示确认提示
    self.inputBox.PlaceholderText = "⚠️ 确认执行: " .. description
    self.inputBox.Text = ""
    
    -- 添加确认消息
    self:addMessage(string.format([[
⚠️ **需要确认脚本执行**

📝 描述: %s

📄 代码预览:
```lua
%s
```

请输入 '确认' 执行 或 '取消' 放弃]], 
        description, 
        codePreview:sub(1, 300) .. (#codePreview > 300 and "..." or "")
    ), false)
end

-- 隐藏确认提示
function UI:hideConfirmationPrompt()
    self.isConfirming = false
    self.inputBox.PlaceholderText = "输入问题或指令..."
    self.inputBox.Text = ""
end

-- Markdown解析（主要处理代码块）
local function parseMarkdown(text)
    -- 防止nil值
    if not text or type(text) ~= "string" then
        return {{type = "text", content = tostring(text or "")}}
    end
    
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

-- 创建可折叠的思考区域
function UI:createThinkingBlock(reasoning, parent)
    local isExpanded = false
    local maxPreviewLen = 150
    
    local thinkingFrame = Instance.new("Frame", parent)
    thinkingFrame.Size = UDim2.new(1, 0, 0, 0)
    thinkingFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    thinkingFrame.BorderSizePixel = 0
    thinkingFrame.AutomaticSize = Enum.AutomaticSize.Y
    createCorner(thinkingFrame, 6)
    
    local container = Instance.new("Frame", thinkingFrame)
    container.Size = UDim2.new(1, -8, 0, 0)
    container.Position = UDim2.new(0, 4, 0, 4)
    container.BackgroundTransparency = 1
    container.AutomaticSize = Enum.AutomaticSize.Y
    
    local listLayout = Instance.new("UIListLayout", container)
    listLayout.Padding = UDim.new(0, 4)
    
    -- 标题栏（可点击展开/收起）
    local header = Instance.new("TextButton", container)
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundTransparency = 1
    header.Text = ""
    
    local icon = Instance.new("TextLabel", header)
    icon.Size = UDim2.new(0, 20, 1, 0)
    icon.Position = UDim2.new(0, 0, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "💭"
    icon.TextSize = 14
    icon.Font = Enum.Font.Gotham
    
    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 22, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "思考过程"
    title.TextColor3 = self.Theme.textSecondary
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local arrow = Instance.new("TextLabel", header)
    arrow.Name = "Arrow"
    arrow.Size = UDim2.new(0, 16, 1, 0)
    arrow.Position = UDim2.new(1, -16, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▶"
    arrow.TextColor3 = self.Theme.textMuted
    arrow.TextSize = 10
    arrow.Font = Enum.Font.Gotham
    
    -- 内容区域（默认隐藏）
    local contentFrame = Instance.new("Frame", container)
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, 0, 0, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.AutomaticSize = Enum.AutomaticSize.Y
    contentFrame.Visible = false
    
    local contentLabel = Instance.new("TextLabel", contentFrame)
    contentLabel.Size = UDim2.new(1, 0, 0, 0)
    contentLabel.BackgroundTransparency = 1
    contentLabel.Text = reasoning
    contentLabel.TextColor3 = self.Theme.textSecondary
    contentLabel.TextSize = 12
    contentLabel.Font = Enum.Font.Gotham
    contentLabel.TextWrapped = true
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.AutomaticSize = Enum.AutomaticSize.Y
    
    -- 点击展开/收起
    header.MouseButton1Click:Connect(function()
        isExpanded = not isExpanded
        contentFrame.Visible = isExpanded
        arrow.Text = isExpanded and "▼" or "▶"
    end)
    
    return thinkingFrame
end

UI.messageCallbacks = {}

function UI:onExecute(callback)
    self.messageCallbacks.onExecute = callback
end

function UI:onSave(callback)
    self.messageCallbacks.onSave = callback
end

-- 添加消息气泡（支持Markdown和思考过程）
function UI:addMessage(text, isUser, reasoning)
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
    
    -- 如果有思考过程，先显示思考区域
    if reasoning and #reasoning > 0 then
        local thinkingFrame = self:createThinkingBlock(reasoning, container)
    end
    
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
    -- 从全局获取 Config
    local Config = _G.AIAnalyzer and _G.AIAnalyzer.Config
    
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
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
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
    
    -- 动态创建提供商按钮
    local providerBtns = {}
    local providerList = {}
    local currentProvider = Config and Config.Settings and Config.Settings.currentProvider or "DeepSeek"
    
    -- 从 Config 读取提供商列表
    if Config and Config.Providers then
        for key, provider in pairs(Config.Providers) do
            table.insert(providerList, {key = key, name = provider.name})
        end
        -- 排序保持一致
        table.sort(providerList, function(a, b) return a.key < b.key end)
    else
        providerList = {{key = "DeepSeek", name = "DeepSeek"}, {key = "OpenAI", name = "OpenAI"}}
    end
    
    local btnCount = #providerList
    local btnWidth = 1 / btnCount
    
    for i, prov in ipairs(providerList) do
        local btn = Instance.new("TextButton", providerFrame)
        btn.Name = prov.key
        btn.Size = UDim2.new(btnWidth, -4, 1, -8)
        btn.Position = UDim2.new((i - 1) * btnWidth, 4, 0, 4)
        btn.BackgroundColor3 = prov.key == currentProvider and self.Theme.accent or self.Theme.backgroundSecondary
        btn.BorderSizePixel = 0
        btn.Text = prov.name
        btn.TextColor3 = prov.key == currentProvider and Color3.new(1, 1, 1) or self.Theme.text
        btn.TextSize = 11
        btn.Font = prov.key == currentProvider and Enum.Font.GothamBold or Enum.Font.Gotham
        createCorner(btn, 4)
        providerBtns[prov.key] = btn
    end
    
    -- ========== 模型选择（仅部分提供商显示）==========
    local modelLabel = Instance.new("TextLabel", scrollFrame)
    modelLabel.Name = "ModelLabel"
    modelLabel.Size = UDim2.new(1, -8, 0, 16)
    modelLabel.BackgroundTransparency = 1
    modelLabel.Text = "模型选择"
    modelLabel.TextColor3 = self.Theme.text
    modelLabel.TextSize = 12
    modelLabel.Font = Enum.Font.GothamBold
    modelLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local modelFrame = Instance.new("Frame", scrollFrame)
    modelFrame.Name = "ModelFrame"
    modelFrame.Size = UDim2.new(1, -8, 0, 28)
    modelFrame.BackgroundColor3 = self.Theme.backgroundTertiary
    modelFrame.BorderSizePixel = 0
    createCorner(modelFrame, 6)
    
    local modelDropdown = Instance.new("TextButton", modelFrame)
    modelDropdown.Name = "ModelDropdown"
    modelDropdown.Size = UDim2.new(1, -8, 1, 0)
    modelDropdown.Position = UDim2.new(0, 4, 0, 0)
    modelDropdown.BackgroundTransparency = 1
    modelDropdown.Text = "选择模型..."
    modelDropdown.TextColor3 = self.Theme.text
    modelDropdown.TextSize = 12
    modelDropdown.Font = Enum.Font.Gotham
    modelDropdown.TextXAlignment = Enum.TextXAlignment.Left
    
    local modelDropdownArrow = Instance.new("TextLabel", modelFrame)
    modelDropdownArrow.Size = UDim2.new(0, 20, 1, 0)
    modelDropdownArrow.Position = UDim2.new(1, -24, 0, 0)
    modelDropdownArrow.BackgroundTransparency = 1
    modelDropdownArrow.Text = "▼"
    modelDropdownArrow.TextColor3 = self.Theme.textSecondary
    modelDropdownArrow.TextSize = 10
    modelDropdownArrow.Font = Enum.Font.Gotham
    
    -- 模型下拉列表容器（初始隐藏，使用 ScrollingFrame 支持滚动）
    local modelListFrame = Instance.new("ScrollingFrame", scrollFrame)
    modelListFrame.Name = "ModelListFrame"
    modelListFrame.Size = UDim2.new(1, -8, 0, 150)
    modelListFrame.BackgroundColor3 = self.Theme.backgroundTertiary
    modelListFrame.BorderSizePixel = 0
    modelListFrame.Visible = false
    modelListFrame.ScrollBarThickness = 4
    modelListFrame.ScrollBarImageColor3 = self.Theme.accent
    modelListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    modelListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    createCorner(modelListFrame, 6)
    
    local modelListLayout = Instance.new("UIListLayout", modelListFrame)
    modelListLayout.Padding = UDim.new(0, 2)
    
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
    
    -- ========== 运行模式选择 ==========
    local runModeLabel = Instance.new("TextLabel", scrollFrame)
    runModeLabel.Size = UDim2.new(1, -8, 0, 16)
    runModeLabel.BackgroundTransparency = 1
    runModeLabel.Text = "脚本运行模式"
    runModeLabel.TextColor3 = self.Theme.text
    runModeLabel.TextSize = 12
    runModeLabel.Font = Enum.Font.GothamBold
    runModeLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local runModeFrame = Instance.new("Frame", scrollFrame)
    runModeFrame.Name = "RunModeFrame"
    runModeFrame.Size = UDim2.new(1, -8, 0, 36)
    runModeFrame.BackgroundColor3 = self.Theme.backgroundTertiary
    runModeFrame.BorderSizePixel = 0
    createCorner(runModeFrame, 6)
    
    -- 获取当前运行模式
    local Tools = _G.AIAnalyzer and _G.AIAnalyzer.Tools
    local currentRunMode = "default"
    if Tools and Tools.getRunMode then
        currentRunMode = Tools:getRunMode()
    end
    local modeLabels = {
        smart = "智能",
        default = "默认", 
        yolo = "YOLO"
    }
    
    local modeBtns = {}
    local modes = {"smart", "default", "yolo"}
    local modeWidth = 1 / #modes
    
    for i, mode in ipairs(modes) do
        local modeBtn = Instance.new("TextButton", runModeFrame)
        modeBtn.Name = mode .. "ModeBtn"
        modeBtn.Size = UDim2.new(modeWidth, -4, 1, -8)
        modeBtn.Position = UDim2.new((i - 1) * modeWidth, 4, 0, 4)
        modeBtn.BackgroundColor3 = mode == currentRunMode and self.Theme.accent or self.Theme.backgroundSecondary
        modeBtn.BorderSizePixel = 0
        modeBtn.Text = modeLabels[mode]
        modeBtn.TextColor3 = mode == currentRunMode and Color3.new(1, 1, 1) or self.Theme.text
        modeBtn.TextSize = 11
        modeBtn.Font = mode == currentRunMode and Enum.Font.GothamBold or Enum.Font.Gotham
        createCorner(modeBtn, 4)
        modeBtns[mode] = modeBtn
    end
    
    -- 模式说明
    local modeDescLabel = Instance.new("TextLabel", scrollFrame)
    modeDescLabel.Name = "ModeDescLabel"
    modeDescLabel.Size = UDim2.new(1, -8, 0, 32)
    modeDescLabel.BackgroundTransparency = 1
    modeDescLabel.Text = "智能: 低风险自动执行 | 默认: 每次询问 | YOLO: 从不询问"
    modeDescLabel.TextColor3 = self.Theme.textSecondary
    modeDescLabel.TextSize = 10
    modeDescLabel.Font = Enum.Font.Gotham
    modeDescLabel.TextWrapped = true
    
    -- ========== Token 统计 ==========
    local tokenSection = Instance.new("TextLabel", scrollFrame)
    tokenSection.Size = UDim2.new(1, -8, 0, 20)
    tokenSection.BackgroundTransparency = 1
    tokenSection.Text = "── Token 统计 ──"
    tokenSection.TextColor3 = self.Theme.textSecondary
    tokenSection.TextSize = 12
    tokenSection.Font = Enum.Font.GothamBold
    
    local tokenInfo = Instance.new("Frame", scrollFrame)
    tokenInfo.Name = "TokenInfo"
    tokenInfo.Size = UDim2.new(1, -8, 0, 60)
    tokenInfo.BackgroundColor3 = self.Theme.backgroundTertiary
    tokenInfo.BorderSizePixel = 0
    createCorner(tokenInfo, 6)
    
    local tokenStatsLabel = Instance.new("TextLabel", tokenInfo)
    tokenStatsLabel.Name = "TokenStatsLabel"
    tokenStatsLabel.Size = UDim2.new(1, -12, 1, 0)
    tokenStatsLabel.Position = UDim2.new(0, 6, 0, 0)
    tokenStatsLabel.BackgroundTransparency = 1
    tokenStatsLabel.Text = "总消耗: 0 tokens\n请求次数: 0\n输入: 0 | 输出: 0"
    tokenStatsLabel.TextColor3 = self.Theme.text
    tokenStatsLabel.TextSize = 11
    tokenStatsLabel.Font = Enum.Font.Gotham
    tokenStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
    tokenStatsLabel.TextYAlignment = Enum.TextYAlignment.Top
    tokenStatsLabel.TextWrapped = true
    
    local resetTokenBtn = Instance.new("TextButton", scrollFrame)
    resetTokenBtn.Name = "ResetTokenBtn"
    resetTokenBtn.Size = UDim2.new(1, -8, 0, 24)
    resetTokenBtn.BackgroundColor3 = self.Theme.backgroundSecondary
    resetTokenBtn.BorderSizePixel = 0
    resetTokenBtn.Text = "重置统计"
    resetTokenBtn.TextColor3 = self.Theme.textSecondary
    resetTokenBtn.TextSize = 11
    resetTokenBtn.Font = Enum.Font.Gotham
    createCorner(resetTokenBtn, 4)
    
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
    self.providerButtons = providerBtns
    self.modelDropdown = modelDropdown
    self.modelListFrame = modelListFrame
    self.modelLabel = modelLabel
    self.saveSettingsBtn = saveBtn
    self.testConnectionBtn = testBtn
    self.tokenStatsLabel = tokenStatsLabel
    self.resetTokenBtn = resetTokenBtn
    self.runModeButtons = modeBtns  -- 运行模式按钮
    
    -- 初始化模型选择
    self:updateModelDropdown(currentProvider)
    
    return settingsFrame
end

-- 更新模型下拉框
function UI:updateModelDropdown(providerKey)
    local Config = _G.AIAnalyzer and _G.AIAnalyzer.Config
    if not Config then return end
    
    local provider = Config.Providers[providerKey]
    if not provider then return end
    
    -- 清空现有列表
    for _, child in ipairs(self.modelListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- 获取模型列表
    local models = provider.models or {}
    
    -- 如果没有模型列表或只有一个模型，隐藏模型选择
    if #models <= 1 then
        self.modelLabel.Visible = false
        self.modelDropdown.Parent.Visible = false
        self.modelListFrame.Visible = false
        if #models == 1 then
            self.modelDropdown.Text = models[1]
        end
        return
    end
    
    -- 显示模型选择
    self.modelLabel.Visible = true
    self.modelDropdown.Parent.Visible = true
    
    -- 设置当前选中的模型
    local currentModel = provider.defaultModel or models[1]
    self.modelDropdown.Text = currentModel
    
    -- 创建模型选项
    for i, modelName in ipairs(models) do
        local option = Instance.new("TextButton", self.modelListFrame)
        option.Name = "Model_" .. i
        option.Size = UDim2.new(1, -4, 0, 24)
        option.BackgroundColor3 = self.Theme.backgroundSecondary
        option.BorderSizePixel = 0
        option.Text = "  " .. modelName
        option.TextColor3 = modelName == currentModel and self.Theme.accent or self.Theme.text
        option.TextSize = 11
        option.Font = Enum.Font.Gotham
        option.TextXAlignment = Enum.TextXAlignment.Left
        
        option.MouseButton1Click:Connect(function()
            self.modelDropdown.Text = modelName
            self.modelListFrame.Visible = false
            -- 更新 Config 中的默认模型
            provider.defaultModel = modelName
            -- 自动保存设置
            local Config = _G.AIAnalyzer and _G.AIAnalyzer.Config
            if Config then
                Config:save()
            end
        end)
    end
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

-- 更新运行模式显示
function UI:updateRunModeDisplay(currentMode)
    local modeLabels = {
        smart = "智能",
        default = "默认",
        yolo = "YOLO"
    }
    
    if self.runModeButtons then
        for mode, btn in pairs(self.runModeButtons) do
            local isSelected = mode == currentMode
            btn.BackgroundColor3 = isSelected and self.Theme.accent or self.Theme.backgroundSecondary
            btn.TextColor3 = isSelected and Color3.new(1, 1, 1) or self.Theme.text
            btn.Font = isSelected and Enum.Font.GothamBold or Enum.Font.Gotham
        end
    end
end

-- 资源浏览器
function UI:createResourceView()
    local resourceFrame = Instance.new("Frame", self.mainContent)
    resourceFrame.Name = "ResourceView"
    resourceFrame.Size = UDim2.new(1, 0, 1, 0)
    resourceFrame.BackgroundTransparency = 1
    
    -- 标签页容器
    local tabContainer = Instance.new("Frame", resourceFrame)
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, -16, 0, 36)
    tabContainer.Position = UDim2.new(0, 8, 0, 8)
    tabContainer.BackgroundTransparency = 1
    
    -- 标签页按钮布局
    local tabLayout = Instance.new("UIListLayout", tabContainer)
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 4)
    
    -- 创建标签页按钮
    local tabs = {
        {id = "all", text = "全部", icon = "📁"},
        {id = "remotes", text = "Remote", icon = "📤"},
        {id = "scripts", text = "脚本", icon = "📝"},
        {id = "types", text = "按类型", icon = "🏷️"},
        {id = "search", text = "搜索", icon = "🔍"}
    }
    
    self.resourceTabs = {}
    self.currentResourceTab = "all"
    
    for _, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabContainer)
        btn.Name = tab.id .. "Tab"
        btn.Size = UDim2.new(0, 80, 1, 0)
        btn.BackgroundColor3 = tab.id == "all" and self.Theme.accent or self.Theme.backgroundSecondary
        btn.BorderSizePixel = 0
        btn.Text = tab.icon .. " " .. tab.text
        btn.TextColor3 = tab.id == "all" and Color3.new(1, 1, 1) or self.Theme.text
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamSemibold
        createCorner(btn, 6)
        
        btn.MouseButton1Click:Connect(function()
            self:switchResourceTab(tab.id)
        end)
        
        self.resourceTabs[tab.id] = btn
    end
    
    -- 工具栏
    local toolbar = Instance.new("Frame", resourceFrame)
    toolbar.Name = "Toolbar"
    toolbar.Size = UDim2.new(1, -16, 0, 28)
    toolbar.Position = UDim2.new(0, 8, 0, 48)
    toolbar.BackgroundTransparency = 1
    
    -- 搜索框
    local searchBox = Instance.new("TextBox", toolbar)
    searchBox.Name = "SearchBox"
    searchBox.Size = UDim2.new(1, -80, 1, 0)
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
    
    -- 扫描按钮
    local scanBtn = Instance.new("TextButton", toolbar)
    scanBtn.Name = "ScanButton"
    scanBtn.Size = UDim2.new(0, 60, 1, 0)
    scanBtn.Position = UDim2.new(1, -60, 0, 0)
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
    resourceList.Size = UDim2.new(1, -16, 1, -88)
    resourceList.Position = UDim2.new(0, 8, 0, 80)
    resourceList.BackgroundColor3 = self.Theme.backgroundTertiary
    resourceList.BorderSizePixel = 0
    resourceList.ScrollBarThickness = 5
    resourceList.ScrollBarImageColor3 = self.Theme.accent
    resourceList.CanvasSize = UDim2.new(0, 0, 0, 0)
    resourceList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    createCorner(resourceList, 8)
    
    local listLayout = Instance.new("UIListLayout", resourceList)
    listLayout.Padding = UDim.new(0, 2)
    
    -- 存储资源数据
    self.allResources = {
        all = {},
        remotes = {},
        localscripts = {},
        serverscripts = {},
        modulescripts = {},
        others = {}
    }
    
    self.resourceView = resourceFrame
    self.resourceSearchBox = searchBox
    self.resourceList = resourceList
    self.scanBtn = scanBtn
    
    return resourceFrame
end

-- 切换资源标签页
function UI:switchResourceTab(tabId)
    if self.currentResourceTab == tabId then return end
    
    self.currentResourceTab = tabId
    
    -- 更新标签页样式
    for id, btn in pairs(self.resourceTabs) do
        if id == tabId then
            btn.BackgroundColor3 = self.Theme.accent
            btn.TextColor3 = Color3.new(1, 1, 1)
        else
            btn.BackgroundColor3 = self.Theme.backgroundSecondary
            btn.TextColor3 = self.Theme.text
        end
    end
    
    -- 刷新资源列表
    self:refreshResourceList()
end

-- 构建资源树形结构
function UI:buildResourceTree(resources)
    local tree = {}
    
    for _, res in ipairs(resources) do
        local path = res.path or ""
        local parts = {}
        
        -- 分割路径
        for part in path:gmatch("[^%.]+") do
            table.insert(parts, part)
        end
        
        -- 构建树
        local current = tree
        for i, part in ipairs(parts) do
            local isLast = i == #parts
            
            if not current[part] then
                current[part] = {
                    name = part,
                    children = {},
                    resources = {},
                    isFolder = not isLast,
                    expanded = false
                }
            end
            
            if isLast then
                -- 最后一个部分是资源
                current[part].resources[#current[part].resources + 1] = res
                current[part].className = res.className
                current[part].onClick = res.onClick
                current[part].isFolder = false
            else
                -- 中间部分是文件夹
                current[part].isFolder = true
                current = current[part].children
            end
        end
    end
    
    return tree
end

-- 刷新资源列表显示
function UI:refreshResourceList()
    -- 清空当前列表
    for _, child in pairs(self.resourceList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    
    local Scanner = _G.AIAnalyzer and _G.AIAnalyzer.Scanner
    local searchQuery = self.resourceSearchBox and self.resourceSearchBox.Text:lower() or ""
    
    -- 辅助函数：从Scanner对象创建资源项
    local function makeResourceItem(obj)
        return {
            name = obj.name,
            className = obj.className,
            path = obj.path,
            instance = obj.instance,
            onClick = function()
                if self.resourceCallbacks and self.resourceCallbacks.sendToAI then
                    self.resourceCallbacks.sendToAI(obj)
                end
            end
        }
    end
    
    -- 根据当前标签获取资源
    local resources = {}
    
    if self.currentResourceTab == "types" then
        -- 按类型显示
        self:renderTypesView(Scanner)
        return
    elseif self.currentResourceTab == "search" then
        -- 搜索模式
        if searchQuery ~= "" and Scanner then
            local result = Scanner:search(searchQuery, {limit = 200})
            for _, r in ipairs(result.results) do
                table.insert(resources, makeResourceItem(r))
            end
        end
    elseif self.currentResourceTab == "remotes" then
        -- 从typeIndex获取所有Remote类型
        if Scanner and Scanner.cache.typeIndex then
            for typeName, objects in pairs(Scanner.cache.typeIndex) do
                if typeName:find("Remote") then
                    for _, obj in ipairs(objects) do
                        table.insert(resources, makeResourceItem(obj))
                    end
                end
            end
        end
    elseif self.currentResourceTab == "scripts" then
        -- 从typeIndex获取所有Script类型
        if Scanner and Scanner.cache.typeIndex then
            for _, typeName in ipairs({"LocalScript", "Script", "ModuleScript"}) do
                local objects = Scanner.cache.typeIndex[typeName]
                if objects then
                    for _, obj in ipairs(objects) do
                        table.insert(resources, makeResourceItem(obj))
                    end
                end
            end
        end
    else
        -- 全部：从cache.objects获取
        if Scanner and Scanner.cache.objects then
            for _, obj in ipairs(Scanner.cache.objects) do
                table.insert(resources, makeResourceItem(obj))
            end
        end
    end
    
    -- 如果有搜索词，过滤
    if searchQuery ~= "" and self.currentResourceTab ~= "search" then
        local filtered = {}
        for _, res in ipairs(resources) do
            if res.name:lower():find(searchQuery, 1, true) or 
               res.path:lower():find(searchQuery, 1, true) or
               res.className:lower():find(searchQuery, 1, true) then
                table.insert(filtered, res)
            end
        end
        resources = filtered
    end
    
    -- 限制显示数量
    local maxDisplay = 500
    if #resources > maxDisplay then
        local limited = {}
        for i = 1, maxDisplay do
            table.insert(limited, resources[i])
        end
        resources = limited
        
        -- 显示提示
        self:addResourceItem("... 还有 " .. (#resources - maxDisplay) .. " 个结果 ...", "", "", nil, false)
    end
    
    -- 构建树形结构
    local tree = self:buildResourceTree(resources)
    
    -- 存储展开状态
    if not self.expandedPaths then
        self.expandedPaths = {}
    end
    
    -- 渲染树形结构
    self:renderTreeLevel(tree, 0)
end

-- 渲染按类型视图
function UI:renderTypesView(Scanner)
    if not Scanner or not Scanner.cache.typeIndex then
        self:addResourceItem("请先扫描游戏资源", "", "", nil, false)
        return
    end
    
    local types = Scanner:getAllTypes()
    local maxTypes = 50
    
    for i, t in ipairs(types) do
        if i > maxTypes then break end
        
        local item = Instance.new("TextButton", self.resourceList)
        item.Size = UDim2.new(1, -8, 0, 32)
        item.BackgroundColor3 = self.Theme.backgroundSecondary
        item.BorderSizePixel = 0
        item.Text = ""
        createCorner(item, 4)
        
        -- 类型图标
        local icon = "📄"
        if t.name:find("Remote") then icon = "📤"
        elseif t.name:find("Script") then icon = "📝"
        elseif t.name:find("Part") then icon = "🧱"
        elseif t.name:find("Mesh") then icon = "🎨"
        elseif t.name:find("Sound") then icon = "🔊"
        elseif t.name:find("Particle") then icon = "✨"
        elseif t.name:find("Light") then icon = "💡"
        elseif t.name:find("Camera") then icon = "📷"
        elseif t.name:find("GUI") or t.name:find("Gui") then icon = "🖥️"
        elseif t.name:find("Animation") then icon = "🎬"
        end
        
        local iconLabel = Instance.new("TextLabel", item)
        iconLabel.Size = UDim2.new(0, 24, 1, 0)
        iconLabel.Position = UDim2.new(0, 8, 0, 0)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Text = icon
        iconLabel.TextSize = 14
        iconLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local nameLabel = Instance.new("TextLabel", item)
        nameLabel.Size = UDim2.new(1, -120, 1, 0)
        nameLabel.Position = UDim2.new(0, 32, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = t.name
        nameLabel.TextColor3 = self.Theme.text
        nameLabel.TextSize = 12
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local countLabel = Instance.new("TextLabel", item)
        countLabel.Size = UDim2.new(0, 60, 1, 0)
        countLabel.Position = UDim2.new(1, -68, 0, 0)
        countLabel.BackgroundTransparency = 1
        countLabel.Text = tostring(t.count)
        countLabel.TextColor3 = self.Theme.textSecondary
        countLabel.TextSize = 11
        countLabel.Font = Enum.Font.Gotham
        countLabel.TextXAlignment = Enum.TextXAlignment.Right
        
        -- 点击展开该类型
        item.MouseButton1Click:Connect(function()
            self:showTypeResources(t.name, Scanner)
        end)
    end
end

-- 显示某类型的资源列表
function UI:showTypeResources(typeName, Scanner)
    -- 清空当前列表
    for _, child in pairs(self.resourceList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    
    local resources = Scanner:filterByType(typeName)
    local maxDisplay = 200
    
    -- 返回按钮
    local backBtn = Instance.new("TextButton", self.resourceList)
    backBtn.Size = UDim2.new(1, -8, 0, 28)
    backBtn.BackgroundColor3 = self.Theme.accent
    backBtn.BorderSizePixel = 0
    backBtn.Text = "← 返回类型列表"
    backBtn.TextColor3 = Color3.new(1, 1, 1)
    backBtn.TextSize = 12
    backBtn.Font = Enum.Font.GothamBold
    createCorner(backBtn, 4)
    backBtn.MouseButton1Click:Connect(function()
        self.currentResourceTab = "types"
        self:refreshResourceList()
    end)
    
    -- 标题
    local title = Instance.new("TextLabel", self.resourceList)
    title.Size = UDim2.new(1, -8, 0, 24)
    title.BackgroundTransparency = 1
    title.Text = typeName .. " (" .. #resources .. " 个)"
    title.TextColor3 = self.Theme.text
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- 资源列表
    for i, res in ipairs(resources) do
        if i > maxDisplay then
            self:addResourceItem("... 还有 " .. (#resources - maxDisplay) .. " 个", "", "", nil, false)
            break
        end
        
        self:addTreeResourceItem(res.name, res.className, res.path, function()
            if self.resourceCallbacks and self.resourceCallbacks.sendToAI then
                self.resourceCallbacks.sendToAI(res)
            end
        end, 0)
    end
end

-- 渲染树形层级
function UI:renderTreeLevel(tree, depth)
    -- 获取排序后的键
    local keys = {}
    for key, node in pairs(tree) do
        table.insert(keys, {key = key, node = node})
    end
    
    -- 排序：文件夹在前，然后按名称排序
    table.sort(keys, function(a, b)
        if a.node.isFolder ~= b.node.isFolder then
            return a.node.isFolder
        end
        return a.key:lower() < b.key:lower()
    end)
    
    for _, item in ipairs(keys) do
        local node = item.node
        local indent = string.rep("  ", depth)
        
        if node.isFolder then
            -- 渲染文件夹
            local pathKey = indent .. node.name
            local isExpanded = self.expandedPaths[pathKey]
            
            self:addTreeFolderItem(node.name, depth, isExpanded, #node.children, pathKey)
            
            if isExpanded then
                -- 渲染子节点
                self:renderTreeLevel(node.children, depth + 1)
            end
        else
            -- 渲染资源项
            for _, res in ipairs(node.resources) do
                self:addTreeResourceItem(res.name, res.className, res.path, res.onClick, depth)
            end
        end
    end
end

-- 添加树形文件夹项
function UI:addTreeFolderItem(name, depth, isExpanded, childCount, pathKey)
    local item = Instance.new("TextButton", self.resourceList)
    item.Size = UDim2.new(1, -8, 0, 26)
    item.BackgroundColor3 = self.Theme.backgroundSecondary
    item.BorderSizePixel = 0
    item.Text = ""
    createCorner(item, 4)
    
    local indent = 8 + depth * 16
    
    -- 展开/收起箭头
    local arrow = Instance.new("TextLabel", item)
    arrow.Size = UDim2.new(0, 16, 1, 0)
    arrow.Position = UDim2.new(0, indent, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = isExpanded and "▼" or "▶"
    arrow.TextColor3 = self.Theme.textSecondary
    arrow.TextSize = 10
    arrow.Font = Enum.Font.GothamBold
    arrow.TextXAlignment = Enum.TextXAlignment.Center
    
    -- 文件夹图标
    local folderIcon = Instance.new("TextLabel", item)
    folderIcon.Size = UDim2.new(0, 20, 1, 0)
    folderIcon.Position = UDim2.new(0, indent + 16, 0, 0)
    folderIcon.BackgroundTransparency = 1
    folderIcon.Text = isExpanded and "📂" or "📁"
    folderIcon.TextColor3 = self.Theme.accent
    folderIcon.TextSize = 12
    folderIcon.TextXAlignment = Enum.TextXAlignment.Left
    
    -- 文件夹名称
    local nameLabel = Instance.new("TextLabel", item)
    nameLabel.Size = UDim2.new(1, -indent - 80, 1, 0)
    nameLabel.Position = UDim2.new(0, indent + 36, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = self.Theme.text
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- 子项数量
    local countLabel = Instance.new("TextLabel", item)
    countLabel.Size = UDim2.new(0, 30, 1, 0)
    countLabel.Position = UDim2.new(1, -35, 0, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "(" .. childCount .. ")"
    countLabel.TextColor3 = self.Theme.textMuted
    countLabel.TextSize = 10
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    -- 点击展开/收起
    item.MouseButton1Click:Connect(function()
        self.expandedPaths[pathKey] = not self.expandedPaths[pathKey]
        self:refreshResourceList()
    end)
    
    item.MouseEnter:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.15), {BackgroundColor3 = self.Theme.backgroundTertiary}):Play()
    end)
    
    item.MouseLeave:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.15), {BackgroundColor3 = self.Theme.backgroundSecondary}):Play()
    end)
    
    return item
end

-- 添加树形资源项
function UI:addTreeResourceItem(name, className, path, onClick, depth)
    local typeColor = self.Theme.textSecondary
    if className:find("Remote") then
        typeColor = Color3.fromRGB(255, 180, 100)
    elseif className:find("Script") then
        typeColor = Color3.fromRGB(100, 200, 255)
    end
    
    local item = Instance.new("TextButton", self.resourceList)
    item.Size = UDim2.new(1, -8, 0, 24)
    item.BackgroundColor3 = self.Theme.backgroundSecondary
    item.BorderSizePixel = 0
    item.Text = ""
    createCorner(item, 4)
    
    local indent = 8 + (depth + 1) * 16
    
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
    
    local iconLabel = Instance.new("TextLabel", item)
    iconLabel.Size = UDim2.new(0, 20, 1, 0)
    iconLabel.Position = UDim2.new(0, indent, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextSize = 12
    iconLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- 资源名称
    local nameLabel = Instance.new("TextLabel", item)
    nameLabel.Size = UDim2.new(1, -indent - 80, 1, 0)
    nameLabel.Position = UDim2.new(0, indent + 20, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = self.Theme.text
    nameLabel.TextSize = 11
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- 类型标签
    local classLabel = Instance.new("TextLabel", item)
    classLabel.Size = UDim2.new(0, 80, 1, 0)
    classLabel.Position = UDim2.new(1, -85, 0, 0)
    classLabel.BackgroundTransparency = 1
    classLabel.Text = className
    classLabel.TextColor3 = typeColor
    classLabel.TextSize = 9
    classLabel.Font = Enum.Font.Gotham
    classLabel.TextXAlignment = Enum.TextXAlignment.Right
    classLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    item.MouseButton1Click:Connect(onClick)
    
    item.MouseEnter:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.15), {BackgroundColor3 = self.Theme.accent}):Play()
    end)
    
    item.MouseLeave:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.15), {BackgroundColor3 = self.Theme.backgroundSecondary}):Play()
    end)
    
    return item
end

-- 添加资源到分类
function UI:addResourceToCategory(name, className, path, onClick)
    -- 确保 allResources 已初始化
    if not self.allResources then
        self.allResources = {
            all = {},
            remotes = {},
            localscripts = {},
            serverscripts = {},
            modulescripts = {},
            others = {}
        }
    end
    
    local resource = {
        name = name,
        className = className,
        path = path,
        onClick = onClick
    }
    
    -- 添加到全部
    table.insert(self.allResources.all, resource)
    
    -- 根据类型分类
    if className:find("Remote") then
        table.insert(self.allResources.remotes, resource)
    elseif className == "LocalScript" then
        table.insert(self.allResources.localscripts, resource)
    elseif className == "Script" then
        table.insert(self.allResources.serverscripts, resource)
    elseif className == "ModuleScript" then
        table.insert(self.allResources.modulescripts, resource)
    else
        table.insert(self.allResources.others, resource)
    end
    
    -- 如果当前标签页匹配，直接显示
    local shouldShow = self.currentResourceTab == "all" or
       (self.currentResourceTab == "remotes" and className:find("Remote")) or
       (self.currentResourceTab == "localscripts" and className == "LocalScript") or
       (self.currentResourceTab == "serverscripts" and className == "Script") or
       (self.currentResourceTab == "modulescripts" and className == "ModuleScript") or
       (self.currentResourceTab == "others" and not className:find("Remote") and className ~= "LocalScript" and className ~= "Script" and className ~= "ModuleScript")
    
    if shouldShow then
        self:addResourceItem(name, className, path, onClick)
    end
end

-- 资源操作弹窗（展开菜单风格）
function UI:showResourceDialog(resource, callbacks)
    -- 移除已存在的弹窗
    local existing = self.screenGui:FindFirstChild("ResourceDialogOverlay")
    if existing then existing:Destroy() end
    
    local overlay = Instance.new("Frame", self.screenGui)
    overlay.Name = "ResourceDialogOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.6
    overlay.ZIndex = 200
    
    -- 计算按钮数量确定弹窗高度
    local btnCount = 2  -- 分析 + 复制路径
    if resource.className:find("Remote") then btnCount = btnCount + 1 end
    if resource.className:find("Script") then btnCount = btnCount + 2 end
    
    local dialogHeight = 75 + btnCount * 36
    
    local dialog = Instance.new("Frame", overlay)
    dialog.Name = "Dialog"
    dialog.Size = UDim2.new(0, 320, 0, dialogHeight)
    dialog.Position = UDim2.new(0.5, -160, 0.5, -dialogHeight/2)
    dialog.BackgroundColor3 = self.Theme.background
    dialog.BorderSizePixel = 0
    dialog.ZIndex = 201
    createCorner(dialog, 12)
    
    local stroke = Instance.new("UIStroke", dialog)
    stroke.Color = self.Theme.border
    stroke.Thickness = 1
    
    -- 标题区域
    local titleArea = Instance.new("Frame", dialog)
    titleArea.Size = UDim2.new(1, 0, 0, 50)
    titleArea.BackgroundColor3 = self.Theme.backgroundSecondary
    titleArea.BorderSizePixel = 0
    createCorner(titleArea, 12)
    
    -- 图标
    local icon = "📄"
    if resource.className:find("RemoteEvent") then icon = "📤"
    elseif resource.className:find("RemoteFunction") then icon = "📥"
    elseif resource.className:find("LocalScript") then icon = "📜"
    elseif resource.className:find("ModuleScript") then icon = "📦"
    elseif resource.className:find("Script") then icon = "📝"
    end
    
    local iconLabel = Instance.new("TextLabel", titleArea)
    iconLabel.Size = UDim2.new(0, 40, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextSize = 22
    iconLabel.Font = Enum.Font.Gotham
    
    local title = Instance.new("TextLabel", titleArea)
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 40, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = resource.name
    title.TextColor3 = self.Theme.text
    title.TextSize = 15
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    
    local subtitle = Instance.new("TextLabel", titleArea)
    subtitle.Size = UDim2.new(1, -70, 0, 16)
    subtitle.Position = UDim2.new(0, 40, 0, 30)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = resource.className
    subtitle.TextColor3 = self.Theme.textMuted
    subtitle.TextSize = 11
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    
    -- 关闭按钮
    local closeBtn = Instance.new("TextButton", titleArea)
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -32, 0.5, -12)
    closeBtn.BackgroundColor3 = self.Theme.error
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 202
    createCorner(closeBtn, 4)
    
    local function close()
        overlay:Destroy()
    end
    
    closeBtn.MouseButton1Click:Connect(close)
    
    -- 按钮容器
    local btnContainer = Instance.new("Frame", dialog)
    btnContainer.Size = UDim2.new(1, -16, 1, -58)
    btnContainer.Position = UDim2.new(0, 8, 0, 54)
    btnContainer.BackgroundTransparency = 1
    
    local btnY = 0
    
    local function addBtn(text, callback, color, iconStr)
        local btn = Instance.new("TextButton", btnContainer)
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.Position = UDim2.new(0, 0, 0, btnY)
        btn.BackgroundColor3 = color or self.Theme.backgroundTertiary
        btn.BorderSizePixel = 0
        btn.Text = "  " .. (iconStr or "›") .. "  " .. text
        btn.TextColor3 = color and Color3.new(1, 1, 1) or self.Theme.text
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        createCorner(btn, 6)
        
        btn.MouseButton1Click:Connect(function()
            close()
            if callback then callback() end
        end)
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = self.Theme.accent}):Play()
        end)
        
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = color or self.Theme.backgroundTertiary}):Play()
        end)
        
        btnY = btnY + 38
    end
    
    local function addDivider()
        local divider = Instance.new("Frame", btnContainer)
        divider.Size = UDim2.new(1, -16, 0, 1)
        divider.Position = UDim2.new(0, 8, 0, btnY + 4)
        divider.BackgroundColor3 = self.Theme.border
        divider.BorderSizePixel = 0
        btnY = btnY + 12
    end
    
    -- 主要操作
    addBtn("让AI分析", callbacks.analyze, self.Theme.accent, "🤖")
    
    -- 根据类型显示不同操作
    if resource.className:find("Remote") then
        addBtn("生成调用代码", callbacks.generateCode, self.Theme.success, "🔧")
    end
    
    if resource.className:find("Script") then
        addBtn("查看源码", callbacks.viewSource, Color3.fromRGB(100, 120, 200), "📄")
        addBtn("发送给AI分析", callbacks.sendToAI, self.Theme.accent, "📤")
    end
    
    addDivider()
    
    -- 通用操作
    addBtn("复制路径", function()
        if setclipboard then
            setclipboard(resource.path)
        end
        self:addSystemMessage("✅ 已复制路径: " .. resource.path)
    end, nil, "📋")
    
    addBtn("复制名称", function()
        if setclipboard then
            setclipboard(resource.name)
        end
        self:addSystemMessage("✅ 已复制名称: " .. resource.name)
    end, nil, "📝")
    
    -- 点击背景关闭
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            close()
        end
    end)
    
    return dialog
end

-- 系统消息
function UI:addSystemMessage(text)
    self:addMessage("ℹ️ " .. text, false)
end

-- 资源列表项
function UI:addResourceItem(name, className, path, onClick, showFullPath)
    local typeColor = self.Theme.textSecondary
    if className:find("Remote") then
        typeColor = Color3.fromRGB(255, 180, 100)
    elseif className:find("Script") then
        typeColor = Color3.fromRGB(100, 200, 255)
    end
    
    local item = Instance.new("TextButton", self.resourceList)
    item.Size = UDim2.new(1, -8, 0, showFullPath and 36 or 40)
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
    
    if showFullPath then
        -- 资源页面：单行显示完整路径
        local pathText = Instance.new("TextLabel", item)
        pathText.Size = UDim2.new(1, -80, 1, 0)
        pathText.Position = UDim2.new(0, 12, 0, 0)
        pathText.BackgroundTransparency = 1
        pathText.Text = icon .. " " .. path
        pathText.TextColor3 = self.Theme.text
        pathText.TextSize = 11
        pathText.Font = Enum.Font.Code
        pathText.TextXAlignment = Enum.TextXAlignment.Left
        pathText.TextTruncate = Enum.TextTruncate.AtEnd
        
        local classText = Instance.new("TextLabel", item)
        classText.Size = UDim2.new(0, 70, 1, 0)
        classText.Position = UDim2.new(1, -75, 0, 0)
        classText.BackgroundTransparency = 1
        classText.Text = className
        classText.TextColor3 = typeColor
        classText.TextSize = 10
        classText.Font = Enum.Font.Gotham
        classText.TextXAlignment = Enum.TextXAlignment.Right
    else
        -- 聊天页面：两行显示
        local nameText = Instance.new("TextLabel", item)
        nameText.Size = UDim2.new(0.55, 0, 0.5, 0)
        nameText.Position = UDim2.new(0, 8, 0, 0)
        nameText.BackgroundTransparency = 1
        nameText.Text = icon .. " " .. name
        nameText.TextColor3 = self.Theme.text
        nameText.TextSize = 12
        nameText.Font = Enum.Font.GothamSemibold
        nameText.TextXAlignment = Enum.TextXAlignment.Left
        nameText.TextTruncate = Enum.TextTruncate.AtEnd
        
        local classText = Instance.new("TextLabel", item)
        classText.Size = UDim2.new(0.35, 0, 0.5, 0)
        classText.Position = UDim2.new(0.58, 0, 0, 0)
        classText.BackgroundTransparency = 1
        classText.Text = className
        classText.TextColor3 = typeColor
        classText.TextSize = 10
        classText.Font = Enum.Font.Gotham
        classText.TextXAlignment = Enum.TextXAlignment.Left
        classText.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- 第二行：简短路径
        local pathText = Instance.new("TextLabel", item)
        pathText.Size = UDim2.new(1, -16, 0.5, 0)
        pathText.Position = UDim2.new(0, 8, 0.5, 0)
        pathText.BackgroundTransparency = 1
        pathText.Text = path
        pathText.TextColor3 = self.Theme.textMuted
        pathText.TextSize = 10
        pathText.Font = Enum.Font.Code
        pathText.TextXAlignment = Enum.TextXAlignment.Left
        pathText.TextTruncate = Enum.TextTruncate.AtEnd
    end
    
    if type(onClick) == "function" then
        item.MouseButton1Click:Connect(onClick)
    end
    
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

-- 更新Token显示
function UI:updateTokenDisplay(usage)
    if usage then
        self.tokenStats.total = self.tokenStats.total + (usage.total_tokens or 0)
        self.tokenStats.prompt = self.tokenStats.prompt + (usage.prompt_tokens or 0)
        self.tokenStats.completion = self.tokenStats.completion + (usage.completion_tokens or 0)
        self.tokenStats.requests = self.tokenStats.requests + 1
        -- 缓存命中token（DeepSeek特有）
        if usage.cache_hit_tokens then
            self.tokenStats.cacheHit = (self.tokenStats.cacheHit or 0) + usage.cache_hit_tokens
        end
    end
    
    -- 更新标题栏显示
    if self.tokenText then
        local displayText
        if self.tokenStats.total >= 1000000 then
            displayText = string.format("%.1fM", self.tokenStats.total / 1000000)
        elseif self.tokenStats.total >= 1000 then
            displayText = string.format("%.1fK", self.tokenStats.total / 1000)
        else
            displayText = tostring(self.tokenStats.total)
        end
        self.tokenText.Text = displayText .. " tokens"
    end
    
    -- 更新设置页面统计
    if self.tokenStatsLabel then
        local function formatNum(n)
            if not n then return "0" end
            if n >= 1000000 then
                return string.format("%.2fM", n / 1000000)
            elseif n >= 1000 then
                return string.format("%.1fK", n / 1000)
            else
                return tostring(n)
            end
        end
        
        local statsText = string.format(
            "总消耗: %s tokens\n请求次数: %d\n输入: %s | 输出: %s",
            formatNum(self.tokenStats.total),
            self.tokenStats.requests,
            formatNum(self.tokenStats.prompt),
            formatNum(self.tokenStats.completion)
        )
        
        -- 如果有缓存命中，显示缓存节省
        if self.tokenStats.cacheHit and self.tokenStats.cacheHit > 0 then
            statsText = statsText .. "\n缓存命中: " .. formatNum(self.tokenStats.cacheHit)
        end
        
        self.tokenStatsLabel.Text = statsText
    end
end

-- 获取Token统计
function UI:getTokenStats()
    return self.tokenStats
end

-- 重置Token统计
function UI:resetTokenStats()
    self.tokenStats = {
        total = 0,
        prompt = 0,
        completion = 0,
        requests = 0,
        cacheHit = 0
    }
    self:updateTokenDisplay()
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

-- ========== 文件浏览器功能 ==========

-- 创建文件浏览器弹窗
function UI:createFileBrowser()
    if self.fileBrowserFrame then
        self.fileBrowserFrame.Visible = true
        return
    end
    
    local browserFrame = Instance.new("Frame", self.screenGui)
    browserFrame.Name = "FileBrowser"
    browserFrame.Size = UDim2.new(0, 400, 0, 350)
    browserFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
    browserFrame.BackgroundColor3 = self.Theme.background
    browserFrame.BorderSizePixel = 0
    browserFrame.Visible = false
    browserFrame.ZIndex = 100
    createCorner(browserFrame, 12)
    
    -- 标题栏
    local titleBar = Instance.new("Frame", browserFrame)
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = self.Theme.backgroundSecondary
    titleBar.BorderSizePixel = 0
    createCorner(titleBar, 12)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "📁 文件浏览器"
    title.TextColor3 = self.Theme.text
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -32, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    createCorner(closeBtn, 6)
    closeBtn.ZIndex = 101
    closeBtn.MouseButton1Click:Connect(function()
        self:hideFileBrowser()
    end)
    
    -- 路径显示
    local pathBar = Instance.new("Frame", browserFrame)
    pathBar.Name = "PathBar"
    pathBar.Size = UDim2.new(1, -16, 0, 28)
    pathBar.Position = UDim2.new(0, 8, 0, 42)
    pathBar.BackgroundColor3 = self.Theme.backgroundTertiary
    pathBar.BorderSizePixel = 0
    createCorner(pathBar, 6)
    
    local pathLabel = Instance.new("TextLabel", pathBar)
    pathLabel.Name = "PathLabel"
    pathLabel.Size = UDim2.new(1, -12, 1, 0)
    pathLabel.Position = UDim2.new(0, 6, 0, 0)
    pathLabel.BackgroundTransparency = 1
    pathLabel.Text = "📂 workspace"
    pathLabel.TextColor3 = self.Theme.textSecondary
    pathLabel.TextSize = 11
    pathLabel.Font = Enum.Font.Gotham
    pathLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- 文件列表
    local fileList = Instance.new("ScrollingFrame", browserFrame)
    fileList.Name = "FileList"
    fileList.Size = UDim2.new(1, -16, 1, -140)
    fileList.Position = UDim2.new(0, 8, 0, 76)
    fileList.BackgroundColor3 = self.Theme.backgroundSecondary
    fileList.BorderSizePixel = 0
    fileList.ScrollBarThickness = 5
    fileList.ScrollBarImageColor3 = self.Theme.accent
    fileList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    fileList.CanvasSize = UDim2.new(0, 0, 0, 0)
    createCorner(fileList, 8)
    
    local listLayout = Instance.new("UIListLayout", fileList)
    listLayout.Padding = UDim.new(0, 2)
    
    -- 编辑器区域（初始隐藏）
    local editorFrame = Instance.new("Frame", browserFrame)
    editorFrame.Name = "EditorFrame"
    editorFrame.Size = UDim2.new(1, -16, 0, 0)
    editorFrame.Position = UDim2.new(0, 8, 1, -8)
    editorFrame.BackgroundColor3 = self.Theme.backgroundTertiary
    editorFrame.BorderSizePixel = 0
    editorFrame.Visible = false
    createCorner(editorFrame, 8)
    
    -- 文件名输入
    local fileNameInput = Instance.new("TextBox", browserFrame)
    fileNameInput.Name = "FileNameInput"
    fileNameInput.Size = UDim2.new(1, -16, 0, 24)
    fileNameInput.Position = UDim2.new(0, 8, 1, -52)
    fileNameInput.BackgroundColor3 = self.Theme.backgroundTertiary
    fileNameInput.BorderSizePixel = 0
    fileNameInput.PlaceholderText = "文件名..."
    fileNameInput.PlaceholderColor3 = self.Theme.textMuted
    fileNameInput.Text = ""
    fileNameInput.TextColor3 = self.Theme.text
    fileNameInput.TextSize = 11
    fileNameInput.Font = Enum.Font.Gotham
    fileNameInput.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(fileNameInput, 6)
    fileNameInput.Visible = false
    
    -- 操作按钮
    local btnFrame = Instance.new("Frame", browserFrame)
    btnFrame.Size = UDim2.new(1, -16, 0, 28)
    btnFrame.Position = UDim2.new(0, 8, 1, -36)
    btnFrame.BackgroundTransparency = 1
    
    local newFileBtn = Instance.new("TextButton", btnFrame)
    newFileBtn.Size = UDim2.new(0.25, -4, 1, 0)
    newFileBtn.BackgroundColor3 = self.Theme.accent
    newFileBtn.BorderSizePixel = 0
    newFileBtn.Text = "新建"
    newFileBtn.TextColor3 = Color3.new(1, 1, 1)
    newFileBtn.TextSize = 11
    newFileBtn.Font = Enum.Font.GothamBold
    createCorner(newFileBtn, 6)
    
    local saveFileBtn = Instance.new("TextButton", btnFrame)
    saveFileBtn.Size = UDim2.new(0.25, -4, 1, 0)
    saveFileBtn.Position = UDim2.new(0.25, 2, 0, 0)
    saveFileBtn.BackgroundColor3 = self.Theme.success
    saveFileBtn.BorderSizePixel = 0
    saveFileBtn.Text = "保存"
    saveFileBtn.TextColor3 = Color3.new(1, 1, 1)
    saveFileBtn.TextSize = 11
    saveFileBtn.Font = Enum.Font.GothamBold
    createCorner(saveFileBtn, 6)
    
    local runFileBtn = Instance.new("TextButton", btnFrame)
    runFileBtn.Size = UDim2.new(0.25, -4, 1, 0)
    runFileBtn.Position = UDim2.new(0.5, 4, 0, 0)
    runFileBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
    runFileBtn.BorderSizePixel = 0
    runFileBtn.Text = "运行"
    runFileBtn.TextColor3 = Color3.new(1, 1, 1)
    runFileBtn.TextSize = 11
    runFileBtn.Font = Enum.Font.GothamBold
    createCorner(runFileBtn, 6)
    
    local cancelBtn = Instance.new("TextButton", btnFrame)
    cancelBtn.Size = UDim2.new(0.25, -4, 1, 0)
    cancelBtn.Position = UDim2.new(0.75, 6, 0, 0)
    cancelBtn.BackgroundColor3 = self.Theme.textSecondary
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Text = "取消"
    cancelBtn.TextColor3 = Color3.new(1, 1, 1)
    cancelBtn.TextSize = 11
    cancelBtn.Font = Enum.Font.GothamBold
    createCorner(cancelBtn, 6)
    
    -- 保存引用
    self.fileBrowserFrame = browserFrame
    self.fileBrowserPathLabel = pathLabel
    self.fileBrowserList = fileList
    self.fileBrowserEditor = editorFrame
    self.fileNameInput = fileNameInput
    self.fileBrowserButtons = {
        newFile = newFileBtn,
        save = saveFileBtn,
        run = runFileBtn,
        cancel = cancelBtn
    }
    self.fileBrowserCurrentPath = "workspace"
    self.fileBrowserSelectedFile = nil
    
    -- 绑定事件
    self:bindFileBrowserEvents()
end

-- 绑定文件浏览器事件
function UI:bindFileBrowserEvents()
    local btns = self.fileBrowserButtons
    
    btns.newFile.MouseButton1Click:Connect(function()
        self:createNewFile()
    end)
    
    btns.save.MouseButton1Click:Connect(function()
        self:saveCurrentFile()
    end)
    
    btns.run.MouseButton1Click:Connect(function()
        self:runCurrentFile()
    end)
    
    btns.cancel.MouseButton1Click:Connect(function()
        self:hideFileBrowser()
    end)
end

-- 显示文件浏览器
function UI:showFileBrowser(initialPath)
    self:createFileBrowser()
    self.fileBrowserFrame.Visible = true
    self.fileBrowserEditor.Visible = false
    self.fileNameInput.Visible = false
    self.fileBrowserFrame.Size = UDim2.new(0, 400, 0, 350)
    self.fileBrowserSelectedFile = nil
    self:navigateToFolder(initialPath or "workspace")
end

-- 隐藏文件浏览器
function UI:hideFileBrowser()
    if self.fileBrowserFrame then
        self.fileBrowserFrame.Visible = false
    end
end

-- 导航到文件夹
function UI:navigateToFolder(path)
    local exec = _G.AIAnalyzer and _G.AIAnalyzer.Executor
    if not exec or not exec.listfiles then
        self:addMessage("⚠️ 当前执行器不支持文件浏览", false)
        return
    end
    
    self.fileBrowserCurrentPath = path
    self.fileBrowserPathLabel.Text = "📂 " .. path
    
    -- 清空列表
    for _, child in ipairs(self.fileBrowserList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- 返回上一级
    if path ~= "workspace" then
        local parentPath = path:match("^(.+)/[^/]+$") or "workspace"
        self:addFileBrowserItem("📁 ..", "folder", parentPath, true)
    end
    
    -- 获取文件列表
    local success, files = pcall(exec.listfiles, path)
    if not success or not files then
        self:addFileBrowserItem("❌ 无法读取目录", "error", nil, false)
        return
    end
    
    -- 排序：文件夹在前
    local folders = {}
    local regularFiles = {}
    
    for _, file in ipairs(files) do
        local name = file:match("[^/]+$") or file
        local isFolder = exec.isfolder and exec.isfolder(file)
        
        if isFolder then
            table.insert(folders, {name = name, path = file, isFolder = true})
        else
            table.insert(regularFiles, {name = name, path = file, isFolder = false})
        end
    end
    
    -- 显示文件夹
    for _, item in ipairs(folders) do
        self:addFileBrowserItem("📁 " .. item.name, "folder", item.path, false)
    end
    
    -- 显示文件
    for _, item in ipairs(regularFiles) do
        local ext = item.name:match("%.(%w+)$") or ""
        local icon = "📄"
        if ext == "lua" then icon = "📝"
        elseif ext == "json" then icon = "📋"
        elseif ext == "txt" then icon = "📃"
        end
        self:addFileBrowserItem(icon .. " " .. item.name, "file", item.path, false)
    end
    
    if #folders == 0 and #regularFiles == 0 then
        self:addFileBrowserItem("📂 空目录", "empty", nil, false)
    end
end

-- 添加文件浏览器项目
function UI:addFileBrowserItem(text, itemType, path, isBack)
    local item = Instance.new("TextButton", self.fileBrowserList)
    item.Size = UDim2.new(1, -4, 0, 28)
    item.BackgroundColor3 = self.Theme.backgroundTertiary
    item.BorderSizePixel = 0
    item.Text = "  " .. text
    item.TextColor3 = self.Theme.text
    item.TextSize = 12
    item.Font = Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(item, 4)
    
    item.MouseButton1Click:Connect(function()
        if itemType == "folder" then
            self:navigateToFolder(path)
        elseif itemType == "file" then
            self:selectFile(path)
        end
    end)
end

-- 选择文件
function UI:selectFile(path)
    local exec = _G.AIAnalyzer and _G.AIAnalyzer.Executor
    if not exec or not exec.readfile then return end
    
    local fileName = path:match("[^/]+$") or path
    self.fileBrowserSelectedFile = path
    self.fileNameInput.Text = fileName
    self.fileNameInput.Visible = true
    
    -- 读取文件内容
    local success, content = pcall(exec.readfile, path)
    if success and content then
        -- 显示编辑器
        self:showFileEditor(content)
    else
        self:addMessage("❌ 无法读取文件: " .. tostring(content), false)
    end
end

-- 显示文件编辑器
function UI:showFileEditor(content)
    -- 调整浏览器大小
    self.fileBrowserFrame.Size = UDim2.new(0, 500, 0, 500)
    self.fileBrowserFrame.Position = UDim2.new(0.5, -250, 0.5, -250)
    
    -- 清除旧编辑器
    for _, child in ipairs(self.fileBrowserEditor:GetChildren()) do
        child:Destroy()
    end
    
    -- 创建编辑器
    local editor = Instance.new("TextBox", self.fileBrowserEditor)
    editor.Name = "CodeEditor"
    editor.Size = UDim2.new(1, -8, 1, -8)
    editor.Position = UDim2.new(0, 4, 0, 4)
    editor.BackgroundTransparency = 1
    editor.Text = content
    editor.TextColor3 = self.Theme.text
    editor.TextSize = 11
    editor.Font = Enum.Font.Code
    editor.TextXAlignment = Enum.TextXAlignment.Left
    editor.TextYAlignment = Enum.TextYAlignment.Top
    editor.TextWrapped = false
    editor.MultiLine = true
    editor.ClearTextOnFocus = false
    
    self.fileBrowserEditor.Visible = true
    
    -- 调整列表大小
    self.fileBrowserList.Size = UDim2.new(1, -16, 0, 200)
end

-- 创建新文件
function UI:createNewFile()
    local fileName = self.fileNameInput.Text
    if fileName == "" then
        fileName = "new_script.lua"
        self.fileNameInput.Text = fileName
    end
    
    self.fileBrowserSelectedFile = self.fileBrowserCurrentPath .. "/" .. fileName
    
    -- 显示空编辑器
    self:showFileEditor("-- 新文件\n")
end

-- 保存当前文件
function UI:saveCurrentFile()
    local exec = _G.AIAnalyzer and _G.AIAnalyzer.Executor
    if not exec or not exec.writefile then
        self:addMessage("❌ 当前执行器不支持写入文件", false)
        return
    end
    
    local filePath = self.fileBrowserSelectedFile
    if not filePath then
        self:addMessage("⚠️ 请先选择或创建文件", false)
        return
    end
    
    -- 获取编辑器内容
    local editor = self.fileBrowserEditor:FindFirstChild("CodeEditor")
    if not editor then return end
    
    local content = editor.Text
    
    -- 保存文件
    local success, err = pcall(exec.writefile, filePath, content)
    if success then
        self:addMessage("✅ 文件已保存: " .. filePath, false)
    else
        self:addMessage("❌ 保存失败: " .. tostring(err), false)
    end
end

-- 运行当前文件
function UI:runCurrentFile()
    local exec = _G.AIAnalyzer and _G.AIAnalyzer.Executor
    local Tools = _G.AIAnalyzer and _G.AIAnalyzer.Tools
    
    -- 获取编辑器内容
    local editor = self.fileBrowserEditor:FindFirstChild("CodeEditor")
    if not editor then return end
    
    local code = editor.Text
    local filePath = self.fileBrowserSelectedFile or "未命名"
    
    -- 检查运行模式
    local runMode = Tools and Tools:getRunMode() or "default"
    local needConfirm = true
    
    if runMode == "yolo" then
        needConfirm = false
    elseif runMode == "smart" and Tools then
        local risk = Tools:analyzeRisk(code)
        needConfirm = risk.level ~= "low"
    end
    
    if needConfirm then
        -- 显示确认对话框
        self:addMessage(string.format([[
⚠️ **需要确认运行脚本**
📄 文件: %s
📊 运行模式: %s

请确认是否执行此脚本]], filePath, runMode), false)
        
        -- 设置确认状态
        self.pendingFileExecution = code
        self:showConfirmationPrompt("执行文件: " .. filePath, code:sub(1, 300))
    else
        -- 直接执行
        self:executeFileCode(code, filePath)
    end
end

-- 执行文件代码
function UI:executeFileCode(code, filePath)
    local fn, err = loadstring(code)
    if not fn then
        self:addMessage("❌ 编译失败: " .. tostring(err), false)
        return
    end
    
    local ok, result = pcall(fn)
    if ok then
        self:addMessage("✅ 脚本执行成功: " .. filePath, false)
    else
        self:addMessage("❌ 执行错误: " .. tostring(result), false)
    end
end

-- 检查输入框是否触发文件浏览
function UI:checkFileBrowserTrigger()
    local text = self.inputBox.Text
    -- 检测 @ 字符
    if text:sub(-1) == "@" then
        self:showFileBrowser()
        -- 移除 @ 字符
        self.inputBox.Text = text:sub(1, -2)
    end
end

return UI