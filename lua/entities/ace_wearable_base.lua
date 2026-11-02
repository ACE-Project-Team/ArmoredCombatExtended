-- Pickup for an ACE wearable: spawn it, walk up and press Use to put it on.
-- Skin 1 is white, for tinting with the Color tool. Pick it, and the vest's magazines, from the context menu.

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "ACE Wearable"
ENT.Category  = "ACE - Wearables"
ENT.Spawnable = false
ENT.Slot      = nil -- Slot id from ACE.Wearables.Slots, set by each wearable

if CLIENT then return end

function ENT:SpawnFunction(Ply, Trace, ClassName)
	if not Trace.Hit then return end

	local Ent = ents.Create(ClassName)
	Ent:Spawn()
	-- The models keep the playermodel's origin at the feet, so lift by the mesh's own bottom
	Ent:SetPos(Trace.HitPos + Vector(0, 0, 2 - Ent:OBBMins().z))
	Ent:SetAngles(Angle(0, Ply:EyeAngles().y + 180, 0))
	Ent:Activate()

	return Ent
end

function ENT:Initialize()
	local Data = ACE.Wearables.Slots[self.Slot]

	self:SetModel(Data.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local Phys = self:GetPhysicsObject()
	if IsValid(Phys) then Phys:Wake() end
end

function ENT:Use(Ply)
	if not IsValid(Ply) or not Ply:IsPlayer() or not Ply:Alive() then return end

	local Data = ACE.Wearables.Slots[self.Slot]

	if ACE.Wearables.IsWearing(Ply, self.Slot) then
		ACE.SendMsg(Ply, Color(255, 255, 255), "You are already wearing a " .. self.Slot .. ".")
		return
	end

	if not Ply:LookupBone(Data.Bone) then
		ACE.SendMsg(Ply, Color(255, 0, 0), "Your playermodel has no ValveBiped skeleton to wear this on.")
		return
	end

	-- The worn model keeps the pickup's skin, Color tool tint and bodygroups (set from the context menu)
	local Bodygroups = ""
	for I = 0, self:GetNumBodyGroups() - 1 do
		Bodygroups = Bodygroups .. self:GetBodygroup(I)
	end

	ACE.Wearables.SetWearing(Ply, self.Slot, true, self:GetSkin(), self:GetColor(), Bodygroups)
	self:EmitSound("npc/combine_soldier/gear" .. math.random(1, 6) .. ".wav")
	self:Remove()
end
