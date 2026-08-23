include("shared.lua")

local FlareSound = "ambient/gas/steam2.wav"

function ENT:Initialize()

	self.LightUpdate = CurTime() + 0.05
	self.IsFlare = true
	self.CutOffTime = 0

	local InterpretColor = self:GetColor()

	if InterpretColor.b == 1 then --Flare
		ParticleEffectAttach("ACFM_Flare",4, self,1) --TODO: Create a way to identify chaff/flare.  And make effects scale with flare filler.
	ACE.EmitSound( FlareSound, self, 70, 100, 1 )
	else
		ParticleEffectAttach("ACFM_Chaff",4, self,1) --TODO: Create a way to identify chaff/flare.  And make effects scale with flare filler.
		self.StopLight = true
		self.IsFlare = false
		self.CutOffTime = CurTime() + 0.75
	end
	--FlareFX:SetScale(2) --
end

function ENT:Draw()

	self:DrawModel()

	if self:WaterLevel() == 3 then
		self:StopSound( FlareSound )
		self.StopLight = true
	end

	local CT = CurTime()

	if self.IsFlare then
		if CT > self.LightUpdate then
			self.LightUpdate = CurTime() + 0.05
			ACE.RenderLight(self:EntIndex(), 20000, Color(255, 196, 0), self:GetPos(), 0.1)
		end
	else --Not a flare
		if CT > self.CutOffTime then
			self:StopParticleEmission()
			self.CutOffTime = math.huge
		end
	end

end

function ENT:OnRemove()
	self:StopSound( FlareSound )
end


