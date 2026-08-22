AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS( "base_wire_entity" )

local TraceHull = util.TraceHull
local abs = math.abs
local tableInsert = table.insert
local mathHuge = math.huge

local PDClutterSwitchDistance = 100 -- Switch to PD mode if ground clutter is closer than this distance (meters)
local PDMinVelocity = 20 -- Minimum radial velocity (m/s) for targets to be picked up in PD mode

function ENT:Initialize()

	self.ThinkDelay			= 0.1
	self.LastThink			= 0
	self.ResetJamDelay		= 0.45 --Periodically resets jamming strength to zero for the jammer to apply the highest noise available. This means the jamming won't always remain at full strength without a lot of networking.
	self.NextJamCheck		= 0
	self.StatusUpdateDelay	= 0.5
	self.LastStatusUpdate	= ACE.CurTime
	self.Active				= false
	self.AnimationRate		= self.AnimationRate or 1

	self.Heat				= 21
	self.IsJammed			= 0
	self.JamStrength		= 0
	self.JamDir				= vector_origin
	self.FilterMissiles = false


	self.NextLegalCheck		= ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal				= true
	self.LegalIssues			= ""
	--self.MaxElev		= 80
	--self.MinElev		= -20

	self.CurrentScanAngle = 0
	--self.RadarPitchRange		= (self.MaxElev - self.MinElev) / 2

	self.Inputs = WireLib.CreateInputs( self, { "Active", "FilterMissiles"} )
	self.Outputs = WireLib.CreateOutputs( self, {"LocalSweepAngle","Detected", "Owner [ARRAY]", "Position [ARRAY]", "Velocity [ARRAY]", "ID [ARRAY]", "IsJammed", "JamDirection [VECTOR]"} )
	self.OutputData = {
		LocalSweepAngle = 0,
		Detected        = 0,
		Owner           = {},
		Position        = {},
		Velocity        = {},
		IsJammed        = 0,
		JamDirection    = vector_origin
	}
	self:SetActive(ACE.GetDefaultActiveInputState(self))

	--print(self.Class)
end

local function SetConeParameters( Radar )

	Radar.ConeInducedGCTRSize    = 300

end

function ACE.MakeSearchRadar(Owner, Pos, Angle, Id)

	if not Owner:CheckLimit("_ace_missileradar") then return false end

	Id = Id or "Large-SEARCH"

	local radar = ACE.Weapons.Radars[Id]

	if not radar then return false end

	local Radar = ents.Create("ace_searchradar")
	if not IsValid(Radar) then return false end

	Radar:SetAngles(Angle)
	Radar:SetPos(Pos)

	Radar.Model    = radar.model
	Radar.Weight   = radar.weight
	Radar.ACFName  = radar.name
	Radar.ICone    = radar.viewcone	--Note: intentional. --Recorded initial cone
	Radar.Cone     = Radar.ICone
	Radar.MaxRange = radar.maxrange or math.huge	--Defines max search range of radar. Here as needed.
	Radar.PowerID     = radar.powerid
	Radar.AnimationRate     = radar.animspeed
	Radar.ACEPoints		= radar.acepoints or 0.9

	Radar.InaccuracyMul          = (0.035 * (Radar.ICone / 15) ^ 2) * 0.2
	Radar.DPLRFAC                = 65 - (Radar.ICone / 2)

	Radar.Burnthrough = radar.burnthrough

	SetConeParameters( Radar )

	Radar.Id					= Id
	Radar.Class				= radar.class

	Radar:Spawn()

	Radar:CPPISetOwner(Owner)

	Radar:SetModelEasy(radar.model)
	Radar:SetActive(ACE.GetDefaultActiveInputState(Radar), true)

	Radar:SetNWString( "WireName", Radar.ACFName )

	Radar:UpdateOverlayText()

	Owner:AddCount( "_ace_missileradar", Radar )
	Owner:AddCleanup( "acemenu", Radar )

	return Radar

