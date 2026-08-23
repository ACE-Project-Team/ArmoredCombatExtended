AddCSLuaFile ("cl_init.lua")
AddCSLuaFile ("shared.lua")

include ("shared.lua")

SWEP.DeployDelay = 6 --No more rocket 2 taps or sprinting lawnchairs

function SWEP:DoAmmoStatDisplay()
	if not self.BulletData then return end

	local bdata = self.BulletData

	local sendInfo = "SLAM" .. string.format(", %.1fm blast", bdata.BoomFillerMass ^ 0.33 * 8)
	local Energy = ACE_Kinetic(bdata.SlugMV * 39.37, bdata.SlugMass, 999999)
	local MaxPen = (Energy.Penetration / bdata.SlugPenArea) * ACE.KEtoRHA
	sendInfo = sendInfo .. string.format(", %.1fmm pen", MaxPen)

	ACE_SendNotification(self:GetOwner(), sendInfo, 10)
end

function SWEP:Equip()
	self:SetNextPrimaryFire( CurTime() + self.DeployDelay )
end
