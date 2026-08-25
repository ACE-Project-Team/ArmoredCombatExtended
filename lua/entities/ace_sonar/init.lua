AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local TraceHull = util.TraceHull
local min, Clamp = math.min, math.Clamp
local tableInsert = table.insert

ACE.SonarTimeCompression = 0.15 --Multiplier for speed of sound. 0.33 means sound takes ~3x the time to travel to the target. Generally sonar travels at ~1500 m/s

--ACE.SonarLayerDepth = (20 + math.Rand(0,1)) --Layer depth in meters where sonar scatters. Subject to being reworked later.
ACE.SonarLayerDepth = 20 --Layer depth in meters where sonar scatters. Subject to being reworked later.

local SonarSpreadDistribution = Vector(1,1,0.1) --Scales the noise vector
local NoZVector = Vector(1,1,0)


function ENT:Initialize()

	--TODO:
	--Passive sonar

	--Later:
	--Figure out why model legality checks cause errors
	--Add layer function based on limiting ray and add output. Applies to subs below 20 meters
	--Add sidelobes to active sonar.
	--Improve CalcAngle function with trig to reduce cost.
	--Add narrowband sonar generator and classification
	--Add Deep layer starting @ 100m. With extremely limiting angles(55deg?) Will require computing points at each layer if trying to detect across multiple layers.
	--Noisemaker detection on passive sonar. And detection strength.

	self.ThinkDelay			= 0.1
	self.StatusUpdateDelay	= 0.5
	self.LastStatusUpdate	= CurTime()
	self.Active				= false

	self.SelfPos = nil
	self.SelfContraption = nil
	self.SelfBasePlate = nil
	self.WaterZHeight = 0
	self.NextWaterlevelCheck = 0

	self.MaximumDistance	= self.MaximumDistance or 0
	self.BaseMaximumDistance = self.MaximumDistance
	self.PowerScale			= self.PowerScale or 1
	self.WashoutFactor		= self.WashoutFactor or 1
	self.NoiseMul			= self.NoiseMul or 1

	self.Sound = "acf_extra/ACE/sensors/Sonar/coldwaters.wav"
	self.SoundPitch = 100

	self.ActiveTransmitting = false
	self.PulseDuration = 6
	self.BeamAngle = 0
	self.MaxAngle = self.MaxAngle or 270
	self.BeamWidth = self.MaxAngle
	self.WashOut = 0 --Washout factor. Ranges from 0 to 1.

	self.NextPing = 0
	self.SonarYaw = 0

	self.Inputs	= WireLib.CreateInputs( self, {
		"Active (Whether to listen for passive sonar.)",
		"ActiveSonar (Whether to transmit active sonar instead of using passive.)",
		"ActiveAngle (World bearing to point the sonar beam at.)",
		"PulseDuration (Length in sec of pulse. Longer = more accurate. 4 sec needed to get spd. 0.5s Min, 10s Max)",
		"ActiveBeamwidth (Width of the beam of the sonar in degrees. Min 27, Max 270.)",
		"ActiveSound (String soundpath to play when using active sonar. Overrides the soundreplacer.) [STRING]",
		"ActivePitch (The numerical pitch of active sonar from 0-255. Overrides the soundreplacer.)"
	})

	self.Outputs = WireLib.CreateOutputs( self, {
		"Detected (Returns 1 if at least one target was detected with sonar)",
		"Bearing (Returns an array of the angles of sonar targets) [ARRAY]",
		"Depth (Returns an array of the depths of active sonar targets) [ARRAY]",
		"Distance (Returns an array of the horizontal distance to sonar targets) [ARRAY]",
		"Velocity (Returns an array of the vector velocity of each sonar target) [ARRAY]",
		"Owner (Returns an array of the owners of sonar tracks) [ARRAY]",
		"ID (Returns an array of unique IDs for each target that can be used to track a specific contraption) [ARRAY]",
		"SonoDetected (Returns 1 if an active ping was detected)",
		"SonoAngle (Returns an array of the world angle of detected sonar pings) [ARRAY]",
		"TorpDetected (Returns 1 if a torpedo was detected)",
		"TorpPosition (Returns the vector position of any detected torpedoes) [ARRAY]",
		"Washout (Returns the level of washout from speed. At 1 the sonar becomes unusable.)",
		"WaterZHeight (Returns the world Z level of the water.)"
	})

	self.OutputData = {
		Detected		= 0,
		Bearing			= {},
		Depth			= {},
		Distance		= {},
		Owner			= {},
		Velocity		= {},
		ID				= {},
		SonoDetected	= 0,
		SonoAngle		= {},
		TorpDetected	= 0,
		TorpPosition	= {},
		Washout	= 0,
		WaterZHeight = 0
	}

	--List of target info we have. Used to compile into outputs or keep a record of transients of a track. Periodically cleaned after contact is lost for more than so much time.
	self.SonoUpdated = false
	self.SonarPositions = {}
	self.SonarVelocity = {}
	self.SonarOwners = {}
	self.SonarLastTracked = {}


	self.NextLegalCheck     = ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal              = true
	self.LegalIssues        = ""

	-- Must run after legal state is set: SetActive -> UpdateOverlayText reads Legal/NextLegalCheck
	self:SetActive(ACE.GetDefaultActiveInputState(self))

	self.TargetDetected		= false

	self:UpdateOverlayText()

