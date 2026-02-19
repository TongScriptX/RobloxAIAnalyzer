-- Scanner模块 - 资源扫描（支持全资源扫描和智能搜索）
local Scanner = {}

-- 扫描配置
Scanner.config = {
    maxDepth = 25,
    maxObjects = math.huge,  -- 无限制
    includeNilInstances = true,
    services = {
        {name = "Workspace", service = game:GetService("Workspace")},
        {name = "ReplicatedStorage", service = game:GetService("ReplicatedStorage")},
        {name = "ReplicatedFirst", service = game:GetService("ReplicatedFirst")},
        {name = "Lighting", service = game:GetService("Lighting")},
        {name = "StarterGui", service = game:GetService("StarterGui")},
        {name = "StarterPack", service = game:GetService("StarterPack")},
        {name = "StarterPlayer", service = game:GetService("StarterPlayer")},
        {name = "Players", service = game:GetService("Players")},
        {name = "Teams", service = game:GetService("Teams")},
        {name = "SoundService", service = game:GetService("SoundService")},
        {name = "Chat", service = game:GetService("Chat")},
        {name = "TestService", service = game:GetService("TestService")}
    },
    -- 重要类型（用于快速访问）
    importantTypes = {
        RemoteEvent = true,
        RemoteFunction = true,
        LocalScript = true,
        ModuleScript = true,
        Script = true,
        BindableEvent = true,
        BindableFunction = true
    }
}

