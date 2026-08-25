
AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "Debris"

cleanup.Register( "Debris" )

if CLIENT then return end

function ENT:Initialize()

	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup( COLLISION_GROUP_WORLD )

	local phys = self:GetPhysicsObject()

	if IsValid( phys ) then

		phys:Wake()
		phys:SetMaterial("jeeptire")

	end

	if ACE.DebrisLifeTime > 0 then
		timer.Simple(ACE.DebrisLifeTime, function()
			if IsValid(self) then
				self:Remove()
			end
		end)
	end
end