end

function ACE.MakeSonar(Owner, Pos, Angle, Id)

	--print("Test")

	if not Owner:CheckLimit("_ace_missileradar") then return false end

	Id = Id or "Small-Sonar"
	--print(Id)

	local radar = ACE.Weapons.Radars[Id]
	if not radar then return false end

	local Sonar = ents.Create("ace_sonar")

	if IsValid(Sonar) then

		Sonar:SetAngles(Angle)
		Sonar:SetPos(Pos)

		Sonar.Model				= radar.model
		Sonar.Weight			= radar.weight
		Sonar.ACFName			= radar.name
		Sonar.ACEPoints			= radar.acepoints or 0.9

		Sonar.SeekSensitivity	= radar.SeekSensitivity

		local BaseDist =	39.37 * 300 --Base distance of sonar for a large sonar.
		Sonar.MaximumDistance	= BaseDist * (radar.powerscale or 1)
		Sonar.PowerScale		= radar.powerscale or 1
		Sonar.WashoutFactor		= radar.washoutfactor or 1
		Sonar.NoiseMul			= radar.noisemul or 1

		Sonar.MaxAngle = radar.maxangle or 270
		Sonar.BeamWidth = Sonar.MaxAngle

		Sonar.Id				= Id
		Sonar.Class				= radar.class

		Sonar:Spawn()

		Sonar:CPPISetOwner(Owner)

		Sonar:SetNWNetwork()
		Sonar:SetModelEasy(radar.model)
		Sonar:UpdateOverlayText()

		Owner:AddCount( "_ace_missileradar", Sonar )
		Owner:AddCleanup( "acemenu", Sonar )

		return Sonar
	end

	return false
end
list.Set( "ACFCvars", "ace_sonar", {"id"} )
duplicator.RegisterEntityClass("ace_sonar", ACE.MakeSonar, "Pos", "Angle", "Id" )

function ENT:SetNWNetwork()
	self:SetNWString( "WireName", self.ACFName )
end

function ENT:SetModelEasy(mdl)

	self:SetModel( mdl )
	self.Model = mdl

	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(self.Weight)
	end

end

function ENT:TriggerInput( inp, value )
	if inp == "Active" then
		self:SetActive(ACE.GetDefaultActiveInputState(self, value))
	elseif inp == "ActiveSonar" then
		if value > 0 then
			self.ActiveTransmitting = true
		else
			self.ActiveTransmitting = false
		end
		self.SonarPositions = {}
		self.SonarVelocity = {}
		self.SonarOwners = {}
		self.SonarLastTracked = {}
	elseif inp == "ActiveAngle" then
		self.BeamAngle = math.NormalizeAngle(value)
	elseif inp == "PulseDuration" then
		self.PulseDuration = Clamp(value, 0.5 , 10)
	elseif inp == "ActiveBeamwidth" then
		self.BeamWidth = math.Round(Clamp(value,27,self.MaxAngle),1)
		self.MaximumDistance = self.BaseMaximumDistance * (value / -243 + (19 / 9)) * (self.MaxAngle / 270) --Doubles at narrowest angle. Computed intercept for 27,1 and 270,2
	elseif inp == "Cone" then
		if value > 0 then

			self.Cone = Clamp(value / 2, self.MinViewCone ,self.MaxViewCone )

			SetConeParameter( self )

			--You are not going from a wide to narrow beam in half a second deal with it.
			local curTime = CurTime()
			self:NextThink(curTime + 10)
		else
			self.Cone = self.ICone
		end

		self:UpdateOverlayText()
	elseif inp == "ActiveSound" then
		self.Sound = value or "acf_extra/ACE/sensors/Sonar/coldwaters.wav"
	elseif inp == "ActivePitch" then
		self.SoundPitch = Clamp(math.Round(value,0),0,255)
	end
end

function ENT:SetActive(active)

	active = active and true or false

	if self.Active == active then
		self:UpdateOverlayText()

		return
	end

	self.Active = active

	--if active  then

	--else
	if not active  then

		WireLib.TriggerOutput( self, "Detected"	, 0 )
		WireLib.TriggerOutput( self, "Bearing", {} )
		WireLib.TriggerOutput( self, "Depth", {} )
		WireLib.TriggerOutput( self, "Distance", {} )
		WireLib.TriggerOutput( self, "Owner", {} )
		WireLib.TriggerOutput( self, "ID", {} )
		WireLib.TriggerOutput( self, "SonoDetected"	, 0 )
		WireLib.TriggerOutput( self, "SonoAngle", {} )
		WireLib.TriggerOutput( self, "TorpDetected"	, 0 )
		WireLib.TriggerOutput( self, "TorpPosition", {} )
		WireLib.TriggerOutput( self, "Washout"	, 0 )


		self.OutputData.Detected = 0
		self.OutputData.Bearing = {}
		self.OutputData.Depth = {}
		self.OutputData.Distance = {}
		self.OutputData.Owner = {}
		self.OutputData.ID = {}
		self.OutputData.SonoDetected = 0
		self.OutputData.SonoAngle = {}
		self.OutputData.TorpDetected = 0
		self.OutputData.TorpPosition = {}
		self.OutputData.Washout = 0

	end

	self:UpdateOverlayText()

