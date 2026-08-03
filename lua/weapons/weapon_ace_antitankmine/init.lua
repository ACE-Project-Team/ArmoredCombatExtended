AddCSLuaFile ("cl_init.lua")
AddCSLuaFile ("shared.lua")

include ("shared.lua")

SWEP.DeployDelay = 6 --No more rocket 2 taps or sprinting lawnchairs

function SWEP:DoAmmoStatDisplay()


	local sendInfo = string.format( "AT Mine")
		sendInfo = sendInfo .. string.format(", %.1fm blast", 60 ^ 0.33 * 8) --4 taken from mine entity

	ACE_SendNotification(self:GetOwner(), sendInfo, 10)
end

function SWEP:Equip()
	self:SetNextPrimaryFire( CurTime() + self.DeployDelay )
end
