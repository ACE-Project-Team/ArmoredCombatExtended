-- cl_init.lua

include ("shared.lua")

ENT.RenderGroup		= RENDERGROUP_OPAQUE

local ACF_GunInfoWhileSeated = CreateClientConVar("ace_gun_info_while_seated", 0, true, false)

function ENT:Initialize()

	self.BaseClass.Initialize( self )

end

function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not ACF_GunInfoWhileSeated:GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end
