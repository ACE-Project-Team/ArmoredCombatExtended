AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_aps")

local function GetMountTransform(APS)
	return APS:LocalToWorld(APS.GunMountOffset), APS:LocalToWorldAngles(APS.GunMountAngle)
end

local function GetParentRoot(entity)
	local root = entity

	while IsValid(root:GetParent()) do
		root = root:GetParent()
	end

	return root
end

function ENT:Initialize()
	BaseClass.Initialize(self)
	self.Gimbal = false
	self.GunMountPending = false
	self.MountedGun = nil
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

--- Moves and parents the linked gun to the static APS tube mount.
-- @return boolean Whether a gun was mounted.
function ENT:MountLinkedGun()
	local gun = self.LinkedGun
	if not IsValid(gun) then return false end

	if IsValid(self.MountedGun) and self.MountedGun ~= gun then
		self:DetachMountedGun(self.MountedGun)
	end

	local worldPosition, worldAngle = GetMountTransform(self)
	local physics = gun:GetPhysicsObject()
	if IsValid(physics) then
		physics:EnableMotion(false)
		physics:Wake()
	end

	gun:SetParent(self)
	gun:SetLocalPos(self:WorldToLocal(worldPosition))
	gun:SetLocalAngles(self:WorldToLocalAngles(worldAngle))
	gun.acfphysparent = nil
	gun.acfphysstale = 0
	self.MountedGun = gun
	self.GunMountPending = false

	return true
end

--- Unparents a gun mounted to this APS and restores its movable physics.
-- @param gun Entity to detach.
-- @return boolean Whether the gun was attached to this APS.
function ENT:DetachMountedGun(gun)
	if not IsValid(gun) or gun:GetParent() ~= self then
		if self.MountedGun == gun then self.MountedGun = nil end
		return false
	end

	local worldPosition = gun:GetPos()
	local worldAngle = gun:GetAngles()
	gun:SetParent(nil)
	gun:SetPos(worldPosition)
	gun:SetAngles(worldAngle)

	local physics = gun:GetPhysicsObject()
	if IsValid(physics) then
		physics:EnableMotion(true)
		physics:Wake()
	end

	gun.acfphysparent = nil
	gun.acfphysstale = 0
	if self.MountedGun == gun then self.MountedGun = nil end

	return true
end

function ENT:Unlink(Target)
	local wasMounted = self.MountedGun == Target
	local success, message = BaseClass.Unlink(self, Target)

	if success and wasMounted then
		self:DetachMountedGun(Target)
	end

	return success, message
end

function ENT:Update(ArgsTable)
	local success, message = BaseClass.Update(self, ArgsTable)
	self.GunMountPending = true
	self:MountLinkedGun()

	return success, message
end

function ENT:Think()
	BaseClass.Think(self)

	if self.GunMountPending then
		self:MountLinkedGun()
	end

	return true
end

function ENT:OnRemove()
	self:DetachMountedGun(self.MountedGun)

	BaseClass.OnRemove(self)
end

--- Spawns the static APS through the shared ACE factory.
-- @param Owner Player spawning the entity.
-- @param Trace Spawn trace.
-- @param ClassName Entity class requested by the spawn menu.
-- @return Entity spawned APS, or nil when the trace misses or creation is denied.
function ENT:SpawnFunction(Owner, Trace, ClassName)
	if not Trace.Hit then return end

	local APS = ACE.MakeAPS(Owner, Trace.HitPos + Trace.HitNormal * 16, Trace.HitNormal:Angle(), ClassName or "ace_aps_static")
	if IsValid(APS) then APS:DropToFloor() end

	return APS
end

list.Set("ACFCvars", "ace_aps_static", {})
duplicator.RegisterEntityClass("ace_aps_static", function(Owner, Pos, Angle)
	return ACE.MakeAPS(Owner, Pos, Angle, "ace_aps_static")
end, "Pos", "Angle")


local function MountStaticAPS(APS)
	if IsValid(APS) and APS:GetClass() == "ace_aps_static" then
		APS.GunMountPending = true
		APS:MountLinkedGun()
	end
end

hook.Add("PlayerUnfrozeObject", "ACE_APS_StaticMountGun", function(_, entity)
	if not IsValid(entity) then return end

	local root = GetParentRoot(entity)
	local candidates = {}

	if entity:GetClass() == "ace_aps_static" then
		candidates[entity] = true
	end

	for _, constrained in pairs(constraint.GetAllConstrainedEntities(root) or {}) do
		if IsValid(constrained) and constrained:GetClass() == "ace_aps_static" then
			candidates[constrained] = true
		end
	end

	for _, APS in ipairs(ents.FindByClass("ace_aps_static")) do
		if IsValid(APS) and GetParentRoot(APS) == root then
			candidates[APS] = true
		end
	end

	for APS in pairs(candidates) do
		MountStaticAPS(APS)
	end
end)
