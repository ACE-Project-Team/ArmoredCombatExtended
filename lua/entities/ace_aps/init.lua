AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("base_wire_entity")

local APSModel = "models/props_lab/reciever01a.mdl"
local LinkDistance = 512
local MeterToHU = 39.37
local CentimeterToHU = MeterToHU / 100

local RadarSizes = {
	["1"] = "Small",
	["2"] = "Medium",
	["3"] = "Large",
}

local APSLimits = {
	Charges = {1, 8},
	KillRange = {0.5, 30},
	ReloadTime = {0.1, 60},
	YawCoverage = {1, 180},
	PitchCoverage = {1, 90},
}

CreateConVar("sbox_max_ace_aps", 2)

local RadarClasses = {
	acf_missileradar = true,
}

local APSInputDescriptions = {
	"Enables or disables the APS scaffold.",
}

local APSOutputDescriptions = {
	"Current active state.",
	"Number of linked missile radars.",
	"Number of linked ACF guns.",
	"Whether this is the gimbal variant.",
	"Number of APS units in the network.",
	"Number of unique missile radars in the network.",
	"Number of shared target records in the network.",
	"Maximum number of guns this APS can link.",
	"Outer kill-check range in meters.",
	"Number of loaded linked guns.",
	"Configured reload time in seconds.",
	"Onboard directional radar size (1 small, 2 medium, 3 large).",
	"Horizontal half-angle coverage in degrees.",
	"Vertical half-angle coverage in degrees.",
}

local function IsAPS(ent)
	return IsValid(ent) and ent.IsAPS == true
end

local function CopyTargetData(data)
	local copy = {}

	for key, value in pairs(data or {}) do
		copy[key] = value
	end

	return copy
end

local function IsBetterTarget(candidate, current)
	if not current then return true end

	local candidatePriority = tonumber(candidate.Priority) or 0
	local currentPriority = tonumber(current.Priority) or 0

	if candidatePriority ~= currentPriority then
		return candidatePriority > currentPriority
	end

	return (tonumber(candidate.LastSeen) or 0) > (tonumber(current.LastSeen) or 0)
end

local RefreshNetworkHighlight

local function RefreshNetworkState(network)
	network.Radars = {}
	network.Targets = {}

	for member in pairs(network.Members) do
		if IsValid(member) then
				for _, radar in ipairs(member.RadarLinks or {}) do
				if IsValid(radar) then
					network.Radars[radar] = true
				end
			end

				for target, data in pairs(member.TargetReports or {}) do
				if IsValid(target) and IsBetterTarget(data, network.Targets[target]) then
					network.Targets[target] = data
				end
			end
		end
	end

	RefreshNetworkHighlight(network)
end

local function CreateNetwork(members)
	local network = {
		Members = {},
		Radars = {},
		Targets = {},
		NextKill = 0,
		EngagedThreats = {},
	}

	for _, member in ipairs(members) do
		network.Members[member] = true
		member.APSNetwork = network
	end

	RefreshNetworkState(network)
	return network
end