end
list.Set( "ACFCvars", "ace_searchradar", {"id"} )
duplicator.RegisterEntityClass("ace_searchradar", ACE.MakeSearchRadar, "Pos", "Angle", "Id" )

function ENT:SetModelEasy(mdl)

	local Rack = self

	Rack:SetModel( mdl )
	Rack.Model = mdl

	Rack:PhysicsInit( SOLID_VPHYSICS )
	Rack:SetMoveType( MOVETYPE_VPHYSICS )
	Rack:SetSolid( SOLID_VPHYSICS )

	local phys = Rack:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:SetMass(Rack.Weight)
	end

end

function ENT:TriggerInput( inp, value )
	if inp == "Active" then
		self:SetActive(ACE.GetDefaultActiveInputState(self, value))

		if ACE.IsDefaultActiveInputWired(self) then
			local curTime = CurTime()
			self.LastThink = ACE.CurTime
			self:NextThink(curTime + 3) --Radar takes a moment to power up. Used to prevent radar flickering to avoid ECM.
		end
	elseif inp == "FilterMissiles" then
		if value > 0 then
			self.FilterMissiles = true
		else
			self.FilterMissiles = false
		end
	end
end

function ENT:SetActive(active, forceVisual)

	active = active and true or false

	if self.Active == active and not forceVisual then
		self.Status = active and "On" or "Off"
		self:UpdateOverlayText()

		return
	end

	self.Active = active
	self.Status = active and "On" or "Off"

	if active  then
		self.LastThink = ACE.CurTime

		local sequence = self:LookupSequence("active") or 0
		self:ResetSequence(sequence)
		self:SetPlaybackRate( self.AnimationRate )
		self.AutomaticFrameAdvance = true
		self.Heat = 21 + 40
	else
		local sequence = self:LookupSequence("idle") or 0
		self:ResetSequence(sequence)
		self.AutomaticFrameAdvance = false

		WireLib.TriggerOutput( self, "Detected", 0 )
		WireLib.TriggerOutput( self, "Owner", {} )
		WireLib.TriggerOutput( self, "Position", {} )
		WireLib.TriggerOutput( self, "Velocity", {} )
		WireLib.TriggerOutput( self, "IsJammed", 0 )
		WireLib.TriggerOutput( self, "Velocity", vector_origin )

		self.OutputData.Detected = 0
		self.OutputData.Owner = {}
		self.OutputData.Position = {}
		self.OutputData.Velocity = {}
		self.OutputData.IsJammed = 0

		self.Heat = 21
	end

	self:UpdateOverlayText()

end


function ENT:UpdateStatus()
	self.Status = self.Active and "On" or "Off"
end

function ENT:UpdateOverlayText()

	local cone	= self.Cone
	local status	= self.Status or "Off"
	local detected  = status ~= "Off" and self.OutputData.Detected ~= 0 or false
	local Jammed	= self.IsJammed

	local txt = "Status: " .. status

	txt = txt .. "\n\nRotation Rate: " .. math.Round(cone, 2) .. " deg/s"
	--txt = txt .. "\nElevation: +" .. math.Round(self.MaxElev, 2) .. " / " .. math.Round(self.MinElev, 2) .. " degrees"

	txt = txt .. "\n\n360 Sweep Time: " .. math.Round(360 / cone, 2) .. " sec"

	if self.MaxRange < 1000 then
		txt = txt .. "\n\nMax Range: " .. math.Round(self.MaxRange, 0) .. "m"
	end

	--txt = txt .. "\nMax Range: " .. (isnumber(range) and math.Round(range / 39.37 , 2) .. " m" or "Unlimited" )

	if Jammed > 0 then
		txt = txt .. "\n\n! ! ! Warning: Jammed ! ! !"
	end
	if detected then
		txt = txt .. "\n\nTarget Detected!"
	end

	if not self.Legal then
		txt = txt .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end


	txt = txt .. "\nTemp: " .. math.Round(self.Heat) .. "C / " .. math.Round((self.Heat * (9 / 5)) + 32) .. "F"

	self:SetOverlayText(txt)

