AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function SWEP:Equip()
	if not self.BulletData then return end

	self.BulletData.Filter = {self:GetOwner()}
end


function SWEP:DoAmmoStatDisplay()
	if not self.BulletData then return end

	local bdata = self.BulletData

	local sendInfo = string.format( "FIM-92 Stinger (IR) - ")

	sendInfo = sendInfo .. string.format("%.1fm blast", bdata.BoomFillerMass ^ 0.33 * 8)

	sendInfo = sendInfo .. ", Burn time: 2.0s"


	ACE_SendNotification(self:GetOwner(), sendInfo, 10)
end
