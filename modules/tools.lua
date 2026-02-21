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
            description = "读取指定脚本的源代码。可以读取完整脚本或指定行范围。返回脚本源码。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "脚本名称或路径"
                    },
                    start_line = {
                        type = "integer",
                        description = "起始行号（可选，从1开始）"
                    },
                    end_line = {
                        type = "integer",
                        description = "结束行号（可选）"
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
    },
    {
        type = "function",
        ["function"] = {
            name = "search_in_script",
            description = "在脚本源码中搜索指定的文本或关键词。返回包含该文本的脚本列表及上下文。",
            parameters = {
                type = "object",
                properties = {
                    text = {
                        type = "string",
                        description = "要搜索的文本或关键词"
                    },
                    script_name = {
                        type = "string",
                        description = "可选：限定在特定脚本中搜索"
                    },
                    context_lines = {
                        type = "integer",
                        description = "上下文行数，默认2"
                    }
                },
                required = {"text"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "run_script",
            description = "运行Lua代码并返回结果。可以获取输出和错误信息。运行前会根据模式决定是否询问用户确认。",
            parameters = {
                type = "object",
                properties = {
                    code = {
                        type = "string",
                        description = "要运行的Lua代码"
                    },
                    description = {
                        type = "string",
                        description = "代码功能的简短描述（用于向用户说明）"
                    },
                    risk_level = {
                        type = "string",
                        enum = {"low", "medium", "high"},
                        description = "风险等级：low(只读/查询)、medium(修改游戏状态)、high(可能影响其他玩家)"
                    }
                },
                required = {"code", "description"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "get_console_output",
            description = "读取Roblox控制台的所有输出日志。可以获取print、warn、error等输出信息，用于调试和分析游戏行为。",
            parameters = {
                type = "object",
                properties = {
                    filter = {
                        type = "string",
                        description = "可选：过滤关键词，只返回包含该关键词的日志"
                    },
                    max_entries = {
                        type = "integer",
                        description = "最大返回条数，默认50"
                    },
                    log_type = {
                        type = "string",
                        enum = {"all", "output", "warn", "error", "info"},
                        description = "日志类型过滤：output(print输出)、warn(警告)、error(错误)、info(信息)、all(全部)"
                    }
                },
                required = {}
            }
        }
    }
}

-- 运行模式：smart(智能), default(默认询问), yolo(从不询问)
Tools.runMode = "default"

-- 高风险关键词（用于智能模式判断）
local HIGH_RISK_PATTERNS = {
    "FireServer", "InvokeServer", "RemoteEvent", "RemoteFunction",
    "kick", "Kick", "ban", "Ban",
    "destroy", "Destroy", "remove", "Remove",
    "sethiddenproperty", "setsimulationradius",
    "gethiddenproperty", "request",
    "HttpPost", "HttpGet"
}

-- 设置运行模式
function Tools:setRunMode(mode)
    if mode == "smart" or mode == "default" or mode == "yolo" then
        self.runMode = mode
        return true
    end
    return false
end

-- 获取运行模式
function Tools:getRunMode()
    return self.runMode
end

-- 检查代码风险（智能模式使用）
function Tools:analyzeRisk(code)
    local riskLevel = "low"
    local reasons = {}
    
    for _, pattern in ipairs(HIGH_RISK_PATTERNS) do
        if code:find(pattern, 1, true) then
            riskLevel = "high"
            table.insert(reasons, "包含: " .. pattern)
        end
    end
    
    -- 检查是否有循环或大量操作
    if code:find("while%s+true") or code:find("for%s+%w+%s*=") then
        if riskLevel ~= "high" then
            riskLevel = "medium"
        end
        table.insert(reasons, "包含循环结构")
    end
    
    -- 检查是否有延迟操作
    if code:find("wait%s*%(") or code:find("task%.wait") then
        if riskLevel ~= "high" then
            riskLevel = "medium"
        end
        table.insert(reasons, "包含等待操作")
    end
    
    return riskLevel, reasons
end

-- 判断是否需要询问用户
function Tools:shouldAskUser(code, riskLevel)
    if self.runMode == "yolo" then
        return false, "YOLO模式"
    elseif self.runMode == "smart" then
        -- 智能模式：low风险不询问
        if riskLevel == "low" then
            return false, "智能模式-低风险"
        else
            return true, "智能模式-" .. riskLevel .. "风险"
        end
    else
        -- 默认模式：总是询问
        return true, "默认模式"
    end
end

-- 等待用户确认（通过全局变量）
function Tools:waitForConfirmation(description, code)
    -- 设置等待状态
    self.pendingExecution = {
        description = description,
        code = code
    }
    
    -- 返回特殊标记，表示需要等待确认（包含完整代码）
    return {
        needsConfirmation = true,
        description = description,
        code = code,  -- 完整代码
        codePreview = code:sub(1, 200) .. (#code > 200 and "..." or "")  -- 保留预览用于日志
    }
end

-- 执行确认后的代码
function Tools:executeConfirmed()
    if not self.pendingExecution then
        return {error = "No pending execution"}
    end
    
    local code = self.pendingExecution.code
    self.pendingExecution = nil
    
    return self:runCode(code)
end

-- 取消执行
function Tools:cancelExecution()
    self.pendingExecution = nil
    return {cancelled = true}
end

-- 实际运行代码（带超时保护）
function Tools:runCode(code)
    local startTime = tick()
    local output = {}
    local success, result
    local timeout = 10  -- 10秒超时
    local timedOut = false
    
    -- 重定向print输出
    local oldPrint = print
    local oldWarn = warn
    
    print = function(...)
        local args = {...}
        local str = ""
        for i, v in ipairs(args) do
            str = str .. tostring(v) .. (i < #args and " " or "")
        end
        table.insert(output, "[OUTPUT] " .. str)
    end
    
    warn = function(...)
        local args = {...}
        local str = ""
        for i, v in ipairs(args) do
            str = str .. tostring(v) .. (i < #args and " " or "")
        end
        table.insert(output, "[WARN] " .. str)
    end
    
    -- 执行代码
    local fn, err = loadstring(code)
    if not fn then
        success = false
        result = "语法错误: " .. tostring(err)
    else
        -- 使用coroutine实现超时
        local co = coroutine.create(fn)
        local deadline = startTime + timeout
        
        local function checkTimeout()
            if tick() > deadline then
                timedOut = true
                -- 尝试关闭coroutine（不保证成功）
                coroutine.close(co)
            end
        end
        
        -- 定期检查超时
        local checkConnection
        if game:GetService("RunService").Heartbeat then
            checkConnection = game:GetService("RunService").Heartbeat:Connect(checkTimeout)
        end
        
        -- 执行
        local ok, res = coroutine.resume(co)
        
        if checkConnection then
            checkConnection:Disconnect()
        end
        
        if timedOut then
            success = false
            result = "执行超时（超过" .. timeout .. "秒），脚本可能包含耗时操作"
        elseif ok then
            success = true
            result = res
        else
            success = false
            result = tostring(res)
        end
    end
    
    -- 恢复print
    print = oldPrint
    warn = oldWarn
    
    local executionTime = tick() - startTime
    
    -- 执行时间警告
    local warning = nil
    if executionTime > 3 then
        warning = string.format("⚠️ 执行耗时 %.1f 秒，可能影响游戏流畅度", executionTime)
    end
    
    return {
        success = success,
        result = result and tostring(result) or nil,
        output = #output > 0 and output or nil,
        executionTime = executionTime,
        error = not success and result or nil,
        warning = warning,
        timedOut = timedOut
    }
end

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
    elseif toolName == "search_in_script" then
        return self:searchInScript(args, Reader, Scanner)
    elseif toolName == "run_script" then
        return self:runScript(args)
    elseif toolName == "get_console_output" then
        return self:getConsoleOutput(args)
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
    local startLine = args.start_line
    local endLine = args.end_line
    
    if not name then
        return {error = "Script name required"}
    end
    
    if not Reader or not Reader:canDecompile() then
        return {error = "Script reading not available (need decompile support)"}
    end
    
    -- 先查找脚本
    local scripts = Reader:getAllScripts()
    local nameLower = name:lower()
    local bestMatch = nil
    local bestScore = 0
    
    for _, script in ipairs(scripts) do
        local scriptName = script.Name:lower()
        local scriptPath = script:GetFullName():lower()
        
        -- 计算匹配分数
        local score = 0
        
        -- 完全匹配名称 = 最高分
        if scriptName == nameLower then
            score = 100
        -- 名称包含查询 = 中等分
        elseif scriptName:find(nameLower, 1, true) then
            score = 50
        end
        
        -- 路径匹配加分
        if scriptPath:find(nameLower, 1, true) then
            score = score + 30
        end
        
        -- 选择最高分的匹配
        if score > bestScore then
            bestScore = score
            bestMatch = script
        end
    end
    
    if bestMatch then
        local data = Reader:readScript(bestMatch)
        if data and data.source then
            local source = data.source
            local totalLines = data.lines or 0
            
            -- 处理行范围
            if startLine or endLine then
                startLine = startLine or 1
                endLine = endLine or totalLines
                
                -- 分割成行
                local lines = {}
                for line in source:gmatch("[^\n]+") do
                    table.insert(lines, line)
                end
                
                -- 提取指定范围
                local rangeLines = {}
                for i = startLine, math.min(endLine, #lines) do
                    table.insert(rangeLines, string.format("%4d: %s", i, lines[i] or ""))
                end
                
                if #rangeLines > 0 then
                    source = table.concat(rangeLines, "\n")
                else
                    source = "-- No lines in range"
                end
                
                return {
                    name = data.name,
                    type = data.className,
                    path = data.path,
                    source = source,
                    size = #source,
                    lines = totalLines,
                    lineRange = {
                        start = startLine,
                        end_ = math.min(endLine, #lines),
                        total = #lines
                    }
                }
            end
            
            return {
                name = data.name,
                type = data.className,
                path = data.path,
                source = source,
                size = #source,
                lines = totalLines
            }
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

-- 在脚本中搜索文本
function Tools:searchInScript(args, Reader, Scanner)
    local searchText = args.text
    if not searchText or searchText == "" then
        return {error = "Search text required"}
    end
    
    if not Reader or not Reader:canDecompile() then
        return {error = "Script reading not available (need decompile support)"}
    end
    
    if not Scanner or not Scanner.cache then
        return {error = "Scanner not initialized"}
    end
    
    local scriptName = args.script_name
    local contextLines = args.context_lines or 2
    local searchLower = searchText:lower()
    
    local results = {}
    local totalMatches = 0
    
    -- 获取所有脚本
    local scripts = Reader:getAllScripts()
    
    -- 限制搜索的脚本数量，避免卡死
    local maxScriptsToSearch = 50
    local scriptsSearched = 0
    
    for _, script in ipairs(scripts) do
        -- 如果已经搜索了足够的脚本，停止
        if scriptsSearched >= maxScriptsToSearch then
            break
        end
        
        -- 如果指定了脚本名，只搜索匹配的脚本
        if scriptName and not script.Name:lower():find(scriptName:lower(), 1, true) then
            -- 跳过不匹配的脚本
        else
            scriptsSearched = scriptsSearched + 1
            
            local success, data = pcall(function()
                return Reader:readScript(script)
            end)
            
            if success and data and data.source then
                local matches = {}
                local lines = {}
                local lineNum = 0
                
                -- 按行分割源码
                for line in data.source:gmatch("[^\n]+") do
                    lineNum = lineNum + 1
                    lines[lineNum] = line
                end
                
                -- 搜索每一行
                for i = 1, lineNum do
                    local line = lines[i]
                    if line and line:lower():find(searchLower, 1, true) then
                        totalMatches = totalMatches + 1
                        
                        -- 提取上下文
                        local context = {}
                        for j = math.max(1, i - contextLines), math.min(lineNum, i + contextLines) do
                            table.insert(context, {
                                lineNum = j,
                                text = lines[j] or "",
                                isMatch = j == i
                            })
                        end
                        
                        table.insert(matches, {
                            lineNum = i,
                            line = line,
                            context = context
                        })
                    end
                end
                
                if #matches > 0 then
                    table.insert(results, {
                        name = data.name,
                        type = data.className,
                        path = data.path,
                        matchCount = #matches,
                        matches = #matches > 3 and {matches[1], matches[2], matches[3]} or matches,
                        truncated = #matches > 3
                    })
                end
            end
        end
        
        -- 限制结果数量
        if #results >= 10 then break end
    end
    
    return {
        searchText = searchText,
        totalMatches = totalMatches,
        scriptCount = #results,
        scriptsSearched = scriptsSearched,
        searchLimit = maxScriptsToSearch,
        limited = scriptsSearched >= maxScriptsToSearch,
        results = results
    }
end

-- 运行脚本
function Tools:runScript(args)
    local code = args.code
    local description = args.description or "执行脚本"
    local riskLevel = args.risk_level
    
    if not code or code == "" then
        return {error = "代码不能为空"}
    end
    
    -- 如果没有提供风险等级，自动分析
    if not riskLevel then
        riskLevel = select(1, self:analyzeRisk(code))
    end
    
    -- 判断是否需要询问
    local needAsk, reason = self:shouldAskUser(code, riskLevel)
    
    if needAsk then
        -- 需要用户确认
        return self:waitForConfirmation(description, code)
    else
        -- 直接执行
        local result = self:runCode(code)
        result.mode = reason
        result.description = description
        return result
    end
end

-- 获取控制台输出
function Tools:getConsoleOutput(args)
    local filter = args.filter
    local maxEntries = args.max_entries or 50
    local logType = args.log_type or "all"
    
    -- 获取LogService
    local LogService = game:GetService("LogService")
    if not LogService then
        return {error = "无法访问LogService"}
    end
    
    -- 获取日志历史
    local success, logHistory = pcall(function()
        return LogService:GetLogHistory()
    end)
    
    if not success then
        return {error = "无法获取日志历史: " .. tostring(logHistory)}
    end
    
    -- 日志类型映射
    local typeMap = {
        ["all"] = nil,  -- 不过滤
        ["output"] = Enum.MessageType.MessageOutput,
        ["warn"] = Enum.MessageType.MessageWarning,
        ["error"] = Enum.MessageType.MessageError,
        ["info"] = Enum.MessageType.MessageInfo
    }
    
    local targetType = typeMap[logType]
    
    -- 过滤日志
    local filteredLogs = {}
    local filterLower = filter and filter:lower() or nil
    
    for _, logEntry in ipairs(logHistory) do
        local shouldInclude = true
        
        -- 类型过滤
        if targetType and logEntry.messageType ~= targetType then
            shouldInclude = false
        end
        
        -- 关键词过滤
        if shouldInclude and filterLower then
            local messageLower = logEntry.message:lower()
            if not messageLower:find(filterLower, 1, true) then
                shouldInclude = false
            end
        end
        
        if shouldInclude then
            table.insert(filteredLogs, {
                type = tostring(logEntry.messageType):gsub("Enum%.MessageType%.", ""),
                message = logEntry.message,
                timestamp = logEntry.timestamp
            })
        end
    end
    
    -- 限制数量（取最近的）
    local totalLogs = #filteredLogs
    if #filteredLogs > maxEntries then
        local startIndex = #filteredLogs - maxEntries + 1
        local trimmed = {}
        for i = startIndex, #filteredLogs do
            table.insert(trimmed, filteredLogs[i])
        end
        filteredLogs = trimmed
    end
    
    -- 格式化输出
    local formattedLogs = {}
    for i, log in ipairs(filteredLogs) do
        local typeIcon = "📝"
        if log.type == "MessageWarning" then typeIcon = "⚠️"
        elseif log.type == "MessageError" then typeIcon = "❌"
        elseif log.type == "MessageInfo" then typeIcon = "ℹ️"
        end
        
        -- 截断过长的消息
        local msg = log.message
        if #msg > 500 then
            msg = msg:sub(1, 500) .. "...(截断)"
        end
        
        table.insert(formattedLogs, string.format("%s [%s] %s", typeIcon, log.type, msg))
    end
    
    return {
        success = true,
        totalLogs = totalLogs,
        returnedLogs = #filteredLogs,
        filter = filter,
        logType = logType,
        logs = formattedLogs,
        rawLogs = filteredLogs  -- 原始数据供程序使用
    }
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
    
    -- 需要用户确认的情况
    if result.needsConfirmation then
        parts[#parts + 1] = "⏳ 需要确认运行脚本:"
        parts[#parts + 1] = "描述: " .. result.description
        parts[#parts + 1] = "完整代码:"
        parts[#parts + 1] = "```lua"
        parts[#parts + 1] = result.code or result.codePreview
        parts[#parts + 1] = "```"
        parts[#parts + 1] = "[等待用户确认...]"
        return table.concat(parts, "\n")
    end
    
    -- 运行结果
    if result.success ~= nil then
        if result.success then
            parts[#parts + 1] = "✅ 脚本执行成功"
            if result.mode then
                parts[#parts + 1] = "模式: " .. result.mode
            end
            if result.executionTime then
                parts[#parts + 1] = string.format("耗时: %.3f秒", result.executionTime)
            end
            if result.result then
                parts[#parts + 1] = "返回值: " .. result.result
            end
            if result.output and #result.output > 0 then
                parts[#parts + 1] = "输出:"
                for _, line in ipairs(result.output) do
                    parts[#parts + 1] = "  " .. line
                end
            end
            if result.warning then
                parts[#parts + 1] = result.warning
            end
        else
            parts[#parts + 1] = "❌ 脚本执行失败"
            if result.error then
                parts[#parts + 1] = "错误: " .. tostring(result.error)
            end
            if result.timedOut then
                parts[#parts + 1] = "💡 建议: 将复杂脚本拆分成多个小步骤，或使用spawn()异步执行"
            end
        end
        return table.concat(parts, "\n")
    end
    
    if result.cancelled then
        return "⚠️ 脚本执行已取消"
    end
    
    if result.results and result.searchText then
        -- search_in_script 结果
        parts[#parts + 1] = string.format("在脚本中搜索 '%s' 找到 %d 处匹配 (共 %d 个脚本):", 
            result.searchText, result.totalMatches, result.scriptCount)
        for i, script in ipairs(result.results) do
            parts[#parts + 1] = string.format("\n📁 %s [%s] - %d 处匹配", 
                script.name, script.type, script.matchCount)
            for _, match in ipairs(script.matches) do
                parts[#parts + 1] = string.format("  第 %d 行: %s", 
                    match.lineNum, match.line:sub(1, 80))
            end
            if script.truncated then
                parts[#parts + 1] = "  ... 还有更多匹配"
            end
        end
    elseif result.results then
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
        
        -- 显示行范围信息
        if result.lineRange then
            local r = result.lineRange
            parts[#parts + 1] = string.format("Lines %d-%d of %d:", r.start, r.end_, r.total)
        else
            parts[#parts + 1] = string.format("Size: %d bytes, %d lines", result.size, result.lines or 0)
        end
        
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
    elseif result.logs then
        -- 控制台输出结果
        parts[#parts + 1] = string.format("📋 控制台日志 (共 %d 条，返回 %d 条)", result.totalLogs, result.returnedLogs)
        if result.filter then
            parts[#parts + 1] = "过滤关键词: " .. result.filter
        end
        if result.logType and result.logType ~= "all" then
            parts[#parts + 1] = "日志类型: " .. result.logType
        end
        parts[#parts + 1] = ""
        for _, log in ipairs(result.logs) do
            parts[#parts + 1] = log
        end
    end
    
    return table.concat(parts, "\n")
end

return Tools
