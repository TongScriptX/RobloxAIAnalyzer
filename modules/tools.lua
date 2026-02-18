-- AI工具定义模块
-- 提供给AI的工具函数，让AI可以主动搜索和读取资源

local Tools = {}

-- 工具定义（用于发送给AI API）
Tools.definitions = {
    {
        type = "function",
        ["function"] = {
            name = "search_resources",
            description = "搜索游戏内的资源对象，如RemoteEvent、RemoteFunction、LocalScript等。返回匹配的资源列表。",
            parameters = {
                type = "object",
                properties = {
                    query = {
                        type = "string",
                        description = "搜索关键词，可以是资源名称的一部分"
                    },
                    resource_type = {
                        type = "string",
                        enum = {"all", "remote", "script", "other"},
                        description = "资源类型过滤：remote(RemoteEvent/RemoteFunction), script(LocalScript/ModuleScript/Script), other(其他类型), all(全部)"
                    }
                },
                required = {"query"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "read_script",
            description = "读取指定脚本的源代码。需要提供脚本的名称或路径。返回脚本的完整源码。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "脚本名称或路径"
                    }
                },
                required = {"name"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "get_remote_info",
            description = "获取RemoteEvent或RemoteFunction的详细信息，包括路径、参数结构等。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "Remote的名称或路径"
                    }
                },
                required = {"name"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "list_resources",
            description = "列出游戏内所有可访问的资源，按类型分组。返回资源摘要列表。",
            parameters = {
                type = "object",
                properties = {
                    resource_type = {
                        type = "string",
                        enum = {"remotes", "scripts", "all"},
                        description = "要列出的资源类型"
                    },
                    limit = {
                        type = "integer",
                        description = "返回数量限制，默认20"
                    }
                },
                required = {"resource_type"}
            }
        }
    }
}

-- 执行工具调用
function Tools:execute(toolName, args, context)
    local Scanner = context.Scanner
    local Reader = context.Reader
    
    if toolName == "search_resources" then
        return self:searchResources(args, Scanner)
    elseif toolName == "read_script" then
        return self:readScript(args, Reader, Scanner)
    elseif toolName == "get_remote_info" then
        return self:getRemoteInfo(args, Scanner)
    elseif toolName == "list_resources" then
        return self:listResources(args, Scanner)
    end
    
    return {error = "Unknown tool: " .. toolName}
end

-- 搜索资源
function Tools:searchResources(args, Scanner)
    local query = args.query or ""
    local resourceType = args.resource_type or "all"
    
    if not Scanner or not Scanner.cache then
        return {error = "Scanner not initialized or no cache available"}
    end
    
    local results = {}
    local queryLower = query:lower()
    
    local searchPool
    if resourceType == "remote" then
        searchPool = Scanner.cache.remotes or {}
    elseif resourceType == "script" then
        searchPool = Scanner.cache.scripts or {}
    else
        searchPool = Scanner.cache.objects or {}
    end
    
    for _, obj in ipairs(searchPool) do
        local nameMatch = obj.name and obj.name:lower():find(queryLower, 1, true)
        local pathMatch = obj.path and obj.path:lower():find(queryLower, 1, true)
        local classMatch = obj.className and obj.className:lower():find(queryLower, 1, true)
        
        if nameMatch or pathMatch or classMatch then
            table.insert(results, {
                name = obj.name,
                type = obj.className,
                path = obj.path
            })
            
            if #results >= 30 then break end
        end
    end
    
    return {
        query = query,
        count = #results,
        results = results
    }
end

-- 读取脚本源码
function Tools:readScript(args, Reader, Scanner)
    local name = args.name
    if not name then
        return {error = "Script name required"}
    end
    
    if not Reader or not Reader:canDecompile() then
        return {error = "Script reading not available (need decompile support)"}
    end
    
    -- 先查找脚本
    local scripts = Reader:getAllScripts()
    local nameLower = name:lower()
    
    for _, script in ipairs(scripts) do
        if script.Name:lower():find(nameLower, 1, true) then
            local data = Reader:readScript(script)
            if data and data.source then
                return {
                    name = data.name,
                    type = data.className,
                    path = data.path,
                    source = data.source,
                    size = #data.source,
                    lines = data.lines
                }
            end
        end
    end
    
    return {error = "Script not found: " .. name}
end

