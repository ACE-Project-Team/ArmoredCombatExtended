
local ClassName = "Radar"


ACF = ACF or {}
ACF.Guidance = ACF.Guidance or {}

local this = ACF.Guidance[ClassName] or inherit.NewSubOf(ACF.Guidance.Wire)
ACF.Guidance[ClassName] = this

---
--GetGuidanceOverride
--models/props_c17/light_cagelight02_on.mdl --IR Jammer
--models/props_wasteland/prison_lamp001c.mdl --RWR

this.Name = ClassName

--Currently acquired target.
this.Target = nil

-- Cone to acquire targets within.
this.SeekCone = 20

-- Cone to retain targets within.
this.ViewCone = 70

-- This instance must wait this long between target seeks.
this.SeekDelay = 0.1 -- Re-seek drastically reduced cost so we can re-seek

--Whether the missile has IRCCM. Will disable seeking when the locked target would have been a countermeasure.
this.HasIRCCM = false

-- Minimum distance for a target to be considered
this.MinimumDistance = 393.7	--10m

this.desc = "This guidance package detects a target-position infront of itself, and guides the munition towards it."

--Multiplier for the ground clutter effect.
this.GCMultiplier = 1

function this:Init()
	self.LastSeek = CurTime() - self.SeekDelay - 0.000001
	self.LastTargetPos = Vector()
end

function this:Configure(missile)

	self:super().Configure(self, missile)

	self.ViewCone = ACF_GetGunValue(missile.BulletData, "viewcone") or this.ViewCone
	self.ViewConeCos = math.cos(math.rad(self.ViewCone))
	self.SeekCone = ACF_GetGunValue(missile.BulletData, "seekcone") or this.SeekCone
	self.GCMultiplier	= ACF_GetGunValue(missile.BulletData, "groundclutterfactor") or this.GCMultiplier
	self.HasIRCCM	= ACF_GetGunValue(missile.BulletData, "irccm") or this.HasIRCCM
	self.seekReduction	= ACF_GetGunValue(missile.BulletData, "seekreduction") or 1
end

--TODO: still a bit messy, refactor this so we can check if a flare exits the viewcone too.
function this:GetGuidance(missile)

	self:PreGuidance(missile)

	local override = self:ApplyOverride(missile)
	if override then self.Target = nil return override end

	self:CheckTarget(missile)

	if not IsValid(self.Target) then
		return {}
	end

	missile.IsDecoyed = false
	if self.Target:GetClass( ) == "ace_flare" then
		missile.IsDecoyed = true
		if self.HasIRCCM then
			--print("IRCCM reject")
			self.Target = nil
			return {}
		end
	end

	local missilePos = missile:GetPos()
	--local missileForward = missile:GetForward()
	--local targetPhysObj = self.Target:GetPhysicsObject()
	local Lastpos = self.TPos or Vector()
	self.TPos = self.Target:GetPos()
	local mfo	= missile:GetForward()
	local mdir	= (self.TPos - missilePos):GetNormalized()
	local dot	= mfo:Dot(mdir)

	if dot < self.ViewConeCos then
		self.Target = nil
		return {}
	else
		local LastDist = self.Dist or 0
		self.Dist = (self.TPos - missilePos):Length()
		DeltaDist = (self.Dist - LastDist) / engine.TickInterval()

		if DeltaDist < 0 then --More accurate traveltime calculation. Only works when closing on target.
			self.TTime = math.Clamp(math.abs(self.Dist / DeltaDist), 0, 5)
		else
			self.TTime = (self.Dist / missile.Speed / 39.37)
		end

		local TarVel = (self.TPos - Lastpos) / engine.TickInterval()
		missile.TargetVelocity = TarVel --Used for Inertial Guidance
		self.TargetPos = self.TPos + TarVel * self.TTime  * ((missile.MissileActive and (missile.IsJammed == 0)) and 1 or 0) --Don't lead the target on the rail
		return {TargetPos = self.TargetPos, ViewCone = self.ViewCone}
	end

end

function this:ApplyOverride(missile)

	if self.Override then

		local ret = self.Override:GetGuidanceOverride(missile, self)

		if ret then
			ret.ViewCone = self.ViewCone
			ret.ViewConeRad = math.rad(self.ViewCone)
			return ret
		end

	end

end

function this:CheckTarget(missile)

	--if not (self.Target or self.Override) then
		local target = self:AcquireLock(missile)

		if IsValid(target) then
			self.Target = target
		end
	--end

end