end

local LOSTraceData = {
	mask = MASK_SOLID_BRUSHONLY,
	mins = vector_origin,
	maxs = vector_origin,
}

function ENT:SONARDevDisplayAngles(Duration)

		local DebugColor = Color(255, 135, 0)

		local OffsetAng = self.MaxAngle * 0.5 - self.BeamWidth * 0.5 --0.5 of the max angle limit. In this case 270

		local LocalYaw = math.NormalizeAngle(self.BeamAngle - self.SonarYaw)

		local BeamAng = math.Clamp(LocalYaw, -OffsetAng , OffsetAng)

		BeamAng = math.NormalizeAngle(BeamAng + self.SonarYaw)

		local BeamWidth = self.BeamWidth * 0.5

		local Ang1 = BeamAng - BeamWidth
		local Ang2 = BeamAng + BeamWidth

		local SelfPos = self.SelfPos
		local Voffset1 = Vector(self.MaximumDistance,0,-1000)
		--local Voffset2 = Vector(self.MaximumDistance,0,1000)

		debugoverlay.Line(SelfPos, SelfPos + Angle(0,BeamAng,0):Forward() * 500, Duration, Color(0, 0, 255), true)
		--debugoverlay.Line(SelfPos, SelfPos + Angle(0,Ang1,0):Forward() * self.MaximumDistance, Duration, DebugColor)
		--debugoverlay.Line(SelfPos, SelfPos + Angle(0,Ang2,0):Forward() * self.MaximumDistance, Duration, DebugColor)

		debugoverlay.BoxAngles(SelfPos, vector_origin, Voffset1, Angle(0,Ang1,0), Duration, Color(DebugColor.r, DebugColor.g, DebugColor.b, 255))
		debugoverlay.BoxAngles(SelfPos, vector_origin, Voffset1, Angle(0,Ang2,0), Duration, Color(DebugColor.r, DebugColor.g, DebugColor.b, 255))

		--debugoverlay.BoxAngles(SelfPos, vector_origin, Voffset2, Angle(0,Ang1,0), Duration, Color(DebugColor.r, DebugColor.g, DebugColor.b, 5))
		--debugoverlay.BoxAngles(SelfPos, vector_origin, Voffset2, Angle(0,Ang2,0), Duration, Color(DebugColor.r, DebugColor.g, DebugColor.b, 5))

end

function ENT:DoSonarFunctions()

	if self:WaterLevel() ~= 3 then return end

	self.SonarYaw = self:GetAngles().yaw

	if ACE.CurTime > self.NextWaterlevelCheck then
		self:GetWaterHeight()
		self.NextWaterlevelCheck = ACE.CurTime + 3
	end

	self:UpdateSonarTorpedoTracks()
	self:UpdateRecievedPings()

	if self.ActiveTransmitting and ACE.CurTime > self.NextPing then
		if GetConVar( "developer" ):GetBool() ~= 0 then --Is there a faster way to do this?
			self:SONARDevDisplayAngles(self.PulseDuration)
		end
			self:activeSonar()
			self.NextPing = ACE.CurTime + self.PulseDuration
	elseif ACE.CurTime > self.NextPing then
		self:passiveSonar()
		self.NextPing = ACE.CurTime + 0.5
	end

end

function ENT:SONARIsInCone(TarAng , UseActiveWidth)

	local UsedWidth = self.MaxAngle or 270
	if UseActiveWidth or false then
		UsedWidth = self.BeamWidth
	end
	local BeamTest = UsedWidth * 0.5 --0.5 of the max angle limit. In this case 270
	local LocalYaw = math.NormalizeAngle(TarAng - self.BeamAngle)

	--print("BeamWidth: " .. BeamTest)
	--print("LocalYaw: " .. math.Round(LocalYaw,0))

	if math.abs(LocalYaw) < BeamTest then
		return true
	end

	return false
end

function ENT:GetWaterHeight()

	local SelfPos = self.SelfPos

	local WaterTr = { }
	WaterTr.start = SelfPos + Vector(0,0, 50000)
	WaterTr.endpos = SelfPos - Vector(0,0, 50000)
	WaterTr.mask = MASK_WATER
	local Water = util.TraceLine( WaterTr )

	if Water.Hit then
		self.WaterZHeight = Water.HitPos.z
	else
		self.WaterZHeight = self:GetPos().z --If all else fails use our depth.
	end

	WireLib.TriggerOutput( self, "WaterZHeight"	, self.WaterZHeight )

