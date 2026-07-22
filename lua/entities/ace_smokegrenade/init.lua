AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")


function ENT:Initialize()
	self:SetModel("models/weapons/w_eq_smokegrenade.mdl")
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionBounds(Vector(-2, -2, -2) , Vector(2, 2, 2))
	self:SetMoveType(MOVETYPE_FLYGRAVITY);
	self:PhysicsInit(MOVECOLLIDE_FLY_CUSTOM);
	self:SetUseType(SIMPLE_USE);


	local phys = self:GetPhysicsObject()
	phys:SetMass(5)

	self.FuseTime = 4
	self.phys = phys
	self.LastTime = CurTime()
	if (IsValid(phys)) then
		phys:Wake()
		phys:SetBuoyancyRatio(5)
		phys:SetDragCoefficient(0)
		phys:SetDamping(0, 8)
		phys:SetMaterial("grenade")
	end
end

local function MakeSmoke(size, pos, dir)
	local Flash = EffectData()
	Flash:SetOrigin(pos + Vector(0,0,10))
	--Flash:SetNormal(Vector(0, 0, 1))
	Flash:SetNormal(dir)
	Flash:SetRadius(size ^ 0.33)
	Flash:SetMagnitude((size ^ 0.33) * 0.5)

	Flash:SetStart(Vector(200, 200, 200))
	util.Effect("ACE_Smoke", Flash) --In all honesty we're probably going to need a seperate smoke effect.
end

function ENT:Think()

	local curtime = CurTime()
	self.FuseTime = self.FuseTime-(curtime-self.LastTime)
	self.LastTime = CurTime()

	if self.FuseTime < 0 then

		self:Remove()

		local pos = self:GetPos()
		MakeSmoke(25, pos,Vector(1, 0, 0))
		MakeSmoke(25, pos,Vector(-1, 0, 0))
		MakeSmoke(25, pos,Vector(0, 1, 0))
		MakeSmoke(25, pos,Vector(0, -1, 0))
		MakeSmoke(25, pos,Vector(1, -1, 0))
		MakeSmoke(25, pos,Vector(-1, 1, 0))
		MakeSmoke(25, pos,Vector(1, 1, 0))
		MakeSmoke(25, pos,Vector(-1, -1, 0))
		--timer.Simple(1, function() MakeSmoke(10, pos) end)
		--timer.Simple(4, function() MakeSmoke(10, pos) end)
		--timer.Simple(7, function() MakeSmoke(5, pos) end)
		--timer.Simple(10, function() MakeSmoke(5, pos) end)

		sound.Play("weapons/smokegrenade/sg_explode.wav", self:GetPos())
	end
end
