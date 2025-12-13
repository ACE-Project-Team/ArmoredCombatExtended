
local ClassName = "Top_Attack_IR"


ACF = ACF or {}
ACF.Guidance = ACF.Guidance or {}

local this = ACF.Guidance[ClassName] or inherit.NewSubOf(ACF.Guidance.Wire)
ACF.Guidance[ClassName] = this

---


this.Name = ClassName

--Currently acquired target.
this.Target = nil

-- Cone to acquire targets within.
this.SeekCone = 2

-- Cone to retain targets within.
this.ViewCone = 180

-- This instance must wait this long between target seeks.
this.SeekDelay = 0.1 -- Re-seek drastically reduced cost so we can re-seek

--Whether the missile has IRCCM. Will disable seeking when the locked target would have been a countermeasure.
this.HasIRCCM = false

--Defines how many degrees are required above the ambient one to consider a target
this.HeatAboveAmbient = 25

-- Minimum distance for a target to be considered
this.MinimumDistance = 200  -- ~5m

-- Maximum distance for a target to be considered.
this.MaximumDistance = 20000

this.LargestDist = 0

this.TopAttackFactor = 1

this.desc = "This guidance package detects hot targets infront of itself, and guides the munition towards it."

this.TTime = 0

function this:Init()
	self.LastSeek = CurTime() - self.SeekDelay - 0.000001
	self.LastTargetPos = Vector()
end

function this:Configure(missile)

	self:super().Configure(self, missile)

	self.ViewCone		= (ACF_GetGunValue(missile.BulletData, "viewcone") or this.ViewCone)
	self.ViewConeCos		= (math.cos(math.rad(self.ViewCone)))
	self.SeekCone		= (ACF_GetGunValue(missile.BulletData, "seekcone") or this.SeekCone)
	self.HeatAboveAmbient = self.HeatAboveAmbient / (ACF_GetGunValue(missile.BulletData, "seeksensitivity") or 10)
	--self.SeekSensitivity	= ACF_GetGunValue(missile.BulletData, "seeksensitivity") or this.SeekSensitivity
	self.HasIRCCM	= ACF_GetGunValue(missile.BulletData, "irccm") or this.HasIRCCM
	self.seekReduction	= ACF_GetGunValue(missile.BulletData, "seekreduction") or 1

	--print("CEent")
	--for i, ent in ipairs(ACE.contraptionEnts) do
	--	print(ent)
	--end

end

--TODO: still a bit messy, refactor this so we can check if a flare exits the viewcone too.
function this:GetGuidance(missile)

	--print(self.HeatAboveAmbient)
	self:PreGuidance(missile)

	local override = self:ApplyOverride(missile)
	if override then return override end

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
	--print("Target")

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
		self.GDist = ((self.TPos - missilePos) * Vector(1,1,0)):Length()
		DeltaDist = (self.Dist - LastDist) / engine.TickInterval()

		if DeltaDist < 0 then --More accurate traveltime calculation. Only works when closing on target.
			self.TTime = math.Clamp(math.abs(self.Dist / DeltaDist), 0, 5)
		else
			self.TTime = (self.Dist / missile.Speed / 39.37)
		end

--		if self.Target:GetClass( ) == "ace_flare" and this.HasIRCCM then

		--print(self.Dist/39.37)

		local AddDist = 0
		if self.LargestDist == 0 then
			self.TopAttackFactor = self.GDist * 0.15
			self.LargestDist = math.max(self.GDist * 0.3,3000)
		end

		if self.GDist > self.LargestDist then
			AddDist = self.TopAttackFactor
		--else
			--print("Direct")
		end

		local TarVel = (self.TPos - Lastpos) / engine.TickInterval()
		missile.TargetVelocity = TarVel --Used for Inertial Guidance
		self.TargetPos = self.TPos + TarVel * self.TTime * (missile.MissileActive and 1 or 0) + Vector(0,0,AddDist) --Don't lead the target on the rail
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

	local target = self:AcquireLock(missile)

	if IsValid(target) then
		self.Target = target
	end
end

function this:GetWhitelistedContraptionsInCone(missile)

	if table.IsEmpty(CFW.Contraptions) then return {} end

	local missilePos	= missile:GetPos()
	local WhitelistConts = {}
	local LOSdata	= {}
	local LOStr		= {}

	local entpos		= Vector()
	local difpos		= Vector()
	local dist		= 0

	local scanEnt = nil
	for Contraption in pairs(CFW.Contraptions) do
		scanEnt = Contraption:GetACEBaseplate()

		-- skip any invalid entity
		if not IsValid(scanEnt) then continue end

		entpos  = scanEnt:GetPos()
		difpos  = entpos - missilePos
		dist	= difpos:Length()

		-- skip any ent outside of minimun distance
		if dist < self.MinimumDistance and ACF.CurTime < (missile.ActivationTime or math.huge) + 0.5 then continue end --Disables the minimum distance check after a missile has existed for more than a second

		-- skip any ent far than maximum distance
		if dist > self.MaximumDistance then continue end

		LOSdata.start		= missilePos
		LOSdata.endpos		= entpos
		LOSdata.collisiongroup  = COLLISION_GROUP_WORLD
		LOSdata.filter		= function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end
		LOSdata.mins			= Vector(0,0,0)
		LOSdata.maxs			= Vector(0,0,0)

		LOStr = util.TraceHull( LOSdata )

		--Trace did not hit world
		if not LOStr.Hit then
			table.insert(WhitelistConts, Contraption)
		end


	end

	return WhitelistConts

