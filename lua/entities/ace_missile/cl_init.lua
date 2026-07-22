include("shared.lua")




function ENT:Initialize()

	--self.LightUpdate = CurTime() + 0.05
	self.LightSize = self:BoundingRadius() * 400

end

function ENT:Draw()

	self:DrawModel()

	local MotorActive = self:GetNW2Bool( "MissileActive" );
	--if CurTime() > self.LightUpdate then
	--	self.LightUpdate = CurTime() + 0.05
	if MotorActive then
		self:RenderMotorLight()
	end
	--end
end

function ENT:RenderMotorLight()

	local idx = self:EntIndex()
	local colour = Color(255, 128, 48)
	local pos = self:GetPos() - self:GetForward() * 64

	ACE_RenderLight(idx, self.LightSize, colour, pos, 1)
	--ACE_RenderLight(self:EntIndex(), 5000, Color(255, 196, 0), self:GetPos(), 0.1)
end
