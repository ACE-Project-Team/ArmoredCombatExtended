


AddCSLuaFile()
include("acf/shared/sh_acfm_getters.lua")




local function checkIfDataIsMissile(data)
	return ACE_IsAmmoMissileType(data)
end




function ACE_Missile_ModifyRoundDisplayFuncs()

	local roundTypes = ACE.RoundTypes

	if not ACE.Missile_RoundDisplayFuncs then

		ACE.Missile_RoundDisplayFuncs = {}

		for k, v in pairs(roundTypes) do
			ACE.Missile_RoundDisplayFuncs[k] = v.getDisplayData
		end

	end


	for k, v in pairs(roundTypes) do

		local oldDisplayData = ACE.Missile_RoundDisplayFuncs[k]

		if oldDisplayData then
			v.getDisplayData = function(data)

				if not checkIfDataIsMissile(data) then
					return oldDisplayData(data)
				end

				-- NOTE: if these replacements cause side-effects somehow, move to a masking-metatable approach

				local MuzzleVel = data.MuzzleVel
				local slugMV = data.SlugMV
				local slugMV2 = data.SlugMV2
				local PenArea = data.PenArea

				local PenMul = ACE_GetGunValue(data.Id, "penmul") or 1.2
				local VelMul = ACE_GetGunValue(data.Id, "velmul") or 3
				local CalMul = ACE_GetGunValue(data.Id, "calmul") or 1

				data.MuzzleVel = (MuzzleVel or 0) * VelMul
				data.SlugMV = (slugMV or 0) * PenMul
				data.SlugMV2 = (slugMV2 or 0) * PenMul
				data.PenArea = (PenArea or data.PenArea or 0) * CalMul

				local ret = oldDisplayData(data)

				data.SlugMV = slugMV
				data.SlugMV2 = slugMV2
				data.MuzzleVel = MuzzleVel
				data.PenArea = PenArea

				return ret
			end
		end
	end

end




local function configConcat(tbl, sep)

	local toConcat = {}

	for k, v in pairs(tbl) do
		toConcat[#toConcat + 1] = tostring(k) .. " = " .. tostring(v)
	end

	return table.concat(toConcat, sep)

end




function ACE_Missile_ModifyCrateTextFuncs()

	local roundTypes = ACE.RoundTypes

	if not ACE.Missile_CrateTextFuncs then

		ACE.Missile_CrateTextFuncs = {}

		for k, v in pairs(roundTypes) do
			ACE.Missile_CrateTextFuncs[k] = v.cratetxt
		end

	end


	for k, v in pairs(roundTypes) do

		local oldCratetxt = ACE.Missile_CrateTextFuncs[k]

		if oldCratetxt then
			v.cratetxt = function(data, crate)

				local origCrateTxt = oldCratetxt(data)

				if not checkIfDataIsMissile(data) then
					return origCrateTxt
				end

				local str = { origCrateTxt }

				local Type = IsValid(crate) and crate.RoundId or data.RoundId

				local guidance  = IsValid(crate) and crate.RoundData7 or data.Data7
				local fuse	= IsValid(crate) and crate.RoundData8 or data.Data8

				if guidance then
					guidance = ACE_Missile_CreateConfigurable(guidance, ACE.Guidance, data, "guidance")
					if guidance and guidance.Name ~= "Dumb" then
						str[#str + 1] = "\n\n"
						str[#str + 1] = guidance.Name
						str[#str + 1] = " guidance\n("
						str[#str + 1] = configConcat(guidance:GetDisplayConfig(Type), ", ")
						str[#str + 1] = ")"
					end
				end

				if fuse then
					fuse = ACE_Missile_CreateConfigurable(fuse, ACE.Fuse, data, "fuses")
					if fuse then
						str[#str + 1] = "\n\n"
						str[#str + 1] = fuse.Name
						str[#str + 1] = " fuse\n("
						str[#str + 1] = configConcat(fuse:GetDisplayConfig(), ", ")
						str[#str + 1] = ")"
					end
				end

				return table.concat(str)
			end

			ACE.RoundTypes[k].cratetxt = v.cratetxt
		end
	end

end




function ACE_Missile_ModifyRoundBaseGunpowder()

	local oldGunpowder = ACE.Missile_ModifiedRoundBaseGunpowder and oldGunpowder or ACE_RoundBaseGunpowder


	ACE_RoundBaseGunpowder = function(PlayerData, Data, ServerData, GUIData)

		PlayerData, Data, ServerData, GUIData = oldGunpowder(PlayerData, Data, ServerData, GUIData)

		Data.Id = PlayerData.Id

		return PlayerData, Data, ServerData, GUIData

	end


	ACE.Missile_ModifiedRoundBaseGunpowder = true

end



timer.Simple(1, ACE_Missile_ModifyRoundBaseGunpowder)
timer.Simple(1, ACE_Missile_ModifyRoundDisplayFuncs)
timer.Simple(1, ACE_Missile_ModifyCrateTextFuncs)



