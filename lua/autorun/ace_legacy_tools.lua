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
	-- Master clients can receive canonical tool files from a newer server
	-- without receiving that server checkout's localization resource.
	local CompatibilityPhrases = {
		acemenu = {
			name = "ACE Menu", desc = "Spawn the Armored Combat Extended weapons and ammo",
			left = "Create/Update entity", right = "Link/Unlink entities"
		},
		acearmorprop = {
			name = "ACE Armor Properties", desc = "Sets the ACE armour of an entity",
			left = "Apply armour settings", right = "Copy armour settings",
			reload = "Get information about contraption"
		},
		acechaircam = {
			name = "ACE Third Person View Fixer",
			desc = "Allows third person view to pass through all type of entities while seated, useful when cam controllers are not used",
			left = "Apply the fix to a seat", reload = "Remove the fix from a seat"
		},
		acecopy = {
			name = "ACE Copy Tool", desc = "Copy ammo or gearbox data from one object to another",
			[0] = "Left click to paste data, Right click to copy data"
		},
		acesound = {
			name = "ACE Sound Replacer", desc = "Change the sound of guns and engines",
			left = "Apply the new sound", right = "Copy the sound",
			reload = "Reset to default sound"
		},
		acfarmorprop = {
			name = "ACE Armor Properties", desc = "Sets the ACE armour of an entity",
			left = "Apply armour settings", right = "Copy armour settings",
			reload = "Get information about contraption"
		},
		acfchaircam = {
			name = "ACE Third Person View Fixer",
			desc = "Allows third person view to pass through all type of entities while seated, useful when cam controllers are not used",
			left = "Apply the fix to a seat", reload = "Remove the fix from a seat"
		},
		acfcopy = {
			name = "ACE Copy Tool", desc = "Copy ammo or gearbox data from one object to another",
			[0] = "Left click to paste data, Right click to copy data"
		},
		acfmenu = {
			name = "ACE Menu", desc = "Spawn the Armored Combat Extended weapons and ammo",
			left = "Create/Update entity", right = "Link/Unlink entities"
		},
		acfsound = {
			name = "ACE Sound Replacer", desc = "Change the sound of guns and engines",
			left = "Apply the new sound", right = "Copy the sound",
			reload = "Reset to default sound"
		}
	}

	for mode, phrases in pairs(CompatibilityPhrases) do
		for phrase, value in pairs(phrases) do
			language.Add("tool." .. mode .. "." .. phrase, value)
		end
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
