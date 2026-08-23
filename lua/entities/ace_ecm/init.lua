AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:SpawnFunction( _, trace )

	if not trace.Hit then return end

	local SPos = (trace.HitPos + Vector(0, 0, 1))

	local ent = ents.Create( "ace_ecm" )
	ent:SetPos( SPos )
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:Initialize()

	self.ThinkDelay = 0.25 --0.25 second delay, hopefully enough to prevent ECM flashing
	self.Weight = 1000

	self.Active = false
	curTime = 0

	self:SetModel( "models/missiles/minipod.mdl" )
	self:PhysicsInit(SOLID_VPHYSICS)

	self:GetPhysicsObject():SetMass(self.Weight)

	self.Inputs = WireLib.CreateInputs( self, { "Active", "JamDirection [VECTOR]", "JamPos [VECTOR]" } )
	self.Outputs = WireLib.CreateOutputs( self, {"JamCount"} )

	WireLib.TriggerOutput( self, "JamCount", 0 )

	self.NextLegalCheck	= ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal = true
	self.LegalIssues = ""

	--out radars jammed?
	self:SetActive(false)

	self.CurrentlyJamming = 0
	self.JamDirection = vector_origin
	self.JamTargetPos = 0 --Used for storing and updating jam vector if there is one.

	self.PowerID = 7

	self.ACEPoints = 500
end


function ENT:TriggerInput( inp, value )
	if inp == "Active" then
		self:SetActive(ACE.GetDefaultActiveInputState(self, value) and self.Legal)
	elseif inp == "JamDirection" then
		self.JamDirection = value
		self.JamTargetPos = nil
	elseif inp == "JamPos" then
		self.JamTargetPos = value
		self.JamDirection = self.JamTargetPos - self:GetPos()
		--:GetNormalized() May not need to be normalized?
	end

end

function ENT:SetActive(active)

	self.Active = active

	self:NextThink(curTime + 3) --ECM engaged, Warmup boot.

	if active  then
		local sequence = self:LookupSequence("active") or 0
		self:ResetSequence(sequence)
		self.AutomaticFrameAdvance = true
	else
		local sequence = self:LookupSequence("idle") or 0
		self:ResetSequence(sequence)
		self.AutomaticFrameAdvance = false
		self.CurrentlyJamming = 0
		WireLib.TriggerOutput( self, "JamCount", 0 )
	end

end

function ENT:Think()

	local curTime = CurTime()
	self:NextThink(curTime + self.ThinkDelay)

	if ACE.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACE.CheckLegal(self, self.Model, math.Round(self.Weight, 2), nil, true, true)
		self.NextLegalCheck = ACE.Legal.NextCheck(self.legal)

	end

	self.CurrentlyJamming = 0
	if self.Active and self.Legal then

		if self.JamTargetPos and isvector(self.JamTargetPos) then
			self.JamDirection = (self.JamTargetPos-self:GetPos()):GetNormalized()
		end


		local thisPos = self:GetPos()


		local found = table.Copy(ACE.radarEntities)

		for MissileEnt, _ in pairs(ACE.ActiveMissiles) do
			--print(MissileEnt)
			table.insert( found, MissileEnt )
		end


		for _, scanEnt in pairs(found) do

			--check if ent is valid
			if scanEnt:IsValid() then

				local entpos	= scanEnt:WorldSpaceCenter()

				local difpos	= (entpos - thisPos)

				local OffBoreAng = self.JamDirection:Angle()
				local ang	= difpos:Angle() - OffBoreAng	--Used for testing if inrange

				--local ang	= self:WorldToLocalAngles(difpos:Angle())	--Used for testing if inrange
				local absang	= Angle(math.abs(ang.p),math.abs(ang.y),0)  --Since I like ABS so much

				--Entity is within radar cone
				if (absang.p < 10 and absang.y < 10) then --10 degree jammer cone

					local LOStr = util.TraceLine( {

						start = thisPos ,endpos = entpos,
						collisiongroup = COLLISION_GROUP_WORLD,
						filter = function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end,

					}) --Hits anything in the world.

					--Trace did not hit world
					if not LOStr.Hit then
						self.CurrentlyJamming = self.CurrentlyJamming + 1
						--ECM Beam width strength
						--Center beam 1x strength
						--1 axis off (90 deg) - 1/3x
						--2 axis off (180deg) - 1/6x
						local JamStrength = 1 / (1 + (absang.p / 10 + absang.y / 10) * 3)

						scanEnt.IsJammed			= 1
						scanEnt.JamStrength		= JamStrength
						scanEnt.JamDir				= -difpos:GetNormalized()

						--local JamID = ACE.radarIDs[scanEnt]

					end

				end

			end

		end
		WireLib.TriggerOutput( self, "JamCount", self.CurrentlyJamming )
	end

	self:UpdateOverlayText()

end

function ENT:UpdateOverlayText()

	local Active = self.Active
	local JamCount = self.CurrentlyJamming
	local str = string.format("Active: %s\nJam Count: %s", Active, JamCount)

	if not self.Legal then
		str = str .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText(str)
end

function ENT:OnRemove()

end









