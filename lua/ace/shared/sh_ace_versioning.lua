-- ACE versioning - git/workshop/zip aware, ported from ACF-3 lua/acf/core/version_sh.lua
AddCSLuaFile()

ACE = ACE or {}

local Realm = SERVER and "Server" or "Client"

local function LocalToUTC(time)
    return os.time(os.date("!*t", time)) or 0
end

local function GetGitHead(Path)
    local HeadFile = Path .. "/.git/HEAD"
    if not file.Exists(HeadFile, "GAME") then return end
    local content = file.Read(HeadFile, "GAME")
    if not content then return end
    local _, _, head = content:find("refs/heads/(.+)$")
    if not head then return end
    return head:Trim()
end

local function GetGitCommit(Path, Head)
    if not Head then return end
    local RefPath = Path .. "/.git/refs/heads/" .. Head
    if not file.Exists(RefPath, "GAME") then return end
    local sha = file.Read(RefPath, "GAME")
    if not sha then return end
    local BranchSha = string.GetFileFromFilename(Head) .. "-" .. sha:Trim():sub(1, 7)
    local Time = file.Time(RefPath, "GAME")
    return BranchSha, Time
end

local function GetGitOwner(Path)
    local FetchPath = Path .. "/.git/FETCH_HEAD"
    if not file.Exists(FetchPath, "GAME") then return end
    local Fetch = file.Read(FetchPath, "GAME")
    if not Fetch then return end
    local Start, End = Fetch:find("github.com[/]?[:]?[%w_-]+/")
    if not Start then return end
    return Fetch:sub(Start + 11, End - 1)
end

--- Returns local version info, handling git/workshop/zip.
-- @param owner string Expected owner.
-- @param name string Addon name.
-- @param path string Addon path from debug.getinfo.
-- @return table Version {head, code, date, owner, path, realm}
function ACE.CheckLocalVersion(Owner, Name, Path)
    local Result = {
        realm = Realm,
        path = Path,
        head = "master",
        code = "Not Installed",
        date = 0,
        owner = Owner
    }
    if not Path then return Result end
    -- git
    if file.Exists(Path .. "/.git/HEAD", "GAME") then
        local Head = GetGitHead(Path)
        local Code, Date = GetGitCommit(Path, Head)
        Result.head = Head or "master"
        Result.owner = GetGitOwner(Path) or Owner
        if Code and Date then
            Result.code = "Git-" .. Code
            Result.date = LocalToUTC(Date)
        end
        return Result
    end
    -- workshop - canary.yml should create data_static/ace/ace-version.txt with sha (not yet, fallback)
    local WorkshopPath = "data_static/ace/" .. string.lower(Name) .. "-version.txt"
    if file.Exists(WorkshopPath, "GAME") then
        local FileData = file.Read(WorkshopPath, "GAME"):Trim()
        local Code = FileData:sub(1, 7)
        local Date = file.Time(WorkshopPath, "GAME")
        Result.code = "Git-master-" .. Code
        Result.date = LocalToUTC(Date)
        return Result
    end
    -- zip
    if file.Exists(Path .. "/LICENSE", "GAME") then
        Result.code = "ZIP-Unknown"
        Result.date = LocalToUTC(file.Time(Path .. "/LICENSE", "GAME"))
        return Result
    end
    return Result
end

local function GitDateToEpoch(dateStr)
    local year, month, day, hour, min, sec = dateStr:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    return os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec)})
end