end

function ACE.SonarCalculateAngle(StartPos, FinalPos)
	local PosDiff = FinalPos - StartPos
	local AngleFromTarget = PosDiff:Angle()

	return AngleFromTarget
end

function ACE.SonarCalculateDepth(Position, WaterZ)
	local Depth = -min(Position.z - WaterZ, 0)

	return Depth
end

function ENT:activeSonar()

	local ActiveSound = self.Sound
	local ActivePitch = self.SoundPitch


	if not IsValid(self) then return end
	local SelfPos = self.SelfPos

	local SonarDepth = (self.WaterZHeight - SelfPos.z) / 39.37

	--EmitSound("acf_extra/ACE/sensors/Sonar/coldwaters.wav", SelfPos, 0, CHAN_WEAPON, 1, 400 * self.PowerScale, 0, 100 ) --Formerly 107
	self:EmitSound(ActiveSound, 150 * self.PowerScale, ActivePitch, 1, CHAN_WEAPON )

	local SpeedOfSound = 1540 * 39.37 * ACE.SonarTimeCompression

	--self:SONARDevDisplayAngles(Color(255, 135, 0), self.PulseDuration)

	----------------------------------------
	--Sounds and Player liquification part--
	----------------------------------------

	for _, ply in pairs (player.GetAll()) do

		if ply:WaterLevel() == 0 then continue end
		if ply:InVehicle() then continue end
		local plyPos = ply:GetPos()
		local AngToTarg = ACE.SonarCalculateAngle(SelfPos, plyPos)

		if not self:SONARIsInCone(AngToTarg.yaw, true) then continue end

		local Dist = (plyPos-SelfPos):Length()

		if Dist < self.MaximumDistance * 2 then --Close enough to hear the sonar

			timer.Simple( Dist / SpeedOfSound, function()

				LOSTraceData.start = SelfPos
				LOSTraceData.endpos = plyPos
				local LOSTrace = TraceHull(LOSTraceData)

				local Ratio = 1 - (Dist / self.MaximumDistance)

				if not LOSTrace.Hit and Dist < self.MaximumDistance and not ply:HasGodMode() and ply:Alive() then
						local Damage = math.Round(100 * Ratio,0)
						if Damage > 50 then
							ply:EmitSound("npc/antlion_guard/antlion_guard_shellcrack" .. math.random(1,2) .. ".wav", 100, 40, 1, CHAN_AUTO )
						elseif Damage > 5 then
							ply:EmitSound("npc/stalker/stalker_pain" .. math.random(1,3) .. ".wav", 100, 100, 1, CHAN_AUTO )
						end
						ply:TakeDamage(Damage)
				end

				ply:EmitSound(ActiveSound, 300 * Ratio, ActivePitch, 1, CHAN_WEAPON )
			end)
		end

	end

	----------------------------------------
	-----Contraption Detection Handling-----
	----------------------------------------

	local SelfContraption = self.SelfContraption
	local MyID = ACE.GetContraptionIndex(SelfContraption) or -1


	local CacheTime = ACE.CurTime + 5 --Time in seconds to remove a sonar ping

	for Contraption in pairs(CFW.Contraptions) do
		local Base = Contraption:GetACEBaseplate()

		--print("TestSonar")

		if Contraption == SelfContraption or not IsValid(Base) then continue end

		local BasePos = Base:GetPos()
		local AngToTarg = ACE.SonarCalculateAngle(SelfPos, BasePos)
		local AngPitch = math.NormalizeAngle(-AngToTarg.pitch)

		if not self:SONARIsInCone(AngToTarg.yaw, true) then continue end

		--print(AngPitch)
		if math.abs(AngPitch) > 70 then continue end --Sonar elevation too great.

		if BasePos.z > self.WaterZHeight + 200 then continue end --Target must be within 5m of the water.

		local Dist = (BasePos-SelfPos):Length()

		--TestIfLayerObscured function

		LOSTraceData.start = SelfPos
		LOSTraceData.endpos = BasePos
		local LOSTrace = TraceHull(LOSTraceData)

		if LOSTrace.Hit then continue end

		--print("ContraptionEnt")

		local TravelTime = Dist / SpeedOfSound

		local EnvironmentalFactor = 1 --Represents the modifier for environmental sound travel range. Things like shallow waters will affect this.
		local RecievingEnvironmentalFactor = 1


		--Calculates depth reduction due to the depth of the water. Sonar transmissions in shallow water typically have less range due to sonar reflecting off the bottom and escaping out of the water. Among other factors.
		LOSTraceData.start = BasePos
		LOSTraceData.endpos = BasePos + vector_up * -50000
		LOSTrace = TraceHull(LOSTraceData)

		local ZHit = 0
		local BottomDepth = 0
		local DepthBelowKeel = 0
		if LOSTrace.Hit then
			ZHit = LOSTrace.HitPos.z

			BottomDepth = (self.WaterZHeight - ZHit) / 39.37 --Depth in meters
			--print("Depth: " .. math.Round(BottomDepth) .. "m")

			EnvironmentalFactor = EnvironmentalFactor * (0.3 + 0.7 * min(BottomDepth / 40,1)) --40m of water depth are required for max sonar range
			--print(math.Round(EnvironmentalFactor,2))

			--Math for sonar reciever
			RecievingEnvironmentalFactor = EnvironmentalFactor

			--Submarines sitting on the bottom are harder to detect.
			DepthBelowKeel = (BasePos.z - ZHit) / 39.37
			if DepthBelowKeel < 4 then
				RecievingEnvironmentalFactor = RecievingEnvironmentalFactor * 0.33
			end
		end

		local TarDepth = (self.WaterZHeight - BasePos.z) / 39.37
		if ACE.CheckShadowZoneObscured(SonarDepth, TarDepth, AngPitch) then continue end

		--print(math.Round(self.MaximumDistance * EnvironmentalFactor / 39.37))

		--debugoverlay.Line(SelfPos, BasePos, self.PulseDuration, Color(255, 0, 0), true)

		if Dist < self.MaximumDistance * 2 then --Target can hear our sonar

			local Ratio = math.max(1 - (Dist / self.MaximumDistance * EnvironmentalFactor),0.4)

			if not (ACE.ScheduleSonarTravelSound and ACE.ScheduleSonarTravelSound(Base, TravelTime, SelfPos, BasePos, ActiveSound, ActivePitch, Ratio, 130, CHAN_WEAPON, Color(255, 0, 183), TravelTime)) then
				timer.Simple( TravelTime, function()
					if not IsValid(Base) then return end
					debugoverlay.Line(SelfPos, BasePos, TravelTime, Color(255, 0, 183), true)
					Base:EmitSound(ActiveSound, 130, ActivePitch, 1 * Ratio, CHAN_WEAPON )
				end)
			end

			Contraption.SonarPings = Contraption.SonarPings or {}
			Contraption.SonarPings[MyID] = Contraption.SonarPings[MyID] or {}
			Contraption.SonarPings[MyID].Angle = ACE.SonarCalculateAngle(BasePos, SelfPos)
			Contraption.SonarPings[MyID].Time = CacheTime

			if not (ACE.ScheduleSonarPingExpiry and ACE.ScheduleSonarPingExpiry(Contraption, MyID, 6)) then
				timer.Simple( 6, function() --Longer than cachetime. Should always clear unless something else resets the time.
					if not IsValid(Contraption:GetACEBaseplate()) then return end
					--PrintTable(Contraption.SonarPings or {})
					if ACE.CurTime > Contraption.SonarPings[MyID].Time then
						Contraption.SonarPings[MyID] = nil
						--table.remove(Contraption.SonarPings,MyID)
					end
				end)
			end

			--table.remove(self.SonarPositions,ID)

		end

		if Dist < self.MaximumDistance * RecievingEnvironmentalFactor then --We can hear the sonar return

			local Ratio = math.max(1 - (2 * Dist / self.MaximumDistance * RecievingEnvironmentalFactor),0.4)

			if not (ACE.ScheduleSonarTravelSound and ACE.ScheduleSonarTravelSound(self, TravelTime * 2, SelfPos, BasePos, ActiveSound, ActivePitch * 1, 1 * Ratio, 100, CHAN_AUTO, Color(43, 0, 255), TravelTime)) then
				timer.Simple( TravelTime * 2, function()
					debugoverlay.Line(SelfPos, BasePos, TravelTime, Color(43, 0, 255), true)
					if not IsValid(self) then return end
					self:EmitSound(ActiveSound, 100, ActivePitch * 1, 1 * Ratio, CHAN_AUTO )
				end)
			end

			timer.Simple( TravelTime * 2 + self.PulseDuration * 0.5, function() --Needs to process the sonar pulse

				if not IsValid(Base) then return end
				debugoverlay.Line(SelfPos, BasePos, TravelTime, Color(0, 255, 38), true)

				local ID = ACE.GetContraptionIndex(Contraption)
				local Owner = Base:CPPIGetOwner()


				--Min pulse duration is 0.5
				--Max pulse duration is 10
				--Multiplier ranges from 40x to 2x
				local PulseLengthErrorMul = 30 / self.PulseDuration
				local WashOutErrorMul = 1 + self.WashOut * 2

				local InaccMul = self.NoiseMul * SonarSpreadDistribution * PulseLengthErrorMul * WashOutErrorMul

				--Max errormul = 20x PL * 2x WO = 40x
				--Max Error = 1m * 40x = 40m
				local Inaccuracy = VectorRand() * 39.37 * InaccMul

				self.SonarPositions[ID] = self.SonarPositions[ID] or {}
				self.SonarPositions[ID] = BasePos + Inaccuracy
				self.SonarVelocity[ID] = Base:GetVelocity()
				self.SonarOwners[ID] = Owner:Nick()
				self.SonarLastTracked[ID] = ACE.CurTime

				self.SonoUpdated = true --Let the sonar know to update the outputs

			end)

		end

	end
