
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include("shared.lua")
include("radar_types_support.lua")

CreateConVar("sbox_max_ace_missileradar", 6)

DEFINE_BASECLASS( "base_wire_entity" )

local tableInsert = table.insert

local RadarWireDescs = {

	--Outputs
	["Detected"]  = "Returns the amount of missiles that this radar is currently detecting.",
	["Entities"]  = "Returns all the detected missiles into an array.",
	["Position"]  = "Returns the current position of all the flying missiles of this radar",
	["Velocity"]  = "Returns the velocity of all the active missiles into an array.",
	["ID"]  = "Returns the unique ID of any tracked missile.",
	["Owner"]  = "Returns the name of the owner of the missile.",

}

function ENT:Initialize()

	self.BaseClass.Initialize(self)

	self.Inputs				= WireLib.CreateInputs( self, { "Active" } )
	self.Outputs			= WireLib.CreateOutputs( self, {
		"Detected (" .. RadarWireDescs["Detected"] .. ")",
		"ClosestDistance",
		"Entities (" .. RadarWireDescs["Entities"] .. ") [ARRAY]",
		"Position (" .. RadarWireDescs["Position"] .. ") [ARRAY]",
		"Velocity (" .. RadarWireDescs["Velocity"] .. ") [ARRAY]",
		"ID (" .. RadarWireDescs["ID"] .. ") [ARRAY]",
		"Owner (" .. RadarWireDescs["Owner"] .. ") [ARRAY]",
		"Heat"
	} )

	self.OutputData = {
		Detected = 0,
		ClosestDistance = 0,
		Entities = {},
		Position = {},
		Velocity = {},
		ID = {},
		Owner = {},
	}

	self.ThinkDelay			= 0
	self.StatusUpdateDelay	= 0.5
	self.LastStatusUpdate	= CurTime()

	self.NextLegalCheck		= ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal				= true
	self.LegalIssues		= ""

	self.Heat 				= ACE.AmbientTemp

	self.IsJammed			= 0
	self.JamStrength		= 0
	self.JamDir				= vector_origin
	self.NextJamCheck		= 0
	self.ResetJamDelay		= 0.2 --Periodically resets jamming strength to zero for the jammer to apply the highest noise available. This means the jamming won't always remain at full strength without a lot of networking.

	self.PowerID = 8

	self.Active				= false

	self:CreateRadar(self.ACFName or "Missile Radar", self.ConeDegs or 180)

	self:EnableClientInfo(true)

	self:ConfigureForClass()

	self:GetOverlayText()

	self:SetActive(ACE.GetDefaultActiveInputState(self))

end




function ENT:ConfigureForClass()

	local behaviour = ACE.Missile.RadarBehaviour[self.Class]

	if not behaviour then return end

	self.GetDetectedEnts = behaviour.GetDetectedEnts

end




function ENT:TriggerInput( inp, value )
	if inp == "Active" then
		self:SetActive(ACE.GetDefaultActiveInputState(self, value))
	end
end




function ENT:SetActive(active, forceVisual)

	active = active and true or false

	if self.Active == active and not forceVisual then
		self.Status = active and "On" or "Off"
		self:GetOverlayText()

		return
	end

	self.Active = active
	self.Status = active and "On" or "Off"

	if active then
		local sequence = self:LookupSequence("active") or 0
		self:ResetSequence(sequence)
		self.AutomaticFrameAdvance = true
	else
		local sequence = self:LookupSequence("idle") or 0
		self:ResetSequence(sequence)
		self.AutomaticFrameAdvance = false
	end

	self:GetOverlayText()

end




