AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")


function ENT:Initialize()

	self:SetModel( "models/weapons/w_slam.mdl" )
	self:SetMoveType(MOVETYPE_VPHYSICS);
	self:PhysicsInit(SOLID_VPHYSICS);
	self:SetUseType(SIMPLE_USE);
	self:SetSolid(SOLID_VPHYSICS);
	local phys = self:GetPhysicsObject()
	phys:SetMass(0.5) --4.1 kg mine, round down.
	self:DrawShadow( false )
--	self:SetMaterial( "models/props_canal/metalwall005b" )

	self.TimeVar = 1
	self.phys = phys
	self.LastTime = 0

	if ( IsValid( phys ) ) then phys:Wake() end

	self.phys:EnableMotion(false)
	self:SetBodygroup( 0, 1 )

	self.Range = 3000 --Max range of beam

	self.SpawnTime = CurTime()

	self.Enabled = false

	self.Triggered = false
end

function ENT:Boom()
	local HEWeight = 0.25
	local Radius = HEWeight ^ 0.33 * 8 * 39.37

	ACE_HE(self:GetPos(), Vector(0, 0, 1), HEWeight, HEWeight * 0.5, self.DamageOwner, nil, self) --0.5 is standard antipersonal mine

	local Flash = EffectData()
		Flash:SetOrigin( self:GetPos() )
		Flash:SetNormal( Vector(0, 0, -1) )
		Flash:SetRadius( math.Round(math.max(Radius / 39.37, 1),2) )
	util.Effect( "ACE_Scaled_Explosion", Flash )


	self.FakeCrate = ents.Create("acf_fakecrate2")
	self.FakeCrate:RegisterTo(self.Bulletdata)
	self.Bulletdata["Crate"] = self.FakeCrate:EntIndex()
	self:DeleteOnRemove(self.FakeCrate)

	self.Bulletdata["Flight"] = self:GetUp():GetNormalized() * self.Bulletdata["MuzzleVel"] * 39.37

	self.Bulletdata.Pos = self:GetPos() + self:GetUp() * 2

	self.CreateShell = ACE.RoundTypes[self.Bulletdata.Type].create
	self:CreateShell( self.Bulletdata )
end

function ENT:OnRemove()
	if CLIENT then return end

	if self.Triggered then
		self:Boom()
	end
end

function ENT:Think()
	if CurTime() - self.SpawnTime < 2.5 then
		return
	elseif not self.Enabled then
		self:EmitSound("buttons/blip2.wav")

		self.Enabled = true
	end

	local forward = self:GetUp()

	local triggerRangerT = util.TraceHull( {
		start = self:GetPos() + forward * 60,
		endpos = self:GetPos() + forward * self.Range,
		ignoreworld  = true,
		mins = Vector( -30, -30, -30 ),
		maxs = Vector( 30, 30, 30 ),
		mask = MASK_SHOT_HULL
	} )

	local triggerRanger = util.TraceHull( {
		start = self:GetPos() + forward * 60,
		endpos = self:GetPos() + forward * 300,
		ignoreworld  = true,
		mins = Vector( -30, -30, -30 ),
		maxs = Vector( 30, 30, 30 ),
		mask = MASK_SHOT_HULL
	} )

	if (triggerRanger.Hit or (triggerRangerT.Hit and (triggerRangerT.Entity:GetClass() ~= "player"))) and not self.Triggered then
		self.Triggered = true

		timer.Simple(self.ExplosionDelay, function()
			if not IsValid(self) then return end

			self:Remove()
			self:Boom()
		end)
	end
end
