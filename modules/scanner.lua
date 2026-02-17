-- Scanner模块 - 资源扫描
local Scanner = {}

-- 扫描配置
Scanner.config = {
    maxDepth = 20,
    maxObjects = 5000,
    includeNilInstances = true,
    services = {
        {name = "Workspace", service = game:GetService("Workspace")},
        {name = "ReplicatedStorage", service = game:GetService("ReplicatedStorage")},
        {name = "ReplicatedFirst", service = game:GetService("ReplicatedFirst")},
        {name = "Lighting", service = game:GetService("Lighting")},
        {name = "StarterGui", service = game:GetService("StarterGui")},
        {name = "StarterPack", service = game:GetService("StarterPack")},
        {name = "StarterPlayer", service = game:GetService("StarterPlayer")}
    },
    focusTypes = {
        RemoteEvent = true,
        RemoteFunction = true,
        LocalScript = true,
        ModuleScript = true,
        Script = true,
        BindableEvent = true,
        BindableFunction = true,
        Folder = true
    }
}

-- 扫描结果缓存
Scanner.cache = {
    objects = {},
    remotes = {},
    scripts = {},
    instances = {},  -- 保存实例引用
    lastScanTime = 0,
    isValid = false
}

-- 对象信息结构
local function createObjectInfo(instance, path, depth)
    return {
        name = instance.Name,
        className = instance.ClassName,
        path = path,
        depth = depth,
        instance = instance,  -- 保存实例引用
        children = {},
        properties = {}
    }
end

-- 获取关键属性
local function getProperties(instance)
    local props = {}
    
    pcall(function()
        if instance.Value ~= nil then
            props.Value = tostring(instance.Value)
        end
    end)
    
    pcall(function()
        if instance:IsA("RemoteFunction") then
            props.invokeEnabled = true
        end
        if instance:IsA("RemoteEvent") then
            props.fireEnabled = true
        end
    end)
    
    pcall(function()
        if instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
            props.disabled = instance.Disabled
        end
    end)
    
    pcall(function()
        if instance:IsA("BasePart") then
            props.position = tostring(instance.Position)
            props.size = tostring(instance.Size)
            props.anchored = instance.Anchored
            props.canCollide = instance.CanCollide
        end
    end)
    
    pcall(function()
        if instance:IsA("GuiObject") then
            props.visible = instance.Visible
        end
    end)
    
    return props
end

-- 递归扫描
local function scanInstance(instance, path, depth, results, counters)
    if counters.total >= Scanner.config.maxObjects then return end
    if depth > Scanner.config.maxDepth then return end
    
    local currentPath = path .. "." .. instance.Name
    counters.total = counters.total + 1
    
    local objInfo = createObjectInfo(instance, currentPath, depth)
    objInfo.properties = getProperties(instance)
    
    if Scanner.config.focusTypes[instance.ClassName] then
        table.insert(results.focused, objInfo)
        
        if instance.ClassName == "RemoteEvent" or instance.ClassName == "RemoteFunction" then
            table.insert(results.remotes, objInfo)
        elseif instance.ClassName == "LocalScript" or instance.ClassName == "Script" or instance.ClassName == "ModuleScript" then
            table.insert(results.scripts, objInfo)
        end
    end
    
    table.insert(results.all, {
        name = instance.Name,
        className = instance.ClassName,
        path = currentPath,
        instance = instance
    })
    
    -- 递归扫描子对象
    local children = instance:GetChildren()
    for _, child in ipairs(children) do
        scanInstance(child, currentPath, depth + 1, results, counters)
    end
end

-- 扫描nil instances
local function scanNilInstances(results, counters)
    if not Scanner.config.includeNilInstances then
        return
    end
    
    local success, nilInstances = pcall(function()
        return getnilinstances()
    end)
    
    if not success then
        return
    end
    
    for _, instance in pairs(nilInstances) do
        if counters.total >= Scanner.config.maxObjects then
            break
        end
        
        counters.total = counters.total + 1
        local objInfo = createObjectInfo(instance, "nil." .. instance.Name, 0)
        objInfo.properties = getProperties(instance)
        objInfo.isNil = true
        
        if Scanner.config.focusTypes[instance.ClassName] then
            table.insert(results.focused, objInfo)
        end
        
        table.insert(results.all, {
            name = instance.Name,
            className = instance.ClassName,
            path = "nil." .. instance.Name,
            isNil = true
        })
    end