function ACE.MakeMissileRadar(Owner, Pos, Angle, Id)

	if not Owner:CheckLimit("_ace_missileradar") then return false end

	local radar = ACE.Weapons.Radars[Id]

	if not radar then return false end

	local Radar = ents.Create("acf_missileradar")
	if not Radar:IsValid() then return false end
	Radar:SetAngles(Angle)
	Radar:SetPos(Pos)

	Radar.Model        = radar.model
	Radar.Weight       = radar.weight
	Radar.ACFName      = radar.name
	Radar.ConeDegs     = radar.viewcone
	Radar.Range        = radar.range
	Radar.Id           = Id
	Radar.Class        = radar.class

	Radar.Sound        = ACE.Missile.DefaultRadarSound
	Radar.DefaultSound = Radar.Sound
	Radar.SoundPitch   = 100
	Radar.ACEPoints		= radar.acepoints or 0.9

	Radar:Spawn()
	Radar:SetPlayer(Owner)

	Radar:CPPISetOwner(Owner)

	Radar:SetModelEasy(radar.model)
	Radar:SetActive(ACE.GetDefaultActiveInputState(Radar), true)

	Owner:AddCount( "_ace_missileradar", Radar )
	Owner:AddCleanup( "acemenu", Radar )

	Radar:SetNWString( "WireName", Radar.ACFName )
	Radar:SetNWString( "Sound", Radar.Sound )
	Radar:SetNWInt( "SoundPitch",  Radar.SoundPitch )

	return Radar

end
list.Set( "ACFCvars", "acf_missileradar", {"id"} )
duplicator.RegisterEntityClass("acf_missileradar", ACE.MakeMissileRadar, "Pos", "Angle", "Id" )

function ENT:CreateRadar(ACFName, ConeDegs)

	self.ConeDegs = ConeDegs
	self.ACFName = ACFName

	self:RefreshClientInfo()

end

function ENT:RefreshClientInfo()

	self:SetNWFloat("ConeDegs", self.ConeDegs)
	self:SetNWFloat("Range", self.Range)
	self:SetNWString("Id", self.ACFName)
	self:SetNWString("Name", self.ACFName)

end

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

function ENT:Think()

	if self.Active and self.Legal then
		self:ScanForMissiles()
	else
		self:ClearOutputs()
	end

	local curTime = CurTime()
	self:NextThink(curTime + self.ThinkDelay)

	if ACE.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACE.CheckLegal(self, self.Model, math.Round(self.Weight, 2), nil, true, true)
		self.NextLegalCheck = ACE.Legal.NextCheck(self.legal)

		local shouldBeActive = ACE.GetDefaultActiveInputState(self)

		if self.Active ~= shouldBeActive then
			self:SetActive(shouldBeActive)
		end

	end

	if (self.LastStatusUpdate + self.StatusUpdateDelay < curTime) then
		self:UpdateStatus()
		self.LastStatusUpdate = curTime
	end

	self.Heat = ACE.HeatFromRadar(self, self.ThinkDelay)
	WireLib.TriggerOutput(self, "Heat", self.Heat)
	self:GetOverlayText()

	if self.IsJammed ~= 0 and ACE.CurTime > self.NextJamCheck then
		self.NextJamCheck = ACE.CurTime + self.ResetJamDelay

		--Reset everything for next check
		self.IsJammed			= 0
		self.JamStrength		= 0
		self.JamDir				= vector_origin

	end


	return true
end

function ENT:UpdateStatus()

	if self.Active then
		self.Status = "On"
	else
		self.Status = "Off"
	end
end

function ENT:GetDetectedEnts()

	--print("reached base GetDetectedEnts")

end