end

function ENT:passiveSonar() --Subject to rework


	if not IsValid(self) then return end
	local SelfPos = self.SelfPos

	local SonarDepth = (self.WaterZHeight - SelfPos.z) / 39.37

	local SpeedOfSound = 1540 * 39.37 * ACE.SonarTimeCompression

	----------------------------------------
	-----Contraption Detection Handling-----
	----------------------------------------

	local SelfContraption = self.SelfContraption

	for Contraption in pairs(CFW.Contraptions) do
		local Base = Contraption:GetACEBaseplate()

		--print("TestSonar")

		if Contraption == SelfContraption or not IsValid(Base) then continue end

		local BasePos = Base:GetPos()
		local AngToTarg = ACE.SonarCalculateAngle(SelfPos, BasePos)
		local AngPitch = math.NormalizeAngle(-AngToTarg.pitch)

		if not self:SONARIsInCone(AngToTarg.yaw, false) then continue end

		--print(AngPitch)
		if math.abs(AngPitch) > 70 then continue end --Sonar elevation too great.

		if BasePos.z > self.WaterZHeight + 200 then continue end --Target must be within 5m of the water.

		local Dist = (BasePos-SelfPos):Length()

		LOSTraceData.start = SelfPos
		LOSTraceData.endpos = BasePos
		local LOSTrace = TraceHull(LOSTraceData)

		if LOSTrace.Hit then continue end

		--print("ContraptionEnt")

		local TravelTime = Dist / SpeedOfSound
		local TarDepth = (self.WaterZHeight - BasePos.z) / 39.37
		local TarSpeed = Base:GetVelocity():Length()

		if ACE.CheckShadowZoneObscured(TarDepth, SonarDepth, -AngPitch) then continue end

		--About noise
		-- Base noise is the sound-level input used by sonar detection.
		--A target needs a relative noise of 1 to be detected
		--It halves every 200m
		-- Movement noise is reduced by 25% for each 10 m of depth.

		--A stationary target can be detected 100m away
		--A moving target at 10mph can be detected 400m away

		local Noise = 3.75 --Base noise of contraption
		Noise = Noise + TarSpeed / 88 / (1 + TarDepth / 10 * 0.25) -- 1/88 = 1 / 17.6 / 10 * 2. The noise needed to be detected 400m away.

		Noise = Noise * 0.5 ^ (Dist / 39.37 / 100)


		--Calculates depth reduction due to the depth of the water. Sonar transmissions in shallow water typically have less range due to sonar reflecting off the bottom and escaping out of the water. Among other factors.
		LOSTraceData.start = BasePos
		LOSTraceData.endpos = BasePos + vector_up * -50000
		LOSTrace = TraceHull(LOSTraceData)

		local ZHit = 0
		local BottomDepth = 0
		if LOSTrace.Hit then
			ZHit = LOSTrace.HitPos.z
			BottomDepth = (self.WaterZHeight - ZHit) / 39.37 --Depth in meters
			--print("Depth: " .. math.Round(BottomDepth) .. "m")

			Noise = Noise * (0.5 + 0.5 * min(BottomDepth / 40,1)) --40m of water depth are required for max sonar range
			--print(math.Round(EnvironmentalFactor,2))
		end

		--print(math.Round(self.MaximumDistance * EnvironmentalFactor / 39.37))

		--debugoverlay.Line(SelfPos, BasePos, self.PulseDuration, Color(255, 0, 0), true)

		if Noise * (1.34 * self.PowerScale) > 1 then --We can hear the target's noise

			timer.Simple( TravelTime, function()

				if not IsValid(Base) then return end
				debugoverlay.Line(SelfPos, BasePos, TravelTime, Color(0, 255, 38), true)

				local ID = ACE.GetContraptionIndex(Contraption)
				local Owner = Base:CPPIGetOwner()

				local WashOutErrorMul = 1 + self.WashOut * 4

				local InaccMul = self.NoiseMul * SonarSpreadDistribution * WashOutErrorMul

				--Max errormul = 20x PL * 2x WO = 40x
				--Max Error = 1m * 40x = 40m
				local Inaccuracy = VectorRand() * 39.37 * InaccMul


				self.SonarPositions[ID] = self.SonarPositions[ID] or {}
				self.SonarPositions[ID] = BasePos + Inaccuracy
				self.SonarVelocity[ID] = vector_origin
				self.SonarOwners[ID] = Owner:Nick()
				self.SonarLastTracked[ID] = ACE.CurTime

				self.SonoUpdated = true --Let the sonar know to update the outputs

			end)

		end

	end
