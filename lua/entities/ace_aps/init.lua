AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("base_wire_entity")

local APSModel = "models/props_lab/reciever01a.mdl"
local LinkDistance = 512

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
	"Whether an ACF gun is linked.",
	"Whether this is the gimbal variant.",
	"Number of APS units in the network.",
	"Number of unique missile radars in the network.",
	"Number of shared target records in the network.",
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

local function RefreshNetworkState(network)
	network.Radars = {}
	network.Targets = {}

	for member in pairs(network.Members) do
		if IsValid(member) then
			for _, radar in ipairs(member.RadarLinks) do
				if IsValid(radar) then
					network.Radars[radar] = true
				end
			end

			for target, data in pairs(member.TargetReports) do
				if IsValid(target) and IsBetterTarget(data, network.Targets[target]) then
					network.Targets[target] = data
				end
			end
		end
	end
end

local function CreateNetwork(members)
	local network = {
		Members = {},
		Radars = {},
		Targets = {},
	}

	for _, member in ipairs(members) do
		network.Members[member] = true
		member.APSNetwork = network
	end

	RefreshNetworkState(network)
	return network
end

local function EnsureAPSState(aps)
	aps.RadarLinks = aps.RadarLinks or {}
	aps.APSLinks = aps.APSLinks or {}
	aps.TargetReports = aps.TargetReports or {}

	if not aps.APSNetwork then
		aps.APSNetwork = CreateNetwork({aps})
	end
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

			for linked in pairs(member.APSLinks) do
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

local function NotifyPoints(aps, ent, reason)
	if ACE_PointsInputChanged and IsValid(ent) then
		ACE_PointsInputChanged({aps, ent}, reason)
	end
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
	self.LinkedGun = nil
	self.APSLinks = {}
	self.TargetReports = {}
	self.APSNetwork = CreateNetwork({self})
	self.Inputs = WireLib.CreateInputs(self, {"Active"}, APSInputDescriptions)
	self.Outputs = WireLib.CreateOutputs(self, {
		"Active",
		"Radar Count",
		"Gun Linked",
		"Gimbal",
		"Network Count",
		"Network Radar Count",
		"Network Target Count",
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
function ACE.MakeAPS(Owner, Pos, Angle, Class)
	if not IsValid(Owner) or not Owner:CheckLimit("_ace_aps") then return false end

	local APS = ents.Create(Class)
	if not IsValid(APS) then return false end

	APS:SetPos(Pos)
	APS:SetAngles(Angle)
	APS:Spawn()
	APS:Activate()
	APS:CPPISetOwner(Owner)

	Owner:AddCount("_ace_aps", APS)
	Owner:AddCleanup("acemenu", APS)

	return APS
end

--- Handles an ACE menu update for an APS entity.
-- @param _ArgsTable table Reserved update arguments from the ACE menu.
-- @return boolean Always true; APS properties are not configurable yet.
-- @return string Update result message.
function ENT:Update(_ArgsTable)
	return true, "APS properties are not configurable yet."
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

	if Target:GetClass() == "acf_gun" then
		if IsValid(self.LinkedGun) then
			return false, "This APS can only link to one gun!"
		end

		return true
	end

	return false, "APS can only link to missile radars or an ACF gun!"
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
	elseif Target:GetClass() == "acf_gun" then
		self.LinkedGun = Target
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

	if self.LinkedGun == Target then
		self.LinkedGun = nil
		removed = true
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
	WireLib.TriggerOutput(self, "Gun Linked", IsValid(self.LinkedGun) and 1 or 0)
	WireLib.TriggerOutput(self, "Gimbal", self.Gimbal and 1 or 0)
	WireLib.TriggerOutput(self, "Network Count", networkCount)
	WireLib.TriggerOutput(self, "Network Radar Count", networkRadarCount)
	WireLib.TriggerOutput(self, "Network Target Count", networkTargetCount)
end

function ENT:UpdateOverlayText()
	EnsureAPSState(self)

	local gunStatus = IsValid(self.LinkedGun) and "Linked" or "Not linked"
	local variant = self.Gimbal and "Gimbal" or "Static"
	local network = self.APSNetwork
	local networkCount = table.Count(network and network.Members or {})
	local targetCount = table.Count(network and network.Targets or {})

	self:SetOverlayText(
		"APS: " .. variant ..
		"\nStatus: " .. (self.Active and "On" or "Off") ..
		"\nRadars: " .. #self.RadarLinks ..
		"\nGun: " .. gunStatus ..
		"\nNetwork: " .. networkCount ..
		"\nShared targets: " .. targetCount
	)
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
	RefreshNetworkState(self.APSNetwork)
	self:UpdateWireOutputs()
	self:UpdateOverlayText()

	return true
end

--- Removes a locally reported target from this APS network's aggregation.
-- @param Target Entity to clear.
-- @return boolean Whether a report was removed.
function ENT:ClearTargetReport(Target)
	EnsureAPSState(self)

	if not self.TargetReports[Target] then return false end

	self.TargetReports[Target] = nil
	RefreshNetworkState(self.APSNetwork)
	self:UpdateWireOutputs()
	self:UpdateOverlayText()

	return true
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

	if not IsValid(self.LinkedGun) then
		self.LinkedGun = nil
	end

	if networkChanged then
		RefreshNetworkState(self.APSNetwork)
	end

	self:UpdateWireOutputs()
	self:UpdateOverlayText()
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

	if IsValid(self.LinkedGun) then
		table.insert(entityIDs, self.LinkedGun:EntIndex())
	end

	local apsEntityIDs = {}
	for linked in pairs(self.APSLinks) do
		if IsValid(linked) then
			table.insert(apsEntityIDs, linked:EntIndex())
		end
	end

	duplicator.StoreEntityModifier(self, "ACEAPSLinks", {
		entities = entityIDs,
		apsEntities = apsEntityIDs,
	})
	BaseClass.PreEntityCopy(self)
end

--- Restores APS links after duplicator paste.
-- @param Player Player who pasted the entity.
-- @param Ent Duplicator source entity data.
-- @param CreatedEntities Entities created by the duplicator.
function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
	EnsureAPSState(self)

	if Ent.EntityMods and Ent.EntityMods.ACEAPSLinks then
		local links = Ent.EntityMods.ACEAPSLinks

		for _, entityID in ipairs(links.entities or {}) do
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

	if IsValid(self.LinkedGun) then
		NotifyPoints(self, self.LinkedGun, "aps-removed")
	end
end