RefreshNetworkHighlight = function(network)
	local entities = {}

	for member in pairs(network.Members) do
		if IsValid(member) then
			entities[member] = true

				for _, gun in ipairs(member.LinkedGuns or {}) do
					if IsValid(gun) then entities[gun] = true end
				end

			for _, radar in ipairs(member.RadarLinks or {}) do
				if IsValid(radar) then
					entities[radar] = true
				end
			end

			for _, ammo in ipairs(member.AmmoLinks or {}) do
				if IsValid(ammo) then
					entities[ammo] = true
				end
			end
		end
	end

	local ids = {}
	for entity in pairs(entities) do
		ids[#ids + 1] = entity:EntIndex()
	end
	table.sort(ids)
	local encoded = table.concat(ids, ",")

	for entity in pairs(network.HighlightEntities or {}) do
		if not entities[entity] and IsValid(entity) and entity.ACEAPSNetwork == network then
			entity.ACEAPSNetwork = nil
			entity.ACEAPSNetworkEntities = nil
			entity:SetNW2String("ACEAPSNetworkEntities", "")
		end
	end

	for entity in pairs(entities) do
		entity.ACEAPSNetwork = network
		entity.ACEAPSNetworkEntities = entities
		entity:SetNW2String("ACEAPSNetworkEntities", encoded)
	end

	network.HighlightEntities = entities
end

local function EnsureAPSState(aps)
	aps.RadarLinks = aps.RadarLinks or {}
	aps.AmmoLinks = aps.AmmoLinks or {}
	aps.APSOwnedAmmoLinks = aps.APSOwnedAmmoLinks or {}
	aps.LinkedGuns = aps.LinkedGuns or {}
	aps.APSLinks = aps.APSLinks or {}
	aps.TargetReports = aps.TargetReports or {}
	aps.EngagedThreats = aps.EngagedThreats or {}
	aps.KillRange = aps.KillRange or 3
	aps.ReloadTime = aps.ReloadTime or 1
	aps.RadarSize = tostring(aps.RadarSize or "1")
	aps.YawCoverage = aps.YawCoverage or 90
	aps.PitchCoverage = aps.PitchCoverage or 45
	aps.NextKill = aps.NextKill or 0

	if not aps.APSNetwork then
		aps.APSNetwork = CreateNetwork({aps})
	end

	aps.APSNetwork.NextKill = aps.APSNetwork.NextKill or 0
	aps.APSNetwork.EngagedThreats = aps.APSNetwork.EngagedThreats or {}
end

local function GetNetworkMembers(network)
	local members = {}

	for member in pairs(network and network.Members or {}) do
		if IsValid(member) then
			table.insert(members, member)
		end
	end

	return members
end

local function MergeNetworks(first, second)
	if first == second then return first end

	local members = GetNetworkMembers(first)
	for _, member in ipairs(GetNetworkMembers(second)) do
		table.insert(members, member)
	end

	return CreateNetwork(members)
end

local function RebuildNetwork(network)
	RefreshNetworkHighlight(network)
	local remaining = {}

	for member in pairs(network and network.Members or {}) do
		if IsValid(member) then
			remaining[member] = true
		end
	end

	while next(remaining) do
		local start
		for member in pairs(remaining) do
			start = member
			break
		end

		local component = {}
		local queue = {start}
		remaining[start] = nil

		while #queue > 0 do
			local member = table.remove(queue)
			table.insert(component, member)

			for linked in pairs(member.APSLinks or {}) do
				if remaining[linked] then
					remaining[linked] = nil
					table.insert(queue, linked)
				end
			end
		end

		CreateNetwork(component)
	end
end

local function GetNetworkRadarList(network)
	local radars = {}

	for radar in pairs(network and network.Radars or {}) do
		table.insert(radars, radar)
	end

	return radars
end

local function GetNetworkTargetList(network)
	local targets = {}

	for target, data in pairs(network and network.Targets or {}) do
		table.insert(targets, {
		Entity = target,
		Data = data,
	})
	end

	table.sort(targets, function(first, second)
		return IsBetterTarget(first.Data, second.Data)
	end)

	return targets
end

local function IsLinkInRange(aps, ent)
	return aps:GetPos():DistToSqr(ent:GetPos()) <= LinkDistance * LinkDistance
end

local function IsRadar(ent)
	return IsValid(ent) and RadarClasses[ent:GetClass()] == true
end

local function IsAmmo(ent)
	return IsValid(ent) and ent:GetClass() == "acf_ammo"
end

local function NotifyPoints(aps, ent, reason)
	if ACE_PointsInputChanged and IsValid(ent) then
		ACE_PointsInputChanged({aps, ent}, reason)
	end
end

local function GetTargetState(target, data)
	local position = data and data.Position or target:GetPos()
	local velocity = data and data.Velocity

	if not velocity and target.Flight then
		velocity = target.Flight * MeterToHU
	end

	return position, velocity or vector_origin
end

local function GetGunMuzzle(gun)
	local origin = gun:LocalToWorld(gun.Muzzle or vector_origin)
	return origin, gun:GetForward()
end

local function GetRoundKillRadius(round, distance, rayLength)
	if round.Type == "FL" then
		local pelletRadius = (round.FlechetteRadius or round.Caliber or 0) * CentimeterToHU
		local spread = math.tan(math.rad(round.FlechetteSpread or 0)) * distance
		return spread + pelletRadius
	end

	local fillerMass = round.BoomFillerMass or round.FillerMass or 0
	if fillerMass > 0 and ACE.CalculateHERadius then
		return ACE.CalculateHERadius(fillerMass) * 0.75
	end

	return (round.Caliber or 0) * CentimeterToHU * 0.5
end

local function GetRoundIntercept(origin, direction, targetPosition, round, rayLength)
	local offset = targetPosition - origin
	local distance = offset:Dot(direction)
	if distance <= 0 or distance > rayLength then return end

	local closestPoint = origin + direction * distance
	local radialDistance = targetPosition:Distance(closestPoint)
	local killRadius = GetRoundKillRadius(round, distance, rayLength)
	if radialDistance > killRadius then return end

	local flechetteFraction = 1
	if round.Type == "FL" and killRadius > 0 then
		flechetteFraction = math.Clamp(1 - radialDistance / killRadius, 0.05, 1)
	end

	return closestPoint, distance, flechetteFraction
end

local function ClampAPSConfig(aps, charges, killRange, reloadTime, radarSize, yawCoverage, pitchCoverage)
	aps.Charges = math.Clamp(math.floor(tonumber(charges) or aps.Charges or 1), unpack(APSLimits.Charges))
	aps.KillRange = math.Clamp(tonumber(killRange) or aps.KillRange or 3, unpack(APSLimits.KillRange))
	aps.ReloadTime = math.Clamp(tonumber(reloadTime) or aps.ReloadTime or 1, unpack(APSLimits.ReloadTime))
	aps.RadarSize = RadarSizes[tostring(radarSize)] and tostring(radarSize) or tostring(aps.RadarSize or "1")
	aps.YawCoverage = math.Clamp(tonumber(yawCoverage) or aps.YawCoverage or 90, unpack(APSLimits.YawCoverage))
	aps.PitchCoverage = math.Clamp(tonumber(pitchCoverage) or aps.PitchCoverage or 45, unpack(APSLimits.PitchCoverage))
end

function ENT:Initialize()
	BaseClass.Initialize(self)
	self.CanUpdate = true

	self:SetModel(self.APSModel or APSModel)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local physics = self:GetPhysicsObject()
	if IsValid(physics) then
		physics:SetMass(25)
		physics:Wake()
	end

	self.IsMaster = true
	self.RadarLinks = {}
	self.AmmoLinks = {}
	self.LinkedGuns = {}
	self.APSLinks = {}
	self.TargetReports = {}
	self.KillRange = self.KillRange or 3
	ClampAPSConfig(self)
	self.NextKill = 0
	self.EngagedThreats = {}
	self.APSNetwork = CreateNetwork({self})
	self.Inputs = WireLib.CreateInputs(self, {"Active"}, APSInputDescriptions)
	self.Outputs = WireLib.CreateOutputs(self, {
		"Active",
		"Radar Count",
		"Gun Count",
		"Gimbal",
		"Network Count",
			"Network Radar Count",
			"Network Target Count",
			"Charges",
			"Kill Range",
			"Ready Guns",
			"Reload Time",
			"Radar Size",
			"Yaw Coverage",
			"Pitch Coverage",
		}, APSOutputDescriptions)
	self.Active = true
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

--- Creates an APS entity for the ACE menu and duplicator.
-- @param Owner Player who owns the entity.
-- @param Pos Vector spawn position.
-- @param Angle Angle spawn orientation.
-- @param Class string APS entity class.
-- @return Entity spawned APS, or false when creation is denied.
function ACE.MakeAPS(Owner, Pos, Angle, Class, Charges, KillRange, ReloadTime, RadarSize, YawCoverage, PitchCoverage,
	Preset)
	if not IsValid(Owner) or not Owner:CheckLimit("_ace_aps") then return false end

	local APS = ents.Create(Class)
	if not IsValid(APS) then return false end

	APS:SetPos(Pos)
	APS:SetAngles(Angle)
	APS.APSPreset = Preset or APS.APSPreset
	ClampAPSConfig(APS, Charges, KillRange, ReloadTime, RadarSize, YawCoverage, PitchCoverage)
	APS:Spawn()
	APS:Activate()
	APS:CPPISetOwner(Owner)

	Owner:AddCount("_ace_aps", APS)
	Owner:AddCleanup("acemenu", APS)

	return APS
end

--- Handles a live ACE menu update for configurable APS properties.
-- @param ArgsTable table ACE menu arguments.
-- @return boolean Whether the update succeeded.
-- @return string Update result message.
function ENT:Update(ArgsTable)
	local oldCharges = self.Charges
	ClampAPSConfig(self, ArgsTable[4], ArgsTable[5], ArgsTable[6], ArgsTable[7], ArgsTable[8], ArgsTable[9])
	if ArgsTable[10] and ArgsTable[10] ~= "" then self.APSPreset = ArgsTable[10] end

	if self.Charges < #self.LinkedGuns then
		self.Charges = oldCharges
		return false, "Unlink guns before reducing charges below the current gun count."
	end

	self:UpdateWireOutputs()
	self:UpdateOverlayText()

	return true, "APS configuration updated."
end

--- Returns whether an entity is an APS that can join this network.
-- @param Target Entity to check.
-- @return boolean Whether the target is a linkable APS.
function ENT:IsLinkableAPS(Target)
	EnsureAPSState(self)
	return IsAPS(Target) and Target ~= self
end

--- Checks whether an entity can be linked to this APS.
-- @param Target Entity to validate.
-- @return boolean Whether the link is allowed.
-- @return string|nil Failure reason.
function ENT:CanLink(Target)
	EnsureAPSState(self)

	if not IsValid(Target) then
		return false, "Invalid entity!"
	end

	if not IsLinkInRange(self, Target) then
		return false, "That entity is too far away to link!"
	end

	if IsAPS(Target) then
		EnsureAPSState(Target)

		if Target == self then
			return false, "An APS cannot link to itself!"
		end

		if self.APSLinks[Target] then
			return false, "That APS is already linked!"
		end

		return true
	end

	if IsRadar(Target) then
		for _, radar in ipairs(self.RadarLinks) do
			if radar == Target then
				return false, "That radar is already linked!"
			end
		end

		return true
	end

	if IsAmmo(Target) then
		if Target.RoundType == "Refill" then
			return false, "Refill crates cannot be linked to an APS!"
		end

		for _, ammo in ipairs(self.AmmoLinks) do
			if ammo == Target then
				return false, "That ammo crate is already linked!"
			end
		end

		return true
	end

	if Target:GetClass() == "acf_gun" then
		if #self.LinkedGuns >= (self.Charges or 1) then
			return false, "This APS has no remaining gun charges!"
		end

		return true
	end

	return false, "APS can only link to missile radars, ammo crates, or an ACF gun!"
end

--- Links another APS, missile radar, or gun to this APS.
-- @param Target Entity to link.
-- @return boolean Whether the link succeeded.
-- @return string Result or failure message.
function ENT:Link(Target)
	EnsureAPSState(self)
	if IsAPS(Target) then EnsureAPSState(Target) end

	local canLink, message = self:CanLink(Target)
	if not canLink then
		return false, message
	end

	if IsRadar(Target) then
		table.insert(self.RadarLinks, Target)
	elseif IsAmmo(Target) then
		local linkedGuns = {}
		for _, gun in ipairs(self.LinkedGuns) do
			if IsValid(gun) and not table.HasValue(gun.AmmoLink or {}, Target) then
				local linked, linkMessage = gun:Link(Target)
				if not linked then
					for _, linkedGun in ipairs(linkedGuns) do
						linkedGun:Unlink(Target)
						if self.APSOwnedAmmoLinks[linkedGun] then
							self.APSOwnedAmmoLinks[linkedGun][Target] = nil
						end
					end
					return false, linkMessage or "A linked gun rejected that ammo crate!"
				end
				table.insert(linkedGuns, gun)
				self.APSOwnedAmmoLinks[gun] = self.APSOwnedAmmoLinks[gun] or {}
				self.APSOwnedAmmoLinks[gun][Target] = true
			end
		end

		table.insert(self.AmmoLinks, Target)
	elseif Target:GetClass() == "acf_gun" then
		table.insert(self.LinkedGuns, Target)

		local linkedAmmo = {}
		for _, ammo in ipairs(self.AmmoLinks) do
			if IsValid(ammo) and not table.HasValue(Target.AmmoLink or {}, ammo) then
				local linked, linkMessage = Target:Link(ammo)
				if not linked then
					for _, linkedEntity in ipairs(linkedAmmo) do
						Target:Unlink(linkedEntity)
						if self.APSOwnedAmmoLinks[Target] then
							self.APSOwnedAmmoLinks[Target][linkedEntity] = nil
						end
					end
					table.remove(self.LinkedGuns)
					return false, linkMessage or "The linked gun rejected an APS ammo crate!"
				end

				table.insert(linkedAmmo, ammo)
				self.APSOwnedAmmoLinks[Target] = self.APSOwnedAmmoLinks[Target] or {}
				self.APSOwnedAmmoLinks[Target][ammo] = true
			end
		end
	elseif IsAPS(Target) then
		self.APSLinks[Target] = true
		Target.APSLinks[self] = true
		MergeNetworks(self.APSNetwork, Target.APSNetwork)
	end

	RefreshNetworkState(self.APSNetwork)
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
	NotifyPoints(self, Target, "aps-link")

	return true, "Link successful!"
end

--- Removes a linked APS, missile radar, or gun from this APS.
-- @param Target Entity to unlink.
-- @return boolean Whether the unlink succeeded.
-- @return string Result or failure message.
function ENT:Unlink(Target)
	EnsureAPSState(self)
	if IsAPS(Target) then EnsureAPSState(Target) end

	local removed = false

	for index = #self.RadarLinks, 1, -1 do
		if self.RadarLinks[index] == Target then
			table.remove(self.RadarLinks, index)
			removed = true
		end
	end

	for index = #self.AmmoLinks, 1, -1 do
		if self.AmmoLinks[index] == Target then
			table.remove(self.AmmoLinks, index)
			for _, gun in ipairs(self.LinkedGuns) do
				local owned = self.APSOwnedAmmoLinks[gun] and self.APSOwnedAmmoLinks[gun][Target]
				if IsValid(gun) and owned and table.HasValue(gun.AmmoLink or {}, Target) then
					gun:Unlink(Target)
				end
				if self.APSOwnedAmmoLinks[gun] then self.APSOwnedAmmoLinks[gun][Target] = nil end
			end
			removed = true
		end
	end

	for index = #self.LinkedGuns, 1, -1 do
		if self.LinkedGuns[index] == Target then
			for _, ammo in ipairs(self.AmmoLinks) do
				local owned = self.APSOwnedAmmoLinks[Target] and self.APSOwnedAmmoLinks[Target][ammo]
				if IsValid(Target) and owned and table.HasValue(Target.AmmoLink or {}, ammo) then
					Target:Unlink(ammo)
				end
			end
			self.APSOwnedAmmoLinks[Target] = nil

			table.remove(self.LinkedGuns, index)
			removed = true
		end
	end

	if IsAPS(Target) and self.APSLinks[Target] then
		self.APSLinks[Target] = nil
		Target.APSLinks[self] = nil
		RebuildNetwork(self.APSNetwork)
		removed = true
	end

	if not removed then
		return false, "That entity is not linked to this APS!"
	end

	if IsValid(Target) and Target.ACEAPSNetwork == self.APSNetwork and not IsAPS(Target) then
		Target.ACEAPSNetwork = nil
		Target.ACEAPSNetworkEntities = nil
		Target:SetNW2String("ACEAPSNetworkEntities", "")
	end

	RefreshNetworkState(self.APSNetwork)
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
	NotifyPoints(self, Target, "aps-unlink")

	return true, "Unlink successful!"
end

function ENT:TriggerInput(Input, Value)
	if Input ~= "Active" then return end

	self.Active = Value ~= 0
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

function ENT:UpdateWireOutputs()
	EnsureAPSState(self)

	local network = self.APSNetwork
	local networkCount = table.Count(network and network.Members or {})
	local networkRadarCount = table.Count(network and network.Radars or {})
	local networkTargetCount = table.Count(network and network.Targets or {})

	WireLib.TriggerOutput(self, "Active", self.Active and 1 or 0)
	WireLib.TriggerOutput(self, "Radar Count", #self.RadarLinks)
	WireLib.TriggerOutput(self, "Gun Count", #self.LinkedGuns)
	WireLib.TriggerOutput(self, "Gimbal", self.Gimbal and 1 or 0)
	WireLib.TriggerOutput(self, "Network Count", networkCount)
	WireLib.TriggerOutput(self, "Network Radar Count", networkRadarCount)
	WireLib.TriggerOutput(self, "Network Target Count", networkTargetCount)
	WireLib.TriggerOutput(self, "Charges", self:GetCharges())
	WireLib.TriggerOutput(self, "Kill Range", self:GetKillRangeMeters())
	WireLib.TriggerOutput(self, "Ready Guns", self:GetReadyGunCount())
	WireLib.TriggerOutput(self, "Reload Time", self.ReloadTime)
	WireLib.TriggerOutput(self, "Radar Size", tonumber(self.RadarSize) or 1)
	WireLib.TriggerOutput(self, "Yaw Coverage", self.YawCoverage)
	WireLib.TriggerOutput(self, "Pitch Coverage", self.PitchCoverage)
end

function ENT:UpdateOverlayText()
	EnsureAPSState(self)

	local gunStatus = #self.LinkedGuns .. "/" .. (self.Charges or 0)
	local variant = self.Gimbal and "Gimbal" or (self.APSPreset or "Static")
	local network = self.APSNetwork
	local networkCount = table.Count(network and network.Members or {})
	local targetCount = table.Count(network and network.Targets or {})

	self:SetOverlayText(
		"APS: " .. variant ..
		"\nStatus: " .. (self.Active and "On" or "Off") ..
		"\nRadars: " .. #self.RadarLinks ..
		"\nGuns: " .. gunStatus ..
		"\nReady guns: " .. self:GetReadyGunCount() ..
			"\nKill range: " .. math.Round(self:GetKillRangeMeters(), 2) .. " m" ..
			"\nReload: " .. math.Round(self.ReloadTime, 2) .. " s" ..
			"\nRadar: " .. (RadarSizes[self.RadarSize] or "Small") .. " directional" ..
			"\nCoverage: +/-" .. math.Round(self.YawCoverage, 1) .. " yaw, +/-" ..
				math.Round(self.PitchCoverage, 1) .. " pitch" ..
		"\nNetwork: " .. networkCount ..
		"\nShared targets: " .. targetCount
	)
end

function ENT:GetCharges()
	return self.Charges or 0
end

function ENT:GetKillRangeMeters()
	return self.KillRange or 0
end

function ENT:GetKillRange()
	return self:GetKillRangeMeters() * MeterToHU
end

function ENT:GetLinkedGuns()
	EnsureAPSState(self)
	return self.LinkedGuns
end

function ENT:GetReadyGunCount()
	local ready = 0

	for _, gun in ipairs(self.LinkedGuns or {}) do
		if IsValid(gun) and gun.Ready and gun.BulletData and gun.BulletData.Type ~= "Empty" then
			ready = ready + 1
		end
	end

	return ready
end

--- Returns whether a world position is inside the configured directional coverage envelope.
-- @param position Vector world position to test.
-- @return boolean Whether the position is covered.
function ENT:IsPositionCovered(position)
	local localPosition = self:WorldToLocal(position)
	local distance = localPosition:Length()
	if distance <= 0 or distance > self:GetKillRange() then return false end

	local angle = localPosition:Angle()
	return math.abs(math.NormalizeAngle(angle.y)) <= self.YawCoverage and
		math.abs(math.NormalizeAngle(angle.p)) <= self.PitchCoverage
end

--- Returns the current muzzle ray for a linked gun.
-- Variants override this to provide a gimbal bearing solution.
function ENT:GetGunAim(gun, targetPosition)
	local origin, direction = GetGunMuzzle(gun)
	return origin, direction, 0
end

--- Returns whether a variant can bring a gun to bear on a target.
-- @return boolean Whether the gun can engage.
-- @return number Estimated bearing time in seconds.
function ENT:CanGunEngage(_gun, _targetPosition)
	return true, 0
end

--- Applies the shared APS round-volume check to one gun and target.
function ENT:GetInterceptForGun(target, data, gun)
	if not IsValid(gun) or not gun.Ready or not gun.BulletData then return end
	if gun.BulletData.Type == "Empty" then return end

	local position = GetTargetState(target, data)
	if not self:IsPositionCovered(position) then return end
	local canEngage, bearingTime = self:CanGunEngage(gun, position)
	if not canEngage then return end

	local origin, direction, aimTime = self:GetGunAim(gun, position, data)
	if not origin then return end
	direction = direction and direction:GetNormalized() or gun:GetForward()

	local hitPosition, distance, flechetteFraction = GetRoundIntercept(origin, direction, position, gun.BulletData,
		self:GetKillRange())
	if not hitPosition then return end

	return {
		Target = target,
		Position = position,
		HitPosition = hitPosition,
		Direction = direction,
		Distance = distance,
		BearingTime = math.max(bearingTime or 0, aimTime or 0),
		FlechetteFraction = flechetteFraction,
	}
end

--- Returns the first viable linked gun for a target.
function ENT:GetInterceptForTarget(target, data)
	local best

	for index, gun in ipairs(self.LinkedGuns or {}) do
		local intercept = self:GetInterceptForGun(target, data, gun)
		if intercept and (not best or intercept.BearingTime < best.BearingTime or
			(intercept.BearingTime == best.BearingTime and index < best.GunIndex)) then
			intercept.Gun = gun
			intercept.GunIndex = index
			best = intercept
		end
	end

	return best
end

function ENT:TryEngageTarget(target, data, members)
	local now = CurTime()
	local network = self.APSNetwork
	if now < (network.NextKill or 0) or (network.EngagedThreats[target] or 0) > now then return false end

	local ownerAPS
	local intercept
	for _, member in ipairs(members or self:GetNetworkMembers()) do
		if IsValid(member) and member.Active then
			local candidate = member:GetInterceptForTarget(target, data)
			if candidate and (not intercept or candidate.BearingTime < intercept.BearingTime or
				(candidate.BearingTime == intercept.BearingTime and member:EntIndex() < ownerAPS:EntIndex())) then
				ownerAPS = member
				intercept = candidate
			end
		end
	end

	if ownerAPS ~= self or not intercept or not IsValid(intercept.Gun) then return false end

	local gun = intercept.Gun
	gun.ACE_APSLastFire = false
	gun.ACE_APSDirectHit = intercept
	gun:TriggerInput("Fire", 1)
	gun:TriggerInput("Fire", 0)
	gun.ACE_APSDirectHit = nil
	if not gun.ACE_APSLastFire then return false end

	local cooldown = math.max(self.ReloadTime or 0.1, 0.1)
	network.NextKill = now + cooldown
	network.EngagedThreats[target] = now + cooldown
	return true
end

function ENT:TrackAndEngage()
	local targets = {}
	local members = self:GetNetworkMembers()
	self._APSBatchReporting = true

	for target in pairs(ACE.ActiveMissiles or {}) do
		if IsValid(target) and self:IsPositionCovered(target:GetPos()) then
			self:ReportTarget(target, {
				Position = target:GetPos(),
				Velocity = target.Flight and target.Flight * MeterToHU or vector_origin,
				LastSeen = CurTime(),
			})
			targets[target] = true
		end
	end

	for _, radar in ipairs(self:GetNetworkRadars()) do
		local output = radar.OutputData
		for _, target in ipairs(output and output.Entities or {}) do
			if IsValid(target) then
				self:ReportTarget(target, {
					Position = target:GetPos(),
					Velocity = target.Flight and target.Flight * MeterToHU or vector_origin,
					LastSeen = CurTime(),
				})
				targets[target] = true
			end
		end
	end

	for target in pairs(self.TargetReports or {}) do
		if not targets[target] then self:ClearTargetReport(target) end
	end

	self._APSBatchReporting = nil
	self:RefreshAPSNetwork()

	for _, report in ipairs(self:GetNetworkTargets()) do
		self:TryEngageTarget(report.Entity, report.Data, members)
	end
end

--- Returns the APS units in this APS network.
-- @return table Network member entities.
function ENT:GetNetworkMembers()
	EnsureAPSState(self)
	return GetNetworkMembers(self.APSNetwork)
end

--- Returns unique missile radars linked anywhere in this APS network.
-- @return table Network radar entities.
function ENT:GetNetworkRadars()
	EnsureAPSState(self)
	return GetNetworkRadarList(self.APSNetwork)
end

--- Returns network target records ordered by priority and recency.
-- @return table Target records with Entity and Data fields.
function ENT:GetNetworkTargets()
	EnsureAPSState(self)
	return GetNetworkTargetList(self.APSNetwork)
end

--- Returns all APS-network entities for selection and visual highlighting.
-- @return table Set containing APS members, linked radars, and linked guns.
function ENT:GetNetworkEntities()
	EnsureAPSState(self)
	return self.APSNetwork.HighlightEntities or {}
end

--- Reports a target record for future network prioritization and interception.
-- @param Target Entity being reported.
-- @param Data table Optional target data, including Priority and LastSeen.
-- @return boolean Whether the report was accepted.
function ENT:ReportTarget(Target, Data)
	EnsureAPSState(self)

	if not IsValid(Target) then return false end
	if not istable(Data) then Data = {} end

	local report = CopyTargetData(Data)
	report.Priority = tonumber(report.Priority) or 0
	report.LastSeen = tonumber(report.LastSeen) or CurTime()
	report.Source = self
	self.TargetReports[Target] = report
	if not self._APSBatchReporting then
		self:RefreshAPSNetwork()
	end

	return true
end

--- Removes a locally reported target from this APS network's aggregation.
-- @param Target Entity to clear.
-- @return boolean Whether a report was removed.
function ENT:ClearTargetReport(Target)
	EnsureAPSState(self)

	if not self.TargetReports[Target] then return false end

	self.TargetReports[Target] = nil
	if not self._APSBatchReporting then
		self:RefreshAPSNetwork()
	end

	return true
end

function ENT:RefreshAPSNetwork()
	EnsureAPSState(self)
	RefreshNetworkState(self.APSNetwork)
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

function ENT:Think()
	EnsureAPSState(self)

	local networkChanged = false

	for index = #self.RadarLinks, 1, -1 do
		if not IsValid(self.RadarLinks[index]) then
			table.remove(self.RadarLinks, index)
			networkChanged = true
		end
	end

	for target in pairs(self.TargetReports) do
		if not IsValid(target) then
			self.TargetReports[target] = nil
			networkChanged = true
		end
	end

	for index = #self.LinkedGuns, 1, -1 do
		if not IsValid(self.LinkedGuns[index]) then
			table.remove(self.LinkedGuns, index)
			networkChanged = true
		end
	end

	for target, expiry in pairs(self.EngagedThreats) do
		if not IsValid(target) or expiry <= CurTime() then self.EngagedThreats[target] = nil end
	end

	for target, expiry in pairs(self.APSNetwork.EngagedThreats or {}) do
		if not IsValid(target) or expiry <= CurTime() then self.APSNetwork.EngagedThreats[target] = nil end
	end

	if networkChanged then
		RefreshNetworkState(self.APSNetwork)
	end

	self:UpdateWireOutputs()
	self:UpdateOverlayText()
	if self.Active then self:TrackAndEngage() end
	self:NextThink(CurTime() + 0.25)
	return true
end

--- Stores APS links for duplicator persistence.
function ENT:PreEntityCopy()
	EnsureAPSState(self)

	local entityIDs = {}

	for _, radar in ipairs(self.RadarLinks) do
		if IsValid(radar) then
			table.insert(entityIDs, radar:EntIndex())
		end
	end

	local gunEntityIDs = {}
	for _, gun in ipairs(self.LinkedGuns) do
		if IsValid(gun) then table.insert(gunEntityIDs, gun:EntIndex()) end
	end

	local ammoEntityIDs = {}
	for _, ammo in ipairs(self.AmmoLinks) do
		if IsValid(ammo) then
			table.insert(ammoEntityIDs, ammo:EntIndex())
		end
	end

	local apsEntityIDs = {}
	for linked in pairs(self.APSLinks) do
		if IsValid(linked) then
			table.insert(apsEntityIDs, linked:EntIndex())
		end
	end

	duplicator.StoreEntityModifier(self, "ACEAPSLinks", {
		radars = entityIDs,
		guns = gunEntityIDs,
		ammoEntities = ammoEntityIDs,
		apsEntities = apsEntityIDs,
	})
	duplicator.StoreEntityModifier(self, "ACEAPSConfig", {
		Charges = self.Charges,
		KillRange = self.KillRange,
		ReloadTime = self.ReloadTime,
		RadarSize = self.RadarSize,
		YawCoverage = self.YawCoverage,
		PitchCoverage = self.PitchCoverage,
		Preset = self.APSPreset,
	})
	BaseClass.PreEntityCopy(self)
end

--- Restores APS links after duplicator paste.
-- @param Player Player who pasted the entity.
-- @param Ent Duplicator source entity data.
-- @param CreatedEntities Entities created by the duplicator.
function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
	EnsureAPSState(self)
	local config = Ent.EntityMods and Ent.EntityMods.ACEAPSConfig
	if config then
		ClampAPSConfig(self, config.Charges, config.KillRange, config.ReloadTime, config.RadarSize,
			config.YawCoverage, config.PitchCoverage)
		self.APSPreset = config.Preset or self.APSPreset
		Ent.EntityMods.ACEAPSConfig = nil
	end

	if Ent.EntityMods and Ent.EntityMods.ACEAPSLinks then
		local links = Ent.EntityMods.ACEAPSLinks

			for _, entityID in ipairs(links.radars or {}) do
				local linked = CreatedEntities[entityID]
				if IsValid(linked) then
					self:Link(linked)
				end
			end

			for _, entityID in ipairs(links.guns or {}) do
				local linked = CreatedEntities[entityID]
				if IsValid(linked) then self:Link(linked) end
			end

		for _, entityID in ipairs(links.ammoEntities or {}) do
			local linked = CreatedEntities[entityID]
			if IsValid(linked) then
				self:Link(linked)
			end
		end

		for _, entityID in ipairs(links.apsEntities or {}) do
			local linked = CreatedEntities[entityID]
			if IsValid(linked) then
				self:Link(linked)
			end
		end

		Ent.EntityMods.ACEAPSLinks = nil
	end

	BaseClass.PostEntityPaste(self, Player, Ent, CreatedEntities)
end

function ENT:OnRemove()
	Wire_Remove(self)
	EnsureAPSState(self)
	local network = self.APSNetwork
	if network then
		RefreshNetworkHighlight(network)
		network.Members[self] = nil
	end

	for linked in pairs(self.APSLinks) do
		if IsValid(linked) then
			linked.APSLinks[self] = nil
		end
	end

	self.APSLinks = {}
	self.TargetReports = {}
	if network then
		RebuildNetwork(network)
	end
	self.APSNetwork = nil

	for _, radar in ipairs(self.RadarLinks) do
		NotifyPoints(self, radar, "aps-removed")
	end

	for _, gun in ipairs(self.LinkedGuns) do
		for _, ammo in ipairs(self.AmmoLinks) do
			local owned = self.APSOwnedAmmoLinks[gun] and self.APSOwnedAmmoLinks[gun][ammo]
			if IsValid(gun) and IsValid(ammo) and owned and table.HasValue(gun.AmmoLink or {}, ammo) then
				gun:Unlink(ammo)
			end
		end

		NotifyPoints(self, gun, "aps-removed")
	end
end
