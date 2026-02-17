--[[
    Roblox AI Resource Analyzer - Executor Module
    Version: 1.0.0
    
    代码执行模块：安全执行生成的代码
]]

local Executor = {}

-- 执行器环境检测
local function detectExecutorEnv()
    local env = {
        hasLoadstring = false,
        hasGetfenv = false,
        hasSetfenv = false,
        executorName = "Unknown"
    }
    
    -- 检测loadstring
    if loadstring then
        env.hasLoadstring = true
    end
    
    -- 检测getfenv/setfenv
    if getfenv then
        env.hasGetfenv = true
    end
    if setfenv then
        env.hasSetfenv = true
    end
    
    -- 检测执行器名称
    if syn and syn.request then
        env.executorName = "Synapse X"
    elseif KRNL_LOADED then
        env.executorName = "KRNL"
    elseif fluxus and fluxus.request then
        env.executorName = "Fluxus"
    elseif identifyexecutor then
        env.executorName = identifyexecutor()
    end
    
    return env
end

Executor.env = detectExecutorEnv()

-- 安全执行代码
function Executor:safeExecute(code, env)
    if not self.env.hasLoadstring then
        return false, "loadstring not available in this environment"
    end
    
    -- 创建沙盒环境
    local sandboxEnv = env or {}
    
    -- 添加标准库
    setmetatable(sandboxEnv, {
        __index = function(t, k)
            -- 提供Roblox环境
            if _G[k] ~= nil then return _G[k] end
            if _ENV and _ENV[k] ~= nil then return _ENV[k] end
            return nil
        end
    })
    
    -- 添加常用游戏服务
    sandboxEnv.game = game
    sandboxEnv.workspace = workspace
    sandboxEnv.Instance = Instance
    sandboxEnv.Vector3 = Vector3
    sandboxEnv.CFrame = CFrame
    sandboxEnv.Color3 = Color3
    sandboxEnv.UDim = UDim
    sandboxEnv.UDim2 = UDim2
    sandboxEnv.Enum = Enum
    sandboxEnv.math = math
    sandboxEnv.string = string
    sandboxEnv.table = table
    sandboxEnv.os = os
    sandboxEnv.tick = tick
    sandboxEnv.wait = wait
    sandboxEnv.spawn = spawn
    sandboxEnv.delay = delay
    sandboxEnv.print = print
    sandboxEnv.warn = warn
    sandboxEnv.error = error
    sandboxEnv.pcall = pcall
    sandboxEnv.xpcall = xpcall
    sandboxEnv.type = type
    sandboxEnv.tostring = tostring
    sandboxEnv.tonumber = tonumber
    sandboxEnv.pairs = pairs
    sandboxEnv.ipairs = ipairs
    sandboxEnv.next = next
    sandboxEnv.select = select
    sandboxEnv.unpack = unpack
    sandboxEnv.pack = pack
    sandboxEnv.rawget = rawget
    sandboxEnv.rawset = rawset
    
    -- 执行器特有函数
    if getgenv then sandboxEnv.getgenv = getgenv end
    if getrenv then sandboxEnv.getrenv = getrenv end
    if getnilinstances then sandboxEnv.getnilinstances = getnilinstances end
    if getinstances then sandboxEnv.getinstances = getinstances end
    if getconnections then sandboxEnv.getconnections = getconnections end
    if firesignal then sandboxEnv.firesignal = firesignal end
    if fireproximityprompt then sandboxEnv.fireproximityprompt = fireproximityprompt end
    if fireclickdetector then sandboxEnv.fireclickdetector = fireclickdetector end
    
    -- 尝试编译和执行
    local success, compiled = pcall(loadstring, code)
    if not success then
        return false, "Failed to compile: " .. tostring(compiled)
    end
    
    if not compiled then
        return false, "Failed to compile: Unknown error"
    end
    
    -- 设置环境
    if self.env.hasSetfenv then
        setfenv(compiled, sandboxEnv)
    end
    
    -- 执行
    local success2, result = pcall(compiled)
    if not success2 then
        return false, "Runtime error: " .. tostring(result)
    end
    
    return true, result
end

-- 异步执行（在新线程中）
function Executor:asyncExecute(code, callback)
    spawn(function()
        local success, result = self:safeExecute(code)
        if callback then
            callback(success, result)
        end
    end)
end

-- 从代码中提取函数
function Executor:extractFunctions(code)
    local functions = {}
    
    -- 简单的正则匹配函数定义
    for name, params in code:gmatch("function%s+([%w_%.:]+)%s*(%([^)]*%))") do
        table.insert(functions, {
            name = name,
            params = params
        })
    end
    
    return functions
end

-- 从代码中提取Remote调用
function Executor:extractRemoteCalls(code)
    local calls = {}
    
    -- 匹配 :FireServer
    for remote, args in code:gmatch("([%w_%.]+):FireServer%s*(%b())") do
        table.insert(calls, {
            type = "FireServer",
            remote = remote,
            args = args
        })
    end
    
    -- 匹配 :InvokeServer
    for remote, args in code:gmatch("([%w_%.]+):InvokeServer%s*(%b())") do
        table.insert(calls, {
            type = "InvokeServer",
            remote = remote,
            args = args
        })
    end
    
    -- 匹配 :FireClient
    for remote, args in code:gmatch("([%w_%.]+):FireClient%s*(%b())") do
        table.insert(calls, {
            type = "FireClient",
            remote = remote,
            args = args
        })
    end
    
    return calls
end

-- 验证代码安全性
function Executor:validateCode(code)
    local warnings = {}
    local dangerousPatterns = {
        {pattern = "os%.execute", level = "high", message = "os.execute detected - can run system commands"},
        {pattern = "io%.open", level = "medium", message = "io.open detected - can access files"},
        {pattern = "loadstring%s*%(", level = "low", message = "loadstring usage detected"},
        {pattern = "getfenv%s*%(", level = "low", message = "getfenv usage detected"},
        {pattern = "setfenv%s*%(", level = "low", message = "setfenv usage detected"},
        {pattern = "debug%.", level = "low", message = "debug library usage detected"}
    }
    
    for _, check in ipairs(dangerousPatterns) do
        if code:find(check.pattern) then
            table.insert(warnings, {
                level = check.level,
                message = check.message
            })
        end
    end
    
    return warnings
end

-- 获取执行器信息
function Executor:getInfo()
    return {
        executorName = self.env.executorName,
        hasLoadstring = self.env.hasLoadstring,
        hasGetfenv = self.env.hasGetfenv,
        hasSetfenv = self.env.hasSetfenv,
        canExecute = self.env.hasLoadstring
    }
end

-- 检查是否可以执行代码
function Executor:canExecute()
    return self.env.hasLoadstring
end

return Executor
