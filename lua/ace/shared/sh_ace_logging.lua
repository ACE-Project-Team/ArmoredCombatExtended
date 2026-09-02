-- Centralized ACE logging helpers - use instead of raw print/chat.AddText
AddCSLuaFile()

ACE = ACE or {}

local PREFIX = "[ACE | %s]- "

local function serverLog(level, msg)
    print(string.format(PREFIX .. "%s", level, msg))
end

--- Logs an informational message to the console.
-- @param msg string Message to log.
function ACE.LogInfo(msg)
    serverLog("INFO", msg)
end

--- Logs a warning message to the console.
-- @param msg string Message to log.
function ACE.LogWarn(msg)
    serverLog("WARN", msg)
end

--- Logs an error message to the console.
-- @param msg string Message to log.
function ACE.LogError(msg)
    serverLog("ERROR", msg)
end

--- Notifies about an available ACE update.
-- @param ply Player|nil Player to notify, or nil for shared.
-- @param localSha string Local short SHA.
-- @param remoteSha string Remote short SHA.
-- @param branch string Branch name.
function ACE.NotifyUpdate(ply, localSha, remoteSha, branch)
    local text = string.format("A newer version of ACE is available! %s -> %s (%s)", localSha, remoteSha, branch)
    if SERVER and IsValid(ply) then
        -- net-based chat handled by caller via chat.AddText on client; server just logs
        ACE.LogInfo(text .. " for " .. ply:Nick())
    else
        ACE.LogInfo(text)
    end
    if CLIENT then
        chat.AddText(Color(255, 0, 0), text)
    end
end