local function GitTitleBody(Message)
    if not Message then return end
    local Start = Message:find("\n\n")
    Message = Message:Replace("\n\n", "\n"):gsub("[\r]*[\n]+[%s]+", "\n- ")
    local Title = Start and Message:sub(1, Start - 1) or Message
    local Body = Start and Message:sub(Start + 1, #Message) or "No Commit Message"
    return Title, Body
end

local function FetchCommit(url, callback)
    http.Fetch(url, function(body)
        local data = util.JSONToTable(body)
        if not data then ACE.LogError("Failed to fetch commit information") return end
        local raw = data[1] or data
        if not raw or not raw.commit then ACE.LogError("Failed to fetch commit information") return end
        local Title, Body = GitTitleBody(raw.commit.message)
        callback({
            short_sha = raw.sha:sub(1, 7),
            title = Title,
            body = Body,
            author = raw.commit.author.name,
            date = GitDateToEpoch(raw.commit.author.date),
            url = raw.html_url
        })
    end, function() ACE.LogError("Failed to fetch commit information") end)
end

--- Get latest commit for owner/repo/branch.
-- @param owner string GitHub owner.
-- @param repo string Repo name.
-- @param branch string Branch.
-- @param callback function Callback with commit table.
function ACE.GetLatestCommit(owner, repo, branch, callback)
    FetchCommit(("https://api.github.com/repos/%s/%s/commits?per_page=1&sha=%s"):format(owner, repo, branch), callback)
end

-- Auto-detect local ACE version on load (overwrites static ACE.Version/Branch if git found)
do
    local info = debug.getinfo(1, "S")
    local Path = string.Split(info.short_src, "/lua/")[1]
    -- Path is like "ArmoredCombatExtended" for GAME mount
    local Ver = ACE.CheckLocalVersion("ACE-Project-Team", "ArmoredCombatExtended", Path)
    -- Keep ACE.Version as SHA for E2/SF (string), Branch as head
    if Ver.code:find("Git%-") then
        -- code is Git-<branch>-<sha> or Git-master-<sha>
        local sha = Ver.code:match("-(%x+)$")
        if sha then ACE.Version = sha end
        ACE.Branch = Ver.head
    end
    ACE.LocalVersionInfo = Ver
end

--- Checks for a newer ACE version via the GitHub commits API.
-- Fetches the latest commit SHA for the current branch and compares it to the local version, updating ACE.CurrentVersion.
function ACE.UpdateChecking()
    local branch = ACE.Branch or (ACE.LocalVersionInfo and ACE.LocalVersionInfo.head) or "master"
    if isstring(ACE.Version) and ACE.Version:find("-dev") then branch = "dev" end
    if branch == "canary" then branch = "dev" end
    -- fallback dev clone without branch detection
    if isstring(ACE.Version) and ACE.Version == "dev" and branch == "master" and ACE.LocalVersionInfo and ACE.LocalVersionInfo.head == "dev" then branch = "dev" end

    ACE.GetLatestCommit("ACE-Project-Team", "ArmoredCombatExtended", branch, function(commit)
        local remoteSha = commit.short_sha
        local localSha = isstring(ACE.Version) and string.sub(ACE.Version, 1, 7) or tostring(ACE.Version)
        ACE.CurrentVersion = remoteSha
        ACE.LatestCommit = commit
        if localSha == "dev" or localSha == "0" or localSha == "Not Installed" then
            ACE.LogInfo("Dev build (local " .. localSha .. "), remote " .. branch .. " is " .. remoteSha)
            return
        end
        if localSha == remoteSha then
            ACE.LogInfo("You have the latest version! Current version: " .. localSha .. " (" .. branch .. ")")
        else
            ACE.LogInfo("A new version of ACE is available! Your version: " .. localSha .. " (" .. branch .. "). New version: " .. remoteSha)
            if CLIENT then chat.AddText(Color(255, 0, 0), "A newer version of ACE is available! " .. localSha .. " -> " .. remoteSha .. " (" .. branch .. ")") end
        end
    end)
end

timer.Simple(1, function()
    ACE.UpdateChecking()
end)

-- Blog fetching disabled: website needs to expose GET /api/public/blog?limit=3 (like wiki/docs)
-- See https://acegmod.com/wiki/using-the-ace-website-api-and-mcp-servers - blog not yet in public API
--[[ Disabled until endpoint exists:
--- Fetches 3 recent blog posts from acegmod.com (1 call at startup).
-- @param onDone function|nil Callback with posts table.
function ACE.FetchBlogPosts(onDone)
    local url = "https://acegmod.com/api/public/blog?limit=3"
    http.Fetch(url, function(body, _, _, code)
        if code ~= 200 then
            ACE.LogWarn("Blog fetch failed, acegmod.com API " .. tostring(code) .. " (endpoint may not exist yet)")
            acemenupanel = acemenupanel or {}
            acemenupanel.BlogPosts = {}
            if onDone then onDone({}) end
            return
        end
        local data = util.JSONToTable(body)
        if not data then
            ACE.LogWarn("Blog fetch failed to parse JSON")
            acemenupanel = acemenupanel or {}
            acemenupanel.BlogPosts = {}
            if onDone then onDone({}) end
            return
        end
        local posts = data.posts or data.data or data
        if not istable(posts) then posts = {} end
        acemenupanel = acemenupanel or {}
        acemenupanel.BlogPosts = posts
        if onDone then onDone(posts) end
    end, function()
        ACE.LogWarn("Blog fetch no internet")
        acemenupanel = acemenupanel or {}
        acemenupanel.BlogPosts = {}
        if onDone then onDone({}) end
    end)
end

if CLIENT then
    timer.Simple(1.5, function()
        ACE.FetchBlogPosts(function() end)
    end)
end
--]]
