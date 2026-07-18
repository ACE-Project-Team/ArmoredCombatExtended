
local ClassName = "Flare"


ACF = ACF or {}
ACF.Countermeasure = ACF.Countermeasure or {}

local this = ACF.Countermeasure[ClassName] or inherit.NewBaseClass()
ACF.Countermeasure[ClassName] = this

---


this.AppliesTo =
{
	Infrared = true
}


-- bulletdata bound to this object
this.Flare = nil


-- chance as a fraction, 0 - 1
this.SuccessChance = 1


-- Can deactivate after time has passed
this.Active = false


-- indicate to ACFM that this should only be applied when guidance is activated or flare is spawned - not per-frame.
this.ApplyContinuous = false




function this:Init()

end




function this:Configure(flare)

	self.Flare = flare
	self.SuccessChance = flare.DistractChance
	self:UpdateActive()

	--print("SuccessChance", self.SuccessChance, "Active", self.Active)

end




function this:UpdateActive()

	local flare = self.Flare

	if not flare then
		self.Active = false
		return
	end

	self.Active = (flare.CreateTime + flare.BurnTime) > SysTime()

end




function this:GetGuidanceOverride()

	if not self.Flare then return end

	self:UpdateActive()
	if not self.Active then return end

	local activeFlare = ACF.Bullet[self.Flare.Index]
	if not (activeFlare and activeFlare.FlareUID == self.Flare.FlareUID) then return end

	return {TargetPos = self.Flare.Pos, TargetVel = self.Flare.Vel}

end




-- TODO: refine formula.
function this:ApplyChance()

	self:UpdateActive()

	if not self.Active then return false end

	local success = math.random() < self.SuccessChance

	--print("Applying chance", math.Round(self.SuccessChance * 100, 1) .. "% : ", success and "success" or "failed")

	return success

end




-- roll the dice against a missile.  returns true if the flare succeeds in distracting the missile.
-- does not actually apply the effect, just tests the chance of it happening.
-- 'flare' is bulletdata.
function this:TryAgainst(missile, guidance)

	if not self.Flare then return end

	self:UpdateActive()
	if not self.Active then return end

	local cone = guidance.ViewCone

	if not cone or cone <= 0 then return end

	local pos = missile:GetPos()
	local dir = missile:GetForward()

	return ACE.Missile_ConeContainsPos(pos, dir, cone, self.Flare.Pos) and self:ApplyChance(missile, guidance, flare)

end




-- counterpart to ApplyAll.  this takes one flare and applies it to all missiles.
-- returns all missiles which should be affected by this flare.
function this:ApplyToAll()

	if not self.Flare then return {} end

	self:UpdateActive()
	if not self.Active then return {} end

	local ret = {}

	local targets = ACE.Missile_GetAllMissilesWhichCanSee(self.Flare.Pos)

	for _, missile in pairs(targets) do

		local guidance = missile.Guidance

		if self:ApplyChance(missile, guidance) then
			ret[#ret + 1] = missile
		end

	end

	return ret

end




-- 'static' function to iterate over all flares in flight and return one which affects the guidance.
-- TODO: apply sub-1 chance to distract guidance in ACE.Missile_GetAnyFlareInCone.
function this.ApplyAll(missile, guidance)

	local cone = guidance.ViewCone

	if not cone or cone <= 0 then return end

	local pos = missile:GetPos()
	local dir = missile:GetForward()

	local flares = ACE.Missile_GetFlaresInCone(pos, dir, cone)

	for _, flare in pairs(flares) do

		local ret = flare.FlareObj

		if ret:ApplyChance(missile, guidance, flare) then
			return ret
		end

	end

	return nil

end