end

function ENT:CleanupSonarTracks(CleanupDelay)
	local TimeAfter = ACE.CurTime - CleanupDelay
	local IDsToRemove = {}

	-- Collect IDs that need removal
	for ID, LastTracked in pairs(self.SonarLastTracked) do
		if TimeAfter > LastTracked then
			table.insert(IDsToRemove, ID)
		end
	end

	-- Remove outdated elements after collecting IDs
	for _, ID in ipairs(IDsToRemove) do
		self.SonarPositions[ID] = nil
		self.SonarVelocity[ID] = nil
		self.SonarOwners[ID] = nil
		self.SonarLastTracked[ID] = nil
	end

	-- Update sonar outputs if needed
	if #IDsToRemove > 0 then
		self.SonoUpdated = true
	end
end


function ENT:UpdateSonarTorpedoTracks()

	local TorpPositions = {}

	local DetectionRange = 300 * 39.37 * self.PowerScale
	local missiles = ACE.Missile_GetMissilesInSphere(self,DetectionRange)

	local i = 0
	for _, missile in pairs(missiles) do

		if (missile.UnderwaterThrust or 0) < 1 then continue end --Main missile motor doesn't work underwater. Not a torpedo.
		if (missile.IsUnderWater or 0) == 0 then continue end --Torpedo waterlevel is not underwater. Ignore it.


		i = i + 1
		TorpPositions[i] = missile:GetPos()

	end


	if table.Count( TorpPositions ) > 0 then
		WireLib.TriggerOutput( self, "TorpDetected", 1 )
	else
		WireLib.TriggerOutput( self, "TorpDetected", 0 )
	end
	WireLib.TriggerOutput( self, "TorpPosition", TorpPositions )

