
local ClassName = "GPS_TerrainAvoidant"


ACE = ACE or {}
ACE.Guidance = ACE.Guidance or {}

local this = ACE.Guidance[ClassName] or inherit.NewSubOf(ACE.Guidance.Wire)
ACE.Guidance[ClassName] = this

this.Name = ClassName

-- An entity with a Position wire-output
this.InputSource = nil

this.desc = "Terrain following GPS guidance. This guidance package recieves a one-time position and guides to it staying as low as possible."

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

		if not posVec or type(posVec) ~= "Vector" or posVec == Vector() then
			return {TargetPos = nil}
		else
			self.TPos = posVec
		end

		--self.TPos = MPos + self.TPos * 500000

		self.FirstGuidance = false
	end

	local LastDist = self.Dist or 0
	self.Dist = (self.TPos - MPos):Length()
	DeltaDist = (self.Dist - LastDist) / engine.TickInterval()
	local TraveltimeLeft = math.Clamp(-self.Dist / DeltaDist,0,15)


	local Difpos = (self.TPos-MPos):GetNormalized()
	--local Difpos = (MPos-self.TPos)
	local NoZDif = Vector(Difpos.x,Difpos.y,0):GetNormalized()

	-- 39.37 * 800 = 393.7
	local Aheaddistance = 31500

	--local FLLength = missile.Flight:Length()

	local TRadius = 100
	local LOSdata = {}
	LOSdata.start			= MPos
	LOSdata.endpos			= MPos + missile.Flight * 2.5 * 39.37
	--LOSdata.endpos			= MPos + Difpos * FLLength * 20
	--LOSdata.collisiongroup	= COLLISION_GROUP_WORLD
	LOSdata.filter			= function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end --Hits anything world related.
	LOSdata.mins			= Vector(-TRadius)
	LOSdata.maxs			= Vector(TRadius)
	LOSdata.mask = bit.bor(MASK_WATER, CONTENTS_SOLID)
	local LOStr = util.TraceHull( LOSdata )

	local Climb = 0
	local TarZ = 0
	--Trace did not hit world
	if LOStr.Hit and not LOStr.HitSky then

		Climb = 3

	end

	LOSdata.start			= MPos + Vector(0,0,50)
	LOSdata.endpos			= MPos + Vector(0,0,-5000)
	LOSdata.mins			= Vector(0)
	LOSdata.maxs			= Vector(0)
	local TerrainTr = util.TraceHull( LOSdata )

	if TerrainTr.Hit then
		TarZ = TerrainTr.HitPos.z + 100
	else
		TarZ = MPos.z
	end

	--print(TraveltimeLeft)
	--self.TargetPos = MPos + Difpos * Aheaddistance + Vector(0,0,math.Clamp(Difpos.z * 5,-Aheaddistance * 2,Aheaddistance * 2))

	local HeightSmoothing = 20 --Lower values mean less responsiveness to height differences

	if TraveltimeLeft > 1.5 and (Difpos.z >  -0.6) then
		if Climb > 0 then
			self.TargetPos = MPos + Difpos * Aheaddistance + Vector(0,0, Climb *  Aheaddistance + 150)
		else
			self.TargetPos = MPos + NoZDif * Aheaddistance + Vector(0,0,math.Clamp((TarZ-MPos.z) * HeightSmoothing,-Aheaddistance * 1,Aheaddistance * 1))
		end
	else
		self.TargetPos = self.TPos
	end

	if missile.IsJammed ~= 0 then
		self.TPos = nil
		self.TargetPos = nil
	end

	return {TargetPos = self.TargetPos, ViewCone = self.ViewCone}

end

--Another Stupid Workaround. Since guidance degrees are not loaded when ammo is created
function this:GetDisplayConfig(_)

	return
	{
		["Tracking"] = "Single Position"
	}
end
