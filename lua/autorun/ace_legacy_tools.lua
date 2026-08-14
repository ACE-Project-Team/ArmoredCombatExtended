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
		menu = {
		name = "ACE Menu", desc = "Spawn the Armored Combat Extended weapons and ammo",
		left = "Create/Update entity", right = "Link/Unlink entities",
		stage1 = {
			link = "Link selected entities to this entity",
			unlink = "(Hold Use) Unlink selected entities from this entity",
			multiselect = "(Hold Shift) Select more entities",
			reload = "Deselect all entities"
		},
		creationfailed = "Failed to create entity"
		},
		armor = {
			name = "ACE Armor Properties", desc = "Sets the ACE armour of an entity",
			left = "Apply armour settings", right = "Copy armour settings",
			reload = "Get information about contraption",
			reloadhint = "Get information about contraption (double-tap R for preview values)",
			thickness = "Thickness",
			thicknessdesc = "Set the desired armor thickness (in mm) and the mass will be adjusted accordingly.",
			ductility = "Ductility",
			ductilitydesc = "Set the desired armor ductility (thickness-vs-health bias).",
			current = "Current", after = "After", mass = "Mass", mass_scale = "Mass Scale",
			armor = "Armour", health = "Health", material = "Material", acepoints = "Point Cost",
			armorinfo = "Armour Info", curve = "Curve", keprot = "Kinetic Protection",
			chemprot = "Chemical Protection", year = "Year", reloadfull = "Shift + Reload: Get full point readout"
		},
		copy = {
			name = "ACE Copy Tool", desc = "Copy ammo or gearbox data from one object to another",
			[0] = "Left click to paste data, Right click to copy data",
			gearbox = "Gearbox copied successfully!", ammo = "Ammo copied successfully!"
		},
		sound = {
			name = "ACE Sound Replacer", desc = "Change the sound of guns and engines",
			[0] = "Left click to apply sound. Right click to copy sound. Reload to set default sound. Use an empty sound path to disable sound.",
			left = "Apply the new sound", right = "Copy the sound", reload = "Reset to default sound",
			unsupported = "This entity does not support sound replacement",
			info = "Replaces default sounds of certain ACE entities with this tool. You can replace the sounds of cannons, racks, engines and Anti-Missile Radar.",
			openbrowser = "Open Sound Browser", play = "Play", stop = "Stop", copy = "Copy to Clipboard",
			clear = "Clear Sound", pitch = "Pitch",
			pitchdesc = "Adjust the pitch of the sound. Currently supports engines, guns, racks and missile radars."
		},
		chaircam = {
			name = "ACE Third Person View Fixer",
			desc = "Allows third person view to pass through all type of entities while seated, useful when cam controllers are not used",
			left = "Apply the fix to a seat", reload = "Remove the fix from a seat"
		}
	}

	local ToolPhraseModes = {
		acemenu = "menu",
		acfmenu = "menu",
		acearmorprop = "armor",
		acfarmorprop = "armor",
		acechaircam = "chaircam",
		acfchaircam = "chaircam",
		acecopy = "copy",
		acfcopy = "copy",
		acesound = "sound",
		acfsound = "sound"
	}

	local function AddPhrases(mode, phrases, prefix)
		for phrase, value in pairs(phrases) do
			if istable(value) then
				AddPhrases(mode, value, prefix .. phrase .. ".")
			else
				language.Add("tool." .. mode .. "." .. prefix .. phrase, value)
			end
		end
	end

	for mode, phraseGroup in pairs(ToolPhraseModes) do
		AddPhrases(mode, CompatibilityPhrases[phraseGroup], "")
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