end

function ENT:UpdateRecievedPings()

	local PingAngles = {}

	local SelfContraption = self.SelfContraption


	if not table.IsEmpty(SelfContraption.SonarPings or {}) then  --Needs some other workaround as contraptions aren't recognized as valid

		SelfContraption.SonarPings = SelfContraption.SonarPings or {}


		local i = 0
		for _, SonoPings in pairs(SelfContraption.SonarPings) do

			i = i + 1
			--print(SonoPings.Angle)
			PingAngles[i] = SonoPings.Angle

		end


	end

	if table.Count( PingAngles ) > 0 then
		WireLib.TriggerOutput( self, "SonoDetected", 1 )
	else
		WireLib.TriggerOutput( self, "SonoDetected", 0 )
	end
	WireLib.TriggerOutput( self, "SonoAngle", PingAngles )

end

--Negate elevation if reversed
function ACE.CheckShadowZoneObscured(StartDepth, EndDepth, Elevation) --Checks if noise can reach the given area. Likely will be reworked.

	local IsShallow = 1

	--Shallow layer logic
	local ShallowWaterCriticalAngle = 20

	if IsShallow then

		local AboveShallowLayer = 1
		local TarAboveShallowLayer = 1

		if StartDepth > ACE.SonarLayerDepth then --Origin is below the layer
			AboveShallowLayer = 0
		end
		if EndDepth > ACE.SonarLayerDepth then --Target is above the layer
			TarAboveShallowLayer = 0
		end

		if AboveShallowLayer == TarAboveShallowLayer then
			--print("Samelayer")
			return false
		end --On same layer depth as target. Return true. Otherwise do logic



		if AboveShallowLayer > TarAboveShallowLayer then --Target is below layer but we are not
			--print(Elevation)
			if Elevation < -ShallowWaterCriticalAngle then
				--print("Shallowwater Valid")
				return false
			else
				--print("Shallowwater Invalid")
				return true
			end

		elseif TarAboveShallowLayer > AboveShallowLayer then --Target is above layer and we are below it
			--print(Elevation)
			if Elevation > ShallowWaterCriticalAngle then
				--print("Shallowwater Valid")
				return false
			else
				--print("Shallowwater Invalid")
				return true
			end
		end

	end

	--print("Overflow")
	return false

end