-- 获取Remote信息
function Tools:getRemoteInfo(args, Scanner)
    local name = args.name
    if not name then
        return {error = "Remote name required"}
    end
    
    if not Scanner or not Scanner.cache then
        return {error = "Scanner not initialized"}
    end
    
    local nameLower = name:lower()
    
    for _, remote in ipairs(Scanner.cache.remotes or {}) do
        if remote.name:lower():find(nameLower, 1, true) then
            return {
                name = remote.name,
                type = remote.className,
                path = remote.path,
                isRemoteEvent = remote.className == "RemoteEvent",
                isRemoteFunction = remote.className == "RemoteFunction",
                usage = remote.className == "RemoteEvent" 
                    and "FireServer(args) / FireAllClients(args)"
                    or "InvokeServer(args)",
                example = self:generateRemoteExample(remote)
            }
        end
    end
    
    return {error = "Remote not found: " .. name}
end

-- 列出资源
function Tools:listResources(args, Scanner)
    local resourceType = args.resource_type or "all"
    local limit = args.limit or 20
    
    if not Scanner or not Scanner.cache then
        return {error = "Scanner not initialized"}
    end
    
    local result = {}
    
    if resourceType == "remotes" or resourceType == "all" then
        result.remotes = {}
        for i, r in ipairs(Scanner.cache.remotes or {}) do
            if i > limit then break end
            table.insert(result.remotes, {
                name = r.name,
                type = r.className,
                path = r.path
            })
        end
        result.remoteCount = #(Scanner.cache.remotes or {})
    end
    
    if resourceType == "scripts" or resourceType == "all" then
        result.scripts = {}
        for i, s in ipairs(Scanner.cache.scripts or {}) do
            if i > limit then break end
            table.insert(result.scripts, {
                name = s.name,
                type = s.className,
                path = s.path,
                disabled = s.properties and s.properties.disabled
            })
        end
        result.scriptCount = #(Scanner.cache.scripts or {})
    end
    
    result.totalObjects = #(Scanner.cache.objects or {})
    
    return result
end

-- 生成Remote调用示例
function Tools:generateRemoteExample(remote)
    local varName = remote.name:gsub("%s+", "_"):gsub("[^%w_]", "")
    
    if remote.className == "RemoteEvent" then
        return string.format([[
local remote = game:GetService("ReplicatedStorage"):WaitForChild("%s")
remote:FireServer(args)]], remote.name)
    else
        return string.format([[
local remote = game:GetService("ReplicatedStorage"):WaitForChild("%s")
local result = remote:InvokeServer(args)]], remote.name)
    end
end

-- 将工具结果格式化为AI可读的文本
function Tools:formatResult(result)
    local HttpService = game:GetService("HttpService")
    
    if result.error then
        return "Error: " .. result.error
    end
    
    -- 简洁格式化
    local parts = {}
    
    if result.results then
        parts[#parts + 1] = string.format("Found %d results:", result.count)
        for i, r in ipairs(result.results) do
            if i > 10 then
                parts[#parts + 1] = "... and " .. (result.count - 10) .. " more"
                break
            end
            parts[#parts + 1] = string.format("  • %s [%s] - %s", r.name, r.type, r.path)
        end
    elseif result.source then
        parts[#parts + 1] = string.format("Script: %s (%s)", result.name, result.type)
        parts[#parts + 1] = string.format("Path: %s", result.path)
        parts[#parts + 1] = string.format("Size: %d bytes, %d lines", result.size, result.lines or 0)
        parts[#parts + 1] = "Source:"
        parts[#parts + 1] = "```lua"
        parts[#parts + 1] = result.source
        parts[#parts + 1] = "```"
    elseif result.example then
        parts[#parts + 1] = string.format("Remote: %s (%s)", result.name, result.type)
        parts[#parts + 1] = string.format("Path: %s", result.path)
        parts[#parts + 1] = "Usage: " .. result.usage
        parts[#parts + 1] = "Example:"
        parts[#parts + 1] = "```lua"
        parts[#parts + 1] = result.example
        parts[#parts + 1] = "```"
    elseif result.remotes or result.scripts then
        if result.remotes and #result.remotes > 0 then
            parts[#parts + 1] = string.format("Remotes (%d total):", result.remoteCount or #result.remotes)
            for i, r in ipairs(result.remotes) do
                parts[#parts + 1] = string.format("  • %s [%s]", r.name, r.type)
            end
        end
        if result.scripts and #result.scripts > 0 then
            parts[#parts + 1] = string.format("Scripts (%d total):", result.scriptCount or #result.scripts)
            for i, s in ipairs(result.scripts) do
                parts[#parts + 1] = string.format("  • %s [%s]", s.name, s.type)
            end
        end
        parts[#parts + 1] = string.format("Total objects scanned: %d", result.totalObjects or 0)
    end
    
    return table.concat(parts, "\n")
end

return Tools
