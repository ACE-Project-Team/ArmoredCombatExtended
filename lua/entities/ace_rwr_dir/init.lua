AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:SpawnFunction( _, trace )

	if not trace.Hit then return end

	local SPos = (trace.HitPos + Vector(0, 0,1))

	local ent = ents.Create( "ace_rwr_dir" )
	ent:SetPos( SPos )
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:Initialize()

	self.ThinkDelay = 0.1
	self.Detected = 0
	self.Weight = 105

	self.Active = false

	self:SetModel( "models/radar/radar_sml.mdl" )
	self:PhysicsInit(SOLID_VPHYSICS)

	self:GetPhysicsObject():SetMass(self.Weight)

	self.Inputs = WireLib.CreateInputs( self, { "Active" } )
	self.Outputs = WireLib.CreateOutputs( self, {"Detected", "Radar ID [ARRAY]", "Angle [ARRAY]", "Radar Power [ARRAY]"} )

	self.NextLegalCheck	= ACE.CurTime
	self.Legal = false
	self.LegalIssues = "Awaiting legality validation"

	-- Must run after legal state is set: SetActive -> UpdateOverlayText reads Legal/NextLegalCheck
	self:SetActive(ACE_GetDefaultActiveInputState(self))


	self.Cone = 50

end


function ENT:TriggerInput( inp, value )
	if inp == "Active" then
		self:SetActive(ACE_GetDefaultActiveInputState(self, value))
	end
end

function ENT:SetActive(active)
	if active and not ACE.RequireEntityLegal(self) then active = false end

	active = active and true or false

	if self.Active == active then
		self:UpdateOverlayText()

		return
	end

	self.Active = active

	if active  then
		local sequence = self:LookupSequence("active") or 0
		self:ResetSequence(sequence)
		self.AutomaticFrameAdvance = true
	else
		local sequence = self:LookupSequence("idle") or 0
		self:ResetSequence(sequence)
		self.AutomaticFrameAdvance = false

		WireLib.TriggerOutput( self, "Detected", 0 )
		WireLib.TriggerOutput( self, "Angle", {} )
		WireLib.TriggerOutput( self, "Radar ID", {} )
		WireLib.TriggerOutput( self, "Radar Power", {} )
	end

	self:UpdateOverlayText()

end

function ENT:Think()

	local curTime = CurTime()
	self:NextThink(curTime + self.ThinkDelay)

	if ACE.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACE.RequireLegal(self, self.Model, math.Round(self.Weight, 2), nil, true, true)
		self.NextLegalCheck = ACE.Legal.NextCheck(self.Legal)

		local shouldBeActive = ACE_GetDefaultActiveInputState(self)

		if self.Active ~= shouldBeActive then
			self:SetActive(shouldBeActive)
		end

	end


	if self.Active and ACE.RequireEntityLegal(self) then

		local ScanArray = ACE.radarEntities

		local thisPos = self:GetPos()
		local detected = 0
		local radIDs = {}
		local detAngs = {}
		local radPOWs = {}
		local randinac = Angle(math.Rand(-3,3),math.Rand(-3,3),0)

		for _, scanEnt in pairs(ScanArray) do

			if IsValid(scanEnt) then

				local entpos = scanEnt:GetPos()
				local difpos = (thisPos - entpos)

				local radActive = scanEnt.Active

				if radActive then
					local nonlocang = (-difpos):Angle()


					local ang = angle_zero
					local absang = angle_zero
					local ScanCone1 = 5
					local ScanCone2 = 5

					if scanEnt:GetClass() ~= "ace_searchradar" then
						ang = scanEnt:WorldToLocalAngles(difpos:Angle())	--Used for testing if inrange
						absang = Angle(math.abs(ang.p),math.abs(ang.y),0) --Since I like ABS so much

						ScanCone1 = (scanEnt.Cone or scanEnt.ConeDegs or 0 ) + 8
						ScanCone2 = (scanEnt.Cone or scanEnt.ConeDegs  or 0 ) + 8
					else --Search radar
						ang	=  scanEnt:WorldToLocalAngles(difpos:Angle())  - Angle(0,scanEnt.CurrentScanAngle,0)	--Used for testing if inrange
						--absang	= Angle(math.abs(math.NormalizeAngle(ang.p)),math.abs(math.NormalizeAngle(ang.y)),0)  --Since I like ABS so much
						absang	= Angle(0,math.abs(math.NormalizeAngle(ang.y)),0)  --Because elevation limits are disabled on search radars
						ScanCone1 = 99999
						ScanCone2 = scanEnt.Cone / 4 + 8
					end


					local ang2 = self:WorldToLocalAngles(nonlocang)
					local absang = Angle(math.abs(ang.p),math.abs(ang.y),0) --Since I like ABS so much
					local absang2 = Angle(math.abs(ang2.p),math.abs(ang2.y),0) --Since I like ABS so much

					if absang.p < ScanCone1  and absang.y < ScanCone2 and absang2.p < self.Cone and absang2.y < self.Cone then --Entity is within radar cone

						local LOStr = util.TraceLine( {
							start = thisPos ,
							endpos = entpos,collisiongroup = COLLISION_GROUP_WORLD,
							filter = function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end, --Hits anything in the world.
							mins = Vector(0,0,0),
							maxs = Vector(0,0,0)
							} )

						if not LOStr.Hit then --Trace did not hit world

							detected = 1

							table.insert(radIDs,ACE.radarIDs[scanEnt])
							table.insert(detAngs, Angle(nonlocang.p + randinac.p, nonlocang.y + randinac.y, nonlocang.r + randinac.r) ) --3
							table.insert(radPOWs,scanEnt.PowerID or 0)
						end
					end
				end
			end
		end

		self.Detected = detected

		WireLib.TriggerOutput( self, "Detected", detected )
		WireLib.TriggerOutput( self, "Radar ID", radIDs )
		WireLib.TriggerOutput( self, "Angle", detAngs )
		WireLib.TriggerOutput( self, "Radar Power", radPOWs )
	end

	self:UpdateOverlayText()

	return true

end

function ENT:UpdateOverlayText()

	local Active = self.Active
	local Detected = self.Detected
	local str = string.format("Active: %s\nDetected: %s", Active, Detected)

	if not self.Legal then
		str = str .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText(str)
end
