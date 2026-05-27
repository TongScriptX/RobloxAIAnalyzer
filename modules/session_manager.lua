-- 会话管理模块
-- 保存/加载历史会话，支持切换当前会话

local SessionManager = {}

local HttpService = game:GetService("HttpService")

SessionManager.dirName = "RobloxAIAnalyzer"
SessionManager.indexFile = "RobloxAIAnalyzer/sessions_index.json"

local function nowIso()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function safeSlug(text)
    return trim(text):gsub("[^%w_%-]", "_")
end

function SessionManager:getExecutor()
    return _G.AIAnalyzer and _G.AIAnalyzer.Executor
end

function SessionManager:canPersist()
    local exec = self:getExecutor()
    return exec and exec.writefile and exec.readfile
end

function SessionManager:ensureDir()
    local exec = self:getExecutor()
    if not exec or not exec.makefolder then
        return false
    end
    pcall(exec.makefolder, self.dirName)
    return true
end

function SessionManager:readJsonFile(path)
    local exec = self:getExecutor()
    if not exec or not exec.readfile then
        return nil
    end

    local ok, content = pcall(exec.readfile, path)
    if not ok or not content or content == "" then
        return nil
    end

    local okDecode, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if okDecode then
        return data
    end

    return nil
end

function SessionManager:writeJsonFile(path, data)
    local exec = self:getExecutor()
    if not exec or not exec.writefile then
        return false, "File writing not supported by executor"
    end

    self:ensureDir()

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not okEncode then
        return false, "Failed to encode JSON: " .. tostring(encoded)
    end

    local okWrite, err = pcall(exec.writefile, path, encoded)
    if not okWrite then
        return false, tostring(err)
    end

    return true
end

function SessionManager:getSessionPath(id)
    return string.format("%s/session_%s.json", self.dirName, safeSlug(id))
end

function SessionManager:loadIndex()
    local data = self:readJsonFile(self.indexFile)
    if type(data) ~= "table" then
        return {
            currentSessionId = nil,
            sessions = {}
        }
    end

    data.sessions = type(data.sessions) == "table" and data.sessions or {}
    return data
end

function SessionManager:saveIndex(index)
    return self:writeJsonFile(self.indexFile, index)
end

function SessionManager:generateSessionId()
    local seed = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    return safeSlug(seed)
end

function SessionManager:makeSessionTitle(messages)
    if type(messages) == "table" then
        for _, msg in ipairs(messages) do
            if msg.role == "user" and msg.content and msg.content ~= "" then
                return trim(msg.content):sub(1, 32)
            end
        end
    end
    return "新会话"
end

function SessionManager:listSessions()
    local index = self:loadIndex()
    table.sort(index.sessions, function(a, b)
        return (a.updatedAt or "") > (b.updatedAt or "")
    end)
    return index.sessions, index.currentSessionId
end

function SessionManager:createSession(initialTitle)
    local id = self:generateSessionId()
    local session = {
        id = id,
        title = trim(initialTitle) ~= "" and trim(initialTitle) or "新会话",
        createdAt = nowIso(),
        updatedAt = nowIso(),
        messages = {},
        summary = nil,
        totalTokens = 0,
        modelName = nil
    }

    local index = self:loadIndex()
    table.insert(index.sessions, {
        id = session.id,
        title = session.title,
        createdAt = session.createdAt,
        updatedAt = session.updatedAt
    })
    index.currentSessionId = session.id

    local ok, err = self:writeJsonFile(self:getSessionPath(id), session)
    if not ok then
        return nil, err
    end

    self:saveIndex(index)
    return session
end

function SessionManager:getSession(id)
    if not id or id == "" then
        return nil
    end
    return self:readJsonFile(self:getSessionPath(id))
end

function SessionManager:saveSession(session)
    if not session or not session.id then
        return false, "Invalid session"
    end

    session.updatedAt = nowIso()
    if not session.title or session.title == "" then
        session.title = self:makeSessionTitle(session.messages)
    end

    local ok, err = self:writeJsonFile(self:getSessionPath(session.id), session)
    if not ok then
        return false, err
    end

    local index = self:loadIndex()
    local found = false
    for _, item in ipairs(index.sessions) do
        if item.id == session.id then
            item.title = session.title
            item.updatedAt = session.updatedAt
            found = true
            break
        end
    end
    if not found then
        table.insert(index.sessions, {
            id = session.id,
            title = session.title,
            createdAt = session.createdAt or session.updatedAt,
            updatedAt = session.updatedAt
        })
    end
    index.currentSessionId = session.id
    self:saveIndex(index)
    return true
end

function SessionManager:setCurrentSessionId(id)
    local index = self:loadIndex()
    index.currentSessionId = id
    self:saveIndex(index)
end

function SessionManager:deleteSession(id)
    local exec = self:getExecutor()
    if not id or id == "" then
        return false, "Invalid session id"
    end

    local index = self:loadIndex()
    local nextSessions = {}
    for _, item in ipairs(index.sessions) do
        if item.id ~= id then
            table.insert(nextSessions, item)
        end
    end
    index.sessions = nextSessions

    if index.currentSessionId == id then
        index.currentSessionId = nextSessions[1] and nextSessions[1].id or nil
    end

    if exec and exec.delfile then
        pcall(exec.delfile, self:getSessionPath(id))
    end

    self:saveIndex(index)
    return true, index.currentSessionId
end

return SessionManager
