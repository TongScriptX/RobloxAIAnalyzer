--[[
    Roblox AI Resource Analyzer - UI Module
    Version: 1.0.0
    
    图形用户界面模块
]]

local UI = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- UI主题配置
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

-- 创建圆角
local function createCorner(parent, radius)
    local corner = Instance.new("UICorner", parent)
    corner.CornerRadius = UDim.new(0, radius or 8)
    return corner
end

-- 创建内边距
local function createPadding(parent, padding)
    local pad = Instance.new("UIPadding", parent)
    pad.PaddingTop = UDim.new(0, padding)
    pad.PaddingBottom = UDim.new(0, padding)
    pad.PaddingLeft = UDim.new(0, padding)
    pad.PaddingRight = UDim.new(0, padding)
    return pad
end

-- 创建主窗口
function UI:createMainWindow()
    -- 主ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RobloxAIAnalyzer"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    -- 主框架
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 650, 0, 480)
    mainFrame.Position = UDim2.new(0.5, -325, 0.5, -240)
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
    titleBar.Size = UDim2.new(1, 0, 0, 45)
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
    titleText.Size = UDim2.new(1, -100, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "AI Resource Analyzer"
    titleText.TextColor3 = self.Theme.text
    titleText.TextSize = 18
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- 状态指示器
    local statusIndicator = Instance.new("Frame", titleBar)
    statusIndicator.Name = "StatusIndicator"
    statusIndicator.Size = UDim2.new(0, 10, 0, 10)
    statusIndicator.Position = UDim2.new(1, -80, 0.5, -5)
    statusIndicator.BackgroundColor3 = self.Theme.warning
    statusIndicator.BorderSizePixel = 0
    createCorner(statusIndicator, 5)
    
    local statusText = Instance.new("TextLabel", titleBar)
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(0, 60, 1, 0)
    statusText.Position = UDim2.new(1, -65, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "未连接"
    statusText.TextColor3 = self.Theme.textSecondary
    statusText.TextSize = 12
    statusText.Font = Enum.Font.Gotham
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- 关闭按钮
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0.5, -15)
    closeBtn.BackgroundColor3 = self.Theme.error
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    createCorner(closeBtn, 6)
    
    -- 最小化按钮
    local minBtn = Instance.new("TextButton", titleBar)
    minBtn.Name = "MinButton"
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -70, 0.5, -15)
    minBtn.BackgroundColor3 = self.Theme.warning
    minBtn.BorderSizePixel = 0
    minBtn.Text = "-"
    minBtn.TextColor3 = Color3.new(0, 0, 0)
    minBtn.TextSize = 16
    minBtn.Font = Enum.Font.GothamBold
    createCorner(minBtn, 6)
    
    -- 内容区域
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, 0, 1, -50)
    contentFrame.Position = UDim2.new(0, 0, 0, 45)
    contentFrame.BackgroundTransparency = 1
    
    -- 侧边栏
    local sidebar = Instance.new("Frame", contentFrame)
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 160, 1, -10)
    sidebar.Position = UDim2.new(0, 5, 0, 5)
    sidebar.BackgroundColor3 = self.Theme.backgroundSecondary
    sidebar.BorderSizePixel = 0
    createCorner(sidebar, 8)
    
    -- 主内容区
    local mainContent = Instance.new("Frame", contentFrame)
    mainContent.Name = "MainContent"
    mainContent.Size = UDim2.new(1, -175, 1, -10)
    mainContent.Position = UDim2.new(0, 170, 0, 5)
    mainContent.BackgroundColor3 = self.Theme.backgroundSecondary
    mainContent.BorderSizePixel = 0
    createCorner(mainContent, 8)
    
    -- 保存引用
    self.screenGui = screenGui
    self.mainFrame = mainFrame
    self.titleBar = titleBar
    self.statusIndicator = statusIndicator
    self.statusText = statusText
    self.sidebar = sidebar
    self.mainContent = mainContent
    
    -- 设置拖动
    self:setupDrag(titleBar, mainFrame)
    
    -- 设置关闭/最小化
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    minBtn.MouseButton1Click:Connect(function()
        if mainFrame.Size.X.Scale > 0 then
            mainFrame.Size = UDim2.new(0, 200, 0, 45)
        else
            mainFrame.Size = UDim2.new(0, 650, 0, 480)
        end
    end)
    
    return screenGui
end

