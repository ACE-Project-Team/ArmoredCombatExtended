AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_aps")

function ENT:Initialize()
	BaseClass.Initialize(self)
	self.Gimbal = true
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
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
