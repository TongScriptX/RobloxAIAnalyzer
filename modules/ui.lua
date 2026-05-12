-- UI模块 - Roblox AI Resource Analyzer
local UI = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- 加载状态
UI.isLoading = false
UI.loadingConnection = nil
UI.loadingDots = 0

-- 资源持续监听连接
UI.resourceConnections = {}
UI.resourceRefreshDebounce = false
UI.resourceAutoRefresh = true

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
    
    -- 连接状态指示器（小圆点）
    local statusIndicator = Instance.new("Frame", titleBar)
    statusIndicator.Name = "StatusIndicator"
    statusIndicator.Size = UDim2.new(0, 8, 0, 8)
    statusIndicator.Position = UDim2.new(1, -140, 0.5, -4)
    statusIndicator.BackgroundColor3 = self.Theme.warning
    statusIndicator.BorderSizePixel = 0
    createCorner(statusIndicator, 4)
    
    -- Token显示区域
    local tokenDisplay = Instance.new("Frame", titleBar)
    tokenDisplay.Name = "TokenDisplay"
    tokenDisplay.Size = UDim2.new(0, 90, 0, 22)
    tokenDisplay.Position = UDim2.new(1, -130, 0.5, -11)
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
        local expandTween = TweenService:Create(self.mainFrame, tweenInfo, {
            Size = UDim2.new(0, self.currentWidth, 0, self.currentHeight),
            Position = UDim2.new(0.5, -self.currentWidth/2, 0.5, -self.currentHeight/2),
            BackgroundTransparency = 0
        })
        expandTween:Play()
        
        -- 展开完成后刷新消息区域布局
        expandTween.Completed:Connect(function()
            -- 强制刷新消息区域的布局
            if self.messageArea then
                local listLayout = self.messageArea:FindFirstChild("UIListLayout")
                if listLayout then
                    -- 触发布局重新计算
                    task.wait(0.1)
                    self.messageArea.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
                end
            end
        end)
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
    messageArea.Size = UDim2.new(1, -16, 1, -76)  -- 调整高度，为状态栏留出空间
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
    
    -- 上下文状态栏（输入框上方）
    local statusFrame = Instance.new("Frame", chatFrame)
    statusFrame.Name = "ContextStatusFrame"
    statusFrame.Size = UDim2.new(1, -16, 0, 18)
    statusFrame.Position = UDim2.new(0, 8, 1, -66)  -- 输入框上方
    statusFrame.BackgroundTransparency = 1
    
    -- 左侧：上下文使用百分比
    local contextLabel = Instance.new("TextLabel", statusFrame)
    contextLabel.Name = "ContextLabel"
    contextLabel.Size = UDim2.new(0.5, 0, 1, 0)
    contextLabel.Position = UDim2.new(0, 0, 0, 0)
    contextLabel.BackgroundTransparency = 1
    contextLabel.Text = "📊 上下文: 0%"
    contextLabel.TextColor3 = self.Theme.textSecondary
    contextLabel.TextSize = 11
    contextLabel.Font = Enum.Font.Gotham
    contextLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- 右侧：Token 消耗显示
    local tokenLabel = Instance.new("TextLabel", statusFrame)
    tokenLabel.Name = "TokenLabel"
    tokenLabel.Size = UDim2.new(0.5, 0, 1, 0)
    tokenLabel.Position = UDim2.new(0.5, 0, 0, 0)
    tokenLabel.BackgroundTransparency = 1
    tokenLabel.Text = "消耗: 0 tokens"
    tokenLabel.TextColor3 = self.Theme.textSecondary
    tokenLabel.TextSize = 11
    tokenLabel.Font = Enum.Font.Gotham
    tokenLabel.TextXAlignment = Enum.TextXAlignment.Right
    
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
    inputBox.ClearTextOnFocus = false  -- 防止点击时清除文本
    
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
    self.contextLabel = contextLabel
    self.tokenLabel = tokenLabel
    
    return chatFrame
end

-- 显示加载动画
function UI:showLoading()
    if self.isLoading then return end
    self.isLoading = true
    self.loadingDots = 0
    self.lastDotTime = 0
    
    -- 禁用输入
    self.inputBox.TextEditable = false
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
    
    -- 如果正在确认脚本但不是修改模式，不恢复输入框
    if self.isConfirming and not self.isModifyingCode then
        return
    end
    
    -- 恢复输入
    if self.inputBox then
        self.inputBox.TextEditable = true
        if not self.isModifyingCode then
            self.inputBox.PlaceholderText = "输入问题或指令..."
        end
    end
    if self.sendBtn then
        self.sendBtn.Text = ">"
        self.sendBtn.BackgroundColor3 = self.Theme.accent
    end
end

-- 更新工具执行状态（显示在输入框placeholder）
function UI:updateToolStatus(statusText)
    if not self.isLoading then return end
    self.currentStatus = statusText or ""
    -- 直接更新占位符文字
    self.inputBox.PlaceholderText = statusText
end

