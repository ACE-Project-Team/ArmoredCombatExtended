AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local acos, deg, remap, clamp = math.acos, math.deg, math.Remap, math.Clamp
local round, ceil, random = math.Round, math.ceil, math.random

function ENT:SpawnFunction( _, trace )

	if not trace.Hit then return end

	local SPos = (trace.HitPos + Vector(0,0,1))

	local ent = ents.Create( "ace_crewseat_driver" )
	ent:SetPos( SPos )
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:Initialize()

	if self:GetModel() == "models/vehicles/pilot_seat.mdl" then
		self:SetPos(self:LocalToWorld(Vector(0, 15.3, -14)))
	end
	self:SetModel( "models/chairs_playerstart/sitpose.mdl" )
	self:SetMoveType(MOVETYPE_VPHYSICS);
	self:PhysicsInit(SOLID_VPHYSICS);
	self:SetUseType(SIMPLE_USE);
	self:SetSolid(SOLID_VPHYSICS);
	self:GetPhysicsObject():SetMass(60)

	self.Master = {}
	self.ACF = {}
	self.ACF.Health = 1
	self.ACF.MaxHealth = 1
	self.Name = "Crew Seat"
	self.Weight = 60
	self.AnglePenalty = 0
	self.LinkedEngine = nil
	self.Sound = "npc/combine_soldier/die" .. tostring(random(1, 3)) .. ".wav"
	self.SoundPitch = 100

	--if not IsValid(self:CPPIGetOwner()) then
	--	self:CPPISetOwner(game.GetWorld())
	--end

	self.NextLegalCheck	= ACF.CurTime + random(ACF.Legal.Min, ACF.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal = true
	self.LegalIssues = ""
	self.ACEPoints = 1

	self.SpecialHealth	= false  --If true needs a special ACF_Activate function
	self.SpecialDamage	= true  --If true needs a special ACF_OnDamage function

	local rareNames = {"Mr.Marty", "RDC", "Cheezus", "KemGus", "Golem Man", "Arend", "Mac", "Firstgamerable", "kerbal cadet", "Psycho Dog", "Ferv", "Rice", "spEAM"}

	local randomNum = random(1, 100)

	if randomNum <= 2 then
		self.Name  = rareNames[random(1, #rareNames)]
	else
		local randomPrefixes = {"John", "Bob", "Sam", "Joe", "Ben", "Alex", "Chris", "David", "Eric", "Frank", "Antonio", "Ivan", "Alexander", "Victor", "Elon", "Vladimir"}
		local randomSuffixes = {"Smith", "Johnson", "Dover", "Wang", "Kim", "Lee", "Brown", "Davis", "Evans", "Garcia", "", "Russel", "King", "Musk", "Popov"}

		local randomPrefix = randomPrefixes[random(1, #randomPrefixes)]
		local randomSuffix = randomSuffixes[random(1, #randomSuffixes)]

		self.Name  = randomPrefix .. " " .. randomSuffix
	end
end


local startPenalty = 45
local maxPenalty = 90

function ENT:Think()
	local curSeatAngle = deg(acos(self:GetUp():Dot(Vector(0, 0, 1))))
	self.AnglePenalty = clamp(remap(curSeatAngle, startPenalty, maxPenalty, 0, 1), 0, 1)

	if ACF.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACF_CheckLegal(self, self.Model, round(self.Weight, 2), nil, true, true)
		self.NextLegalCheck = ACF.Legal.NextCheck(self.legal)

	end

	local eng = self.LinkedEngine
	if not self.Legal and IsValid(eng) then
		eng:Unlink(self)
	end

	self:UpdateOverlayText()
end


function ENT:OnRemove()

	for Key in pairs(self.Master) do
		if self.Master[Key] and self.Master[Key]:IsValid() then
			self.Master[Key]:Unlink( self )
		end
	end

end

function ENT:UpdateOverlayText()
	local hp = round(self.ACF.Health / self.ACF.MaxHealth * 100)

	local str = string.format("Health: %s%%\nName: %s", hp, self.Name)

	if not self.Legal then
		str = str .. "\n\nNot legal, disabled for " .. ceil(self.NextLegalCheck - ACF.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText(str)
end


function ENT:ACF_OnDamage( Entity, Energy, FrArea, _, Inflictor, _, _ )	--This function needs to return HitRes
	self.ACF.Armour = 3
	local HitRes	= ACF_PropDamage( Entity, Energy , FrArea, 0, Inflictor ) --Calling the standard damage prop function. Angle of incidence set to 0 for more consistent damage.

	--print(math.Round(HitRes.Damage * 100))
	--print(HitRes.Loss * 100)

	--print(HitRes.Overkill)

	if HitRes.Kill or HitRes.Overkill > 1 then

		self:ConsumeCrewseats()

		return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }

	end

	return HitRes --This function needs to return HitRes

end

function ENT:ConsumeCrewseats()
    EmitSound(self.Sound, self:GetPos(), 50, CHAN_AUTO, 1, 75, 0, self.SoundPitch)

    self.Legal = false
    self.LegalIssues = "Apparently He Died"

    self:SetNoDraw( true )
    self:SetNotSolid( true )

    -- Store engine active states BEFORE marking driver as dead
    self.PreviousEngineStates = {}

    for _, Link in pairs( self.Master ) do
        if IsValid( Link ) then
            self.PreviousEngineStates[Link] = Link.Active  -- Save state
            Link.HasDriver = false
        end
    end

    local ReplaceSeat = false
    local ClosestDist = math.huge

    if next(ACE.Crewseats) then
        local ReplaceEnt = nil
        for _, SeatEnt in pairs(ACE.Crewseats) do

            if not IsValid(SeatEnt) then continue end
            if SeatEnt:CPPIGetOwner() ~= self:CPPIGetOwner() then continue end

            local Eclass = SeatEnt:GetClass()
            if Eclass ~= "ace_crewseat_loader" then continue end

            local sqDist = SeatEnt:GetPos():DistToSqr(self:GetPos())
            if sqDist < 624100 and (sqDist < ClosestDist) then
                ClosestDist = sqDist
                ReplaceEnt = SeatEnt
            end
        end

        if IsValid(ReplaceEnt) then
            ReplaceSeat = true
            self.Name = ReplaceEnt.Name
            ACF_HEKill( ReplaceEnt, VectorRand(), 0)
        end
    end

    if ReplaceSeat then
        local ReplaceTime = 5 + math.sqrt( ClosestDist ) / 39.37 * 1

        timer.Create( "CrewDie" .. self:GetCreationID(), ReplaceTime, 1, function()
            if IsValid(self) then self:ResetLinks() end
        end)
    else
        ACF_HEKill( self, VectorRand(), 0)
    end

    return ReplaceSeat
end

function ENT:ResetLinks()
    self.ACF.Health = self.ACF.MaxHealth or 1
    self.ACF.Armour = self.ACF.MaxArmour or 1
    self.NextLegalCheck = 0
    self:SetNoDraw( false )
    self:SetNotSolid( false )

    for _, Link in pairs( self.Master ) do
        if IsValid( Link ) then
            table.insert( Link.CrewLink, self )
            Link.HasDriver = true

            -- Only restore engine to active if it was previously active
            if self.PreviousEngineStates and self.PreviousEngineStates[Link] then
                Link:TriggerInput("Active", 1)
            end
        end
    end

    -- Clean up saved states
    self.PreviousEngineStates = nil
end