--[[
	ACF Permission mode: Build
		This mode blocks all damage to entities without the owner's permission.
		Owners can permit damage from specific players.
		Players and NPCs remain vulnerable to damage.  This is what admin mods are for.
		This mode requires a CPPI-compatible prop-protector to function properly.
]]

if not ACE.Permissions or not ACE.Permissions.RegisterMode then error("ACE: Tried to load the " .. modename .. " permission-mode before the permission-core has loaded!") end
local perms = ACE.Permissions


-- the name for this mode used in commands and identification
local modename = "build"

-- a short description of what the mode does
local modedescription = "Disables all ACF damage unless the owner permits it. PvP is allowed."

-- if the attacker or victim can't be identified, what should we do?  true allows damage, false blocks it.
local DefaultPermission = false


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

	if IsValid(ent) and ent:IsPlayer() or ent:IsNPC() then
		--print("is squishy")
		return true
	end

	if not (owner.SteamID or attacker.SteamID) then
		--print("ACF ERROR: owner or attacker is not a player!", tostring(owner), tostring(attacker), "\n", debug.traceback())
		if DefaultPermission then return
		else return DefaultPermission end
	end

	local ownerid		= owner:SteamID()
	local attackerid	= attacker:SteamID()
	local ownerperms	= perms.GetDamagePermissions(ownerid)
	local godOwner		= owner:HasGodMode()
	local godInflictor	= attacker:HasGodMode()

	-- Disallow the damage if the attacker has not any way to receive damage to him.
	--if attacker.HasDisabledPerms then
		--Msg("[ACE | WARN]- The user " .. attacker:Nick() .. " has disabled his own permissions! Cancelling prop damage....")

	-- Deal damage to props if the owner has given permission to the attacker to do it.
	--elseif ownerperms[attackerid] and not (godOwner or godInflictor) then
	if ownerperms[attackerid] and not (godOwner or godInflictor) then
		return true
	end

	-- return false if to deny the damage
	return false
end



perms.RegisterMode(modepermission, modename, modedescription, false, nil, DefaultPermission)