-- 显示脚本确认提示（按钮模式）
function UI:showConfirmationPrompt(description, fullCode)
    -- 检查必要的UI元素
    if not self.inputBox or not self.sendBtn then
        warn("[UI] showConfirmationPrompt: inputBox or sendBtn not found")
        return
    end
    
    self.isConfirming = true
    
    -- 保存当前代码信息用于修改
    self.pendingCodeInfo = {
        description = description,
        code = fullCode
    }
    
    -- 隐藏输入框和发送按钮
    self.inputBox.Visible = false
    self.sendBtn.Visible = false
    
    -- 获取输入框的父容器
    local inputFrame = self.inputBox.Parent
    if not inputFrame then 
        warn("[UI] showConfirmationPrompt: inputFrame not found")
        return 
    end
    
    -- 创建确认按钮容器（放在输入框位置）
    local confirmFrame = Instance.new("Frame", inputFrame)
    confirmFrame.Name = "ConfirmationFrame"
    confirmFrame.Size = UDim2.new(1, 0, 1, 0)
    confirmFrame.Position = UDim2.new(0, 0, 0, 0)
    confirmFrame.BackgroundTransparency = 1
    confirmFrame.ZIndex = 50
    
    -- 确认按钮 (左侧)
    local confirmBtn = Instance.new("TextButton", confirmFrame)
    confirmBtn.Name = "ConfirmBtn"
    confirmBtn.Size = UDim2.new(1/3, -3, 1, 0)
    confirmBtn.Position = UDim2.new(0, 0, 0, 0)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69) -- 绿色
    confirmBtn.TextColor3 = Color3.new(1, 1, 1)
    confirmBtn.Text = "✅ 执行"
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.TextSize = 13
    confirmBtn.BorderSizePixel = 0
    
    local confirmCorner = Instance.new("UICorner", confirmBtn)
    confirmCorner.CornerRadius = UDim.new(0, 6)
    
    -- 修改按钮 (中间)
    local modifyBtn = Instance.new("TextButton", confirmFrame)
    modifyBtn.Name = "ModifyBtn"
    modifyBtn.Size = UDim2.new(1/3, -3, 1, 0)
    modifyBtn.Position = UDim2.new(1/3, 2, 0, 0)
    modifyBtn.BackgroundColor3 = Color3.fromRGB(0, 123, 255) -- 蓝色
    modifyBtn.TextColor3 = Color3.new(1, 1, 1)
    modifyBtn.Text = "✏️ 修改"
    modifyBtn.Font = Enum.Font.GothamBold
    modifyBtn.TextSize = 13
    modifyBtn.BorderSizePixel = 0
    
    local modifyCorner = Instance.new("UICorner", modifyBtn)
    modifyCorner.CornerRadius = UDim.new(0, 6)
    
    -- 取消按钮 (右侧)
    local cancelBtn = Instance.new("TextButton", confirmFrame)
    cancelBtn.Name = "CancelBtn"
    cancelBtn.Size = UDim2.new(1/3, -3, 1, 0)
    cancelBtn.Position = UDim2.new(2/3, 4, 0, 0)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69) -- 红色
    cancelBtn.TextColor3 = Color3.new(1, 1, 1)
    cancelBtn.Text = "❌ 取消"
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 13
    cancelBtn.BorderSizePixel = 0
    
    local cancelCorner = Instance.new("UICorner", cancelBtn)
    cancelCorner.CornerRadius = UDim.new(0, 6)
    
    -- 保存引用
    self.confirmationFrame = confirmFrame
    
    -- 按钮事件
    confirmBtn.MouseButton1Click:Connect(function()
        self:hideConfirmationPrompt()
        if self.onConfirmCallback then
            self.onConfirmCallback()
        end
    end)
    
    modifyBtn.MouseButton1Click:Connect(function()
        -- 隐藏按钮，恢复输入框让用户输入修改建议
        confirmFrame.Visible = false
        self.inputBox.Visible = true
        self.sendBtn.Visible = true
        self.inputBox.PlaceholderText = "输入修改建议，例如：添加错误处理、改为异步执行..."
        self.inputBox.Text = ""
        self.isModifyingCode = true  -- 标记正在修改代码模式
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        self:hideConfirmationPrompt()
        if self.onCancelCallback then
            self.onCancelCallback()
        end
    end)
    
    -- 添加确认消息（显示完整代码）
    self:addMessage(string.format([[
⚠️ **需要确认脚本执行**

📝 描述: %s

📄 完整代码:
```lua
%s
```

请点击下方按钮：执行/修改/取消]], 
        description, 
        fullCode or ""
    ), false)
end

-- 设置确认回调
function UI:onConfirm(callback)
    self.onConfirmCallback = callback
end

-- 设置取消回调
function UI:onCancel(callback)
    self.onCancelCallback = callback
end

-- 隐藏确认提示
function UI:hideConfirmationPrompt()
    self.isConfirming = false
    self.isModifyingCode = false
    self.pendingCodeInfo = nil
    
    -- 恢复输入框和发送按钮
    self.inputBox.Visible = true
    self.sendBtn.Visible = true
    self.inputBox.PlaceholderText = "输入问题或指令..."
    self.inputBox.Text = ""
    
    -- 销毁确认按钮容器
    if self.confirmationFrame then
        self.confirmationFrame:Destroy()
        self.confirmationFrame = nil
    end
end

-- 清除待修改代码信息
function UI:clearPendingCodeInfo()
    self.pendingCodeInfo = nil
end