-- 扫描结果缓存
Scanner.cache = {
    objects = {},
    remotes = {},
    scripts = {},
    instances = {},
    typeIndex = {},      -- 按类型索引
    nameIndex = {},      -- 按名称索引
    lastScanTime = 0,
    isValid = false,
    stats = {
        totalTypes = 0,
        typeCounts = {}
    }
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

-- 获取关键属性（仅对重要类型）
local function getProperties(instance, className)
    -- 普通对象不获取属性，大幅减少pcall开销
    if not Scanner.config.importantTypes[className] then
        return {}
    end
    
    local props = {}
    
    -- 单次pcall处理所有属性检查
    pcall(function()
        if instance:IsA("RemoteFunction") then
            props.invokeEnabled = true
        elseif instance:IsA("RemoteEvent") then
            props.fireEnabled = true
        elseif instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
            props.disabled = instance.Disabled
        end
    end)
    
    return props
end

-- 处理单个对象
local function processInstance(instance, path, depth, results, seenInstances)
    -- 去重检查
    if seenInstances[instance] then return end
    seenInstances[instance] = true
    
    local currentPath = path .. "." .. instance.Name
    local className = instance.ClassName
    
    -- 创建对象信息（不获取属性以提速）
    local objInfo = {
        name = instance.Name,
        className = className,
        path = currentPath,
        depth = depth,
        instance = instance,
        children = {}
    }
    
    -- 存入结果
    table.insert(results.all, objInfo)
    
    -- 类型索引
    if not results.typeIndex[className] then
        results.typeIndex[className] = {}
    end
    table.insert(results.typeIndex[className], objInfo)
    
    -- 名称索引
    local nameLower = instance.Name:lower()
    if not results.nameIndex[nameLower] then
        results.nameIndex[nameLower] = {}
    end
    table.insert(results.nameIndex[nameLower], objInfo)
    
    -- 重要类型
    if Scanner.config.importantTypes[className] then
        table.insert(results.focused, objInfo)
        if className == "RemoteEvent" or className == "RemoteFunction" then
            table.insert(results.remotes, objInfo)
        elseif className == "LocalScript" or className == "Script" or className == "ModuleScript" then
            table.insert(results.scripts, objInfo)
        end
    end
    
    -- 类型统计
    results.typeCounts[className] = (results.typeCounts[className] or 0) + 1
    
    return currentPath
end

-- 扫描服务（分批处理，使用coroutine让出执行权）
local function scanServiceBatch(rootInstance, rootPath, results, counters, seenInstances, onBatch)
    local batchSize = 100  -- 每批处理数量
    local queue = {{instance = rootInstance, path = rootPath, depth = 0}}
    local processed = 0
    
    while #queue > 0 do
        local item = table.remove(queue, 1)
        local instance = item.instance
        
        if not seenInstances[instance] and item.depth <= Scanner.config.maxDepth then
            processInstance(instance, item.path, item.depth, results, seenInstances)
            counters.total = counters.total + 1
            processed = processed + 1
            
            -- 每批处理后让出执行权
            if processed % batchSize == 0 then
                if onBatch then
                    onBatch(counters.total)
                end
                wait()  -- 让出执行权，防止卡死
            end
            
            -- 添加子对象到队列
            local children = instance:GetChildren()
            for _, child in ipairs(children) do
                table.insert(queue, {
                    instance = child,
                    path = item.path .. "." .. instance.Name,
                    depth = item.depth + 1
                })
            end
        end
    end
end

-- 扫描nil instances
local function scanNilInstances(results, counters, seenInstances)
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
        if not seenInstances[instance] then
            local objInfo = {
                name = instance.Name,
                className = instance.ClassName,
                path = "nil." .. instance.Name,
                depth = 0,
                instance = instance,
                isNil = true
            }
            table.insert(results.all, objInfo)
            counters.total = counters.total + 1
            
            -- 类型索引
            local cn = instance.ClassName
            if not results.typeIndex[cn] then results.typeIndex[cn] = {} end
            table.insert(results.typeIndex[cn], objInfo)
            
            -- 名称索引
            local nl = instance.Name:lower()
            if not results.nameIndex[nl] then results.nameIndex[nl] = {} end
            table.insert(results.nameIndex[nl], objInfo)
            
            results.typeCounts[cn] = (results.typeCounts[cn] or 0) + 1
        end
    end
end

-- 执行完整扫描（支持增量回调）
function Scanner:scan(onProgress)
    local results = {
        all = {},
        focused = {},
        remotes = {},
        scripts = {},
        services = {},
        typeIndex = {},
        nameIndex = {},
        typeCounts = {},
        scanTime = os.time()
    }
    
    local counters = { total = 0 }
    local seenInstances = {}
    
    -- 辅助函数：更新缓存并触发进度回调
    local function updateCacheAndNotify(serviceName)
        self.cache = {
            objects = results.all,
            remotes = results.remotes,
            scripts = results.scripts,
            focused = results.focused,
            services = results.services,
            typeIndex = results.typeIndex,
            nameIndex = results.nameIndex,
            typeCounts = results.typeCounts,
            lastScanTime = os.time(),
            isValid = true,
            stats = {
                totalTypes = 0,
                typeCounts = results.typeCounts
            }
        }
        
        local typeCount = 0
        for _ in pairs(results.typeIndex) do
            typeCount = typeCount + 1
        end
        self.cache.stats.totalTypes = typeCount
        
        if onProgress then
            onProgress(#results.all, typeCount, serviceName)
        end
    end
    
    -- 扫描各个服务（分批处理）
    for _, serviceInfo in ipairs(self.config.services) do
        local serviceName = serviceInfo.name
        local service = serviceInfo.service
        
        if service then
            table.insert(results.services, serviceName)
            scanServiceBatch(service, serviceName, results, counters, seenInstances, function(count)
                -- 每批更新缓存
                updateCacheAndNotify(serviceName)
            end)
            updateCacheAndNotify(serviceName)
        end
    end
    
    -- 扫描nil instances
    scanNilInstances(results, counters, seenInstances)
    
    -- 最终更新
    updateCacheAndNotify("nil instances")
    
    print(string.format("[AI CLI] 扫描完成: %d 个对象, %d 种类型", #results.all, self.cache.stats.totalTypes))
    
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

-- 搜索资源（支持智能搜索）
function Scanner:search(query, options)
    options = options or {}
    local searchType = options.type or "all"
    local limit = options.limit or 100
    local exactMatch = options.exact or false
    
    if not query or query == "" then
        return {results = {}, total = 0}
    end
    
    local results = {}
    local queryLower = query:lower()
    
    -- 确定搜索范围
    local searchPool
    if searchType == "remotes" then
        searchPool = self.cache.remotes
    elseif searchType == "scripts" then
        searchPool = self.cache.scripts
    elseif self.cache.typeIndex and self.cache.typeIndex[searchType] then
        -- 按类型搜索
        searchPool = self.cache.typeIndex[searchType]
    else
        searchPool = self.cache.objects
    end
    
    if not searchPool then
        return {results = {}, total = 0}
    end
    
    -- 搜索逻辑
    for _, obj in ipairs(searchPool) do
        if #results >= limit then break end
        
        local nameLower = obj.name:lower()
        local classLower = obj.className:lower()
        local pathLower = obj.path:lower()
        
        local match = false
        local matchType = ""
        
        if exactMatch then
            -- 精确匹配
            if nameLower == queryLower then
                match = true
                matchType = "name_exact"
            elseif classLower == queryLower then
                match = true
                matchType = "class_exact"
            end
        else
            -- 模糊匹配
            if nameLower:find(queryLower, 1, true) then
                match = true
                matchType = "name"
            elseif classLower:find(queryLower, 1, true) then
                match = true
                matchType = "class"
            elseif pathLower:find(queryLower, 1, true) then
                match = true
                matchType = "path"
            end
        end
        
        if match then
            table.insert(results, {
                name = obj.name,
                className = obj.className,
                path = obj.path,
                matchType = matchType,
                instance = obj.instance
            })
        end
    end
    
    return {
        results = results,
        total = #results,
        query = query,
        searchType = searchType
    }
end

-- 按类型过滤（使用索引，更高效）
function Scanner:filterByType(className)
    if self.cache.typeIndex and self.cache.typeIndex[className] then
        return self.cache.typeIndex[className]
    end
    
    -- 回退到遍历搜索
    local results = {}
    for _, obj in ipairs(self.cache.objects) do
        if obj.className == className then
            table.insert(results, obj)
        end
    end
    return results
end

-- 按名称查找（使用索引）
function Scanner:findByName(name, exact)
    local nameLower = name:lower()
    
    if exact and self.cache.nameIndex and self.cache.nameIndex[nameLower] then
        return self.cache.nameIndex[nameLower]
    end
    
    -- 模糊搜索
    local results = {}
    for _, obj in ipairs(self.cache.objects) do
        if obj.name:lower():find(nameLower, 1, true) then
            table.insert(results, obj)
        end
    end
    return results
end

-- 获取所有类型列表
function Scanner:getAllTypes()
    local types = {}
    if self.cache.typeIndex then
        for typeName, objects in pairs(self.cache.typeIndex) do
            table.insert(types, {
                name = typeName,
                count = #objects
            })
        end
    end
    -- 按数量排序
    table.sort(types, function(a, b) return a.count > b.count end)
    return types
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
        totalTypes = self.cache.stats and self.cache.stats.totalTypes or 0,
        typeCounts = self.cache.typeCounts or {},
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
        services = self.cache.services or {},
        typeSummary = {}
    }
    
    -- 添加类型摘要（前20种最多数量）
    if self.cache.typeCounts then
        local sortedTypes = {}
        for typeName, count in pairs(self.cache.typeCounts) do
            table.insert(sortedTypes, {name = typeName, count = count})
        end
        table.sort(sortedTypes, function(a, b) return a.count > b.count end)
        
        for i, t in ipairs(sortedTypes) do
            if i > 20 then break end
            table.insert(context.typeSummary, t)
        end
    end
    
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
            disabled = script.properties and script.properties.disabled
        })
    end
    
    return context
end

-- 获取对象详细信息
function Scanner:getObjectDetails(path)
    for _, obj in ipairs(self.cache.objects) do
        if obj.path == path then
            return {
                name = obj.name,
                className = obj.className,
                path = obj.path,
                properties = obj.properties,
                instance = obj.instance,
                isNil = obj.isNil
            }
        end
    end
    return nil
end

return Scanner
