-- Keep the former ACF tool modes available to addons and saved tool settings.
-- The aliases use the ACE implementations without changing canonical tools.
ACE = ACE or {}

local LegacyTools = {
	acfarmorprop = "acearmorprop",
	acfchaircam = "acechaircam",
	acfcopy = "acecopy",
	acfmenu = "acemenu",
	acfsound = "acesound"
}

local function AddLegacyToolAlias(tool, toolmode)
	local legacyMode
	for oldMode, canonicalMode in pairs(LegacyTools) do
		if canonicalMode == toolmode then
			legacyMode = oldMode
			break
		end
	end
	if not legacyMode then return end
	if SWEP.Tool[legacyMode] then return end

	local legacyTool = table.Copy(tool)
	legacyTool.Mode = legacyMode
	-- Register a separate convar namespace for saved legacy tool settings.
	-- The tool callbacks read these values through GetClientInfo.
	legacyTool.ClientConVar = table.Copy(tool.ClientConVar or {})
	legacyTool:CreateConVars()
	legacyTool.Name = "#tool." .. legacyMode .. ".name"
	legacyTool.AddToMenu = false
	legacyTool.Allowed = function()
		local legacy = GetConVar("toolmode_allow_" .. legacyMode)
		local canonical = GetConVar("toolmode_allow_" .. toolmode)
		return legacy and legacy:GetBool() and canonical and canonical:GetBool() or false
	end

	SWEP.Tool[legacyMode] = legacyTool
end

hook.Add("PreRegisterTOOL", "ACE_LegacyToolAliases", AddLegacyToolAlias)

if CLIENT then
	local LegacyNames = {
		acfarmorprop = "ACE Armor Properties",
		acfchaircam = "ACE Third Person View Fixer",
		acfcopy = "ACE Copy Tool",
		acfmenu = "ACE Menu",
		acfsound = "ACE Sound Replacer"
	}

	for mode in pairs(LegacyTools) do
		language.Add("tool." .. mode .. ".name", LegacyNames[mode])
	end

end

-- Preserve the armor tool's old read-only reload path before CanTool hooks run.
-- hook.Call is used here because an earlier CanTool hook may deny the action.
if not ACE.LegacyCanToolHookCall then
	local PreviousHookCall = hook.Call

	hook.Call = function(name, gamemode, player, entity, toolmode, tool, button, ...)
		if name == "CanTool" and (toolmode == "acearmorprop" or toolmode == "acfarmorprop")
			and button == 3 and player and player:KeyPressed(IN_RELOAD) then
			return true
		end

		return PreviousHookCall(name, gamemode, player, entity, toolmode, tool, button, ...)
	end

	ACE.LegacyCanToolHookCall = true
end
