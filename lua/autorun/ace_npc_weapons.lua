AddCSLuaFile()

-- Every ACE weapon is offered to NPCs unless it sets SWEP.NPCUsable = false.
-- Weapons register before the spawn menu is built, so they are listed as they load.
hook.Add("PreRegisterSWEP", "ACE_NPCUsableWeapons", function(swep, class)
	if swep.Base ~= "weapon_ace_base" or swep.NPCUsable == false then return end

	list.Add("NPCUsableWeapons", {
		class = class,
		title = swep.PrintName and ("ACE " .. swep.PrintName) or class,
		category = swep.Category,
	})
end)
