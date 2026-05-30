-- AI工具定义模块
-- 提供给AI的工具函数，让AI可以主动搜索和读取资源

local Tools = {}

-- 会话级资源缓存：记录本次对话中已读取/搜索过的资源，避免 AI 重复查询
Tools.resourceCache = {
    scripts = {},    -- [name_lower] = {name, path, type, source, lines}
    remotes = {},    -- [name_lower] = {name, path, type, ...}
    searches = {},   -- [query_lower] = {count, results}
}

local function firstNonEmptyString(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
    return nil
end

local function firstNonNil(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value ~= nil then
            return value
        end
    end
    return nil
end

function Tools:normalizeArgs(args)
    args = type(args) == "table" and args or {}
    local normalized = {}

    for key, value in pairs(args) do
        normalized[key] = value
    end

    normalized.name = firstNonEmptyString(
        normalized.name,
        normalized.script_name,
        normalized.script,
        normalized.path,
        normalized.file_path,
        normalized.folder,
        normalized.folder_name,
        normalized.folder_path,
        normalized.resource,
        normalized.resource_name,
        normalized.id,
        normalized.title
    ) or normalized.name

    normalized.output_path = firstNonEmptyString(
        normalized.output_path,
        normalized.output,
        normalized.outputPath,
        normalized.path_out,
        normalized.save_path,
        normalized.target_path,
        normalized.target
    ) or normalized.output_path

    normalized.content = firstNonEmptyString(
        normalized.content,
        normalized.code,
        normalized.source,
        normalized.script_content
    ) or normalized.content

    normalized.description = firstNonEmptyString(
        normalized.description,
        normalized.desc,
        normalized.summary
    ) or normalized.description

    normalized.query = firstNonEmptyString(
        normalized.query,
        normalized.keyword,
        normalized.search,
        normalized.filter
    ) or normalized.query

    normalized.start_line = firstNonNil(normalized.start_line, normalized.startLine, normalized.from_line, normalized.line_start)
    normalized.end_line = firstNonNil(normalized.end_line, normalized.endLine, normalized.to_line, normalized.line_end)
    normalized.max_depth = firstNonNil(normalized.max_depth, normalized.maxDepth, normalized.depth)
    normalized.max_children = firstNonNil(normalized.max_children, normalized.maxChildren, normalized.children_limit)
    normalized.limit = firstNonNil(normalized.limit, normalized.max_results, normalized.count)

    return normalized
end

function Tools:toolError(message, fix, exampleArgs)
    local result = {
        error = message,
        fix = fix,
        retryable = true
    }

    if exampleArgs then
        result.example_args = exampleArgs
    end

    if fix and fix ~= "" then
        result.error = string.format("%s | Fix: %s", tostring(message), tostring(fix))
    end

    return result
end

-- 清空资源缓存（新对话时调用）
function Tools:clearCache()
    self.resourceCache = { scripts = {}, remotes = {}, searches = {} }
end

-- 生成已知资源摘要（注入 system prompt，让 AI 知道哪些已读过）
function Tools:getKnownResourcesSummary()
    local parts = {}

    local scriptNames = {}
    for k in pairs(self.resourceCache.scripts) do
        table.insert(scriptNames, self.resourceCache.scripts[k].name)
    end
    local remoteNames = {}
    for k in pairs(self.resourceCache.remotes) do
        table.insert(remoteNames, self.resourceCache.remotes[k].name)
    end
    local searchQueries = {}
    for k in pairs(self.resourceCache.searches) do
        table.insert(searchQueries, k)
    end

    if #scriptNames == 0 and #remoteNames == 0 and #searchQueries == 0 then
        return nil
    end

    table.insert(parts, "【已读取的游戏资源（无需重复查询）】")
    if #scriptNames > 0 then
        table.insert(parts, "脚本: " .. table.concat(scriptNames, ", "))
    end
    if #remoteNames > 0 then
        table.insert(parts, "Remote: " .. table.concat(remoteNames, ", "))
    end
    if #searchQueries > 0 then
        table.insert(parts, "已搜索关键词: " .. table.concat(searchQueries, ", "))
    end
    table.insert(parts, "如需这些资源的内容，直接使用上下文中已有的信息，不要再次调用工具。")

    return table.concat(parts, "\n")
end

-- 工具定义（用于发送给AI API）
Tools.definitions = {
    {
        type = "function",
        ["function"] = {
            name = "search_resources",
            description = "搜索游戏内的资源对象，如RemoteEvent、RemoteFunction、LocalScript等。返回匹配的资源列表。搜索完成后，你应该分析结果并回答用户的问题，而不是仅仅列出结果。",
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
            description = "读取指定脚本的源代码。优先使用参数 name，兼容 script_name/path/file_path。可以读取完整脚本或指定行范围。返回脚本源码和读取状态。使用@前缀读取注入器文件系统中的文件（如 @workspace/script.lua）。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "脚本名称或路径。使用@前缀读取注入器文件（如 @workspace/test.lua），否则读取游戏内脚本"
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
            name = "save_script",
            description = "将游戏内脚本或执行器文件保存到注入器指定路径。优先使用 name 和 output_path，兼容 script_name/path 与 output/outputPath/save_path。支持把 read_script 读取到的内容直接落盘。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "脚本名称或路径。使用@前缀读取注入器文件（如 @workspace/test.lua），否则读取游戏内脚本"
                    },
                    output_path = {
                        type = "string",
                        description = "保存到执行器文件系统中的目标路径，例如 AICli/output/test.lua"
                    },
                    start_line = {
                        type = "integer",
                        description = "可选：仅读取并保存起始行号之后的内容"
                    },
                    end_line = {
                        type = "integer",
                        description = "可选：仅读取并保存结束行号之前的内容"
                    }
                },
                required = {"name", "output_path"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "list_remotes",
            description = "列出扫描到的 RemoteEvent / RemoteFunction，支持按名称过滤。",
            parameters = {
                type = "object",
                properties = {
                    query = {
                        type = "string",
                        description = "可选：按名称或路径过滤"
                    },
                    limit = {
                        type = "integer",
                        description = "返回数量限制，默认30"
                    }
                },
                required = {}
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
            name = "analyze_remote_usage",
            description = "分析指定 Remote 在脚本中的使用情况，返回引用该 Remote 的脚本、调用方式和上下文。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "Remote 名称或路径"
                    },
                    context_lines = {
                        type = "integer",
                        description = "上下文行数，默认2"
                    }
                },
                required = {"name"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "call_remote",
            description = "直接调用指定 Remote。支持 RemoteEvent 的 FireServer 和 RemoteFunction 的 InvokeServer。arguments_json 传 JSON 数组，如 [1,\"abc\",true]。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "Remote 名称或路径"
                    },
                    arguments_json = {
                        type = "string",
                        description = "JSON 数组形式参数，例如 [123,\"test\"]"
                    },
                    mode = {
                        type = "string",
                        enum = {"auto", "fire", "invoke"},
                        description = "调用方式，默认 auto"
                    }
                },
                required = {"name"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "remote_interceptor",
            description = "管理 Remote 调用拦截/监听。当前支持 status/start/stop/flush，用于记录客户端发出的 FireServer/InvokeServer 调用。",
            parameters = {
                type = "object",
                properties = {
                    action = {
                        type = "string",
                        enum = {"status", "start", "stop", "flush"},
                        description = "操作类型"
                    }
                },
                required = {"action"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "inspect_resource_folder",
            description = "查看某个文件夹/容器内的资源结构，返回层级树、子节点统计和详细格式化结果。优先使用参数 name，兼容 folder/folder_name/folder_path/path。适合分析 Workspace、ReplicatedStorage 下的某个目录。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "文件夹或容器的名称/路径，例如 ReplicatedStorage.Remotes 或 Workspace.Game"
                    },
                    max_depth = {
                        type = "integer",
                        description = "最大递归深度，默认3，最大6"
                    },
                    max_children = {
                        type = "integer",
                        description = "每层最多展示的子节点数量，默认25，最大60"
                    }
                },
                required = {"name"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "list_saved_scripts",
            description = "列出 AI 之前生成并自动暂存的脚本。可按标题过滤，便于后续直接修改或调用，而不必重新生成。",
            parameters = {
                type = "object",
                properties = {
                    query = {
                        type = "string",
                        description = "可选：按标题或描述过滤"
                    },
                    limit = {
                        type = "integer",
                        description = "返回数量限制，默认20"
                    }
                },
                required = {}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "get_saved_script",
            description = "读取已暂存的 AI 脚本内容，可直接查看、修改或交给 run_script 执行。优先使用参数 name，兼容 id/title。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "脚本 id 或标题"
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
            name = "save_temp_script",
            description = "保存或覆盖临时脚本库中的脚本。适合把修改后的脚本重新暂存，供后续继续调用。优先使用参数 name 和 content，兼容 title 与 code/source。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "脚本标题；若与现有脚本匹配则更新，否则新建"
                    },
                    content = {
                        type = "string",
                        description = "脚本源码"
                    },
                    description = {
                        type = "string",
                        description = "可选描述"
                    }
                },
                required = {"name", "content"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "run_saved_script",
            description = "直接执行临时脚本库中的脚本，无需再次生成代码。优先使用参数 name，兼容 id/title。",
            parameters = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                        description = "脚本 id 或标题"
                    },
                    description = {
                        type = "string",
                        description = "可选：执行描述"
                    },
                    risk_level = {
                        type = "string",
                        enum = {"low", "medium", "high"},
                        description = "风险等级，默认 medium"
                    }
                },
                required = {"name"}
            }
        }
    },
    {
        type = "function",
        ["function"] = {
            name = "inspect_ui_resources",
            description = "查看页面 HUD、PlayerGui、StarterGui、CoreGui 等 UI 资源结构及关键信息，例如 Visible、Enabled、Text、Image。",
            parameters = {
                type = "object",
                properties = {
                    scope = {
                        type = "string",
                        enum = {"playergui", "startergui", "coregui", "all"},
                        description = "查看范围，默认 playergui"
                    },
                    query = {
                        type = "string",
                        description = "可选：按 UI 名称过滤"
                    },
                    max_depth = {
                        type = "integer",
                        description = "最大递归深度，默认3，最大6"
                    },
                    max_children = {
                        type = "integer",
                        description = "每层最多展示数量，默认30，最大80"
                    }
                },
                required = {}
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
Tools.remoteInterceptor = {
    active = false,
    installed = false,
    hooks = {},
    logs = {},
    maxLogs = 100
}

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
    local Executor = context.Executor
    args = self:normalizeArgs(args)

    if toolName == "search_resources" then
        -- 缓存：相同 query+type 直接返回
        local cacheKey = (args.query or ""):lower() .. "|" .. (args.resource_type or "all")
        if self.resourceCache.searches[cacheKey] then
            local cached = self.resourceCache.searches[cacheKey]
            return { query = args.query, count = cached.count, results = cached.results, _cached = true }
        end
        local result = self:searchResources(args, Scanner)
        if not result.error then
            self.resourceCache.searches[cacheKey] = { count = result.count, results = result.results }
        end
        return result

    elseif toolName == "read_script" then
        -- 缓存：无行范围限制时缓存完整源码；有行范围则不缓存（分段读取）
        local nameKey = (args.name or ""):lower()
        if not args.start_line and not args.end_line and self.resourceCache.scripts[nameKey] then
            local cached = self.resourceCache.scripts[nameKey]
            return { name = cached.name, type = cached.type, path = cached.path,
                     source = cached.source, size = #cached.source, lines = cached.lines, _cached = true, status = "success", statusIcon = "✓" }
        end
        local result = self:readScript(args, Reader, Scanner, Executor)
        if not result.error and not args.start_line and not args.end_line then
            self.resourceCache.scripts[nameKey] = {
                name = result.name, type = result.type, path = result.path,
                source = result.source or "", lines = result.lines or 0
            }
        end
        return result

    elseif toolName == "save_script" then
        return self:saveScriptToFile(args, Reader, Scanner, Executor)
    elseif toolName == "list_saved_scripts" then
        return self:listSavedScripts(args)
    elseif toolName == "get_saved_script" then
        return self:getSavedScript(args)
    elseif toolName == "save_temp_script" then
        return self:saveTempScript(args)
    elseif toolName == "run_saved_script" then
        return self:runSavedScript(args)

    elseif toolName == "list_remotes" then
        return self:listRemotes(args, Scanner)

    elseif toolName == "get_remote_info" then
        local nameKey = (args.name or ""):lower()
        if self.resourceCache.remotes[nameKey] then
            local cached = self.resourceCache.remotes[nameKey]
            return { name = cached.name, type = cached.type, path = cached.path,
                     parameters = cached.parameters, example = cached.example, _cached = true }
        end
        local result = self:getRemoteInfo(args, Scanner)
        if not result.error then
            self.resourceCache.remotes[nameKey] = {
                name = result.name, type = result.type, path = result.path,
                parameters = result.parameters, example = result.example
            }
        end
        return result

    elseif toolName == "analyze_remote_usage" then
        return self:analyzeRemoteUsage(args, Reader, Scanner)
    elseif toolName == "call_remote" then
        return self:callRemote(args, Scanner)
    elseif toolName == "remote_interceptor" then
        return self:remoteInterceptorAction(args)
    elseif toolName == "inspect_resource_folder" then
        return self:inspectResourceFolder(args, Scanner)
    elseif toolName == "inspect_ui_resources" then
        return self:inspectUIResources(args)
    elseif toolName == "list_resources" then
        return self:listResources(args, Scanner)
    elseif toolName == "search_in_script" then
        return self:searchInScript(args, Reader, Scanner)
    elseif toolName == "run_script" then
        return self:runScript(args)
    elseif toolName == "get_console_output" then
        return self:getConsoleOutput(args)
    end
    
    return self:toolError(
        "Unknown tool: " .. tostring(toolName),
        "Use one of the declared tool names exactly as provided by the tool list."
    )
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

function Tools:listRemotes(args, Scanner)
    if not Scanner or not Scanner.cache then
        return {error = "Scanner not initialized"}
    end

    local query = (args.query or ""):lower()
    local limit = math.max(1, math.min(tonumber(args.limit) or 30, 100))
    local results = {}

    for _, remote in ipairs(Scanner.cache.remotes or {}) do
        local path = (remote.path or ""):lower()
        local name = (remote.name or ""):lower()
        if query == "" or name:find(query, 1, true) or path:find(query, 1, true) then
            table.insert(results, {
                name = remote.name,
                type = remote.className,
                path = remote.path
            })
            if #results >= limit then
                break
            end
        end
    end

    return {
        query = args.query or "",
        count = #results,
        total = #(Scanner.cache.remotes or {}),
        results = results
    }
end

function Tools:listSavedScripts(args)
    local ScriptLibrary = _G.AIAnalyzer and _G.AIAnalyzer.ScriptLibrary
    if not ScriptLibrary or not ScriptLibrary.canPersist or not ScriptLibrary:canPersist() then
        return self:toolError(
            "Script library not available",
            "Do not call saved-script tools until the executor supports readfile and writefile."
        )
    end

    local query = tostring(args.query or ""):lower()
    local limit = math.max(1, math.min(tonumber(args.limit) or 20, 100))
    local scripts = ScriptLibrary:listScripts()
    local results = {}

    for _, item in ipairs(scripts) do
        local title = tostring(item.title or ""):lower()
        local description = tostring(item.description or ""):lower()
        if query == "" or title:find(query, 1, true) or description:find(query, 1, true) then
            table.insert(results, {
                id = item.id,
                name = item.title,
                description = item.description,
                updatedAt = item.updatedAt,
                createdAt = item.createdAt
            })
            if #results >= limit then
                break
            end
        end
    end

    return {
        query = args.query or "",
        count = #results,
        total = #scripts,
        results = results
    }
end

function Tools:getSavedScript(args)
    local ScriptLibrary = _G.AIAnalyzer and _G.AIAnalyzer.ScriptLibrary
    if not ScriptLibrary or not ScriptLibrary.canPersist or not ScriptLibrary:canPersist() then
        return self:toolError(
            "Script library not available",
            "Do not call saved-script tools until the executor supports readfile and writefile."
        )
    end

    local script = ScriptLibrary:getScript(args.name)
    if not script then
        return self:toolError(
            "Saved script not found: " .. tostring(args.name),
            "Call list_saved_scripts first, then retry get_saved_script with an existing id or exact title.",
            { name = "example_script_id_or_title" }
        )
    end

    local source = script.content or ""
    local totalLines = 0
    local lines = {}
    for line in source:gmatch("[^\n]*") do
        totalLines = totalLines + 1
        lines[totalLines] = line
    end

    if args.start_line or args.end_line then
        local startLine = args.start_line or 1
        local endLine = math.min(args.end_line or totalLines, totalLines)
        local rangeLines = {}
        for i = startLine, endLine do
            rangeLines[#rangeLines + 1] = string.format("%4d: %s", i, lines[i] or "")
        end
        source = #rangeLines > 0 and table.concat(rangeLines, "\n") or "-- No lines in range"
        return {
            name = script.title,
            type = "saved_ai_script",
            path = "temp://" .. tostring(script.id),
            source = source,
            size = #source,
            lines = totalLines,
            savedScriptId = script.id,
            description = script.description,
            status = "success",
            statusIcon = "✓",
            lineRange = {
                start = startLine,
                end_ = endLine,
                total = totalLines
            }
        }
    end

    return {
        name = script.title,
        type = "saved_ai_script",
        path = "temp://" .. tostring(script.id),
        source = source,
        size = #source,
        lines = totalLines,
        savedScriptId = script.id,
        description = script.description,
        status = "success",
        statusIcon = "✓"
    }
end

function Tools:saveTempScript(args)
    local ScriptLibrary = _G.AIAnalyzer and _G.AIAnalyzer.ScriptLibrary
    if not ScriptLibrary or not ScriptLibrary.canPersist or not ScriptLibrary:canPersist() then
        return self:toolError(
            "Script library not available",
            "Do not call save_temp_script until the executor supports readfile and writefile."
        )
    end

    local existing = ScriptLibrary:getScript(args.name)
    local saved, err
    if existing then
        saved, err = ScriptLibrary:updateScript(existing.id, args.content, args.name, {
            description = args.description,
            source = "tool_save_temp_script"
        })
    else
        saved, err = ScriptLibrary:saveScript(args.name, args.content, {
            description = args.description,
            source = "tool_save_temp_script"
        })
    end

    if not saved then
        return self:toolError(
            "Failed to save temp script: " .. tostring(err),
            "Retry with non-empty content and a short name/title. If updating, first call list_saved_scripts to confirm the target script."
        )
    end

    return {
        success = true,
        id = saved.id,
        name = saved.title,
        description = saved.description,
        updatedAt = saved.updatedAt,
        bytes = #(saved.content or "")
    }
end

function Tools:runSavedScript(args)
    local ScriptLibrary = _G.AIAnalyzer and _G.AIAnalyzer.ScriptLibrary
    if not ScriptLibrary or not ScriptLibrary.canPersist or not ScriptLibrary:canPersist() then
        return self:toolError(
            "Script library not available",
            "Do not call run_saved_script until the executor supports readfile and writefile."
        )
    end

    local script = ScriptLibrary:getScript(args.name)
    if not script then
        return self:toolError(
            "Saved script not found: " .. tostring(args.name),
            "Call list_saved_scripts first, then retry run_saved_script with an existing id or exact title.",
            { name = "example_script_id_or_title" }
        )
    end

    return self:runScript({
        code = script.content or "",
        description = args.description or ("运行临时脚本: " .. tostring(script.title)),
        risk_level = args.risk_level or "medium"
    })
end

-- 读取脚本源码
function Tools:readScript(args, Reader, Scanner, Executor)
    local name = args.name
    local startLine = args.start_line
    local endLine = args.end_line
    
    if not name then
        return self:toolError(
            "Script name required",
            "Retry read_script with `name`. For executor files use `@path/to/file.lua`; for in-game scripts use script name or full path.",
            { name = "StarterPlayer.StarterPlayerScripts.Main" }
        )
    end
    
    -- 检测 @ 前缀，表示注入器文件系统中的文件
    if name:sub(1, 1) == "@" then
        local filePath = name:sub(2)  -- 移除 @ 前缀
        
        if not Executor or not Executor.readfile then
            return self:toolError(
                "File reading not supported by executor",
                "Do not use @file-path reading on this executor. Retry with an in-game script name/path, or switch to an executor that supports readfile."
            )
        end
        
        local success, content = pcall(Executor.readfile, filePath)
        if not success then
            return self:toolError(
                "Failed to read file: " .. tostring(content),
                "Verify the @file path exists and retry with the exact executor file path."
            )
        end
        
        if not content then
            return self:toolError(
                "File not found or empty: " .. filePath,
                "Retry with an existing executor file path prefixed by @, for example `@workspace/test.lua`."
            )
        end
        
        -- 计算行数
        local lines = {}
        for line in content:gmatch("[^\n]*") do
            table.insert(lines, line)
        end
        local totalLines = #lines
        
        -- 处理行范围
        if startLine or endLine then
            startLine = startLine or 1
            endLine = endLine or totalLines
            
            local rangeLines = {}
            for i = startLine, math.min(endLine, totalLines) do
                table.insert(rangeLines, string.format("%4d: %s", i, lines[i] or ""))
            end
            
            if #rangeLines > 0 then
                content = table.concat(rangeLines, "\n")
            else
                content = "-- No lines in range"
            end
            
            return {
                name = filePath:match("[^/]+$") or filePath,
                type = "executor_file",
                path = filePath,
                source = content,
                size = #content,
                lines = totalLines,
                lineRange = {
                    start = startLine,
                    end_ = math.min(endLine, totalLines),
                    total = totalLines
                }
            }
        end
        
            return {
                name = filePath:match("[^/]+$") or filePath,
                type = "executor_file",
                path = filePath,
                source = content,
                size = #content,
                lines = totalLines,
                status = "success",
                statusIcon = "✓"
            }
        end
    
    -- 游戏内脚本读取
    if not Reader or not Reader:canDecompile() then
        return self:toolError(
            "Script reading not available (need getscriptbytecode + external HTTP access)",
            "Do not retry read_script for in-game scripts until bytecode reading and external HTTP decompile support are available."
        )
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
                    status = "success",
                    statusIcon = "✓",
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
                lines = totalLines,
                status = "success",
                statusIcon = "✓"
            }
        end
    end
    
    return self:toolError(
        "Script not found: " .. tostring(name),
        "Retry with a more exact script name or full path. If unsure, call search_resources with `resource_type: script` first.",
        { query = tostring(name), resource_type = "script" }
    )
end

function Tools:saveScriptToFile(args, Reader, Scanner, Executor)
    local outputPath = args.output_path
    if not outputPath or outputPath == "" then
        return self:toolError(
            "Output path required",
            "Retry save_script with both `name` and `output_path`. Example output path: `AICli/output/test.lua`.",
            { name = "StarterPlayer.StarterPlayerScripts.Main", output_path = "AICli/output/test.lua" }
        )
    end

    if not Executor or not Executor.writefile then
        return self:toolError(
            "File writing not supported by executor",
            "Do not call save_script until the executor supports writefile."
        )
    end

    local scriptData = self:readScript(args, Reader, Scanner, Executor)
    if scriptData.error then
        return scriptData
    end

    local success, writeErr = pcall(Executor.writefile, outputPath, scriptData.source or "")
    if not success then
        return self:toolError(
            "Failed to save script: " .. tostring(writeErr),
            "Verify the output_path directory is writable and retry with a valid executor file path such as `AICli/output/test.lua`."
        )
    end

    return {
        success = true,
        status = "success",
        statusIcon = "✓",
        name = scriptData.name,
        type = scriptData.type,
        sourcePath = scriptData.path,
        outputPath = outputPath,
        bytes = #(scriptData.source or ""),
        lines = scriptData.lines or 0
    }
end

-- 获取Remote信息
function Tools:getRemoteInfo(args, Scanner)
    local name = args.name
    if not name then
        return self:toolError(
            "Remote name required",
            "Retry with `name`. If unsure, call list_remotes first and then use one returned remote name/path."
        )
    end
    
    if not Scanner or not Scanner.cache then
        return self:toolError(
            "Scanner not initialized",
            "Refresh or rescan game resources before retrying this tool."
        )
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
    
    return self:toolError(
        "Remote not found: " .. tostring(name),
        "Call list_remotes first, then retry with an exact remote name or full path.",
        { query = tostring(name), limit = 20 }
    )
end

local function findRemoteInstance(Scanner, name)
    if not Scanner or not Scanner.cache or not name then
        return nil
    end

    local nameLower = name:lower()
    local bestMatch, bestScore

    for _, remote in ipairs(Scanner.cache.remotes or {}) do
        local score = 0
        local remoteName = (remote.name or ""):lower()
        local remotePath = (remote.path or ""):lower()
        if remotePath == nameLower then
            score = 200
        elseif remoteName == nameLower then
            score = 150
        elseif remotePath:find(nameLower, 1, true) then
            score = 80
        elseif remoteName:find(nameLower, 1, true) then
            score = 50
        end

        if score > 0 and (not bestScore or score > bestScore) then
            bestMatch = remote
            bestScore = score
        end
    end

    return bestMatch
end

function Tools:analyzeRemoteUsage(args, Reader, Scanner)
    local name = args.name
    if not name or name == "" then
        return self:toolError(
            "Remote name required",
            "Retry with `name`. If unsure, call list_remotes first."
        )
    end
    if not Reader or not Reader:canDecompile() then
        return self:toolError(
            "Script reading not available",
            "Do not retry analyze_remote_usage until script decompile support is available."
        )
    end

    local remote = findRemoteInstance(Scanner, name)
    if not remote then
        return self:toolError(
            "Remote not found: " .. tostring(name),
            "Call list_remotes first, then retry with an exact remote name or full path."
        )
    end

    local usageByName = self:searchInScript({
        text = remote.name,
        context_lines = args.context_lines or 2
    }, Reader, Scanner)

    if usageByName.error then
        return usageByName
    end

    return {
        remote = {
            name = remote.name,
            type = remote.className,
            path = remote.path
        },
        scriptCount = usageByName.scriptCount or 0,
        totalMatches = usageByName.totalMatches or 0,
        scriptsSearched = usageByName.scriptsSearched or 0,
        results = usageByName.results or {}
    }
end

local function decodeArgumentValue(value)
    if type(value) ~= "table" then
        return value
    end

    if value.__type == "Vector3" then
        return Vector3.new(tonumber(value.x) or 0, tonumber(value.y) or 0, tonumber(value.z) or 0)
    elseif value.__type == "CFrame" then
        return CFrame.new(unpack(value.components or {}))
    elseif value.__type == "Color3" then
        return Color3.new(tonumber(value.r) or 0, tonumber(value.g) or 0, tonumber(value.b) or 0)
    elseif value.__type == "Instance" and value.path then
        local current = game
        for part in tostring(value.path):gmatch("[^%.]+") do
            if part ~= "game" then
                current = current and current:FindFirstChild(part)
            end
        end
        return current
    end

    local out = {}
    for k, v in pairs(value) do
        out[k] = decodeArgumentValue(v)
    end
    return out
end

local function decodeRemoteArguments(raw)
    if not raw or raw == "" then
        return {}
    end

    local HttpService = game:GetService("HttpService")
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not ok then
        return nil, "arguments_json 不是有效 JSON: " .. tostring(decoded)
    end
    if type(decoded) ~= "table" then
        return nil, "arguments_json 必须是 JSON 数组"
    end

    local args = {}
    for i, value in ipairs(decoded) do
        args[i] = decodeArgumentValue(value)
    end
    return args
end

function Tools:callRemote(args, Scanner)
    local name = args.name
    if not name or name == "" then
        return self:toolError(
            "Remote name required",
            "Retry with `name`. If unsure, call list_remotes first."
        )
    end

    local remoteInfo = findRemoteInstance(Scanner, name)
    if not remoteInfo or not remoteInfo.instance then
        return self:toolError(
            "Remote not found: " .. tostring(name),
            "Call list_remotes first, then retry call_remote with an exact remote name/path."
        )
    end

    local decodedArgs, decodeErr = decodeRemoteArguments(args.arguments_json)
    if not decodedArgs then
        return {error = decodeErr}
    end

    local mode = args.mode or "auto"
    local remote = remoteInfo.instance
    local remoteClass = remoteInfo.className
    local resultValue

    if mode == "auto" then
        mode = remoteClass == "RemoteFunction" and "invoke" or "fire"
    end

    local ok, callErr = pcall(function()
        if mode == "invoke" then
            resultValue = remote:InvokeServer(unpack(decodedArgs))
        elseif mode == "fire" then
            remote:FireServer(unpack(decodedArgs))
        else
            error("Unsupported mode: " .. tostring(mode))
        end
    end)

    if not ok then
        return {error = "Remote call failed: " .. tostring(callErr)}
    end

    return {
        success = true,
        remote = remoteInfo.name,
        type = remoteClass,
        path = remoteInfo.path,
        mode = mode,
        argumentCount = #decodedArgs,
        result = resultValue ~= nil and tostring(resultValue) or nil
    }
end

local function ensureRemoteInterceptor(self)
    if self.remoteInterceptor.installed then
        return true
    end

    if not hookmetamethod or not getnamecallmethod or not newcclosure then
        return false, "当前执行器不支持 Remote 拦截所需的 hookmetamethod/getnamecallmethod/newcclosure"
    end

    local original
    original = hookmetamethod(game, "__namecall", newcclosure(function(target, ...)
        local method = getnamecallmethod()
        if self.remoteInterceptor.active
            and typeof(target) == "Instance"
            and (method == "FireServer" or method == "InvokeServer")
            and (target:IsA("RemoteEvent") or target:IsA("RemoteFunction")) then
            local entry = {
                time = os.date("%H:%M:%S"),
                method = method,
                name = target.Name,
                className = target.ClassName,
                path = target:GetFullName(),
                argumentCount = select("#", ...),
                arguments = {}
            }
            for i = 1, math.min(select("#", ...), 6) do
                entry.arguments[i] = tostring(select(i, ...))
            end
            table.insert(self.remoteInterceptor.logs, 1, entry)
            while #self.remoteInterceptor.logs > self.remoteInterceptor.maxLogs do
                table.remove(self.remoteInterceptor.logs)
            end
        end
        return original(target, ...)
    end))

    self.remoteInterceptor.installed = true
    self.remoteInterceptor.hooks.namecall = original
    return true
end

function Tools:remoteInterceptorAction(args)
    local action = args.action
    if action == "status" then
        return {
            active = self.remoteInterceptor.active,
            installed = self.remoteInterceptor.installed,
            logCount = #self.remoteInterceptor.logs,
            logs = self.remoteInterceptor.logs
        }
    elseif action == "flush" then
        self.remoteInterceptor.logs = {}
        return {
            success = true,
            active = self.remoteInterceptor.active,
            installed = self.remoteInterceptor.installed,
            logCount = 0
        }
    elseif action == "start" then
        local ok, err = ensureRemoteInterceptor(self)
        if not ok then
            return {error = err}
        end
        self.remoteInterceptor.active = true
        return {
            success = true,
            active = true,
            installed = true,
            logCount = #self.remoteInterceptor.logs
        }
    elseif action == "stop" then
        self.remoteInterceptor.active = false
        return {
            success = true,
            active = false,
            installed = self.remoteInterceptor.installed,
            logCount = #self.remoteInterceptor.logs
        }
    end

    return {error = "Unsupported action: " .. tostring(action)}
end

-- 列出资源
function Tools:listResources(args, Scanner)
    local resourceType = args.resource_type or "all"
    local limit = args.limit or 20
    
    if not Scanner or not Scanner.cache then
        return self:toolError(
            "Scanner not initialized",
            "Refresh or rescan game resources before retrying this tool."
        )
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

local function findObjectByNameOrPath(Scanner, name)
    if not Scanner or not Scanner.cache or not name then
        return nil
    end

    local nameLower = tostring(name):lower()
    local bestMatch, bestScore

    for _, obj in ipairs(Scanner.cache.objects or {}) do
        local objName = (obj.name or ""):lower()
        local objPath = (obj.path or ""):lower()
        local score = 0

        if objPath == nameLower then
            score = 300
        elseif objName == nameLower then
            score = 200
        elseif objPath:find(nameLower, 1, true) then
            score = 100
        elseif objName:find(nameLower, 1, true) then
            score = 60
        end

        if score > 0 and (not bestScore or score > bestScore) then
            bestMatch = obj
            bestScore = score
        end
    end

    return bestMatch
end

local function inspectFolderNode(instance, currentDepth, maxDepth, maxChildren, outLines, stats)
    if currentDepth > maxDepth then
        return
    end

    local children = instance:GetChildren()
    table.sort(children, function(a, b)
        if #a:GetChildren() > 0 and #b:GetChildren() == 0 then
            return true
        elseif #a:GetChildren() == 0 and #b:GetChildren() > 0 then
            return false
        end
        return a.Name:lower() < b.Name:lower()
    end)

    stats.totalNodes = stats.totalNodes + #children
    stats.maxBreadth = math.max(stats.maxBreadth, #children)

    local shown = math.min(#children, maxChildren)
    for i = 1, shown do
        local child = children[i]
        local childCount = #child:GetChildren()
        local indent = string.rep("  ", currentDepth)
        local marker = childCount > 0 and "📁" or "•"
        outLines[#outLines + 1] = string.format("%s%s %s [%s]%s",
            indent,
            marker,
            child.Name,
            child.ClassName,
            childCount > 0 and (" {" .. childCount .. "}") or ""
        )
        stats.typeCounts[child.ClassName] = (stats.typeCounts[child.ClassName] or 0) + 1
        if childCount > 0 and currentDepth < maxDepth then
            inspectFolderNode(child, currentDepth + 1, maxDepth, maxChildren, outLines, stats)
        end
    end

    if #children > maxChildren then
        outLines[#outLines + 1] = string.format("%s... 还有 %d 个子节点未展开", string.rep("  ", currentDepth), #children - maxChildren)
    end
end

function Tools:inspectResourceFolder(args, Scanner)
    local name = args.name
    if not name or name == "" then
        return self:toolError(
            "Folder name required",
            "Retry inspect_resource_folder with `name`. If unsure, first call search_resources or list_resources to discover the exact folder/container path.",
            { name = "ReplicatedStorage.Remotes", max_depth = 3, max_children = 25 }
        )
    end
    if not Scanner or not Scanner.cache then
        return self:toolError(
            "Scanner not initialized",
            "Refresh or rescan game resources before retrying this tool."
        )
    end

    local target = findObjectByNameOrPath(Scanner, name)
    if not target or not target.instance then
        return self:toolError(
            "Folder not found: " .. tostring(name),
            "Retry with a more exact folder/container name or full path. If unsure, call search_resources first.",
            { query = tostring(name), resource_type = "all" }
        )
    end

    local instance = target.instance
    local childCount = #instance:GetChildren()
    if childCount == 0 then
        return {
            name = target.name,
            type = target.className,
            path = target.path,
            maxDepth = 0,
            maxChildren = 0,
            totalNodes = 0,
            tree = {},
            typeSummary = {}
        }
    end

    local maxDepth = math.max(1, math.min(tonumber(args.max_depth) or 3, 6))
    local maxChildren = math.max(1, math.min(tonumber(args.max_children) or 25, 60))
    local lines = {}
    local stats = {
        totalNodes = 0,
        maxBreadth = 0,
        typeCounts = {}
    }

    inspectFolderNode(instance, 1, maxDepth, maxChildren, lines, stats)

    local typeSummary = {}
    for className, count in pairs(stats.typeCounts) do
        table.insert(typeSummary, {type = className, count = count})
    end
    table.sort(typeSummary, function(a, b)
        if a.count == b.count then
            return a.type < b.type
        end
        return a.count > b.count
    end)

    return {
        name = target.name,
        type = target.className,
        path = target.path,
        rootChildren = childCount,
        maxDepth = maxDepth,
        maxChildren = maxChildren,
        totalNodes = stats.totalNodes,
        maxBreadth = stats.maxBreadth,
        tree = lines,
        typeSummary = typeSummary
    }
end

local function appendUIPropertyBits(instance, bits)
    if instance:IsA("ScreenGui") then
        bits[#bits + 1] = "Enabled=" .. tostring(instance.Enabled)
    elseif instance:IsA("GuiObject") then
        bits[#bits + 1] = "Visible=" .. tostring(instance.Visible)
    end

    if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
        local text = tostring(instance.Text or ""):gsub("%s+", " ")
        if text ~= "" then
            bits[#bits + 1] = "Text=" .. text:sub(1, 24)
        end
    end

    if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
        if tostring(instance.Image or "") ~= "" then
            bits[#bits + 1] = "Image=true"
        end
    end
end

local function walkUINode(instance, query, currentDepth, maxDepth, maxChildren, outLines, stats)
    if currentDepth > maxDepth then
        return
    end

    local children = {}
    for _, child in ipairs(instance:GetChildren()) do
        if child:IsA("GuiObject") or child:IsA("LayerCollector") then
            if query == "" or child.Name:lower():find(query, 1, true) then
                children[#children + 1] = child
            elseif currentDepth < maxDepth then
                children[#children + 1] = child
            end
        end
    end

    table.sort(children, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    local shown = math.min(#children, maxChildren)
    stats.totalNodes = stats.totalNodes + #children
    for i = 1, shown do
        local child = children[i]
        local bits = {}
        appendUIPropertyBits(child, bits)
        stats.typeCounts[child.ClassName] = (stats.typeCounts[child.ClassName] or 0) + 1
        outLines[#outLines + 1] = string.format("%s• %s [%s]%s",
            string.rep("  ", currentDepth),
            child.Name,
            child.ClassName,
            #bits > 0 and (" {" .. table.concat(bits, ", ") .. "}") or ""
        )
        if currentDepth < maxDepth then
            walkUINode(child, query, currentDepth + 1, maxDepth, maxChildren, outLines, stats)
        end
    end

    if #children > maxChildren then
        outLines[#outLines + 1] = string.format("%s... 还有 %d 个 UI 子节点未展开", string.rep("  ", currentDepth), #children - maxChildren)
    end
end

function Tools:inspectUIResources(args)
    local Players = game:GetService("Players")
    local StarterGui = game:GetService("StarterGui")
    local CoreGui = game:GetService("CoreGui")
    local player = Players.LocalPlayer
    local query = tostring(args.query or ""):lower()
    local maxDepth = math.max(1, math.min(tonumber(args.max_depth) or 3, 6))
    local maxChildren = math.max(1, math.min(tonumber(args.max_children) or 30, 80))
    local scope = tostring(args.scope or "playergui"):lower()

    local roots = {}
    if scope == "playergui" or scope == "all" then
        if player and player:FindFirstChild("PlayerGui") then
            roots[#roots + 1] = player.PlayerGui
        end
    end
    if scope == "startergui" or scope == "all" then
        roots[#roots + 1] = StarterGui
    end
    if scope == "coregui" or scope == "all" then
        roots[#roots + 1] = CoreGui
    end

    if #roots == 0 then
        return {error = "No UI roots available for scope: " .. scope}
    end

    local tree = {}
    local typeCounts = {}
    local totalNodes = 0
    for _, root in ipairs(roots) do
        tree[#tree + 1] = string.format("📁 %s [%s]", root.Name, root.ClassName)
        local stats = { totalNodes = 0, typeCounts = {} }
        walkUINode(root, query, 1, maxDepth, maxChildren, tree, stats)
        totalNodes = totalNodes + stats.totalNodes
        for className, count in pairs(stats.typeCounts) do
            typeCounts[className] = (typeCounts[className] or 0) + count
        end
    end

    local summary = {}
    for className, count in pairs(typeCounts) do
        summary[#summary + 1] = {type = className, count = count}
    end
    table.sort(summary, function(a, b)
        if a.count == b.count then return a.type < b.type end
        return a.count > b.count
    end)

    return {
        uiScope = scope,
        query = args.query or "",
        totalNodes = totalNodes,
        maxDepth = maxDepth,
        maxChildren = maxChildren,
        tree = tree,
        typeSummary = summary
    }
end

-- 在脚本中搜索文本
function Tools:searchInScript(args, Reader, Scanner)
    local searchText = args.text
    if not searchText or searchText == "" then
        return {error = "Search text required"}
    end
    
    if not Reader or not Reader:canDecompile() then
        return {error = "Script reading not available (need getscriptbytecode + external HTTP access)"}
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
        if result.results[1] and result.results[1].id and result.results[1].name and result.total then
            parts[#parts + 1] = string.format("Saved scripts (%d/%d):", result.count or #result.results, result.total or #result.results)
            for i, item in ipairs(result.results) do
                if i > 15 then
                    parts[#parts + 1] = "... more saved scripts omitted"
                    break
                end
                parts[#parts + 1] = string.format("  • %s [%s] %s", item.name, item.id, item.updatedAt or "")
            end
            return table.concat(parts, "\n")
        end
        parts[#parts + 1] = string.format("Found %d results:", result.count)
        for i, r in ipairs(result.results) do
            if i > 10 then
                parts[#parts + 1] = "... and " .. (result.count - 10) .. " more"
                break
            end
            parts[#parts + 1] = string.format("  • %s [%s] - %s", r.name, r.type, r.path)
        end
    elseif result.source then
        if result.statusIcon then
            parts[#parts + 1] = string.format("%s Read script success", result.statusIcon)
        end
        parts[#parts + 1] = string.format("Script: %s (%s)", result.name, result.type)
        parts[#parts + 1] = string.format("Path: %s", result.path)
        if result.savedScriptId then
            parts[#parts + 1] = string.format("Saved Script ID: %s", result.savedScriptId)
        end
        if result.description and result.description ~= "" then
            parts[#parts + 1] = string.format("Description: %s", result.description)
        end
        
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
    elseif result.outputPath then
        if result.statusIcon then
            parts[#parts + 1] = string.format("%s Save script success", result.statusIcon)
        end
        parts[#parts + 1] = string.format("Script: %s (%s)", result.name, result.type)
        parts[#parts + 1] = string.format("Source Path: %s", result.sourcePath)
        parts[#parts + 1] = string.format("Saved To: %s", result.outputPath)
        parts[#parts + 1] = string.format("Size: %d bytes, %d lines", result.bytes or 0, result.lines or 0)
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
    elseif result.id and result.name and result.bytes then
        parts[#parts + 1] = "✅ 临时脚本已保存"
        parts[#parts + 1] = string.format("Name: %s", result.name)
        parts[#parts + 1] = string.format("ID: %s", result.id)
        if result.description and result.description ~= "" then
            parts[#parts + 1] = string.format("Description: %s", result.description)
        end
        parts[#parts + 1] = string.format("Size: %d bytes", result.bytes)
        parts[#parts + 1] = string.format("Updated: %s", result.updatedAt or "")
    elseif result.tree then
        if result.uiScope then
            parts[#parts + 1] = string.format("UI Scope: %s", result.uiScope)
            if result.query and result.query ~= "" then
                parts[#parts + 1] = string.format("Query: %s", result.query)
            end
            parts[#parts + 1] = string.format("UI Nodes: %d | Max depth: %d | Per-level limit: %d",
                result.totalNodes or 0,
                result.maxDepth or 0,
                result.maxChildren or 0
            )
            if result.typeSummary and #result.typeSummary > 0 then
                parts[#parts + 1] = "UI type summary:"
                for i, item in ipairs(result.typeSummary) do
                    if i > 12 then
                        parts[#parts + 1] = "  ... more types omitted"
                        break
                    end
                    parts[#parts + 1] = string.format("  • %s x%d", item.type, item.count)
                end
            end
            parts[#parts + 1] = "UI Tree:"
            for _, line in ipairs(result.tree) do
                parts[#parts + 1] = line
            end
            return table.concat(parts, "\n")
        end
        parts[#parts + 1] = string.format("Folder: %s [%s]", result.name or "Unknown", result.type or "Unknown")
        parts[#parts + 1] = string.format("Path: %s", result.path or "")
        parts[#parts + 1] = string.format("Root children: %d | Expanded nodes: %d | Max depth: %d | Per-level limit: %d",
            result.rootChildren or 0,
            result.totalNodes or 0,
            result.maxDepth or 0,
            result.maxChildren or 0
        )
        if result.typeSummary and #result.typeSummary > 0 then
            parts[#parts + 1] = "Type summary:"
            for i, item in ipairs(result.typeSummary) do
                if i > 12 then
                    parts[#parts + 1] = "  ... more types omitted"
                    break
                end
                parts[#parts + 1] = string.format("  • %s x%d", item.type, item.count)
            end
        end
        parts[#parts + 1] = "Tree:"
        for _, line in ipairs(result.tree) do
            parts[#parts + 1] = line
        end
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
