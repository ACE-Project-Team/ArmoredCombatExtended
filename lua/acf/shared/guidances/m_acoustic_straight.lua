
local ClassName = "Acoustic_Straight"


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
this.ViewCone = 25

-- This instance must wait this long between target seeks.
this.SeekDelay = 2 -- Re-seek drastically reduced cost so we can re-seek. Dynamically reduced as the guidance gets closer

-- Minimum distance for a target to be considered
this.MinimumDistance = 393.7	--10m
this.MaxDistance = 100 * 39.37	--10m

this.desc = "Acoustic torpedo guidance."
--Useful for airdropped torpedoes. Follows a helical pattern until it reaches its target depth. WARNING: Targetposition can only specify the depth to search at. This torpedo will search around the area it was first dropped.

--Sets initial guidance info
this.FirstGuidance = true

function this:Init()
	self.LastSeek = CurTime() - self.SeekDelay - 0.000001
	self.LastTargetPos = Vector()
end

function this:Configure(missile)

	self:super().Configure(self, missile)

	self.ViewCone = ACF_GetGunValue(missile.BulletData, "viewcone") or this.ViewCone
	self.ViewConeCos = math.cos(math.rad(self.ViewCone))
	self.SeekCone = ACF_GetGunValue(missile.BulletData, "seekcone") or this.SeekCone
	self.SeekCone = self.SeekCone * 3
	self.GCMultiplier	= ACF_GetGunValue(missile.BulletData, "groundclutterfactor") or this.GCMultiplier
end

--TODO: still a bit messy, refactor this so we can check if a flare exits the viewcone too.
function this:GetGuidance(missile)

	self:PreGuidance(missile)

	local missilePos = missile:GetPos()

	if self.FirstGuidance then
		local launcher = missile.Launcher

		if not IsValid(launcher) then
			return {}
		end

		local posVec = launcher.TargPos
		local zHeight = 0

		if not posVec or type(posVec) ~= "Vector" or posVec == Vector() then
		--	return {TargetPos = nil}
			self.TarPos = missile:GetForward()
			zHeight = missilePos.z
		else
			self.TarPos = (posVec - missilePos):GetNormalized()
			zHeight = posVec.z
		end

		self.TarPos = missilePos + self.TarPos * 500000
		self.TarPos = Vector(self.TarPos.x,self.TarPos.y,zHeight)
		self.FirstGuidance = false
	end

	local override = self:ApplyOverride(missile)
	if override then self.Target = nil return override end

	self:CheckTarget(missile)

	if IsValid(self.Target) then
		--print("VAL TAR")
		missile.IsDecoyed = false
		if self.Target:GetClass( ) == "ace_flare" then --Ace flare entity deletes itself underwater unless an acoustic CM?
			missile.IsDecoyed = true
		end

		--local missileForward = missile:GetForward()
		--local targetPhysObj = self.Target:GetPhysicsObject()
		local Lastpos = self.TPos or Vector()
		self.TPos = self.Target:GetPos()
		local mfo	= missile:GetForward()
		local mdir	= (self.TPos - missilePos):GetNormalized()
		local dot	= mfo:Dot(mdir)

		if dot < self.ViewConeCos then
			self.Target = nil
			--self.TarPos = missilePos
			missile.StraightRunning = 2
			--print("Eh")
			return {TargetPos = self.TargetPos, ViewCone = self.ViewCone}
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
			self.TarPos = self.TPos + TarVel * self.TTime  * (missile.MissileActive and 1 or 0) --Don't lead the target on the rail

		end

	end

	local Difpos = (self.TarPos-missilePos)
	--local Difpos = (MPos-self.TPos)
	local NoZDif = Vector(Difpos.x, Difpos.y, 0):GetNormalized()

	-- 39.37 * 800 = 393.7
	local Aheaddistance = 31500
	self.TargetPos = missilePos + NoZDif * Aheaddistance + Vector(0,0,math.Clamp(Difpos.z * 15,-Aheaddistance * 1,Aheaddistance * 1))
	self.TargetPos = Vector(self.TargetPos.x, self.TargetPos.y, math.min(self.TargetPos.z,(missile.WaterZHeight or 5000000) - 75))


	return {TargetPos = self.TargetPos, ViewCone = self.ViewCone}

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
	local foundAnim = {}

	--local ScanArray = ACE.contraptionEnts

	local scanEnt = nil
	for Contraption in pairs(CFW.Contraptions) do
		scanEnt = Contraption:GetACEBaseplate()
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

			-- skip any ent outside of minimun distance
			if dist > self.MaxDistance then continue end

			local LOSdata = {}
			LOSdata.start			= missilePos
			LOSdata.endpos			= entpos
			LOSdata.collisiongroup	= COLLISION_GROUP_WORLD
			LOSdata.filter			= function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end --Hits anything world related.
			LOSdata.mins			= Vector(0,0,0)
			LOSdata.maxs			= Vector(0,0,0)
			local LOStr = util.TraceHull( LOSdata )

			--Trace did not hit world
			if not LOStr.Hit and (entpos.z < (missile.WaterZHeight or -50000) + 200) then --Replace with contraption entity flag for water vehicles.

					table.insert(foundAnim, scanEnt)

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

	if missile:WaterLevel() == 0 then return nil end

	-- Part 1: get all whitelisted entities in seek-cone.
	local found = self:GetWhitelistedEntsInCone(missile)

	-- Part 2: get a good seek target
	local missilePos = missile:GetPos()
	EmitSound("acf_extra/ACE/sensors/Sonar/High1.wav", missilePos, 0, 1, CHAN_WEAPON, 400, 0, 100 ) --Formerly 107


	local bestAng = math.huge
	local bestent = nil

	if missile.TargetPos then
		--print("HasTpos")
		self.OffBoreAng = missile:WorldToLocalAngles((missile.TargetPos - missilePos):Angle()) or Angle()
		self.OffBoreAng = Angle(math.Clamp( self.OffBoreAng.pitch, -self.ViewCone + self.SeekCone, self.ViewCone - self.SeekCone ), math.Clamp( self.OffBoreAng.yaw, -self.ViewCone + self.SeekCone, self.ViewCone - self.SeekCone ),0)
	end

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

		if (absang.p < self.SeekCone and absang.y < self.SeekCone) then --Entity is within missile cone
			classifyent:EmitSound("acf_extra/ACE/sensors/Sonar/High1.wav", 400, 100, 1, CHAN_WEAPON ) --Formerly 107
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

	local entpos = bestent:GetPos()
	local difpos = entpos - missilePos
	local dist = difpos:Length()

	self.LastSeek = curTime + self.SeekDelay * math.Clamp(dist / self.MaxDistance,0.1,self.SeekDelay)

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