end

-- 执行完整扫描
function Scanner:scan()
    local results = {
        all = {},
        focused = {},
        remotes = {},
        scripts = {},
        services = {},
        scanTime = os.time()
    }
    
    local counters = { total = 0 }
    
    -- 扫描各个服务
    for _, serviceInfo in ipairs(self.config.services) do
        local serviceName = serviceInfo.name
        local service = serviceInfo.service
        
        if service then
            table.insert(results.services, serviceName)
            scanInstance(service, serviceName, 0, results, counters)
        end
    end
    
    -- 扫描nil instances
    scanNilInstances(results, counters)
    
    -- 更新缓存
    self.cache = {
        objects = results.all,
        remotes = results.remotes,
        scripts = results.scripts,
        focused = results.focused,
        lastScanTime = os.time(),
        isValid = true
    }
    
    return results
end

-- 获取缓存的扫描结果
function Scanner:getCached()
    if self.cache.isValid then
        return self.cache
    end
    return nil
end

-- 刷新缓存
function Scanner:refresh()
    self.cache.isValid = false
    return self:scan()
end

-- 搜索资源
function Scanner:search(query, searchType)
    searchType = searchType or "all"
    local results = {}
    query = query:lower()
    
    local searchPool
    if searchType == "remotes" then
        searchPool = self.cache.remotes
    elseif searchType == "scripts" then
        searchPool = self.cache.scripts
    elseif searchType == "focused" then
        searchPool = self.cache.focused
    else
        searchPool = self.cache.objects
    end
    
    if not searchPool then
        return results
    end
    
    for _, obj in ipairs(searchPool) do
        local nameMatch = obj.name:lower():find(query)
        local classMatch = obj.className:lower():find(query)
        local pathMatch = obj.path:lower():find(query)
        
        if nameMatch or classMatch or pathMatch then
            table.insert(results, obj)
        end
    end
    
    return results
end

-- 按类型过滤
function Scanner:filterByType(className)
    local results = {}
    
    for _, obj in ipairs(self.cache.objects) do
        if obj.className == className then
            table.insert(results, obj)
        end
    end
    
    return results
end

-- 获取对象的完整路径
function Scanner:getFullPath(instance)
    local path = instance.Name
    local current = instance.Parent
    
    while current and current ~= game do
        path = current.Name .. "." .. path
        current = current.Parent
    end
    
    return path
end

-- 获取扫描统计信息
function Scanner:getStats()
    return {
        totalObjects = #self.cache.objects,
        remoteCount = #self.cache.remotes,
        scriptCount = #self.cache.scripts,
        focusedCount = #self.cache.focused,
        lastScanTime = self.cache.lastScanTime,
        isValid = self.cache.isValid
    }
end

-- 将扫描结果转换为AI可理解的格式
function Scanner:toAIContext(maxItems)
    maxItems = maxItems or 100
    local context = {
        gameName = game.Name,
        placeId = game.PlaceId,
        jobId = game.JobId,
        remotes = {},
        scripts = {},
        services = self.cache.services or {}
    }
    
    -- 添加Remote信息
    for i, remote in ipairs(self.cache.remotes) do
        if i > maxItems then break end
        table.insert(context.remotes, {
            name = remote.name,
            type = remote.className,
            path = remote.path
        })
    end
    
    -- 添加Script信息
    for i, script in ipairs(self.cache.scripts) do
        if i > maxItems then break end
        table.insert(context.scripts, {
            name = script.name,
            type = script.className,
            path = script.path,
            disabled = script.properties.disabled
        })
    end
    
    return context
end

return Scanner