end


--bit.bor(MASK_WATER, MASK_SOLID_BRUSHONLY)
local LOSTraceData = {
	mask = MASK_SOLID_BRUSHONLY,
	mins = vector_origin,
	maxs = vector_origin,
}

local GCTraceData = {
	mask = bit.bor(MASK_WATER, MASK_SOLID_BRUSHONLY),
	mins = vector_origin,
	maxs = vector_origin,
}

local WaterTraceData = {
	mask = MASK_WATER,
	mins = vector_origin,
	maxs = vector_origin,
}

function ENT:Think()
	local curTime = ACE.CurTime

	local DeltaTime = curTime - self.LastThink


	self:NextThink(curTime + self.ThinkDelay)

	if ACE.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACE.CheckLegal(self, self.Model, math.Round(self.Weight, 2), nil, true, true)
		self.NextLegalCheck = ACE.Legal.NextCheck(self.legal)

		local shouldBeActive = ACE.GetDefaultActiveInputState(self)

		if self.Active ~= shouldBeActive then
			self:SetActive(shouldBeActive)
		end

	end

	if self.Active and self.Legal then

		self.CurrentScanAngle = self.CurrentScanAngle + self.Cone * DeltaTime
		-- Modulo, not math.min(x-360, 360): a single step that overshoots by >=360 deg (large DeltaTime
		-- on a hibernating/laggy server) would otherwise clamp to 360 and stick the sweep there forever.
		if self.CurrentScanAngle >= 360 then self.CurrentScanAngle = self.CurrentScanAngle % 360 end

		--local radID = ACE.radarIDs[self]

		WireLib.TriggerOutput( self, "IsJammed", self.IsJammed )
		self.OutputData.IsJammed = self.IsJammed

		local Owners = {}
		local Distances = {}
		local Positions = {}
		local Velocities = {}
		local IDs = {}

		local SelfContraption = self:CFW_GetContraption()
		local SelfPos = self:WorldSpaceCenter()
		local SelfForward = self:GetForward()
		local ConeClutterSize = self.ConeInducedGCTRSize
		GCTraceData.mins = Vector(-ConeClutterSize, -ConeClutterSize, -ConeClutterSize)
		GCTraceData.maxs = Vector(ConeClutterSize, ConeClutterSize, ConeClutterSize)

		--Inaccuracy of radar per meter of range.
		local BaseRadInaccuracy = 0.02 * 39.37 --0.02 meters per every meter. 8 meters @ 400m. 16 meters @ 100m.

		local CounterMeasures = ACE.Missile_GetFlaresInCone(SelfPos, SelfForward, self.Cone * 2)
		local CMCount = table.Count(CounterMeasures)

		for Contraption in pairs(CFW.Contraptions) do
			local Base = Contraption:GetACEBaseplate()
			if Contraption == SelfContraption or not IsValid(Base) then continue end

			local BasePos = Base:GetPos()
			local PosDiff = BasePos - SelfPos
			local BaseDistance = PosDiff:Length()
			local DirectionToTarget = PosDiff / BaseDistance
			local Owner = Base:CPPIGetOwner()
			BaseDistance = BaseDistance / 39.3701 --Used to normalize vector. Convert to meters for other calcs

			if BaseDistance > self.MaxRange then continue end --Exceeded max range of radar


			LOSTraceData.start = SelfPos
			LOSTraceData.endpos = BasePos

			local ang	=  self:WorldToLocalAngles(PosDiff:Angle())  - Angle(0, -self.CurrentScanAngle, 0)	--Used for testing if inrange
			local absang	= Angle(math.abs(math.NormalizeAngle(ang.p)), math.abs(math.NormalizeAngle(ang.y)), 0)  --Since I like ABS so much

			--Entity is within radar cone, has a valid owner, and is not terrain obscured
			if not ((absang.y < self.Cone / 4) and IsValid(Owner) and not TraceHull(LOSTraceData).Hit) then continue end

			--If not jammed
			--OR
			--Burnthrough distance is greater than the current distrance to the target(In meters)
			local BurnThrough = self.IsJammed == 0 or self.Burnthrough / self.JamStrength >= BaseDistance

			if not BurnThrough then continue end

			GCTraceData.start = BasePos
			GCTraceData.endpos = BasePos + DirectionToTarget * 50000

			local GCTrace = TraceHull(GCTraceData)
			local GCTraceHitPos = GCTrace.HitPos

			local ClutterDistance
			if not GCTrace.HitSky then
				-- If the trace is starting in a solid, the ground is right behind/below the target
				ClutterDistance = GCTrace.StartSolid and 0 or (GCTraceHitPos:Distance(BasePos) / 39.3701)

				if (Contraption.totalMass or 0) > 20000 then --The contraption weighs more than 20 tons. About the weight of most planes. It is clearly a large target.
					WaterTraceData.start = BasePos + vector_up * 5000
					WaterTraceData.endpos = BasePos - vector_up * 5000
					local WaterTrace = TraceHull(WaterTraceData)
					if WaterTrace.Hit and abs(BasePos.z-WaterTrace.HitPos.z) < 250 then --Target is on the water. Assuming the target is large enough, makes radar returns easier to find.
						ClutterDistance = mathHuge
					end
				end
			else
				ClutterDistance = mathHuge
			end

			local BaseVelocityVector = Base:GetVelocity() / 39.3701

			local OutputPosition, ValidTarget

			if ClutterDistance < PDClutterSwitchDistance then -- PD mode
				debugoverlay.Line(BasePos, GCTraceHitPos, 0.15, Color(255, 0, 0))
				debugoverlay.Box(GCTraceHitPos, GCTraceData.mins, GCTraceData.maxs, 0.15, Color(255, 0, 0, 0))
				debugoverlay.Text(GCTraceHitPos, "Ground Clutter", 0.15)

				local RadialVelocity = BaseVelocityVector:Dot(DirectionToTarget)

				if abs(RadialVelocity) > PDMinVelocity then
					ValidTarget = true
				end
			else
				ValidTarget = true
			end

			if ValidTarget then

				local BaseInaccuracy = VectorRand() * BaseDistance * BaseRadInaccuracy * (1 + self.JamStrength / 2)

				if CMCount > 0 then
					BaseInaccuracy = BaseInaccuracy * 2
					local ratio = math.Rand(0,1)
					if ratio > 0.6 then
						local CM = CounterMeasures[math.random(1,CMCount)]
						local SigStrength = CM.RadarSig
						if SigStrength > 0.2 then
							BasePos = CM:GetPos()
							BaseInaccuracy = BaseInaccuracy * 3
						end
					end
				end

				OutputPosition = BasePos + BaseInaccuracy

				local ContraptionIndex = ACE.GetContraptionIndex(Contraption)
				local InsertionIndex = ACE.GetBinaryInsertIndex(Distances, BaseDistance)


				tableInsert(Owners, InsertionIndex, Owner:Nick())
				tableInsert(Distances, InsertionIndex, BaseDistance) --If this becomes too intensive the SRC and TRK radar can be rewritten to use sqrt distance. Biggest issue will be refactoring inaccuracy.
				tableInsert(Positions, InsertionIndex, OutputPosition)
				tableInsert(Velocities, InsertionIndex, Base:GetVelocity())
				tableInsert(IDs, InsertionIndex, ContraptionIndex)

				debugoverlay.Line(SelfPos, OutputPosition, 0.15, Color(0, 255, 0))
			end
		end

		--It's ugly I know. But it's simplified and doesn't copy the CFW table.
		if not self.FilterMissiles then
			for Missile in pairs(ACE.ActiveMissiles) do
				if IsValid(Missile) then
					local MissilePos = Missile:GetPos()
					local PosDiff = MissilePos - SelfPos
					local MissileDistance = PosDiff:Length()
					local Owner = Missile:CPPIGetOwner()
					MissileDistance = MissileDistance / 39.3701 --Used to normalize vector. Convert to meters for other calcs

					if MissileDistance > self.MaxRange then continue end --Exceeded max range of radar

					LOSTraceData.start = SelfPos
					LOSTraceData.endpos = MissilePos

					--If not jammed
					--OR
					--Burnthrough distance is greater than the current distrance to the target(In meters)
					local BurnThrough = self.IsJammed == 0 or (self.Burnthrough / self.JamStrength) >= MissileDistance

					local ang	=  self:WorldToLocalAngles(PosDiff:Angle())  - Angle(0, -self.CurrentScanAngle, 0)	--Used for testing if inrange
					local absang	= Angle(math.abs(math.NormalizeAngle(ang.p)), math.abs(math.NormalizeAngle(ang.y)), 0)  --Since I like ABS so much

					--Entity is within radar cone, has a valid owner, and is not terrain obscured
					if not ((absang.y < self.Cone / 4) and IsValid(Owner) and not TraceHull(LOSTraceData).Hit) or not BurnThrough then continue end

					local InsertionIndex = ACE.GetBinaryInsertIndex(Distances, MissileDistance)

					tableInsert(Owners, InsertionIndex, Owner:Nick())
					tableInsert(Distances, InsertionIndex, MissileDistance) --If this becomes too intensive the SRC and TRK radar can be rewritten to use sqrt distance. Biggest issue will be refactoring inaccuracy.
					tableInsert(Positions, InsertionIndex, MissilePos)
					tableInsert(Velocities, InsertionIndex, Missile.Flight * 39.37)
					tableInsert(IDs, InsertionIndex, -Missile.MissileID)

					debugoverlay.Line(SelfPos, MissilePos, 0.15, Color(255, 0, 140))

				end
			end
		end

		local TargetDetected = #Owners > 0
		self.TargetDetected = TargetDetected
		local OutputData = self.OutputData

		if TargetDetected then
			WireLib.TriggerOutput(self, "Detected", 1)
			WireLib.TriggerOutput(self, "Owner", Owners)
			WireLib.TriggerOutput(self, "Position", Positions)
			WireLib.TriggerOutput(self, "Velocity", Velocities)
			WireLib.TriggerOutput(self, "ID", IDs)

			OutputData.Detected = 1
			OutputData.Owner = Owners
			OutputData.Position = Positions
			OutputData.Velocity = Velocities
			OutputData.ID = IDs

		else
			WireLib.TriggerOutput(self, "Detected", 0)
			WireLib.TriggerOutput(self, "Owner", {})
			WireLib.TriggerOutput(self, "Position", {})
			WireLib.TriggerOutput(self, "Velocity", {})
			WireLib.TriggerOutput(self, "ID", {})

			OutputData.Detected = 0
			OutputData.Owner = {}
			OutputData.Position = {}
			OutputData.Velocity = {}
			OutputData.ID = {}
		end
	end

	if (self.LastStatusUpdate + self.StatusUpdateDelay < curTime) then
		self:UpdateStatus()
		self.LastStatusUpdate = curTime
	end

	WireLib.TriggerOutput( self, "JamDirection", self.JamDir )
	self:UpdateOverlayText()

	if self.IsJammed ~= 0 and ACE.CurTime > self.NextJamCheck then
		self.NextJamCheck = ACE.CurTime + self.ResetJamDelay

		--Reset everything for next check
		self.IsJammed			= 0
		self.JamStrength		= 0
		self.JamDir				= vector_origin

	end

	WireLib.TriggerOutput( self, "LocalSweepAngle", self.CurrentScanAngle )

	self.LastThink = curTime

	return true  --Needed for think delay override
end