end

-- Return the first entity found within the seek-tolerance, or the entity within the seek-cone closest to the seek-tolerance.
function this:AcquireLock(missile)

	local curTime = CurTime()

	if self.LastSeek > curTime then return nil end
	self.LastSeek = curTime + self.SeekDelay

	--Part 1: get all ents in cone
	local found = self:GetWhitelistedContraptionsInCone(missile)

	--Part 2: get a good seek target
	if table.IsEmpty(found) then return NULL end

	local missilePos	= missile:GetPos()

	local bestAng	= math.huge
	local bestent	= NULL

	local entpos		= Vector()
	local difpos		= Vector()
	--local entvel		= Vector()
	local dist		= 0

	local physEnt	= NULL

	local ang		= Angle()
	local absang		= Angle()
	local testang	= Angle()

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

	local CheckTemp = ACE.AmbientTemp + self.HeatAboveAmbient

	local BestHeat = 1
	for _, Contraption in ipairs(found) do

		local _, HottestEntityTemp = Contraption:GetACEHottestEntity()
		HottestEntityTemp = HottestEntityTemp or 0
		local classifyent = Contraption:GetACEBaseplate()

		entpos  = classifyent:WorldSpaceCenter()
		difpos  = entpos - missilePos
		dist	= difpos:Length()
		entvel  = classifyent:GetVelocity()

		--Gets the heat from friction of the baseplate

		local BaseTemp = 0
		physEnt = classifyent:GetPhysicsObject()

		if IsValid(physEnt) and physEnt:IsMoveable() then
			BaseTemp = ACE_InfraredHeatFromProp( classifyent , dist )
		end


		if not Contraption.aceEntities or (HottestEntityTemp and BaseTemp > HottestEntityTemp) then
			entpos = classifyent:GetPos()
		else
			entpos = Contraption:GetACEHeatPosition()
		end

		local Heat = BaseTemp + math.max(ACE.AmbientTemp,HottestEntityTemp)

		--0x heat @ 1200m
		--0.25x heat @ 900m
		--0.5x heat @ 600m
		--0.75x heat @ 300m
		--1.0x heat @ 0m

		local HeatMulFromDist = 1 - math.min(dist / 47244, 1) --39.37 * 1200 = 47244
		Heat = Heat * HeatMulFromDist

		--Skip if not Hotter than AmbientTemp in deg C.
		if Heat <= CheckTemp then continue end


		if missile.TargetPos then --Initialized. Work from here.
			--print("Offbore")
			ang	= missile:WorldToLocalAngles((entpos - missilePos):Angle()) - self.OffBoreAng	--Used for testing if inrange

			--print(missile.TargetPos)
		else

		ang	= missile:WorldToLocalAngles((entpos - missilePos):Angle())	--Used for testing if inrange

		end

		absang	= Angle(math.abs(ang.p),math.abs(ang.y),0) --Since I like ABS so much

		local SeekExpanded = self.SeekCone*SeekMul --Expanded Seeker Angle used for searching without a target.
		if absang.p < SeekExpanded and absang.y < SeekExpanded then --Entity is within missile cone

			testang = absang.p + absang.y --Could do pythagorean stuff but meh, works 98% of time

			--if self.Target == scanEnt then
			--	testang = testang / self.SeekSensitivity
			--end

			--180 is from 90deg + 90deg, assuming the target is fully offbore.
			--4x heat fully front and center. 1x heat fully offbore
			local BoreHeatMul = 4 - ((absang.p + absang.y) / 180 * 3)

			testang = -Heat * BoreHeatMul



			--Sorts targets as closest to being directly in front of radar
			if testang < bestAng then

				bestAng = testang
				bestent = classifyent
				BestHeat = Heat

			end

		end


	end

	local CounterMeasures = ACFM_GetFlaresInCone(missilePos, DifSeek, self.SeekCone)

	local HottestCM = 0
	local CM = nil
	for _, CounterMeasure in ipairs(CounterMeasures) do
		local Heat = CounterMeasure.Thermal
		if Heat > HottestCM then
			HottestCM = Heat
			CM = CounterMeasure
		end
	end

	if HottestCM > BestHeat then
		bestent = CM
	end

	--if IsValid(bestent) and bestent:GetClass( ) == "ace_flare" then print("SQUIRREL") end
	--print(bestent)

	return bestent
end

--Another Stupid Workaround. Since guidance degrees are not loaded when ammo is created
function this:GetDisplayConfig(Type)

	local Guns = ACF.Weapons.Guns
	local GunTable = Guns[Type]

	local ViewCone = GunTable.viewcone and GunTable.viewcone * 2 or 0
	local seekCone = GunTable.seekcone and GunTable.seekcone * 2 or 0

	return
	{
		["Seeking"] = math.Round(seekCone, 1) .. " deg",
		["Tracking"] = math.Round(ViewCone, 1) .. " deg"
	}
end
