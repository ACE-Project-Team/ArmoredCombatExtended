AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_aps")

function ENT:Initialize()
	BaseClass.Initialize(self)
	self.Gimbal = true
	self.GimbalAim = {}
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

function ENT:CanGunEngage(_gun, targetPosition)
	local direction = (targetPosition - self:GetPos()):GetNormalized()
	local localAngles = self:WorldToLocalAngles(direction:Angle())
	local yaw = math.abs(math.AngleDifference(localAngles.y, 0))
	local pitch = math.abs(math.AngleDifference(localAngles.p, 0))

	return yaw <= (self.YawRadius or 90) and pitch <= (self.PitchRadius or 45), 0
end

function ENT:GetGunAim(gun, targetPosition)
	local desired = (targetPosition - gun:GetPos()):Angle()
	local current = self.GimbalAim[gun] or gun:GetAngles()
	local step = (self.SlewRate or 180) * 0.05

	current.p = math.ApproachAngle(current.p, desired.p, step)
	current.y = math.ApproachAngle(current.y, desired.y, step)
	current.r = desired.r
	self.GimbalAim[gun] = current
	gun:SetAngles(current)

	local origin = gun:LocalToWorld(gun.Muzzle or vector_origin)
	local direction = gun:GetForward()
	local error = math.abs(math.AngleDifference(current.y, desired.y)) + math.abs(math.AngleDifference(current.p, desired.p))
	local bearingTime = error / math.max(self.SlewRate or 180, 1)
	if error > (self.AimCone or 2) then return origin, direction, bearingTime + 1 end

	return origin, direction, bearingTime
end

--- Spawns the gimbal APS through the shared ACE factory.
-- @param Owner Player spawning the entity.
-- @param Trace Spawn trace.
-- @param ClassName Entity class requested by the spawn menu.
-- @return Entity spawned APS, or nil when the trace misses or creation is denied.
function ENT:SpawnFunction(Owner, Trace, ClassName)
	if not Trace.Hit then return end

	local APS = ACE.MakeAPS(Owner, Trace.HitPos + Trace.HitNormal * 16, Trace.HitNormal:Angle(), ClassName or "ace_aps_gimbal")
	if IsValid(APS) then APS:DropToFloor() end

	return APS
end

list.Set("ACFCvars", "ace_aps_gimbal", {})
duplicator.RegisterEntityClass("ace_aps_gimbal", function(Owner, Pos, Angle)
	return ACE.MakeAPS(Owner, Pos, Angle, "ace_aps_gimbal")
end, "Pos", "Angle")
