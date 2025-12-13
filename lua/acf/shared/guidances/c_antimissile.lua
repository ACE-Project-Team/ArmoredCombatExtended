--Technically this would only go after vehicles actively beaming the radar. But due to the current implementation this is fine.
--Later add a check to see if the entity is also in the radar cone of the target.
local ClassName = "Antimissile"


ACF = ACF or {}
ACF.Guidance = ACF.Guidance or {}

local this = ACF.Guidance[ClassName] or inherit.NewSubOf(ACF.Guidance.Wire)
ACF.Guidance[ClassName] = this

this.Name = ClassName

--Currently acquired target.
this.Target = nil

-- Cone to retain targets within.
this.ViewCone = 25

-- This instance must wait this long between target seeks.
this.SeekDelay = 0.25 -- Re-seek drastically reduced cost so we can re-seek

--Whether the missile has IRCCM. Will disable seeking when the locked target would have been a countermeasure.
this.HasIRCCM = false

-- Minimum distance for a target to be considered
this.MinimumDistance = 393.7	--10m

this.desc = "This guidance package detects a target-position infront of itself, and guides the munition towards it."

function this:Init()
	self.LastSeek = CurTime() - self.SeekDelay - 0.000001
	self.LastTargetPos = Vector()
end

function this:Configure(missile)

	self:super().Configure(self, missile)

	self.ViewCone = ACF_GetGunValue(missile.BulletData, "viewcone") or this.ViewCone
	self.ViewConeCos = math.cos(math.rad(self.ViewCone))
	self.HasIRCCM	= ACF_GetGunValue(missile.BulletData, "irccm") or this.HasIRCCM
end

--TODO: still a bit messy, refactor this so we can check if a flare exits the viewcone too.
function this:GetGuidance(missile)

	self:PreGuidance(missile)

	self:CheckTarget(missile)

	if not IsValid(self.Target) then
		return {}
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
		self.TargetPos = self.TPos + TarVel * self.TTime * (missile.MissileActive and 1 or 0) --Don't lead the target on the rail
		return {TargetPos = self.TargetPos, ViewCone = self.ViewCone}
	end

end

function this:CheckTarget(missile)

	if not self.Target then
		local target = self:AcquireLock(missile)

		if IsValid(target) then
			self.Target = target
		end
	end

end

--Gets all valid targets, does not check angle
function this:GetWhitelistedEntsInCone(missile)
	local missilePos = missile:GetPos()
	local foundAnim = {}

	for  scanEnt, _ in pairs(ACF_ActiveMissiles) do
		-- skip any invalid entity
		if not scanEnt:IsValid() then continue end


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
			table.insert(foundAnim, scanEnt)
		end
	end

	return foundAnim

end

-- Return the first entity found within the seek-tolerance, or the entity within the seek-cone closest to the seek-tolerance.
function this:AcquireLock(missile)

	local CPPIOwn = missile:CPPIGetOwner()

	local curTime = CurTime()

	--We make sure that its seeking between the defined delay
	if self.LastSeek > curTime then return nil end

	self.LastSeek = curTime + self.SeekDelay

	-- Part 1: get all whitelisted entities in seek-cone.
	local found = self:GetWhitelistedEntsInCone(missile)

	-- Part 2: get a good seek target
	local missilePos = missile:GetPos()

	local bestAng = math.huge
	local bestCount = math.huge
	local bestent = nil


	for _, classifyent in pairs(found) do

		if CPPIOwn == classifyent:CPPIGetOwner() then continue end

		local entpos = classifyent:GetPos()
		local ang = missile:WorldToLocalAngles((entpos - missilePos):Angle())	--Used for testing if inrange
		local absang = Angle(math.abs(ang.p),math.abs(ang.y),0) --Since I like ABS so much

		--print(absang.p)
		--print(absang.y)

		if (absang.p < self.ViewCone and absang.y < self.ViewCone) then --Entity is within missile cone

			debugoverlay.Sphere(entpos, 100, 5, Color(255,100,0,255))

			--Could do pythagorean stuff but meh, works 98% of time
			local testang = absang.p + absang.y

			if classifyent.AMMTarget then --Missile already has an antimissile missile registered to it

				if classifyent.AMMTarget == missile then --Is the assigned target this missile?

					bestAng = testang
					bestent = classifyent
					--print("AMM: owned target")
					break

				elseif testang < bestAng then --Sorts targets as closest to being directly in front of radar

					bestAng = testang
					bestent = classifyent
					--print("AMM: standard assignment")

				end

			else --Missile has no Anti Missile Missile registered to it. TARGET IT.

					classifyent.AMMTarget = missile
					bestAng = testang
					bestent = classifyent
					--print("AMM: assigned to target")
					break

			end
				
			

		end
	end

	--print("iterated and found", mostCentralEnt)
	if not bestent then return nil end

	return bestent
end

--Another Stupid Workaround. Since guidance degrees are not loaded when ammo is created
function this:GetDisplayConfig(Type)

	local Guns = ACF.Weapons.Guns
	local GunTable = Guns[Type]

	local ViewCone = GunTable.viewcone and GunTable.viewcone * 2 or 0

	return
	{
		["Seeking"] = math.Round(ViewCone, 1) .. " deg"
	}
end