-- Markdown转Roblox RichText（处理行内格式）
local function markdownToRichText(text)
    if not text then return "" end
    
    -- 先转义特殊字符（避免与RichText标签冲突）
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    
    -- 按顺序处理，从复杂到简单
    
    -- 1. ***粗体斜体*** → <b><i>粗体斜体</i></b>
    -- 使用更精确的模式，匹配非星号字符
    text = text:gsub("%*%*%*([^%*]+)%*%*%*", "<b><i>%1</i></b>")
    
    -- 2. **粗体** → <b>粗体</b>
    text = text:gsub("%*%*([^%*]+)%*%*", "<b>%1</b>")
    
    -- 3. *斜体* → <i>斜体</i>
    -- 匹配单个星号包围的非星号内容
    text = text:gsub("%*([^%*%s][^%*]-[^%*%s])%*", "<i>%1</i>")
    -- 也匹配单个字符的情况如 *a*
    text = text:gsub("%*([^%*%s])%*", "<i>%1</i>")
    
    -- 4. __下划线__ → <u>下划线</u>
    text = text:gsub("__([^_]+)__", "<u>%1</u>")
    
    -- 5. ~~删除线~~ → <s>删除线</s>
    text = text:gsub("~~([^~]+)~~", "<s>%1</s>")
    
    -- 6. ==高亮== → <mark>高亮</mark>
    text = text:gsub("==([^=]+)==", '<mark color="#FFD700">%1</mark>')
    
    -- 7. `行内代码` → 橙色字体
    text = text:gsub("`([^`]+)`", '<font color="#FF9800">%1</font>')
    
    -- 8. 处理标题 (# 开头) - 需要按行处理
    local lines = {}
    for line in text:gmatch("[^\n]*") do
        -- ### 标题
        if line:match("^###%s+") then
            line = line:gsub("^###%s+", '<font size="16"><b>') .. "</b></font>"
        -- ## 标题
        elseif line:match("^##%s+") then
            line = line:gsub("^##%s+", '<font size="18"><b>') .. "</b></font>"
        -- # 标题
        elseif line:match("^#%s+") then
            line = line:gsub("^#%s+", '<font size="20"><b>') .. "</b></font>"
        end
        -- 列表项
        if line:match("^%s*%-%s") then
            line = line:gsub("^(%s*)%-%s", "%1• ")
        end
        table.insert(lines, line)
    end
    text = table.concat(lines, "\n")
    
    -- 9. 处理链接 [文字](url) → 文字
    text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
    
    return text
end

-- Markdown解析（处理代码块和行内格式）
local function parseMarkdown(text)
    -- 防止nil值
    if not text or type(text) ~= "string" then
        return {{type = "text", content = tostring(text or ""), richText = tostring(text or "")}}
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
                    table.insert(blocks, {
                        type = "text",
                        content = beforeText,
                        richText = markdownToRichText(beforeText)
                    })
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
                table.insert(blocks, {
                    type = "text",
                    content = text:sub(pos),
                    richText = markdownToRichText(text:sub(pos))
                })
                break
            end
        else
            -- 剩余文本
            local remaining = text:sub(pos)
            if remaining:match("%S") then
                table.insert(blocks, {
                    type = "text",
                    content = remaining,
                    richText = markdownToRichText(remaining)
                })
            end
            break
        end
    end
    
    if #blocks == 0 then
        return {{type = "text", content = text, richText = markdownToRichText(text)}}
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
            -- 文本块（支持RichText）
            local textLabel = Instance.new("TextLabel", container)
            textLabel.Size = UDim2.new(1, 0, 0, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.RichText = true  -- 启用富文本
            textLabel.Text = block.richText or block.content
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
    local listLayout = self.messageArea:FindFirstChild("UIListLayout")
    if listLayout then
        self.messageArea.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
        self.messageArea.CanvasPosition = Vector2.new(0, listLayout.AbsoluteContentSize.Y)
    end
    
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

    -- Base URL
    local baseUrlLabel = Instance.new("TextLabel", scrollFrame)
    baseUrlLabel.Size = UDim2.new(1, -8, 0, 16)
    baseUrlLabel.BackgroundTransparency = 1
    baseUrlLabel.Text = "Base URL"
    baseUrlLabel.TextColor3 = self.Theme.text
    baseUrlLabel.TextSize = 12
    baseUrlLabel.Font = Enum.Font.GothamBold
    baseUrlLabel.TextXAlignment = Enum.TextXAlignment.Left

    local baseUrlInput = Instance.new("TextBox", scrollFrame)
    baseUrlInput.Name = "BaseUrlInput"
    baseUrlInput.Size = UDim2.new(1, -8, 0, 28)
    baseUrlInput.BackgroundColor3 = self.Theme.backgroundTertiary
    baseUrlInput.BorderSizePixel = 0
    baseUrlInput.PlaceholderText = "例如: https://api.openai.com"
    baseUrlInput.PlaceholderColor3 = self.Theme.textMuted
    baseUrlInput.Text = ""
    baseUrlInput.TextColor3 = self.Theme.text
    baseUrlInput.TextSize = 12
    baseUrlInput.Font = Enum.Font.Gotham
    baseUrlInput.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(baseUrlInput, 6)

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

    -- Model Name
    local modelLabel = Instance.new("TextLabel", scrollFrame)
    modelLabel.Name = "ModelLabel"
    modelLabel.Size = UDim2.new(1, -8, 0, 16)
    modelLabel.BackgroundTransparency = 1
    modelLabel.Text = "模型名称"
    modelLabel.TextColor3 = self.Theme.text
    modelLabel.TextSize = 12
    modelLabel.Font = Enum.Font.GothamBold
    modelLabel.TextXAlignment = Enum.TextXAlignment.Left

    local modelInput = Instance.new("TextBox", scrollFrame)
    modelInput.Name = "ModelInput"
    modelInput.Size = UDim2.new(1, -8, 0, 28)
    modelInput.BackgroundColor3 = self.Theme.backgroundTertiary
    modelInput.BorderSizePixel = 0
    modelInput.PlaceholderText = "例如: gpt-4o-mini"
    modelInput.PlaceholderColor3 = self.Theme.textMuted
    modelInput.Text = ""
    modelInput.TextColor3 = self.Theme.text
    modelInput.TextSize = 12
    modelInput.Font = Enum.Font.Gotham
    modelInput.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(modelInput, 6)

    local providerBtns = {}
    local modelListFrame = Instance.new("Frame", scrollFrame)
    modelListFrame.Name = "ModelListFrame"
    modelListFrame.Visible = false
    
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
    self.baseUrlInput = baseUrlInput
    self.apiKeyInput = apiInput
    self.modelInput = modelInput
    self.scriptDirInput = dirInput
    self.confirmToggle = confirmBtn
    self.providerButtons = providerBtns
    self.modelListFrame = modelListFrame
    self.modelLabel = modelLabel
    self.saveSettingsBtn = saveBtn
    self.testConnectionBtn = testBtn
    self.tokenStatsLabel = tokenStatsLabel
    self.resetTokenBtn = resetTokenBtn
    self.runModeButtons = modeBtns

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
    
    -- 资源列表（虚拟列表）
    local resourceList = Instance.new("ScrollingFrame", resourceFrame)
    resourceList.Name = "ResourceList"
    resourceList.Size = UDim2.new(1, -16, 1, -88)
    resourceList.Position = UDim2.new(0, 8, 0, 80)
    resourceList.BackgroundColor3 = self.Theme.backgroundTertiary
    resourceList.BorderSizePixel = 0
    resourceList.ScrollBarThickness = 6
    resourceList.ScrollBarImageColor3 = self.Theme.accent
    resourceList.CanvasSize = UDim2.new(0, 0, 0, 0)
    resourceList.ScrollingDirection = Enum.ScrollingDirection.Y
    createCorner(resourceList, 8)
    
    -- 虚拟列表容器（用于定位条目）
    local listContainer = Instance.new("Frame", resourceList)
    listContainer.Name = "ListContainer"
    listContainer.Size = UDim2.new(1, 0, 1, 0)
    listContainer.BackgroundTransparency = 1
    listContainer.ClipsDescendants = false
    
    -- 虚拟列表状态
    self.virtualList = {
        container = listContainer,
        entries = {},        -- 复用的UI条目池
        visibleCount = 0,    -- 可见条目数
        scrollIndex = 0,     -- 当前滚动位置
        entryHeight = 22,    -- 每个条目高度
        flattenedTree = {},  -- 扁平化的树（用于虚拟列表）
        expandedNodes = {},  -- 展开的节点
        nodeCache = {},      -- 节点缓存
        totalNodes = 0,      -- 总节点数
    }
    
    -- 滚动事件（添加防抖防止循环）
    local lastScrollUpdate = 0
    resourceList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        local now = tick()
        if now - lastScrollUpdate < 0.05 then return end -- 50ms防抖
        lastScrollUpdate = now
        self:updateVirtualList()
    end)
    
    self.resourceView = resourceFrame
    self.resourceSearchBox = searchBox
    self.resourceList = resourceList
    self.scanBtn = scanBtn
    
    -- 设置资源持续监听
    self:setupResourceConnections()
    
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

-- 刷新资源列表显示（虚拟列表 + 树形目录）
function UI:refreshResourceList()
    -- 防抖：100ms内只允许一次刷新
    local now = tick()
    if self._lastRefreshTime and (now - self._lastRefreshTime) < 0.1 then
        return
    end
    self._lastRefreshTime = now
    
    local Scanner = _G.AIAnalyzer and _G.AIAnalyzer.Scanner
    local searchQuery = self.resourceSearchBox and self.resourceSearchBox.Text:lower() or ""
    
    -- 重置虚拟列表数据（不销毁条目，让 updateVirtualList 复用）
    local vl = self.virtualList
    if vl then
        -- 隐藏所有条目，等待复用
        if not vl.entries then vl.entries = {} end
        for _, entry in ipairs(vl.entries) do
            if entry then
                entry.Visible = false
                entry:SetAttribute("currentNodeKey", nil)
            end
        end
        vl.flattenedTree = {}
        vl.totalNodes = 0
    end
    
    if not Scanner or not Scanner.cache.typeIndex then
        self:showVirtualMessage("请先扫描游戏资源")
        return
    end
    
    -- 获取资源
    local resources = {}
    if self.currentResourceTab == "search" then
        if searchQuery ~= "" then
            local result = Scanner:search(searchQuery, {limit = 500})
            resources = result.results or {}
        end
    elseif self.currentResourceTab == "remotes" then
        for typeName, objects in pairs(Scanner.cache.typeIndex) do
            if typeName:find("Remote") then
                for _, obj in ipairs(objects) do
                    table.insert(resources, obj)
                end
            end
        end
    elseif self.currentResourceTab == "scripts" then
        for _, typeName in ipairs({"LocalScript", "Script", "ModuleScript"}) do
            local objects = Scanner.cache.typeIndex[typeName]
            if objects then
                for _, obj in ipairs(objects) do
                    table.insert(resources, obj)
                end
            end
        end
    else
        -- 全部：构建树形结构
        resources = Scanner.cache.objects or {}
    end
    
    -- 构建节点树
    self:buildNodeTree(resources)
    
    -- 扁平化树用于虚拟列表
    self:flattenNodeTree()
    
    -- 更新虚拟列表
    self:updateVirtualList()
end

-- 设置资源持续监听（基于DEX脚本模式）
function UI:setupResourceConnections()
    -- 先清理旧连接
    self:teardownResourceConnections()
    
    if not self.resourceAutoRefresh then return end
    
    local Scanner = _G.AIAnalyzer and _G.AIAnalyzer.Scanner
    local services = Scanner and Scanner.config and Scanner.config.services or {}
    
    -- 防抖刷新函数
    local function scheduleRefresh()
        if self.resourceRefreshDebounce then return end
        self.resourceRefreshDebounce = true
        
        task.delay(0.2, function()
            self.resourceRefreshDebounce = false
            -- 只有在资源视图可见时才刷新
            if self.currentView == "resources" and self.resourceView and self.resourceView.Visible then
                -- 标记节点缓存需要更新
                local vl = self.virtualList
                if vl then
                    -- 清除展开节点的子节点缓存，让它们重新加载
                    for key, _ in pairs(vl.expandedNodes) do
                        local node = self:findNodeByKey(key)
                        if node then
                            node.childrenLoaded = false
                            node.children = nil
                        end
                    end
                end
                self:refreshResourceList()
            end
        end)
    end
    
    -- 监听各服务的变化
    for _, serviceInfo in ipairs(services) do
        local service = serviceInfo.service
        if service then
            -- 监听子对象添加
            local conn1 = service.ChildAdded:Connect(function(child)
                scheduleRefresh()
            end)
            table.insert(self.resourceConnections, conn1)
            
            -- 监听子对象移除
            local conn2 = service.ChildRemoved:Connect(function(child)
                scheduleRefresh()
            end)
            table.insert(self.resourceConnections, conn2)
            
            -- 监听后代变化（更精细的监听）
            local conn3 = service.DescendantAdded:Connect(function(descendant)
                scheduleRefresh()
            end)
            table.insert(self.resourceConnections, conn3)
            
            local conn4 = service.DescendantRemoving:Connect(function(descendant)
                scheduleRefresh()
            end)
            table.insert(self.resourceConnections, conn4)
        end
    end
    
    -- 监听全局变化（备用）
    local conn5 = game.ItemChanged:Connect(function(obj, prop)
        if prop == "Parent" or prop == "Name" then
            scheduleRefresh()
        end
    end)
    table.insert(self.resourceConnections, conn5)
end

-- 清理资源监听连接
function UI:teardownResourceConnections()
    for _, conn in ipairs(self.resourceConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    self.resourceConnections = {}
end

-- 切换自动刷新
function UI:toggleResourceAutoRefresh()
    self.resourceAutoRefresh = not self.resourceAutoRefresh
    
    if self.resourceAutoRefresh then
        self:setupResourceConnections()
    else
        self:teardownResourceConnections()
    end
    
    return self.resourceAutoRefresh
end

-- 构建节点树（即时版本：直接使用游戏服务，不遍历缓存）
function UI:buildNodeTree(resources)
    local vl = self.virtualList
    vl.nodeCache = {}
    
    -- 获取Scanner配置的服务列表
    local Scanner = _G.AIAnalyzer and _G.AIAnalyzer.Scanner
    local services = Scanner and Scanner.config and Scanner.config.services or {}
    
    -- 直接从游戏服务创建节点（不遍历资源缓存）
    local serviceNodes = {}
    
    for _, serviceInfo in ipairs(services) do
        local serviceName = serviceInfo.name
        local service = serviceInfo.service
        
        if service then
            local childCount = #service:GetChildren()
            table.insert(serviceNodes, {
                name = serviceName,
                className = "Service",
                isFolder = true,
                children = nil,
                childrenLoaded = false,
                depth = 0,
                count = childCount,
                path = serviceName,
                instance = service
            })
        end
    end
    
    -- 排序
    table.sort(serviceNodes, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    
    vl.nodeCache = serviceNodes
end

-- 通过key查找节点（支持递归搜索子节点）
function UI:findNodeByKey(nodeKey, nodes)
    local vl = self.virtualList
    if not vl then return nil end
    
    -- 如果没有传入nodes，从顶层开始搜索
    if not nodes then
        nodes = vl.nodeCache
    end
    
    if not nodes then return nil end
    
    -- 搜索当前层级
    for _, n in ipairs(nodes) do
        if (n.path or n.name) == nodeKey then
            return n
        end
    end
    
    -- 递归搜索子节点
    for _, n in ipairs(nodes) do
        if n.children then
            -- n.children 是 table，需要转换
            local childrenList = {}
            for _, child in pairs(n.children) do
                table.insert(childrenList, child)
            end
            local found = self:findNodeByKey(nodeKey, childrenList)
            if found then return found end
        end
    end
    
    return nil
end

-- 懒加载子节点（直接从游戏实例获取）
function UI:loadNodeChildren(node)
    if node.childrenLoaded then return end
    
    node.children = {}
    node.childrenLoaded = true
    
    local instance = node.instance
    if not instance then return end
    
    -- 直接从游戏实例获取子对象
    local children = instance:GetChildren()
    
    -- 按名称分组
    local nameGroups = {}
    for _, child in ipairs(children) do
        local name = child.Name
        if not nameGroups[name] then
            nameGroups[name] = {}
        end
        table.insert(nameGroups[name], child)
    end
    
    -- 创建子节点
    for childName, group in pairs(nameGroups) do
        local childCount = #group
        local firstChild = group[1]
        local grandChildren = #firstChild:GetChildren()
        
        node.children[childName] = {
            name = childName,
            className = childCount > 1 and ("x" .. childCount) or firstChild.ClassName,
            isFolder = grandChildren > 0 or childCount > 1,
            children = nil,
            childrenLoaded = false,
            depth = (node.depth or 0) + 1,
            count = grandChildren > 0 and grandChildren or childCount,
            path = node.path .. "." .. childName,
            instance = firstChild,
            parent = node,
            siblings = childCount > 1 and group or nil
        }
    end
end

-- 递归添加到节点树
function UI:addToNodeTree(parentNode, obj, path, depth)
    if not parentNode or not path then return end
    
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    
    -- 至少需要2个部分（服务名 + 对象名）
    if #parts < 2 then return end
    
    -- 跳过已经处理的服务名
    local current = parentNode
    if not current.children then
        current.children = {}
    end
    
    -- 遍历中间的文件夹层级
    for i = depth + 1, #parts - 1 do
        local partName = parts[i]
        if not partName then break end
        
        if not current.children[partName] then
            current.children[partName] = {
                name = partName,
                className = "Folder",
                isFolder = true,
                children = {},
                depth = i - 1,
                parent = current,
                count = 0
            }
        end
        
        -- 确保 children 存在
        if not current.children[partName].children then
            current.children[partName].children = {}
        end
        
        current = current.children[partName]
    end
    
    -- 添加最终对象
    local objName = parts[#parts]
    if objName and current and current.children then
        current.children[objName] = {
            name = objName,
            className = obj.className or "Unknown",
            isFolder = false,
            instance = obj.instance,
            path = obj.path,
            depth = #parts - 1,
            parent = current,
            objData = obj
        }
    end
end

-- 扁平化树用于虚拟列表渲染
function UI:flattenNodeTree()
    local vl = self.virtualList
    vl.flattenedTree = {}
    
    local function flatten(nodes, depth)
        if not nodes then return end
        
        -- 排序：文件夹在前，然后按名称
        local sorted = {}
        for key, node in pairs(nodes) do
            if type(key) == "number" or type(key) == "string" then
                table.insert(sorted, node)
            end
        end
        table.sort(sorted, function(a, b)
            if a.isFolder ~= b.isFolder then
                return a.isFolder
            end
            if a.count and b.count and a.count ~= b.count then
                return a.count > b.count
            end
            return (a.name or "") < (b.name or "")
        end)
        
        for _, node in ipairs(sorted) do
            table.insert(vl.flattenedTree, {
                node = node,
                depth = depth
            })
            
            -- 如果展开，先懒加载子节点再递归
            local nodeKey = node.path or node.name
            if node.isFolder and vl.expandedNodes[nodeKey] then
                if not node.childrenLoaded then
                    self:loadNodeChildren(node)
                end
                if node.children and next(node.children) then
                    flatten(node.children, depth + 1)
                end
            end
        end
    end
    
    flatten(vl.nodeCache, 0)
    vl.totalNodes = #vl.flattenedTree
    
    -- 更新滚动区域大小
    local canvasHeight = vl.totalNodes * vl.entryHeight
    self.resourceList.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
end

-- 显示虚拟列表消息
function UI:showVirtualMessage(text)
    local vl = self.virtualList
    vl.flattenedTree = {{
        node = {name = text, className = "", isFolder = false},
        depth = 0
    }}
    vl.totalNodes = 1
    self.resourceList.CanvasSize = UDim2.new(0, 0, 0, 22)
    self:updateVirtualList()
end

-- 更新虚拟列表（核心渲染函数）
function UI:updateVirtualList()
    local vl = self.virtualList
    if not vl or not vl.container then 
        return 
    end
    
    local scrollPos = self.resourceList.CanvasPosition.Y
    local viewHeight = self.resourceList.AbsoluteSize.Y
    local entryHeight = vl.entryHeight
    
    -- 确保viewHeight有效
    if viewHeight <= 0 then viewHeight = 400 end
    
    -- 计算可见范围
    local startIndex = math.floor(scrollPos / entryHeight) + 1
    local visibleCount = math.max(20, math.ceil(viewHeight / entryHeight) + 5) -- 至少20个条目
    local endIndex = math.min(startIndex + visibleCount, vl.totalNodes)
    
    
    -- 确保有足够的条目
    while #vl.entries < visibleCount do
        local entry = self:createVirtualEntry(#vl.entries + 1)
        table.insert(vl.entries, entry)
    end
    
    -- 隐藏所有条目先
    for i, entry in ipairs(vl.entries) do
        entry.Visible = false
    end
    
    -- 更新需要的条目
    for i = 1, visibleCount do
        local entry = vl.entries[i]
        if not entry then break end
        
        local dataIndex = startIndex + i - 1
        local nodeInfo = vl.flattenedTree[dataIndex]
        
        if nodeInfo and dataIndex <= vl.totalNodes then
            self:updateVirtualEntry(entry, nodeInfo.node, nodeInfo.depth, dataIndex)
            entry.Visible = true
            entry.Position = UDim2.new(0, 0, 0, (dataIndex - 1) * entryHeight)
        end
    end
end

-- 创建虚拟条目
function UI:createVirtualEntry(index)
    local vl = self.virtualList
    local entry = Instance.new("Frame", vl.container)
    entry.Name = "Entry" .. index
    entry.Size = UDim2.new(1, 0, 0, vl.entryHeight)
    entry.BackgroundColor3 = self.Theme.backgroundSecondary
    entry.BorderSizePixel = 0
    entry:SetAttribute("entryIndex", index)
    
    -- 展开按钮（用TextLabel避免阻挡点击）
    local expandBtn = Instance.new("TextLabel", entry)
    expandBtn.Name = "Expand"
    expandBtn.Size = UDim2.new(0, 18, 1, 0)
    expandBtn.Position = UDim2.new(0, 0, 0, 0)
    expandBtn.BackgroundTransparency = 1
    expandBtn.Text = ""
    expandBtn.TextSize = 10
    expandBtn.Font = Enum.Font.Gotham
    expandBtn.TextColor3 = self.Theme.textMuted
    expandBtn.ZIndex = 2
    
    -- 图标
    local icon = Instance.new("TextLabel", entry)
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 18, 1, 0)
    icon.Position = UDim2.new(0, 18, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "📄"
    icon.TextSize = 12
    icon.Font = Enum.Font.Gotham
    
    -- 名称
    local name = Instance.new("TextLabel", entry)
    name.Name = "Name"
    name.Size = UDim2.new(1, -100, 1, 0)
    name.Position = UDim2.new(0, 38, 0, 0)
    name.BackgroundTransparency = 1
    name.Text = ""
    name.TextColor3 = self.Theme.text
    name.TextSize = 11
    name.Font = Enum.Font.GothamSemibold
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- 类名
    local class = Instance.new("TextLabel", entry)
    class.Name = "Class"
    class.Size = UDim2.new(0, 55, 1, 0)
    class.Position = UDim2.new(1, -55, 0, 0)
    class.BackgroundTransparency = 1
    class.Text = ""
    class.TextColor3 = self.Theme.textMuted
    class.TextSize = 9
    class.Font = Enum.Font.Code
    class.TextXAlignment = Enum.TextXAlignment.Right
    
    -- 点击区域
    local clickArea = Instance.new("TextButton", entry)
    clickArea.Name = "ClickArea"
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.ZIndex = 10
    
    return entry
end

-- 更新虚拟条目内容
function UI:updateVirtualEntry(entry, node, depth, index)
    -- 防护检查
    if not entry or not entry.Parent then 
        return 
    end
    
    local vl = self.virtualList
    local expandBtn = entry:FindFirstChild("Expand")
    local icon = entry:FindFirstChild("Icon")
    local name = entry:FindFirstChild("Name")
    local class = entry:FindFirstChild("Class")
    local clickArea = entry:FindFirstChild("ClickArea")
    
    -- 如果子元素不存在，跳过
    if not expandBtn or not icon or not name or not class or not clickArea then
        return
    end
    
    -- 缩进
    local indent = depth * 16
    expandBtn.Position = UDim2.new(0, indent, 0, 0)
    icon.Position = UDim2.new(0, indent + 18, 0, 0)
    name.Position = UDim2.new(0, indent + 38, 0, 0)
    
    -- 当前节点的key
    local nodeKey = node.path or node.name
    
    -- 检查是否需要重新绑定（只在节点变化时重新绑定）
    local currentNodeKey = entry:GetAttribute("currentNodeKey")
    local needRebind = (currentNodeKey ~= nodeKey)
    
    -- 先设置属性，再检查
    entry:SetAttribute("currentNodeKey", nodeKey)
    
    -- 展开/折叠按钮（使用count判断是否有子节点）
    local hasChildren = node.isFolder and (node.count and node.count > 0 or (node.children and next(node.children)))

    if hasChildren then
        local isExpanded = vl.expandedNodes[nodeKey]
        expandBtn.Text = isExpanded and "▼" or "▶"
        expandBtn.Visible = true
        
        -- 只在节点变化时重新绑定连接
        if needRebind and clickArea then
            local entryIdx = entry.Name
            if not self.entryConnections then self.entryConnections = {} end
            
            -- 断开旧连接
            if self.entryConnections[entryIdx] then
                for _, conn in ipairs(self.entryConnections[entryIdx]) do
                    if conn then pcall(function() conn:Disconnect() end) end
                end
            end
            self.entryConnections[entryIdx] = {}
            
            -- 创建新连接（检查长按标志，避免长按后触发点击）
            table.insert(self.entryConnections[entryIdx], clickArea.MouseButton1Click:Connect(function()
                -- 如果长按已触发，不执行展开/折叠
                if entry:GetAttribute("longPressTriggered") then
                    return
                end
                local key = entry:GetAttribute("currentNodeKey")
                local current = self:findNodeByKey(key)
                if current and not current.childrenLoaded then
                    self:loadNodeChildren(current)
                end
                vl.expandedNodes[key] = not vl.expandedNodes[key]
                self:flattenNodeTree()
                self:updateVirtualList()
            end))
        end
    else
        expandBtn.Visible = false
        
        -- 只在节点变化时重新绑定连接
        if needRebind and clickArea then
            local entryIdx = entry.Name
            if not self.entryConnections then self.entryConnections = {} end
            
            -- 断开旧连接
            if self.entryConnections[entryIdx] then
                for _, conn in ipairs(self.entryConnections[entryIdx]) do
                    if conn then pcall(function() conn:Disconnect() end) end
                end
            end
            self.entryConnections[entryIdx] = {}
            
            -- 创建新连接（用于发送AI信息，检查长按标志）
            table.insert(self.entryConnections[entryIdx], clickArea.MouseButton1Click:Connect(function()
                -- 如果长按已触发，不执行点击动作
                if entry:GetAttribute("longPressTriggered") then
                    return
                end
                local key = entry:GetAttribute("currentNodeKey")
                local current = self:findNodeByKey(key)
                if current and current.instance then
                    local objData = {
                        name = node.name,
                        className = node.className,
                        path = node.path,
                        instance = node.instance
                    }
                    if self.resourceCallbacks and self.resourceCallbacks.sendToAI then
                        self.resourceCallbacks.sendToAI(objData)
                    end
                end
            end))
        end
    end
    
    -- 图标
    if node.isFolder then
        icon.Text = "📁"
    elseif node.className and node.className:find("Remote") then
        icon.Text = "📤"
    elseif node.className and node.className:find("Script") then
        icon.Text = "📝"
    else
        icon.Text = "📄"
    end
    
    -- 名称
    local displayCount = node.count and node.count > 0 and (" (" .. node.count .. ")") or ""
    name.Text = node.name .. displayCount
    
    -- 类名
    class.Text = node.className or ""
    
    -- 悬停效果（每次都重新绑定，因为entry可能被复用）
    if not self.entryHoverConnections then self.entryHoverConnections = {} end
    if self.entryHoverConnections[entry.Name] then
        for _, conn in ipairs(self.entryHoverConnections[entry.Name]) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
    end
    self.entryHoverConnections[entry.Name] = {
        entry.MouseEnter:Connect(function()
            entry.BackgroundColor3 = self.Theme.accent
        end),
        entry.MouseLeave:Connect(function()
            entry.BackgroundColor3 = self.Theme.backgroundSecondary
        end)
    }
    
    -- 长按/右键菜单 - 在节点变化时重新绑定
    if needRebind and clickArea then
        -- 确保 entryConnections 已初始化（不覆盖已有的连接）
        if not self.entryConnections then self.entryConnections = {} end
        if not self.entryConnections[entry.Name] then 
            self.entryConnections[entry.Name] = {} 
        end
        -- 注意：不清空已有连接，因为 hasChildren/else 分支已经添加了点击连接
        
        -- 长按计时器和标志
        local longPressTimer = nil
        
        -- 长按检测（MouseButton1Down开始计时）
        local conn1 = clickArea.MouseButton1Down:Connect(function()
            -- 重置长按标志
            entry:SetAttribute("longPressTriggered", false)
            longPressTimer = task.delay(2, function()
                longPressTimer = nil
                -- 设置长按已触发标志
                entry:SetAttribute("longPressTriggered", true)
                local key = entry:GetAttribute("currentNodeKey")
                local current = self:findNodeByKey(key)
                if current then
                    local mousePos = UserInputService:GetMouseLocation()
                    self:showContextMenu(current, Vector2.new(mousePos.X - 10, mousePos.Y - 10))
                end
            end)
        end)
        table.insert(self.entryConnections[entry.Name], conn1)
        
        -- MouseButton1Up取消长按
        local conn2 = clickArea.MouseButton1Up:Connect(function()
            if longPressTimer then
                task.cancel(longPressTimer)
                longPressTimer = nil
            end
        end)
        table.insert(self.entryConnections[entry.Name], conn2)
        
        -- MouseLeave取消长按
        local conn3 = clickArea.MouseLeave:Connect(function()
            if longPressTimer then
                task.cancel(longPressTimer)
                longPressTimer = nil
            end
        end)
        table.insert(self.entryConnections[entry.Name], conn3)
        
        -- 右键菜单（使用Down事件更可靠）
        local conn4 = clickArea.MouseButton2Down:Connect(function()
            local key = entry:GetAttribute("currentNodeKey")
            local current = self:findNodeByKey(key)
            if current then
                local mousePos = UserInputService:GetMouseLocation()
                self:showContextMenu(current, Vector2.new(mousePos.X - 10, mousePos.Y - 10))
            end
        end)
        table.insert(self.entryConnections[entry.Name], conn4)
    end
end

-- 清空资源列表
function UI:clearResourceList()
    for _, child in pairs(self.resourceList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
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

-- 更新连接状态指示器颜色
function UI:updateStatus(status, color)
    -- 状态指示器颜色
    if self.statusIndicator then
        self.statusIndicator.BackgroundColor3 = color or self.Theme.warning
    end
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

-- 更新上下文状态显示
function UI:updateContextStatus(contextStatus)
    if not contextStatus then return end
    
    -- 更新上下文使用百分比
    if self.contextLabel then
        local percent = contextStatus.usagePercent or 0
        local remainingPercent = 100 - percent
        
        -- 根据使用量设置颜色
        local color
        if percent < 50 then
            color = Color3.fromRGB(76, 175, 80)  -- 绿色
        elseif percent < 70 then
            color = Color3.fromRGB(255, 193, 7)  -- 黄色
        else
            color = Color3.fromRGB(244, 67, 54)  -- 红色
        end
        
        self.contextLabel.Text = string.format("📊 上下文: %d%% 剩余", remainingPercent)
        self.contextLabel.TextColor3 = color
    end
    
    -- 更新Token消耗显示
    if self.tokenLabel then
        local tokens = contextStatus.totalTokens or 0
        local maxTokens = contextStatus.maxTokens or 8192
        self.tokenLabel.Text = string.format("消耗: %d / %d tokens", tokens, maxTokens)
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
    -- 清理资源监听连接
    self:teardownResourceConnections()
    
    -- 清理上下文菜单
    self:closeContextMenu()
    
    -- 清理条目连接
    if self.entryConnections then
        for entryName, connections in pairs(self.entryConnections) do
            for _, conn in ipairs(connections) do
                if conn and conn.Connected then
                    conn:Disconnect()
                end
            end
        end
        self.entryConnections = {}
    end
    
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
    -- 先检查执行器是否支持文件浏览
    local exec = _G.AIAnalyzer and _G.AIAnalyzer.Executor
    if not exec or not exec.listfiles then
        self:addMessage("⚠️ 当前执行器不支持文件浏览功能", false)
        return
    end
    
    -- 如果没有指定初始路径，尝试检测执行器支持的路径
    local startPath = initialPath
    if not startPath then
        -- 尝试多种路径格式
        local testPaths = {"workspace", "scripts", "", "."}
        for _, testPath in ipairs(testPaths) do
            local success, result = pcall(exec.listfiles, testPath)
            if success and result then
                startPath = testPath
                break
            end
        end
        -- 如果都不行，默认用空字符串
        startPath = startPath or ""
    end
    
    self:createFileBrowser()
    self.fileBrowserFrame.Visible = true
    self.fileBrowserEditor.Visible = false
    self.fileNameInput.Visible = false
    self.fileBrowserFrame.Size = UDim2.new(0, 400, 0, 350)
    self.fileBrowserSelectedFile = nil
    self:navigateToFolder(startPath)
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
    if not exec then
        self:hideFileBrowser()
        return
    end
    
    self.fileBrowserCurrentPath = path
    -- 显示路径名称，空路径显示为"根目录"
    local displayName = (path == "" or path == ".") and "根目录" or path
    self.fileBrowserPathLabel.Text = "📂 " .. displayName
    
    -- 清空列表
    for _, child in ipairs(self.fileBrowserList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- 返回上一级
    if path ~= "" and path ~= "workspace" then
        local parentPath = path:match("^(.+)/[^/]+$") or ""
        self:addFileBrowserItem("📁 ..", "folder", parentPath, true)
    end
    
    -- 获取文件列表
    local success, filesOrErr = pcall(exec.listfiles, path)
    if not success then
        -- 显示具体错误信息
        local errMsg = tostring(filesOrErr):sub(1, 50)
        self:addFileBrowserItem("❌ 读取失败: " .. errMsg, "error", nil, false)
        -- 尝试使用空路径（根目录）
        if path ~= "" then
            self:addFileBrowserItem("🔄 尝试打开根目录", "folder", "", true)
        end
        return
    end
    
    local files = filesOrErr
    if not files then
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
    
    self.fileBrowserSelectedFile = path
    
    -- 将文件路径追加到输入框现有文本后面
    if self.inputBox then
        -- 设置标志位，防止触发 checkFileBrowserTrigger
        self.isSettingFilePath = true
        
        local filePathStr = "@" .. path .. " "
        
        -- 如果有保存的前置文本，追加到后面
        if self.textBeforeFileSelect and self.textBeforeFileSelect ~= "" then
            self.inputBox.Text = self.textBeforeFileSelect .. " " .. filePathStr
        else
            self.inputBox.Text = filePathStr
        end
        
        -- 清除保存的前置文本和标志位
        self.textBeforeFileSelect = nil
        self.isSettingFilePath = nil
    end
    
    -- 关闭文件浏览器
    self:hideFileBrowser()
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
    -- 如果文件浏览器已经打开或正在选择文件，不处理
    if self.fileBrowserFrame and self.fileBrowserFrame.Visible then
        return
    end
    
    -- 如果正在设置文件路径，跳过
    if self.isSettingFilePath then
        return
    end
    
    local text = self.inputBox.Text
    -- 检测 @ 字符（文本末尾或光标位置）
    if text:sub(-1) == "@" then
        -- 保存当前文本（不含@），以便选择文件后追加
        self.textBeforeFileSelect = text:sub(1, -2)
        self:showFileBrowser()
        -- 移除 @ 字符
        self.inputBox.Text = self.textBeforeFileSelect
    end
end

-- 显示上下文菜单
function UI:showContextMenu(node, position)
    -- 关闭已有菜单
    self:closeContextMenu()
    
    if not node then return end
    if not self.mainFrame then return end
    
    -- 创建菜单容器
    local menu = Instance.new("Frame", self.mainFrame)
    menu.Name = "ContextMenu"
    menu.Size = UDim2.new(0, 160, 0, 0)
    menu.Position = UDim2.new(0, position.X, 0, position.Y)
    menu.BackgroundColor3 = self.Theme.backgroundSecondary
    menu.BorderSizePixel = 1
    menu.BorderColor3 = self.Theme.border
    menu.ZIndex = 100
    menu.AutomaticSize = Enum.AutomaticSize.Y
    createCorner(menu, 6)
    
    -- 添加阴影效果
    local stroke = Instance.new("UIStroke", menu)
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Transparency = 0.7
    stroke.Thickness = 2
    
    local layout = Instance.new("UIListLayout", menu)
    layout.Padding = UDim.new(0, 2)
    
    -- 菜单项配置
    local menuItems = {
        {text = "📋 复制路径", action = function()
            if node.path then
                if setclipboard then
                    local ok = pcall(setclipboard, node.path)
                    if ok then
                        self:addMessage("✅ 路径已复制: " .. node.path, false)
                    else
                        self:addMessage("❌ 复制失败", false)
                    end
                else
                    self:addMessage("⚠️ 当前执行器不支持剪贴板", false)
                end
            end
        end},
        {text = "📝 复制名称", action = function()
            if node.name then
                if setclipboard then
                    local ok = pcall(setclipboard, node.name)
                    if ok then
                        self:addMessage("✅ 名称已复制: " .. node.name, false)
                    else
                        self:addMessage("❌ 复制失败", false)
                    end
                else
                    self:addMessage("⚠️ 当前执行器不支持剪贴板", false)
                end
            end
        end},
    }
    
    -- 如果是脚本类型，添加查看源码选项
    if node.className and node.className:find("Script") and node.instance then
        table.insert(menuItems, {text = "👁️ 查看源码", action = function()
            if decompile then
                local success, source = pcall(decompile, node.instance)
                if success and source then
                    self:addMessage("```lua\n" .. source .. "\n```", false)
                else
                    self:addMessage("❌ 无法获取源码: " .. tostring(source), false)
                end
            else
                self:addMessage("⚠️ 当前执行器不支持反编译", false)
            end
        end})
    end
    
    -- 添加询问AI选项
    table.insert(menuItems, {text = "🤖 询问AI", action = function()
        if self.resourceCallbacks and self.resourceCallbacks.sendToAI then
            self.resourceCallbacks.sendToAI({
                name = node.name,
                className = node.className,
                path = node.path,
                instance = node.instance
            })
        end
    end})
    
    -- 如果是Remote，添加调用选项
    if node.className and node.className:find("Remote") and node.instance then
        table.insert(menuItems, {text = "📤 调用Remote", action = function()
            self:addMessage("📡 Remote路径: " .. tostring(node.path), false)
            if node.className:find("Function") then
                self:addMessage("类型: RemoteFunction - 使用 InvokeServer()", false)
            else
                self:addMessage("类型: RemoteEvent - 使用 FireServer()", false)
            end
        end})
    end
    
    -- 创建菜单项按钮
    for _, item in ipairs(menuItems) do
        local btn = Instance.new("TextButton", menu)
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.BackgroundTransparency = 1
        btn.Text = "  " .. item.text
        btn.TextColor3 = self.Theme.text
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.ZIndex = 101
        
        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = self.Theme.accent
            btn.BackgroundTransparency = 0.3
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundTransparency = 1
        end)
        
        btn.MouseButton1Click:Connect(function()
            item.action()
            self:closeContextMenu()
        end)
    end
    
    -- 保存菜单引用
    self.contextMenu = menu
    
    -- 点击其他地方关闭菜单
    task.wait(0.1)  -- 等待菜单渲染完成
    
    self.contextMenuConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
            local mousePos = UserInputService:GetMouseLocation()
            
            -- 检查点击是否在菜单范围内
            local menuFrame = self.contextMenu
            if menuFrame and menuFrame.Parent then
                local menuPos = menuFrame.AbsolutePosition
                local menuSize = menuFrame.AbsoluteSize
                
                local inMenu = mousePos.X >= menuPos.X and mousePos.X <= menuPos.X + menuSize.X
                            and mousePos.Y >= menuPos.Y and mousePos.Y <= menuPos.Y + menuSize.Y
                
                if not inMenu then
                    self:closeContextMenu()
                end
            else
                -- 菜单已不存在，关闭连接
                self:closeContextMenu()
            end
        end
    end)
end

-- 关闭上下文菜单
function UI:closeContextMenu()
    if self.contextMenuConnection then
        self.contextMenuConnection:Disconnect()
        self.contextMenuConnection = nil
    end
    if self.contextMenu then
        self.contextMenu:Destroy()
        self.contextMenu = nil
    end
end

return UI