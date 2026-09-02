-- ACE versioning - SHA-based, dev vs master
AddCSLuaFile()

ACE = ACE or {}

--- Checks for a newer ACE version via the GitHub commits API.
-- Fetches the latest commit SHA for the current branch and compares it to the local version, updating ACE.CurrentVersion.
function ACE.UpdateChecking()
    local branch = ACE.Branch or "master"
    if isstring(ACE.Version) and ACE.Version:find("-dev") then branch = "dev" end
    if branch == "canary" then branch = "dev" end
    -- unbaked local clone "dev" -> compare to dev branch (canary/workshop dev)
    if isstring(ACE.Version) and ACE.Version == "dev" and branch == "master" then branch = "dev" end
    local url = "https://api.github.com/repos/ACE-Project-Team/ArmoredCombatExtended/commits?sha=" .. branch .. "&per_page=1"

    http.Fetch(url, function(body, _, _, code)
        if code ~= 200 then
            ACE.LogError("Unable to find the latest version! GitHub API returned " .. tostring(code))
            return
        end

        local data = util.JSONToTable(body)
        if not data or not data[1] or not data[1].sha then
            ACE.LogError("Unable to find the latest version! Failed to parse GitHub response.")
            return
        end

        local remoteSha = string.sub(data[1].sha, 1, 7)
        local localSha = isstring(ACE.Version) and string.sub(ACE.Version, 1, 7) or tostring(ACE.Version)

        ACE.CurrentVersion = remoteSha

        if localSha == "dev" or localSha == "0" then
            ACE.LogInfo("Dev build (local " .. localSha .. "), remote " .. branch .. " is " .. remoteSha)
            return
        end

        if localSha == remoteSha then
            ACE.LogInfo("You have the latest version! Current version: " .. localSha .. " (" .. branch .. ")")
        else
            ACE.LogInfo("A new version of ACE is available! Your version: " .. localSha .. " (" .. branch .. "). New version: " .. remoteSha)
            if CLIENT then chat.AddText(Color(255, 0, 0), "A newer version of ACE is available! " .. localSha .. " -> " .. remoteSha .. " (" .. branch .. ")") end
        end
    end, function()
        ACE.LogError("Unable to find the latest version! No internet available.")
        ACE.CurrentVersion = 0
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
