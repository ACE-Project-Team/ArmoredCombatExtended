--[[
	ACF Permission mode: God based
		This mode allows non-godded players to damage the entities of all other non-godded players.
		When in godmode, players can only damage their own entities, and entities of players who have given damage permissions.
]]

if not ACE.Permissions or not ACE.Permissions.RegisterMode then error("ACE: Tried to load the " .. modename .. " permission-mode before the permission-core has loaded!") end
local perms = ACE.Permissions

local modename = "godbased"
local modedescription = "Players without godmode can damage anyone else's entities whose owners are not in godmode."

--[[
	Defines the behaviour of ACF damage protection under this protection mode.
	This function is called every time an entity can be affected by potential ACF damage.
	Args;
		owner		Player:	The owner of the potentially-damaged entity
		attacker	Player:	The initiator of the ACF damage event
		ent			Entity:	The entity which may be damaged.
	Return: boolean
		true if the entity should be damaged, false if the entity should be protected from the damage.
]]

local function modepermission(owner, attacker, ent)
	if not IsValid(ent) then return false end

	local ownerid		= owner:SteamID()
	local attackerid	= attacker:SteamID()
	local ownerperms	= perms.GetDamagePermissions(ownerid)

	if perms.Safezones then
		local entpos = ent:GetPos()
		local attpos = attacker:GetPos()

		if (perms.IsInSafezone(entpos) or perms.IsInSafezone(attpos)) and not ownerperms[attackerid] then return false end
	end

	if ent:IsPlayer() or ent:IsNPC() then
		return true
	end

	local godOwner		= owner:HasGodMode()
	local godInflictor	= attacker:HasGodMode()

	if godOwner then
		return ownerperms[attackerid] and true or false
	else
		return not godInflictor
	end

	return false
end

perms.RegisterMode(modepermission, modename, modedescription, false, nil, DefaultPermission, true)
