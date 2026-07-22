
local ClassName = "Wire"

ACE = ACE or {}
ACE.Guidance = ACE.Guidance or {}

local this = ACE.Guidance[ClassName] or inherit.NewSubOf(ACE.Guidance.Dumb)
ACE.Guidance[ClassName] = this

this.Name = ClassName

-- Length of the guidance wire
this.WireLength = (500 * 39.37) ^ 2			-- about 500m

-- Disables guidance when true
this.WireSnapped = false

this.desc = "This guidance package is controlled by the launcher, which reads a target-position and steers the munition towards it. Has a limited guidance distance."

this.GuidanceWire = nil

function this:Init()

end

-- Use this to make sure you don't alter the shared default filter unintentionally
function this:GetSeekFilter()
	if self.Filter == self.DefaultFilter then
		self.Filter = table.Copy(self.DefaultFilter)
	end

	return self.Filter
end

function this:Configure(missile)

	self.WireSnapped = false

		--For some reason this configuration is executing in the other guidances.
		if self.Name == "Wire" and IsValid(missile) then
			local launcher = missile.Launcher
			if IsValid(launcher) then
			local MissileOffset = missile:WorldToLocal(missile:GetAttachment( missile:LookupAttachment( "exhaust" ) ).Pos)
			local _, LauncherBoundsMax = missile.Launcher:GetCollisionBounds()
			local OffsetLength = LauncherBoundsMax.x

			self.GuidanceWire = ACE_CreateLinkRope( missile:GetPos(), missile, MissileOffset, launcher, Vector(OffsetLength,0,0) )
			end
		end
end

function this:GetGuidance(missile)

	local launcher = missile.Launcher

	if not IsValid(launcher) then
		return {}
	end

	local posVec = launcher.TargPos

	local launcherPos = launcher:GetPos()
	local distMsl = missile:GetPos():DistToSqr(launcherPos)		-- We're using squared distance to optimise

	if distMsl > self.WireLength and not self.WireSnapped then
		self.WireSnapped = true
		--self.GuidanceWire:Remove() --Find some way to remove the rope keyframe later
		local soundstr =  "physics/metal/metal_box_impact_bullet" .. tostring(math.random(1, 3)) .. ".wav"
		launcher:EmitSound(soundstr,500,100)
		return {TargetPos = nil}
	end


	if not posVec or posVec == Vector() or self.WireSnapped then
		return {TargetPos = nil}
	--else
	--	local distTrgt = posVec:DistToSqr(launcherPos)
	--	if distMsl > distTrgt then
	--		return {TargetPos = nil}
	--	end
	end


	self.TargetPos = posVec
	return {TargetPos = posVec}

end

function this:GetDisplayConfig()
	return {["Wire Length"] = math.Round(math.sqrt(self.WireLength) / 39.37, 1) .. " m"}
end
