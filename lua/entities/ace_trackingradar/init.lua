AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS( "base_wire_entity" )

local deg, acos = math.deg, math.acos
local TraceHull = util.TraceHull
local abs = math.abs
local tableInsert = table.insert
local mathHuge = math.huge

local PDClutterSwitchDistance = 200 -- Switch to PD mode if ground clutter is closer than this distance (meters)
local PDMinVelocity = 30 -- Minimum radial velocity (m/s) for targets to be picked up in PD mode

function ENT:Initialize()

	self.ThinkDelay			= 0.1
	self.ResetJamDelay		= 0.45 --Periodically resets jamming strength to zero for the jammer to apply the highest noise available. This means the jamming won't always remain at full strength without a lot of networking.
	self.NextJamCheck		= 0
	self.StatusUpdateDelay	= 0.5
	self.LastStatusUpdate	= ACF.CurTime
	self.Active				= false

	self.Heat				= 21
	self.IsJammed			= 0
	self.JamStrength		= 0
	self.JamDir				= vector_origin

	self.NextLegalCheck		= ACF.CurTime + math.random(ACF.Legal.Min, ACF.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal				= true
	self.LegalIssues		= ""

	self.AcquiredTargets	= {}

	self.Inputs = WireLib.CreateInputs(self, {"Active", "Cone"})
	self.Outputs = WireLib.CreateOutputs(self, {
		"Detected",
		"Owner [ARRAY]",
		"Position [ARRAY]",
		"Velocity [ARRAY]",
		"ID [ARRAY]",
		"IsJammed",
		"JamDirection [VECTOR]"
	})
	self.OutputData = {
		Detected        = 0,
		Owner           = {},
		Position        = {},
		Velocity        = {},
		ID              = {},
		IsJammed        = 0,
		JamDirection    = vector_origin
	}

	self.TargetDetected = false
	self:SetActive(ACF.GetDefaultActiveInputState(self))

end

local function SetConeParameters( Radar )

	Radar.ConeInducedGCTRSize    = Radar.ICone * 30

end

function MakeACE_TrackingRadar(Owner, Pos, Angle, Id)

	if not Owner:CheckLimit("_acf_missileradar") then return false end

	Id = Id or "Large-TRACK"

	local radar = ACF.Weapons.Radars[Id]

	if not radar then return false end

	local Radar = ents.Create("ace_trackingradar")
	if not IsValid(Radar) then return false end

	Radar:SetAngles(Angle)
	Radar:SetPos(Pos)

	Radar.Model = radar.model
	Radar.Weight = radar.weight
	Radar.ACFName = radar.name
	Radar.ICone = radar.viewcone	--Note: intentional. --Recorded initial cone
	Radar.Cone = Radar.ICone
	Radar.PowerID = radar.powerid
	Radar.ACEPoints		= radar.acepoints or 0.9

	Radar.InaccuracyMul = (0.035 * (Radar.ICone / 15) ^ 2) * 0.2
	Radar.DPLRFAC = 65 - (Radar.ICone / 2)

	Radar.OffBoreInaccFactor = radar.offborefactor
	Radar.Burnthrough = radar.burnthrough

	SetConeParameters(Radar)

	Radar.Id = Id
	Radar.Class = radar.class

	Radar:Spawn()

	Radar:CPPISetOwner(Owner)

	Radar:SetModelEasy(radar.model)
	Radar:SetActive(ACF.GetDefaultActiveInputState(Radar), true)

	Radar:SetNWString( "WireName", Radar.ACFName )

	Radar:UpdateOverlayText()

	Owner:AddCount( "_acf_missileradar", Radar )
	Owner:AddCleanup( "acfmenu", Radar )

	return Radar

end
list.Set( "ACFCvars", "ace_trackingradar", {"id"} )
duplicator.RegisterEntityClass("ace_trackingradar", MakeACE_TrackingRadar, "Pos", "Angle", "Id" )

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
		self:SetActive(ACF.GetDefaultActiveInputState(self, value))

		if ACF.IsDefaultActiveInputWired(self) then
			local curTime = CurTime()
			self:NextThink(curTime + 3) --Radar takes a moment to power up. Used to prevent radar flickering to avoid ECM.
		end
	elseif inp == "Cone" then
		if value > 0 then

			self.Cone = math.Clamp(value / 2, 1 ,self.ICone )

			SetConeParameters( self )

			local curTime = CurTime()
			self:NextThink(curTime + 3) --Switching beam width will take time. This is to balance jamming.
		else
			self.Cone = self.ICone
		end

		self:UpdateOverlayText()
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
	self.AcquiredTargets		= {}

	if active  then
		local sequence = self:LookupSequence("active") or 0
		self:ResetSequence(sequence)
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
	local cone = self.Cone
	local status = self.Status or "Off"
	--local detected = status ~= "Off" and self.ClosestToBeam ~= -1 or false
	local Jammed = self.IsJammed

	local txt = "Status: " .. status
	txt = txt .. "\n\nView Cone: " .. math.Round(cone * 2, 2) .. " deg"
	--txt = txt .. "\nMax Range: " .. (isnumber(range) and math.Round(range / 39.37 , 2) .. " m" or "Unlimited" )

	if Jammed > 0 then
		txt = txt .. "\n\n! ! ! Warning: Jammed ! ! !"
	end

	if detected then
		txt = txt .. "\n\nTarget Detected!"
	end

	if not self.Legal then
		txt = txt .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACF.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	txt = txt .. "\nTemp: " .. math.Round(self.Heat) .. "C / " .. math.Round((self.Heat * (9 / 5)) + 32) .. "F"

	self:SetOverlayText(txt)
end

local function GetAngleBetweenVectors(v1, v2)
	return deg(acos(v1:Dot(v2)))
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

function ENT:ScanForContraptions()
	local Owners = {}
	local Distances = {}
	local Positions = {}
	local Velocities = {}
	local IDs = {}
	self.AcquiredTargets		= {}

	local SelfContraption = self:CFW_GetContraption()
	local SelfPos = self:WorldSpaceCenter()
	local SelfForward = self:GetForward()
	local SearchCone = self.Cone
	local ConeClutterSize = self.ConeInducedGCTRSize
	GCTraceData.mins = Vector(-ConeClutterSize, -ConeClutterSize, -ConeClutterSize)
	GCTraceData.maxs = Vector(ConeClutterSize, ConeClutterSize, ConeClutterSize)

	local BTFactor = 1 / (1 + ((self.Cone - 1) / (self.ICone - 1)) * 2)

	local CounterMeasures = ACFM_GetFlaresInCone(SelfPos, SelfForward, self.Cone * 2)
	local CMCount = table.Count(CounterMeasures)

	for Contraption in pairs(CFW.Contraptions) do
		local Base = Contraption:GetACEBaseplate()
		if Contraption ~= SelfContraption and IsValid(Base) then
			local BasePos = Base:GetPos()
			local PosDiff = BasePos - SelfPos
			local BaseDistance = PosDiff:Length()
			local DirectionToTarget = PosDiff / BaseDistance
			local AngleFromTarget = GetAngleBetweenVectors(DirectionToTarget, SelfForward)
			local Owner = Base:CPPIGetOwner()
			BaseDistance = BaseDistance / 39.3701 --Used to normalize vector. Convert to meters for other calcs

			LOSTraceData.start = SelfPos
			LOSTraceData.endpos = BasePos

			local BurnThrough = self.IsJammed == 0 or (self.Burnthrough * 100 * BTFactor) / self.JamStrength >= BaseDistance

			if AngleFromTarget < SearchCone and IsValid(Owner) and not TraceHull(LOSTraceData).Hit and BurnThrough then
				--debugoverlay.Line(SelfPos, BasePos, 0.15, Color(0, 255, 0))

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
					local BaseInaccuracy = VectorRand() * (BaseDistance / 10) * (1 + self.JamStrength / 2)
					local OffboreInaccuracy = 1 + (AngleFromTarget / self.ICone) * self.OffBoreInaccFactor


					if CMCount > 0 then
						BaseInaccuracy = BaseInaccuracy * 1.25
						OffboreInaccuracy = OffboreInaccuracy * 3
						local ratio = math.Rand(0,1)
						if ratio > 0.6 then
							local CM = CounterMeasures[math.random(1,CMCount)]
							local SigStrength = CM.RadarSig
							if SigStrength > 0.2 then
								BasePos = CM:GetPos()
								BaseInaccuracy = BaseInaccuracy * 2.25
							end
						end
					end

					OutputPosition = BasePos + BaseInaccuracy * OffboreInaccuracy

					local ContraptionIndex = ACE.GetContraptionIndex(Contraption)
					local InsertionIndex = ACE.GetBinaryInsertIndex(Distances, BaseDistance)

					tableInsert(Owners, InsertionIndex, Owner:Nick())
					tableInsert(Distances, InsertionIndex, BaseDistance)
					tableInsert(Positions, InsertionIndex, OutputPosition)
					tableInsert(Velocities, InsertionIndex, Base:GetVelocity())
					tableInsert(IDs, InsertionIndex, ContraptionIndex)
					tableInsert(self.AcquiredTargets, Base)

					debugoverlay.Line(SelfPos, OutputPosition, 0.15, Color(0, 255, 0))
				end
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

		table.Merge(self.AcquiredTargets,CounterMeasures)

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

function ENT:Think()
	local curTime = CurTime()
	self:NextThink(curTime + self.ThinkDelay)

	if ACF.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACF_CheckLegal(self, self.Model, math.Round(self.Weight,2), nil, true, true)
		self.NextLegalCheck = ACF.Legal.NextCheck(self.legal)

		local shouldBeActive = ACF.GetDefaultActiveInputState(self)

		if self.Active ~= shouldBeActive then
			self:SetActive(shouldBeActive)
		end

	end

	if self.Active and self.Legal then
		WireLib.TriggerOutput(self, "IsJammed", self.IsJammed)
		self.OutputData.IsJammed = self.IsJammed

		self:ScanForContraptions()
	end

	if self.LastStatusUpdate + self.StatusUpdateDelay < curTime then
		self:UpdateStatus()
		self.LastStatusUpdate = curTime
	end

	WireLib.TriggerOutput( self, "JamDirection", self.JamDir )
	self:UpdateOverlayText()

	if self.IsJammed ~= 0 and ACF.CurTime > self.NextJamCheck then
		self.NextJamCheck = ACF.CurTime + self.ResetJamDelay

		--Reset everything for next check
		self.IsJammed			= 0
		self.JamStrength		= 0
		self.JamDir				= vector_origin

	end

	return true --Needed for think delay override
end