function ENT:ScanForMissiles()

	local missiles = self:GetDetectedEnts() or {}
	local distArray = {}
	local entArray = {}
	local posArray = {}
	local velArray = {}
	local IDArray = {}
	local OwnerArray = {}

	local count = 0

	local closest
	local closestSqr = math.huge

	local thisPos = self:GetPos()


	local BurnThroughDist = (40  / self.JamStrength * 39.37) ^ 2
	for _, missile in pairs(missiles) do

		if (missile.IsUnderWater or 0) > 0 then
			--print("WaterLevelExclusion: " .. missile.IsUnderWater)
			continue
		end

		local distanceSqr = thisPos:DistToSqr(missile.CurPos)

		local BurnThrough = self.IsJammed == 0 or  BurnThroughDist >= distanceSqr
		if not BurnThrough then continue end

		count = count + 1


		local Owner = missile:CPPIGetOwner()

		-- Sort the missiles by distance from the radar
		local insertionIndex = ACE.GetBinaryInsertIndex(distArray, distanceSqr)
		tableInsert(distArray, insertionIndex, distanceSqr)
		tableInsert(entArray, insertionIndex, missile)
		tableInsert(posArray, insertionIndex, missile.CurPos) --Replaced with non-cached value as to not lag behind.
		tableInsert(velArray, insertionIndex, missile.Flight * 39.37)
		tableInsert(IDArray, insertionIndex, missile.MissileID) --Replaced with non-cached value as to not lag behind.
		tableInsert(OwnerArray, insertionIndex, Owner:Nick())

		if distanceSqr < closestSqr then
			closest = missile.CurPos
			closestSqr = distanceSqr
		end
	end

	if not closest then closestSqr = 0 end

	local closestOutput = math.sqrt(closestSqr)

	WireLib.TriggerOutput( self, "Detected", count )
	WireLib.TriggerOutput( self, "ClosestDistance", closestOutput )
	WireLib.TriggerOutput( self, "Entities", entArray )
	WireLib.TriggerOutput( self, "Position", posArray )
	WireLib.TriggerOutput( self, "Velocity", velArray )
	WireLib.TriggerOutput( self, "ID", IDArray )
	WireLib.TriggerOutput( self, "Owner", OwnerArray )

	self.OutputData.Detected = count
	self.OutputData.ClosestDistance = closestOutput
	self.OutputData.Entities = entArray
	self.OutputData.Position = posArray
	self.OutputData.Velocity = velArray
	self.OutputData.ID = IDArray
	self.OutputData.Owner = OwnerArray


	if count > (self.LastMissileCount or 0) then
		self:EmitRadarSound()
	end

	self.LastMissileCount = count

end

function ENT:EmitRadarSound()
	local Effect = EffectData()
		Effect:SetEntity( self )
	util.Effect( "ace_radar_noise", Effect, true, true )
end

function ENT:ClearOutputs()

	if #self.Outputs.Entities.Value > 0 then
		WireLib.TriggerOutput( self, "Entities", {} )
		self.OutputData.Entities = {}
	end

	if #self.Outputs.Position.Value > 0 then
		WireLib.TriggerOutput( self, "Position", {} )
		WireLib.TriggerOutput( self, "ClosestDistance", 0 )
		self.OutputData.Position = {}
		self.OutputData.ClosestDistance = 0
	end

	if #self.Outputs.Velocity.Value > 0 then
		WireLib.TriggerOutput( self, "Velocity", {} )
		self.OutputData.Velocity = {}
	end

	if #self.Outputs.ID.Value > 0 then
		WireLib.TriggerOutput( self, "ID", {} )
		self.OutputData.ID = {}
	end

	if #self.Outputs.Owner.Value > 0 then
		WireLib.TriggerOutput( self, "Owner", {} )
		self.OutputData.Owner = {}
	end

end

function ENT:EnableClientInfo(bool)
	self.ClientInfo = bool
	self:SetNWBool("VisInfo", bool)

	if bool then
		self:RefreshClientInfo()
	end
end

--New Overlay text that is shown when you are looking at the radar
function ENT:GetOverlayText()

	local cone	= self.ConeDegs
	local range	= self.Range
	local status	= self.Status or "Off"
	local detected  = self.Outputs.Detected.Value

	local txt = "Status: " .. status

	txt = txt .. "\n\nView Cone: " .. math.Round(cone * 2, 2) .. " deg"

	txt = txt .. "\nMax Range: " .. (isnumber(range) and math.Round(range / 39.37 , 2) .. " m" or "Unlimited" )

	local Jammed = self.IsJammed
	if Jammed > 0 then
		txt = txt .. "\n\n! ! ! Warning: Jammed ! ! !"
	end

	if detected and detected > 0 then
		txt = txt .. "\n\nMissiles detected: " .. detected
	end

	if not self.Legal then
		txt = txt .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	txt = txt .. "\nTemp: " .. math.Round(self.Heat) .. "C / " .. math.Round((self.Heat * (9 / 5)) + 32) .. "F"

	self:SetOverlayText(txt)

end
