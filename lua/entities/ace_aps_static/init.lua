AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_aps")

local function GetParentRoot(entity)
	local root = entity
	while IsValid(root:GetParent()) do root = root:GetParent() end
	return root
end

function ENT:Initialize()
	BaseClass.Initialize(self)
	self.Gimbal = false
	self.GunMountPending = false
	self.MountedGuns = {}
	self:UpdateTubeBodygroup()
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

function ENT:GetGunAim(gun)
	local origin = gun:LocalToWorld(gun.Muzzle or vector_origin)
	return origin, gun:GetForward(), 0
end

--- Shows the Zaslin tube while at least one linked gun has a round loaded.
function ENT:UpdateTubeBodygroup()
	local loaded = false
	for _, gun in ipairs(self.LinkedGuns or {}) do
		if IsValid(gun) and gun.BulletData and gun.BulletData.Type ~= "Empty" then
			loaded = true
			break
		end
	end

	local submodel = loaded and self.TubeLoadedSubmodel or self.TubeEmptySubmodel
	if self.TubeLoaded == loaded and self:GetBodygroup(self.TubeBodygroup) == submodel then return end

	self:SetBodygroup(self.TubeBodygroup, submodel)
	self.TubeLoaded = loaded
end

function ENT:MountLinkedGuns()
	local active = {}
	for _, gun in ipairs(self.LinkedGuns or {}) do
		if IsValid(gun) then
			local physics = gun:GetPhysicsObject()
			if IsValid(physics) then
				physics:EnableMotion(false)
				physics:Wake()
			end

			gun:SetParent(self)
			gun:SetLocalPos(self.GunMountOffset)
			gun:SetLocalAngles(self.GunMountAngle)
			gun.acfphysparent = nil
			gun.acfphysstale = 0
			active[gun] = true
			self.MountedGuns[gun] = true
		end
	end

	for gun in pairs(self.MountedGuns or {}) do
		if not active[gun] and IsValid(gun) and gun:GetParent() == self then
			self:DetachMountedGun(gun)
		end
		if not IsValid(gun) then self.MountedGuns[gun] = nil end
	end

	self.GunMountPending = false
	self:UpdateTubeBodygroup()
	return next(active) ~= nil
end

function ENT:DetachMountedGun(gun)
	if not IsValid(gun) or gun:GetParent() ~= self then
		self.MountedGuns[gun] = nil
		return false
	end

	local position, angle = gun:GetPos(), gun:GetAngles()
	gun:SetParent(nil)
	gun:SetPos(position)
	gun:SetAngles(angle)

	local physics = gun:GetPhysicsObject()
	if IsValid(physics) then
		physics:EnableMotion(true)
		physics:Wake()
	end

	gun.acfphysparent = nil
	gun.acfphysstale = 0
	self.MountedGuns[gun] = nil
	return true
end

function ENT:Link(target)
	local success, message = BaseClass.Link(self, target)
	if success and target:GetClass() == "acf_gun" then
		self.GunMountPending = true
		self:MountLinkedGuns()
	end
	return success, message
end

function ENT:Unlink(target)
	local success, message = BaseClass.Unlink(self, target)
	if success then self:DetachMountedGun(target) end
	return success, message
end

function ENT:Update(args)
	local success, message = BaseClass.Update(self, args)
	self.GunMountPending = true
	self:MountLinkedGuns()
	return success, message
end

function ENT:Think()
	BaseClass.Think(self)
	self:UpdateTubeBodygroup()
	if self.GunMountPending then self:MountLinkedGuns() end
	self:NextThink(CurTime() + 0.05)
	return true
end

function ENT:OnRemove()
	for gun in pairs(self.MountedGuns or {}) do self:DetachMountedGun(gun) end
	BaseClass.OnRemove(self)
end

function ENT:SpawnFunction(owner, trace, className)
	if not trace.Hit then return end
	local aps = ACE.MakeAPS(owner, trace.HitPos + trace.HitNormal * 16, trace.HitNormal:Angle(), className or "ace_aps_static")
	if IsValid(aps) then aps:DropToFloor() end
	return aps
end

list.Set("ACFCvars", "ace_aps_static", {"data1", "data2", "data3", "data4", "data5", "data6", "data7"})
duplicator.RegisterEntityClass("ace_aps_static", function(owner, pos, angle, charges, killRange, reloadTime,
	radarSize, yawCoverage, pitchCoverage, preset)
	return ACE.MakeAPS(owner, pos, angle, "ace_aps_static", charges, killRange, reloadTime, radarSize,
		yawCoverage, pitchCoverage, preset)
end, "Pos", "Angle", "Charges", "KillRange", "ReloadTime", "RadarSize", "YawCoverage", "PitchCoverage",
	"APSPreset")

local function MountStaticAPS(aps)
	if IsValid(aps) then
		aps.GunMountPending = true
		aps:MountLinkedGuns()
	end
end

hook.Add("PlayerUnfrozeObject", "ACE_APS_StaticMountGun", function(_, entity)
	if not IsValid(entity) then return end

	local root = GetParentRoot(entity)
	local candidates = {}
	if entity:GetClass() == "ace_aps_static" then candidates[entity] = true end

	for constrained in pairs(constraint.GetAllConstrainedEntities(root) or {}) do
		if IsValid(constrained) and constrained:GetClass() == "ace_aps_static" then
			candidates[constrained] = true
		end
	end

	for _, aps in ipairs(ents.FindByClass("ace_aps_static")) do
		if IsValid(aps) and GetParentRoot(aps) == root then candidates[aps] = true end
	end

	for aps in pairs(candidates) do MountStaticAPS(aps) end
end)
