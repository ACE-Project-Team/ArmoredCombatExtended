
local ClassName = "Straight_Running"


ACE = ACE or {}
ACE.Guidance = ACE.Guidance or {}

local this = ACE.Guidance[ClassName] or inherit.NewSubOf(ACE.Guidance.Wire)
ACE.Guidance[ClassName] = this

this.Name = ClassName

-- An entity with a Position wire-output
this.InputSource = nil

this.desc = "Gyroscopic torpedo. Guides the torpedo to the depth and direction of the targetpos or the direction fired."

-- Disables guidance when true
this.FirstGuidance = true

this.TPos = Vector(0,0,0)


function this:Init()

end




function this:Configure(missile)

	self:super().Configure(self, missile)

	self.FirstGuidance = true

end

function this:GetGuidance(missile)

	local MPos = missile:GetPos()

	if self.FirstGuidance then

		local launcher = missile.Launcher

		if not IsValid(launcher) then
			return {}
		end

		local posVec = launcher.TargPos
		local zHeight = 0

		if not posVec or type(posVec) ~= "Vector" or posVec == Vector() then
		--	return {TargetPos = nil}
			self.TPos = missile:GetForward()
			zHeight = MPos.z
		else
			self.TPos = (posVec - MPos):GetNormalized()
			zHeight = posVec.z
		end

		self.TPos = MPos + self.TPos * 500000
		self.TPos = Vector(self.TPos.x,self.TPos.y,zHeight)

		self.FirstGuidance = false
	end

	local Difpos = (self.TPos-MPos)
	--local Difpos = (MPos-self.TPos)
	local NoZDif = Vector(Difpos.x, Difpos.y, 0):GetNormalized()

	-- 39.37 * 800 = 393.7
	local Aheaddistance = 31500
	self.TargetPos = MPos + NoZDif * Aheaddistance + Vector(0,0,math.Clamp(Difpos.z * 10,-Aheaddistance * 1,Aheaddistance * 1))
	self.TargetPos = Vector(self.TargetPos.x, self.TargetPos.y, math.min(self.TargetPos.z,(missile.WaterZHeight or 5000000) - 75))

	return {TargetPos = self.TargetPos, ViewCone = self.ViewCone}

end

--Another Stupid Workaround. Since guidance degrees are not loaded when ammo is created
function this:GetDisplayConfig(_)

	return
	{
		["Tracking"] = "Single Position"
	}
end
