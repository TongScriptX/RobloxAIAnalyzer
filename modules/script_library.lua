local ScriptLibrary = {}

local HttpService = game:GetService("HttpService")

ScriptLibrary.dirName = "RobloxAIAnalyzer"
ScriptLibrary.indexFile = "RobloxAIAnalyzer/temp_scripts_index.json"

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function nowIso()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function safeSlug(text)
    return trim(text):gsub("[^%w_%-]", "_")
end

function ScriptLibrary:getExecutor()
    return _G.AIAnalyzer and _G.AIAnalyzer.Executor
end

function ScriptLibrary:canPersist()
    local exec = self:getExecutor()
    return exec and exec.writefile and exec.readfile
end

function ScriptLibrary:ensureDir()
    local exec = self:getExecutor()
    if exec and exec.makefolder then
        pcall(exec.makefolder, self.dirName)
    end
end

function ScriptLibrary:readJsonFile(path)
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
    return okDecode and data or nil
end

function ScriptLibrary:writeJsonFile(path, data)
    local exec = self:getExecutor()
    if not exec or not exec.writefile then
        return false, "File writing not supported by executor"
    end

    self:ensureDir()

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not okEncode then
        return false, tostring(encoded)
    end

    local okWrite, err = pcall(exec.writefile, path, encoded)
    if not okWrite then
        return false, tostring(err)
    end

    return true
end

function ScriptLibrary:loadIndex()
    local data = self:readJsonFile(self.indexFile)
    if type(data) ~= "table" then
        return { scripts = {} }
    end
    data.scripts = type(data.scripts) == "table" and data.scripts or {}
    return data
end

function ScriptLibrary:saveIndex(index)
    return self:writeJsonFile(self.indexFile, index)
end

function ScriptLibrary:getScriptPath(id)
    return string.format("%s/temp_script_%s.json", self.dirName, safeSlug(id))
end

function ScriptLibrary:generateId()
    return safeSlug(tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)))
end

function ScriptLibrary:hashContent(content)
    local hash = 5381
    for i = 1, #content do
        hash = ((hash * 33) + content:byte(i)) % 2147483647
    end
    return tostring(hash)
end

function ScriptLibrary:makeTitle(content, preferredTitle)
    preferredTitle = trim(preferredTitle)
    if preferredTitle ~= "" then
        return preferredTitle:sub(1, 48)
    end

    local firstLine = trim((content or ""):match("([^\n\r]+)") or "")
    if firstLine ~= "" then
        return firstLine:sub(1, 48)
    end
    return "临时脚本"
end

function ScriptLibrary:listScripts()
    local index = self:loadIndex()
    table.sort(index.scripts, function(a, b)
        return (a.updatedAt or "") > (b.updatedAt or "")
    end)
    return index.scripts
end

function ScriptLibrary:getScript(identifier)
    if not identifier or identifier == "" then
        return nil
    end

    local identLower = tostring(identifier):lower()
    local index = self:loadIndex()
    local best
    local bestScore = 0

    for _, item in ipairs(index.scripts) do
        local score = 0
        local idLower = tostring(item.id or ""):lower()
        local titleLower = tostring(item.title or ""):lower()
        if idLower == identLower then
            score = 200
        elseif titleLower == identLower then
            score = 180
        elseif titleLower:find(identLower, 1, true) then
            score = 100
        elseif idLower:find(identLower, 1, true) then
            score = 80
        end

        if score > bestScore then
            best = item
            bestScore = score
        end
    end

    if not best then
        return nil
    end

    return self:readJsonFile(self:getScriptPath(best.id))
end

function ScriptLibrary:saveScript(title, content, meta)
    meta = meta or {}
    if trim(content) == "" then
        return nil, "Empty script content"
    end

    local hash = self:hashContent(content)
    local index = self:loadIndex()
    for _, item in ipairs(index.scripts) do
        if item.hash == hash then
            local existing = self:readJsonFile(self:getScriptPath(item.id))
            if existing then
                existing.updatedAt = nowIso()
                existing.lastSource = meta.source or existing.lastSource
                self:writeJsonFile(self:getScriptPath(existing.id), existing)
                item.updatedAt = existing.updatedAt
                self:saveIndex(index)
                return existing
            end
        end
    end

    local id = self:generateId()
    local script = {
        id = id,
        title = self:makeTitle(content, title),
        content = content,
        description = trim(meta.description),
        hash = hash,
        createdAt = nowIso(),
        updatedAt = nowIso(),
        lastSource = meta.source,
        sessionId = meta.sessionId
    }

    local ok, err = self:writeJsonFile(self:getScriptPath(id), script)
    if not ok then
        return nil, err
    end

    table.insert(index.scripts, {
        id = script.id,
        title = script.title,
        description = script.description,
        hash = script.hash,
        createdAt = script.createdAt,
        updatedAt = script.updatedAt,
        lastSource = script.lastSource
    })
    self:saveIndex(index)
    return script
end

function ScriptLibrary:updateScript(identifier, content, newTitle, meta)
    local script = self:getScript(identifier)
    if not script then
        return nil, "Script not found: " .. tostring(identifier)
    end
    script.content = content
    script.hash = self:hashContent(content)
    script.title = self:makeTitle(content, newTitle or script.title)
    script.updatedAt = nowIso()
    if meta then
        script.description = trim(meta.description or script.description)
        script.lastSource = meta.source or script.lastSource
    end

    local ok, err = self:writeJsonFile(self:getScriptPath(script.id), script)
    if not ok then
        return nil, err
    end

    local index = self:loadIndex()
    for _, item in ipairs(index.scripts) do
        if item.id == script.id then
            item.title = script.title
            item.description = script.description
            item.hash = script.hash
            item.updatedAt = script.updatedAt
            item.lastSource = script.lastSource
            break
        end
    end
    self:saveIndex(index)
    return script
end

return ScriptLibrary
