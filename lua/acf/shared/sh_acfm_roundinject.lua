


AddCSLuaFile()
include("acf/shared/sh_acfm_getters.lua")




local function checkIfDataIsMissile(data)
	return ACE.IsAmmoMissileType(data)
end




function ACE.Missile_ModifyRoundDisplayFuncs()

	local roundTypes = ACF.RoundTypes

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

				local PenMul = ACE.GetGunValue(data.Id, "penmul") or 1.2
				local VelMul = ACE.GetGunValue(data.Id, "velmul") or 3
				local CalMul = ACE.GetGunValue(data.Id, "calmul") or 1

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




function ACE.Missile_ModifyCrateTextFuncs()

	local roundTypes = ACF.RoundTypes

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
					guidance = ACE.Missile_CreateConfigurable(guidance, ACF.Guidance, data, "guidance")
					if guidance and guidance.Name ~= "Dumb" then
						str[#str + 1] = "\n\n"
						str[#str + 1] = guidance.Name
						str[#str + 1] = " guidance\n("
						str[#str + 1] = configConcat(guidance:GetDisplayConfig(Type), ", ")
						str[#str + 1] = ")"
					end
				end

				if fuse then
					fuse = ACE.Missile_CreateConfigurable(fuse, ACF.Fuse, data, "fuses")
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

			ACF.RoundTypes[k].cratetxt = v.cratetxt
		end
	end

end




function ACE.Missile_ModifyRoundBaseGunpowder()

	local oldGunpowder = ACE.Missile_ModifiedRoundBaseGunpowder and oldGunpowder or ACE.RoundBaseGunpowder


	ACE.RoundBaseGunpowder = function(PlayerData, Data, ServerData, GUIData)

		PlayerData, Data, ServerData, GUIData = oldGunpowder(PlayerData, Data, ServerData, GUIData)

		Data.Id = PlayerData.Id

		return PlayerData, Data, ServerData, GUIData

	end


	ACE.Missile_ModifiedRoundBaseGunpowder = true

end



timer.Simple(1, ACE.Missile_ModifyRoundBaseGunpowder)
timer.Simple(1, ACE.Missile_ModifyRoundDisplayFuncs)
timer.Simple(1, ACE.Missile_ModifyCrateTextFuncs)



