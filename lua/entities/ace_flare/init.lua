AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

ACE.CMTable = ACE.CMTable or {} -- Keep track of all countermeasures for radars

function ENT:Initialize()

	self:SetModel( "models/Items/AR2_Grenade.mdl" )
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetGravity( 0.01 )
	--self:SetNoDraw(true)

	self.Thermal		= self.Thermal or 1
	self.FirstThermal	= self.FirstThermal or 1
	self.Life		= self.Life or 0.1
	self.RadarSig   = self.RadarSig or 1
	self.FirstRadarSig = self.RadarSig

	self.FirstTime = ACE.CurTime

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetMass(3)
		phys:EnableDrag( true )
		phys:SetDragCoefficient( 120 )
		phys:SetBuoyancyRatio( 2 )
		phys:Wake()
	end

	timer.Simple(self.Life, function()
		if IsValid(self) then
			self:Remove()
		end
	end)

	self:SetRenderMode( RENDERMODE_TRANSCOLOR )


	ACE.CMTable[self] = true

	self:CallOnRemove( "ACEFlareRemove", function(ent)
		ACE.CMTable[ent] = nil
	end )

	table.insert( ACE.contraptionEnts, self )
end

function ENT:Think()

	if self:WaterLevel() == 3 then
		self.Thermal = 0
		self:StopParticles()

		return false
	end

	local AliveTime = (ACE.CurTime - self.FirstTime)
	local EffectivenessMul = (1 - (AliveTime / self.Life))
	self.Thermal = self.FirstThermal * EffectivenessMul
	self.RadarSig = self.FirstRadarSig * EffectivenessMul
	--print(self.Thermal)
	--print(self.RadarSig)

	self:NextThink( CurTime() + 0.2 )
	return true
end

function ENT:PhysicsCollide( Table )

	local HitEnt = Table.HitEntity

	if not IsValid(HitEnt) then return end

	if HitEnt:IsNPC() or (HitEnt:IsPlayer() and not HitEnt:HasGodMode()) then
		if vFireInstalled then
			CreateVFireEntFires(HitEnt, 3)
		else
			HitEnt:Ignite( self.Thermal, 1 )
		end
	end
end

function ENT:CanTool()
	return false
end
