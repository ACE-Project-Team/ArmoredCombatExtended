include("shared.lua")

local ACF_InfoWhileSeated = CreateClientConVar("ACF_GunInfoWhileSeated", 0, true, false)

function ENT:Draw()
	local lply = LocalPlayer()
	local hideBubble = not ACF_InfoWhileSeated:GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)
end