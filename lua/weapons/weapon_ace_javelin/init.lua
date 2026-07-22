AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")


function SWEP:Equip()

	if not self.BulletData then return end

	self.BulletData.Filter = {self:GetOwner()}

	self:GetOwner():GiveAmmo( 4 * self.Primary.ClipSize, self.Primary.Ammo , false )
end


function SWEP:DoAmmoStatDisplay()
	if not self.BulletData then return end

	local bdata = self.BulletData

	local sendInfo = string.format( "FGM-148 Javelin (IR) - ")

	sendInfo = sendInfo .. string.format("%.1fm blast", bdata.BoomFillerMass ^ 0.33 * 8)

	local Energy = ACE_Kinetic(bdata.SlugMV * 39.37, bdata.SlugMass, 999999)
	local MaxPen = (Energy.Penetration / bdata.SlugPenArea) * ACE.KEtoRHA
	sendInfo = sendInfo .. string.format(", (1) %.1fmm pen", MaxPen)

	Energy = ACE_Kinetic(bdata.SlugMV2 * 39.37, bdata.SlugMass2, 999999)
	MaxPen = (Energy.Penetration / bdata.SlugPenArea2) * ACE.KEtoRHA
	sendInfo = sendInfo .. string.format(", (2) %.1fmm pen", MaxPen)

	sendInfo = sendInfo .. ", Burn time: 15s"


	ACE_SendNotification(self:GetOwner(), sendInfo, 10)
end