-- 创建侧边栏按钮
function UI:createSidebarButton(name, icon, callback)
    local btn = Instance.new("TextButton", self.sidebar)
    btn.Name = name
    btn.Size = UDim2.new(1, -10, 0, 40)
    btn.Position = UDim2.new(0, 5, 0, #self.sidebar:GetChildren() * 45 + 5)
    btn.BackgroundColor3 = self.Theme.backgroundTertiary
    btn.BorderSizePixel = 0
    btn.Text = "  " .. icon .. "  " .. name
    btn.TextColor3 = self.Theme.text
    btn.TextSize = 14
    btn.Font = Enum.Font.Gotham
    btn.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(btn, 6)
    createPadding(btn, 10)
    
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
    messageArea.Size = UDim2.new(1, -20, 1, -60)
    messageArea.Position = UDim2.new(0, 10, 0, 10)
    messageArea.BackgroundColor3 = self.Theme.backgroundTertiary
    messageArea.BorderSizePixel = 0
    messageArea.ScrollBarThickness = 6
    messageArea.ScrollBarImageColor3 = self.Theme.accent
    createCorner(messageArea, 8)
    
    local listLayout = Instance.new("UIListLayout", messageArea)
    listLayout.Padding = UDim.new(0, 8)
    
    -- 输入区域
    local inputFrame = Instance.new("Frame", chatFrame)
    inputFrame.Name = "InputFrame"
    inputFrame.Size = UDim2.new(1, -20, 0, 40)
    inputFrame.Position = UDim2.new(0, 10, 1, -50)
    inputFrame.BackgroundColor3 = self.Theme.backgroundTertiary
    inputFrame.BorderSizePixel = 0
    createCorner(inputFrame, 8)
    
    local inputBox = Instance.new("TextBox", inputFrame)
    inputBox.Name = "InputBox"
    inputBox.Size = UDim2.new(1, -60, 1, 0)
    inputBox.Position = UDim2.new(0, 10, 0, 0)
    inputBox.BackgroundTransparency = 1
    inputBox.PlaceholderText = "输入问题或指令..."
    inputBox.PlaceholderColor3 = self.Theme.textMuted
    inputBox.Text = ""
    inputBox.TextColor3 = self.Theme.text
    inputBox.TextSize = 14
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.TextWrapped = true
    
    local sendBtn = Instance.new("TextButton", inputFrame)
    sendBtn.Name = "SendButton"
    sendBtn.Size = UDim2.new(0, 40, 0, 30)
    sendBtn.Position = UDim2.new(1, -45, 0.5, -15)
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

-- 添加消息气泡
function UI:addMessage(text, isUser)
    local msgFrame = Instance.new("Frame", self.messageArea)
    msgFrame.Size = UDim2.new(1, -20, 0, 0)
    msgFrame.Position = UDim2.new(0, 10, 0, 0)
    msgFrame.BackgroundColor3 = isUser and self.Theme.accent or self.Theme.backgroundSecondary
    msgFrame.BorderSizePixel = 0
    createCorner(msgFrame, 8)
    
    local msgText = Instance.new("TextLabel", msgFrame)
    msgText.Size = UDim2.new(1, -16, 1, 0)
    msgText.Position = UDim2.new(0, 8, 0, 0)
    msgText.BackgroundTransparency = 1
    msgText.Text = text
    msgText.TextColor3 = isUser and Color3.new(1, 1, 1) or self.Theme.text
    msgText.TextSize = 14
    msgText.Font = Enum.Font.Gotham
    msgText.TextWrapped = true
    msgText.TextXAlignment = Enum.TextXAlignment.Left
    msgText.AutomaticSize = Enum.AutomaticSize.Y
    
    msgFrame.AutomaticSize = Enum.AutomaticSize.Y
    
    -- 自动滚动到底部
    task.wait()
    self.messageArea.CanvasSize = UDim2.new(0, 0, 0, self.messageArea.UIListLayout.AbsoluteContentSize.Y)
    self.messageArea.CanvasPosition = Vector2.new(0, self.messageArea.UIListLayout.AbsoluteContentSize.Y)
    
    return msgFrame
end

-- 创建设置界面
function UI:createSettingsView()
    local settingsFrame = Instance.new("Frame", self.mainContent)
    settingsFrame.Name = "SettingsView"
    settingsFrame.Size = UDim2.new(1, 0, 1, 0)
    settingsFrame.BackgroundTransparency = 1
    
    -- API Key 输入
    local apiLabel = Instance.new("TextLabel", settingsFrame)
    apiLabel.Size = UDim2.new(1, -20, 0, 20)
    apiLabel.Position = UDim2.new(0, 10, 0, 10)
    apiLabel.BackgroundTransparency = 1
    apiLabel.Text = "API Key"
    apiLabel.TextColor3 = self.Theme.text
    apiLabel.TextSize = 14
    apiLabel.Font = Enum.Font.GothamBold
    apiLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local apiInput = Instance.new("TextBox", settingsFrame)
    apiInput.Name = "ApiKeyInput"
    apiInput.Size = UDim2.new(1, -20, 0, 35)
    apiInput.Position = UDim2.new(0, 10, 0, 35)
    apiInput.BackgroundColor3 = self.Theme.backgroundTertiary
    apiInput.BorderSizePixel = 0
    apiInput.PlaceholderText = "输入你的API Key..."
    apiInput.PlaceholderColor3 = self.Theme.textMuted
    apiInput.Text = ""
    apiInput.TextColor3 = self.Theme.text
    apiInput.TextSize = 14
    apiInput.Font = Enum.Font.Gotham
    apiInput.TextXAlignment = Enum.TextXAlignment.Left
    createCorner(apiInput, 6)
    
    -- Provider 选择
    local providerLabel = Instance.new("TextLabel", settingsFrame)
    providerLabel.Size = UDim2.new(1, -20, 0, 20)
    providerLabel.Position = UDim2.new(0, 10, 0, 85)
    providerLabel.BackgroundTransparency = 1
    providerLabel.Text = "AI Provider"
    providerLabel.TextColor3 = self.Theme.text
    providerLabel.TextSize = 14
    providerLabel.Font = Enum.Font.GothamBold
    providerLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local providerFrame = Instance.new("Frame", settingsFrame)
    providerFrame.Size = UDim2.new(1, -20, 0, 40)
    providerFrame.Position = UDim2.new(0, 10, 0, 110)
    providerFrame.BackgroundColor3 = self.Theme.backgroundTertiary
    providerFrame.BorderSizePixel = 0
    createCorner(providerFrame, 6)
    
    local deepseekBtn = Instance.new("TextButton", providerFrame)
    deepseekBtn.Name = "DeepSeek"
    deepseekBtn.Size = UDim2.new(0.5, -5, 1, -10)
    deepseekBtn.Position = UDim2.new(0, 5, 0, 5)
    deepseekBtn.BackgroundColor3 = self.Theme.accent
    deepseekBtn.BorderSizePixel = 0
    deepseekBtn.Text = "DeepSeek"
    deepseekBtn.TextColor3 = Color3.new(1, 1, 1)
    deepseekBtn.TextSize = 14
    deepseekBtn.Font = Enum.Font.GothamBold
    createCorner(deepseekBtn, 6)
    
    local openaiBtn = Instance.new("TextButton", providerFrame)
    openaiBtn.Name = "OpenAI"
    openaiBtn.Size = UDim2.new(0.5, -5, 1, -10)
    openaiBtn.Position = UDim2.new(0.5, 0, 0, 5)
    openaiBtn.BackgroundColor3 = self.Theme.backgroundSecondary
    openaiBtn.BorderSizePixel = 0
    openaiBtn.Text = "OpenAI"
    openaiBtn.TextColor3 = self.Theme.text
    openaiBtn.TextSize = 14
    openaiBtn.Font = Enum.Font.Gotham
    createCorner(openaiBtn, 6)
    
    -- 保存按钮
    local saveBtn = Instance.new("TextButton", settingsFrame)
    saveBtn.Name = "SaveButton"
    saveBtn.Size = UDim2.new(0, 120, 0, 40)
    saveBtn.Position = UDim2.new(0, 10, 0, 170)
    saveBtn.BackgroundColor3 = self.Theme.success
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "保存设置"
    saveBtn.TextColor3 = Color3.new(1, 1, 1)
    saveBtn.TextSize = 14
    saveBtn.Font = Enum.Font.GothamBold
    createCorner(saveBtn, 6)
    
    -- 测试连接按钮
    local testBtn = Instance.new("TextButton", settingsFrame)
    testBtn.Name = "TestButton"
    testBtn.Size = UDim2.new(0, 120, 0, 40)
    testBtn.Position = UDim2.new(0, 140, 0, 170)
    testBtn.BackgroundColor3 = self.Theme.accent
    testBtn.BorderSizePixel = 0
    testBtn.Text = "测试连接"
    testBtn.TextColor3 = Color3.new(1, 1, 1)
    testBtn.TextSize = 14
    testBtn.Font = Enum.Font.GothamBold
    createCorner(testBtn, 6)
    
    self.settingsView = settingsFrame
    self.apiKeyInput = apiInput
    self.providerButtons = {
        deepseek = deepseekBtn,
        openai = openaiBtn
    }
    self.saveSettingsBtn = saveBtn
    self.testConnectionBtn = testBtn
    
    return settingsFrame
end

-- 创建资源浏览器
function UI:createResourceView()
    local resourceFrame = Instance.new("Frame", self.mainContent)
    resourceFrame.Name = "ResourceView"
    resourceFrame.Size = UDim2.new(1, 0, 1, 0)
    resourceFrame.BackgroundTransparency = 1
    
    -- 搜索框
    local searchBox = Instance.new("TextBox", resourceFrame)
    searchBox.Name = "SearchBox"
    searchBox.Size = UDim2.new(1, -20, 0, 35)
    searchBox.Position = UDim2.new(0, 10, 0, 10)
    searchBox.BackgroundColor3 = self.Theme.backgroundTertiary
    searchBox.BorderSizePixel = 0
    searchBox.PlaceholderText = "搜索资源..."
    searchBox.PlaceholderColor3 = self.Theme.textMuted
    searchBox.Text = ""
    searchBox.TextColor3 = self.Theme.text
    searchBox.TextSize = 14
    searchBox.Font = Enum.Font.Gotham
    createCorner(searchBox, 6)
    
    -- 资源列表
    local resourceList = Instance.new("ScrollingFrame", resourceFrame)
    resourceList.Name = "ResourceList"
    resourceList.Size = UDim2.new(1, -20, 1, -60)
    resourceList.Position = UDim2.new(0, 10, 0, 55)
    resourceList.BackgroundColor3 = self.Theme.backgroundTertiary
    resourceList.BorderSizePixel = 0
    resourceList.ScrollBarThickness = 6
    resourceList.ScrollBarImageColor3 = self.Theme.accent
    createCorner(resourceList, 8)
    
    local listLayout = Instance.new("UIListLayout", resourceList)
    listLayout.Padding = UDim.new(0, 4)
    
    -- 扫描按钮
    local scanBtn = Instance.new("TextButton", resourceFrame)
    scanBtn.Name = "ScanButton"
    scanBtn.Size = UDim2.new(0, 100, 0, 35)
    scanBtn.Position = UDim2.new(1, -110, 0, 10)
    scanBtn.BackgroundColor3 = self.Theme.accent
    scanBtn.BorderSizePixel = 0
    scanBtn.Text = "扫描"
    scanBtn.TextColor3 = Color3.new(1, 1, 1)
    scanBtn.TextSize = 14
    scanBtn.Font = Enum.Font.GothamBold
    createCorner(scanBtn, 6)
    
    self.resourceView = resourceFrame
    self.resourceSearchBox = searchBox
    self.resourceList = resourceList
    self.scanBtn = scanBtn
    
    return resourceFrame
end

-- 添加资源项
function UI:addResourceItem(name, className, path, onClick)
    local item = Instance.new("TextButton", self.resourceList)
    item.Size = UDim2.new(1, -10, 0, 30)
    item.Position = UDim2.new(0, 5, 0, #self.resourceList:GetChildren() * 34)
    item.BackgroundColor3 = self.Theme.backgroundSecondary
    item.BorderSizePixel = 0
    item.Text = ""
    createCorner(item, 4)
    
    local nameText = Instance.new("TextLabel", item)
    nameText.Size = UDim2.new(0.5, 0, 1, 0)
    nameText.Position = UDim2.new(0, 10, 0, 0)
    nameText.BackgroundTransparency = 1
    nameText.Text = name
    nameText.TextColor3 = self.Theme.text
    nameText.TextSize = 13
    nameText.Font = Enum.Font.GothamSemibold
    nameText.TextXAlignment = Enum.TextXAlignment.Left
    nameText.TextTruncate = Enum.TextTruncate.AtEnd
    
    local classText = Instance.new("TextLabel", item)
    classText.Size = UDim2.new(0.35, 0, 1, 0)
    classText.Position = UDim2.new(0.5, 0, 0, 0)
    classText.BackgroundTransparency = 1
    classText.Text = className
    classText.TextColor3 = self.Theme.textSecondary
    classText.TextSize = 12
    classText.Font = Enum.Font.Gotham
    classText.TextXAlignment = Enum.TextXAlignment.Left
    
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
    -- 隐藏所有视图
    if self.chatView then self.chatView.Visible = false end
    if self.settingsView then self.settingsView.Visible = false end
    if self.resourceView then self.resourceView.Visible = false end
    
    -- 显示指定视图
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
