
ACF = ACF or {}
ACF.Fuse = ACF.Fuse or {}

local ClassName = "Altitude"

local this = ACF.Fuse[ClassName] or inherit.NewSubOf(ACF.Fuse.Contact)
ACF.Fuse[ClassName] = this

---



this.Name = ClassName


this.Altitude = 0
this.Above = true
this.Active = false


this.desc = "When specified with a target position, this fuse will detonate the missile once it crosses the altitude of the target position."

function this:Configure(Missile)
	self.TimeStarted = CurTime()
	Missile.IgnitionDelay = self.StartDelay
	self.Primer = math.max(Missile.MinStartDelay,self.Primer)
	self.Active = false

	local launcher = Missile.Launcher

	if not IsValid(launcher) then
		return
	end

	local posVec = launcher.TargPos
	if not isvector(posVec) then return end

	local TarZ = posVec.z
	local MissileZ = Missile:GetPos().z
	if MissileZ > TarZ then
		self.Above = true
	else
		self.Above = false
	end
	self.Altitude = TarZ
	self.Active = true
end

-- Do nothing, projectiles auto-detonate on contact anyway.
function this:GetDetonate(missile)

	if not self:IsArmed() then return false end
	if not self.Active then return false end

	local MissileZ = missile:GetPos().z


	if self.Above and MissileZ < self.Altitude then
		return true
	elseif (not self.Above) and MissileZ > self.Altitude then
		return true
	end

	return false

end



function this:GetDisplayConfig()
	return
	{
		["Arming delay"] = math.Round(self.Primer, 3) .. " s",
		["Ignition Delay"] = math.Round(self.StartDelay, 3) .. " s"
	}
end