--Gets all valid targets, does not check angle
function this:GetWhitelistedEntsInCone(missile)

	local missilePos = missile:GetPos()
	local DPLRFAC = 65 - (self.SeekCone / 2)
	local foundAnim = {}

	--local ScanArray = ACE.contraptionEnts

	local ConeInducedGCTRSize = self.SeekCone * 120 --2 meter wide tracehull for every 100m distance
	local GCTraceData = {
		mask = bit.bor(MASK_WATER, MASK_SOLID_BRUSHONLY),
		mins = Vector( -ConeInducedGCTRSize, -ConeInducedGCTRSize, -ConeInducedGCTRSize ),
		maxs = Vector( ConeInducedGCTRSize, ConeInducedGCTRSize, ConeInducedGCTRSize )
	}

	local scanEnt = nil
	for Contraption in pairs(CFW.Contraptions) do
		scanEnt = Contraption:GetACEBaseplate() or nil

		-- skip any invalid entity
		if not IsValid(scanEnt) then continue end


		--No sir I will not ignore the flares. They "might" contain chaff

		--		-- skip any flare from vision.
		--		if scanEnt:GetClass() == "ace_flare" then continue end

		local entpos = scanEnt:GetPos()
		local difpos = entpos - missilePos
		local dist = difpos:Length()

		-- skip any ent outside of minimun distance
		if dist < self.MinimumDistance and ACF.CurTime < (missile.ActivationTime or math.huge) + 0.5 then continue end --Disables the minimum distance check after a missile has existed for more than a second


			local LOSdata = {}
			LOSdata.start			= missilePos
			LOSdata.endpos			= entpos
			LOSdata.collisiongroup	= COLLISION_GROUP_WORLD
			LOSdata.filter			= function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end --Hits anything world related.
			LOSdata.mins			= Vector(0,0,0)
			LOSdata.maxs			= Vector(0,0,0)
			local LOStr = util.TraceHull( LOSdata )

			--Trace did not hit world
			if not LOStr.Hit then

				local GCtr = util.TraceHull( GCTraceData ) --Hits anything in the world.
				GCTraceData.start = entpos
				GCTraceData.endpos = entpos + difpos:GetNormalized() * 8000 * self.GCMultiplier

				--Doppler testing fun
				local entvel = scanEnt:GetVelocity()

				local DPLR = missile:WorldToLocal(missilePos + entvel * 2)
				local Dopplertest = math.min(math.abs(entvel:Length() / math.max(math.abs(DPLR.Y), 0.01)) * 100, 10000)
				local Dopplertest2 = math.min(math.abs(entvel:Length() / math.max(math.abs(DPLR.Z), 0.01)) * 100, 10000)

				--Qualifies as radar target, if a target is moving towards the radar at 30 mph the radar will also classify the target.
				if (Dopplertest < DPLRFAC or Dopplertest2 < DPLRFAC or (math.abs(DPLR.X) > 880)) and ((math.abs(DPLR.X / entvel:Length()) > 0.3) or (not (GCtr.Hit and not GCtr.HitSky))) then
					--print("PassesDoppler")
					--Valid target
					--print(scanEnt)
					table.insert(foundAnim, scanEnt)
				end

			end


	end

	return foundAnim

end

-- Return the first entity found within the seek-tolerance, or the entity within the seek-cone closest to the seek-tolerance.
function this:AcquireLock(missile)

	local curTime = CurTime()

	--We make sure that its seeking between the defined delay
	if self.LastSeek > curTime then return nil end

	self.LastSeek = curTime + self.SeekDelay

	-- Part 1: get all whitelisted entities in seek-cone.
	local found = self:GetWhitelistedEntsInCone(missile)

	-- Part 2: get a good seek target
	local missilePos = missile:GetPos()

	local bestAng = math.huge
	local bestent = nil


	local SeekMul = 3 --Seeker Cone multiplier. Used for Seeker Expanded Acquisition making the missile search in a larger area if it lacks a target.
	if self.Target then
		SeekMul =  self.seekReduction or 1
	end
	
	if missile.TargetPos then
		--print("HasTpos")
		DifSeek = missile.TargetPos - missilePos
		self.OffBoreAng = missile:WorldToLocalAngles(DifSeek:Angle()) or Angle()
		self.OffBoreAng = Angle(math.Clamp( self.OffBoreAng.pitch, -self.ViewCone + self.SeekCone, self.ViewCone - self.SeekCone ), math.Clamp( self.OffBoreAng.yaw, -self.ViewCone + self.SeekCone, self.ViewCone - self.SeekCone ),0)

	else
		DifSeek = missile:GetForward()
	end

	local CounterMeasures = ACFM_GetFlaresInCone(missilePos, DifSeek, self.SeekCone)
	table.Merge(found,CounterMeasures)

	for _, classifyent in pairs(found) do



		local entpos = classifyent:GetPos()
		local ang = Angle()

		if missile.TargetPos then --Initialized. Work from here.
			--print("Offbore")
			ang	= missile:WorldToLocalAngles((entpos - missilePos):Angle()) - self.OffBoreAng	--Used for testing if inrange

			--print(missile.TargetPos)
		else

			ang	= missile:WorldToLocalAngles((entpos - missilePos):Angle())	--Used for testing if inrange

		end


		local absang = Angle(math.abs(ang.p),math.abs(ang.y),0) --Since I like ABS so much

		--print(absang.p)
		--print(absang.y)

		local SeekExpanded = self.SeekCone*SeekMul --Expanded Seeker Angle used for searching without a target.
		if absang.p < SeekExpanded and absang.y < SeekExpanded then --Entity is within missile cone

			debugoverlay.Sphere(entpos, 100, 5, Color(255,100,0,255))

			local Multiplier = 1

			if classifyent:GetClass() == "ace_flare" then
				Multiplier = classifyent.RadarSig
				--print(Multiplier)
				--print("FlareSeen")
			end

			--Could do pythagorean stuff but meh, works 98% of time
			local testang = (absang.p + absang.y + 2.5) / Multiplier

			--Sorts targets as closest to being directly in front of radar
			if testang < bestAng then
				--if Multiplier > 1 then
				--	print("Flarewon")
				--end
					bestAng = testang
				bestent = classifyent

			end
		end
	end

--	print("iterated and found", mostCentralEnt)
	if not bestent then return nil end

	return bestent
end

--Another Stupid Workaround. Since guidance degrees are not loaded when ammo is created
function this:GetDisplayConfig(Type)

	local Guns = ACF.Weapons.Guns
	local GunTable = Guns[Type]

	local seekCone = GunTable.seekcone and GunTable.seekcone * 2 or 0
	local ViewCone = GunTable.viewcone and GunTable.viewcone * 2 or 0

	return
	{
		["Seeking"] = math.Round(seekCone, 1) .. " deg",
		["Tracking"] = math.Round(ViewCone, 1) .. " deg"
	}
end
