--[[*
	ACF Permission mode: None
		This mode completely disables damage protection.
----]]

if not ACE.Permissions or not ACE.Permissions.RegisterMode then error("ACE: Tried to load the " .. modename .. " permission-mode before the permission-core has loaded!") end
local perms = ACE.Permissions

-- the name for this mode used in commands and identification
local modename = "none"

-- a short description of what the mode does
local modedescription = "Completely disables damage protection."


--[[
	Defines the behaviour of ACF damage protection under this protection mode.
	This function is called every time an entity can be affected by potential ACF damage.
	Args;
		owner		Player:	The owner of the potentially-damaged entity
		attacker	Player:	The initiator of the ACF damage event
		ent			Entity:	The entity which may be damaged.
	Return: boolean
		true if the entity should be damaged, false if the entity should be protected from the damage.
----]]
local function modepermission()
	return true
end

perms.RegisterMode(modepermission, modename, modedescription, true, nil, true)