function ENT:UpdateSonarTracks() --Step the track forward by velocity? Or let player do that?

	--Don't update the outputs if there's nothing to update.
	if not self.SonoUpdated then return end
	self.SonoUpdated = false

	local SelfPos = self.SelfPos

	local SonoBearings = {}
	local SonoDepths = {}
	local SonoDistances = {}
	local SonoVelocities = {}
	local SonoID = {}
	local SonoOwner = {}
	local Distances = {} --Not an output

	--Compiles the track lists to the table

	local MySpeed = self.SelfBasePlate:GetVelocity():Length()
	self.WashOut = MySpeed / 616 * self.WashoutFactor -- 616 = 17.6 per mph * 35 mph
	WireLib.TriggerOutput( self, "Washout"	, self.WashOut )


	if self.WashOut < 1 then --The sonar only works as long as it isn't washed out.
		for ID in pairs(self.SonarPositions) do
			--print(ID)

			local SVel = vector_origin --For passive sonar and when the sonar pulse isn't long enough
			--local Dist = 0
			local SOwn = self.SonarOwners[ID]

			if self.ActiveTransmitting and self.PulseDuration > 4 then
				SVel = self.SonarVelocity[ID]
			end

			OutputPosition = self.SonarPositions[ID]
			OutputDistance = OutputPosition:Distance(SelfPos) --/ 39.3701

			local Bearing = ACE.SonarCalculateAngle(SelfPos, OutputPosition).yaw
			local Depth = ACE.SonarCalculateDepth(OutputPosition, self.WaterZHeight)

			--if self.ActiveTransmitting and self.PulseDuration > 0.5 then
			local Dist = ((SelfPos - OutputPosition) * NoZVector):Length()
			--end

			--print("SonoBearing: " .. math.Round(Bearing / 39.37,1))
			--print("SonoDepth: " .. math.Round(Depth / 39.37,2))
			--print("SonoDist: " .. math.Round(Dist / 39.37,2))
			debugoverlay.Cross(OutputPosition,35,self.PulseDuration,Color( 183, 0, 255), true)

			local InsertionIndex = ACE.GetBinaryInsertIndex(Distances, OutputDistance)
			tableInsert(SonoBearings, InsertionIndex, Bearing)
			tableInsert(SonoDepths, InsertionIndex, Depth)
			tableInsert(SonoDistances, InsertionIndex, Dist)
			tableInsert(SonoVelocities, InsertionIndex, SVel)
			tableInsert(SonoID, InsertionIndex, ID)
			tableInsert(SonoOwner, InsertionIndex, SOwn)

		end
	end


	--Updates the wire outputs using the tables
	if table.Count( SonoID ) > 0 then

		WireLib.TriggerOutput( self, "Detected"	, 1 )
		WireLib.TriggerOutput( self, "Bearing", SonoBearings )
		WireLib.TriggerOutput( self, "Depth", SonoDepths )
		WireLib.TriggerOutput( self, "Distance", SonoDistances )
		WireLib.TriggerOutput( self, "Velocity", SonoVelocities )
		WireLib.TriggerOutput( self, "ID", SonoID )
		WireLib.TriggerOutput( self, "Owner", SonoOwner ) --SonoVelocities


		self.OutputData.Detected = 0
		self.OutputData.Bearing = SonoBearings
		self.OutputData.Depth = SonoDepths
		self.OutputData.Distance = SonoDistances
		self.OutputData.Velocity = SonoVelocities
		self.OutputData.ID = SonoID
		self.OutputData.Owner = SonoOwner

	else
		WireLib.TriggerOutput( self, "Detected"	, 0 )
		WireLib.TriggerOutput( self, "Bearing", {} )
		WireLib.TriggerOutput( self, "Depth", {} )
		WireLib.TriggerOutput( self, "Distance", {} )
		WireLib.TriggerOutput( self, "Velocity", {} )
		WireLib.TriggerOutput( self, "ID", {} )
		WireLib.TriggerOutput( self, "Owner", {} )

		self.OutputData.Detected = 0
		self.OutputData.Bearing = {}
		self.OutputData.Depth = {}
		self.OutputData.Distance = {}
		self.OutputData.Velocity = {}
		self.OutputData.ID = {}
		self.OutputData.Owner = {}
	end

end


function ENT:UpdateStatus()
	self.Status = self.Active and "On" or "Off"
end

function ENT:Think()

	local curTime = ACE.CurTime

	-- Legal check system
	if ACE.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACE.CheckLegal(self, nil, math.Round(self.Weight,2), nil, true, true)
		self.NextLegalCheck = ACE.Legal.NextCheck(self.legal)

		local shouldBeActive = ACE.GetDefaultActiveInputState(self)

		if self.Active ~= shouldBeActive then
			self:SetActive(shouldBeActive)
		end

	end

	if self.Active and self.Legal then

		self.SelfPos = self:WorldSpaceCenter()
		self.SelfContraption = self:CFW_GetContraption() or {}

		if not table.IsEmpty(self.SelfContraption) then
			self.SelfBasePlate = self.SelfContraption:GetACEBaseplate()
		else
			self.SelfBasePlate = self
		end

		self:DoSonarFunctions()
		self:CleanupSonarTracks(10) --Wait the duration of an active pulse before cleaning up contacts.
		self:UpdateSonarTracks()
	end

	if (self.LastStatusUpdate + self.StatusUpdateDelay) < curTime then
		self:UpdateStatus()
		self.LastStatusUpdate = curTime
	end

	self:UpdateOverlayText()

	self:NextThink(curTime + self.ThinkDelay)
	return true
end

function ENT:UpdateOverlayText()
	local status	= self.Status or "Off"
	local detected  = status ~= "Off" and self.TargetDetected or false
	local range		= self.BaseMaximumDistance or 0
	local range2	= self.MaximumDistance or 0

	local txt = "Status: " .. status


	txt = txt .. "\n\nCurrent Range: " .. math.Round(range2 / 39.37 , 2) .. " m"

	txt = txt .. "\n\nMax Omnidirectional Range: " .. math.Round(range / 39.37 , 2) .. " m"
	txt = txt .. "\nMax Directional Range: " .. math.Round(range / 39.37 * 2 , 2) .. " m"

	if detected then
		txt = txt .. "\n\nTarget Detected!"
	end

	if not self.Legal then
		txt = txt .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText(txt)
end
