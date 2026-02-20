--[[
    Roblox AI Resource Analyzer - HTTP Module
    Version: 1.0.0
    
    HTTP请求模块：兼容多种脚本执行器的HTTP请求封装
]]

local Http = {}

-- 检测当前执行器环境
local function detectExecutor()
    local executor = {
        name = "Unknown",
        requestFunc = nil,
        supportsHeaders = true,
        supportsTimeout = true
    }
    
    -- Synapse X / Xeno
    if syn and syn.request then
        executor.name = "Synapse X"
        executor.requestFunc = syn.request
    -- Script-Ware
    elseif request then
        executor.name = "Script-Ware"
        executor.requestFunc = request
    -- KRNL
    elseif krnl and krnl.request then
        executor.name = "KRNL"
        executor.requestFunc = krnl.request
        executor.supportsTimeout = false
    -- Fluxus
    elseif fluxus and fluxus.request then
        executor.name = "Fluxus"
        executor.requestFunc = fluxus.request
    -- Electron
    elseif http and http.request then
        executor.name = "Electron"
        executor.requestFunc = http.request
    -- 其他使用httplib的
    elseif getgenv().http_request then
        executor.name = "httplib"
        executor.requestFunc = getgenv().http_request
    -- 通用回退：使用game.HttpService (仅游戏内)
    else
        executor.name = "HttpService"
        executor.requestFunc = nil
        executor.supportsHeaders = false
        executor.supportsTimeout = false
    end
    
    return executor
end

Http.executor = detectExecutor()

-- 请求选项转换
local function normalizeOptions(options)
    local normalized = {
        Url = options.url or options.Url,
        Method = options.method or options.Method or "GET",
        Headers = options.headers or options.Headers or {},
        Body = options.body or options.Body or "",
        Cookies = options.cookies or options.Cookies or {}
    }
    
    if options.timeout then
        normalized.Timeout = options.timeout
    end
    
    return normalized
end

-- 解析响应
local function parseResponse(rawResponse)
    if type(rawResponse) == "table" then
        return {
            statusCode = rawResponse.StatusCode or rawResponse.statusCode or rawResponse.status_code or 0,
            body = rawResponse.Body or rawResponse.body or rawResponse.BodyText or "",
            headers = rawResponse.Headers or rawResponse.headers or {},
            success = (rawResponse.StatusCode or rawResponse.statusCode or 0) >= 200 and 
                      (rawResponse.StatusCode or rawResponse.statusCode or 0) < 300
        }
    end
    
    return {
        statusCode = 0,
        body = tostring(rawResponse),
        headers = {},
        success = false
    }
end

-- 主请求函数
function Http:request(options)
    local normalized = normalizeOptions(options)
    
    -- 设置默认超时（60秒）
    if not normalized.Timeout then
        normalized.Timeout = 60
    end
    
    -- 使用执行器特定的请求函数
    if self.executor.requestFunc then
        local success, result = pcall(function()
            return self.executor.requestFunc(normalized)
        end)
        
        if success then
            return parseResponse(result)
        else
            return {
                statusCode = 0,
                body = "Request failed: " .. tostring(result),
                headers = {},
                success = false,
                error = tostring(result)
            }
        end
    end
    
    -- 使用game.HttpService (游戏内有限制，只能请求Roblox官方API)
    local HttpService = game:GetService("HttpService")
    local success, result = pcall(function()
        if normalized.Method == "GET" then
            return HttpService:GetAsync(normalized.Url, true)
        else
            return HttpService:PostAsync(
                normalized.Url,
                normalized.Body,
                Enum.HttpContentType.ApplicationJson,
                false
            )
        end
    end)
    
    if success then
        return {
            statusCode = 200,
            body = result,
            headers = {},
            success = true
        }
    else
        return {
            statusCode = 0,
            body = "HttpService request failed: " .. tostring(result),
            headers = {},
            success = false,
            error = tostring(result)
        }
    end
end

-- GET请求
function Http:get(url, headers)
    return self:request({
        url = url,
        method = "GET",
        headers = headers or {}
    })
end

-- POST请求
function Http:post(url, body, headers)
    local bodyData = body
    if type(body) == "table" then
        bodyData = game:GetService("HttpService"):JSONEncode(body)
    end
    
    local finalHeaders = headers or {}
    if not finalHeaders["Content-Type"] then
        finalHeaders["Content-Type"] = "application/json"
    end
    
    return self:request({
        url = url,
        method = "POST",
        body = bodyData,
        headers = finalHeaders
    })
end

-- JSON请求（专为AI API设计）
function Http:jsonRequest(url, method, data, headers)
    local bodyData = ""
    if data then
        bodyData = game:GetService("HttpService"):JSONEncode(data)
    end
    
    local finalHeaders = headers or {}
    finalHeaders["Content-Type"] = "application/json"
    
    local response = self:request({
        url = url,
        method = method,
        body = bodyData,
        headers = finalHeaders
    })
    
    -- 解析JSON响应
    if response.success and response.body and response.body ~= "" then
        local success, decoded = pcall(function()
            return game:GetService("HttpService"):JSONDecode(response.body)
        end)
        if success then
            response.data = decoded
        end
    end
    
    return response
end

-- 获取执行器信息
function Http:getExecutorInfo()
    return {
        name = self.executor.name,
        supportsHeaders = self.executor.supportsHeaders,
        supportsTimeout = self.executor.supportsTimeout
    }
end

-- 检查是否支持外部HTTP请求
function Http:canRequestExternal()
    return self.executor.requestFunc ~= nil
end

return Http
