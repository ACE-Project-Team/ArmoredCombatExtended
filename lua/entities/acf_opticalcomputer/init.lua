AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:SpawnFunction( _, trace )

	if not trace.Hit then return end

	local SPos = (trace.HitPos + Vector(0, 0, 1))

	local ent = ents.Create( "acf_opticalcomputer" )
	ent:SetPos( SPos )
	ent:Spawn()
	ent:Activate()

	return ent
end

function MakeACE_OpticalComputer(Owner, Pos, Angle, _Id)
	if IsValid(Owner) and not Owner:CheckLimit("_acf_opticalcomputer") then return false end
	local ent = ents.Create("acf_opticalcomputer")
	if not IsValid(ent) then return false end
	ent:SetPos(Pos)
	ent:SetAngles(Angle)
	ent:Spawn()
	ent:Activate()
	if IsValid(Owner) then
		ent:CPPISetOwner(Owner)
		Owner:AddCount("_acf_opticalcomputer", ent)
		Owner:AddCleanup("acfmenu", ent)
	end
	return ent
end
list.Set("ACFCvars", "acf_opticalcomputer", {"id"})
duplicator.RegisterEntityClass("acf_opticalcomputer", MakeACE_OpticalComputer, "Pos", "Angle", "Id")

function ENT:Initialize()

	self:SetModel( "models/props_lab/monitor01b.mdl" )
	self:SetMoveType(MOVETYPE_VPHYSICS);
	self:PhysicsInit(SOLID_VPHYSICS);
	self:SetUseType(SIMPLE_USE);
	self:SetSolid(SOLID_VPHYSICS);

	self.Weight = 65
	self:GetPhysicsObject():SetMass(self.Weight)


end



function ENT:Think()
end












