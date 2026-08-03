AddCSLuaFile ("cl_init.lua")
AddCSLuaFile ("shared.lua")

include ("shared.lua")

SWEP.DeployDelay = 0 --No more rocket 2 taps or sprinting lawnchairs

function SWEP:DoAmmoStatDisplay()
	local sendInfo = string.format( "Smoke Grenade")
		sendInfo = sendInfo .. string.format(", 10m radius")

	ACE_SendNotification(self:GetOwner(), sendInfo, 10)
end

function SWEP:Equip()
	self:SetNextPrimaryFire( CurTime() + self.DeployDelay )
end
