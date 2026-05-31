AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("base_wire_entity")

local Sustain = ACE.Sustain

local COLLECTOR_MODEL = "models/props_trainstation/mount_connection001a.mdl"

-- Grid nodes a collector can pick up from (catenary / third rail / substation).
local PICKUP = {
	ace_transfer_station = true,
	ace_power_line       = true,
	ace_transformer      = true,
	ace_capacitor        = true,
}

function ENT:Initialize()
	self.Battery    = nil      -- the vehicle's Electric battery we charge
	self.Source     = nil      -- cached nearby energized station
	self.NextScan   = 0
	self.Throughput = 0
	self.Connected  = false
	self.Legal      = true

	self:SetModel(COLLECTOR_MODEL)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
	})
	self.Outputs = WireLib.CreateOutputs(self, {
		"Connected (1 when picking up power) [NORMAL]",
		"Throughput (kW) [NORMAL]",
		"Voltage (V the tapped line is carrying) [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)

	self.Active = true
end

function ENT:SpawnFunction(ply, tr)
	if not tr or not tr.Hit then return end
	return MakeACE_PowerCollector(ply, tr.HitPos + tr.HitNormal * 8, Angle(0, IsValid(ply) and ply:EyeAngles().yaw or 0, 0), "PowerCollector")
end

-- Menu/dupe spawn factory.
function MakeACE_PowerCollector(Owner, Pos, Angle, Id)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_power_collector") then return false end
	local ent = ents.Create("ace_power_collector")
	if not IsValid(ent) then return false end
	ent:SetPos(Pos)
	ent:SetAngles(Angle)
	ent:Spawn()
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(true) end
	if IsValid(Owner) then
		ent:CPPISetOwner(Owner)
		Owner:AddCount("_ace_power_collector", ent)
		Owner:AddCleanup("acfmenu", ent)
	end
	return ent
end

list.Set("ACFCvars", "ace_power_collector", {"id"})
duplicator.RegisterEntityClass("ace_power_collector", MakeACE_PowerCollector, "Pos", "Angle", "Id")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if Target:GetClass() ~= "acf_fueltank" then return false, "Link the vehicle's Electric battery!" end
	if Target.FuelType ~= "Electric" then return false, "Collectors only charge Electric batteries!" end
	self.Battery = Target
	self:UpdateOverlayText()
	return true, "Battery linked - collector will feed it from the grid."
end

function ENT:Unlink(Target)
	if IsValid(Target) and Target == self.Battery then
		self.Battery = nil
		self:UpdateOverlayText()
		return true, "Unlink successful!"
	end
	return false, "That entity is not linked!"
end

-- Find the nearest energized source station in range. Scanned on a slow timer
-- (not every think) so a yard full of trams doesn't hammer the server.
-- Distance from `pos` to the CLOSEST point on `ent` (its bounding box), not its
-- center - so a long scalable power line counts as "in range" when any part of
-- the catenary is near the collector, instead of only when its midpoint is.
local function nodeDistance(ent, pos)
	local np = ent.NearestPoint and ent:NearestPoint(pos)
	if np then return np:Distance(pos) end
	return ent:WorldSpaceCenter():Distance(pos)
end

function ENT:FindSource()
	local range = ACF.GridCollectorRange or 400
	local pos   = self:WorldSpaceCenter()
	local best, bestDist

	-- FindInSphere uses centers, so widen the search a bit; the precise
	-- closest-point test below decides what actually counts as in range.
	for _, ent in ipairs(ents.FindInSphere(pos, range * 4)) do
		if not PICKUP[ent:GetClass()] then continue end
		if not Sustain.GridHasSource(ent) then continue end
		local d = nodeDistance(ent, pos)
		if d <= range and (not bestDist or d < bestDist) then best, bestDist = ent, d end
	end
	return best
end

function ENT:TriggerInput(iname, value)
	if iname == "Active" then self.Active = value ~= 0 end
end

function ENT:UpdateOverlayText()
	local txt = "Power Collector (grid pickup)"
	local status
	if not IsValid(self.Battery) then
		status = "No battery linked (link the vehicle's Electric battery)"
	elseif not self.Battery.Active then
		status = "Battery INACTIVE - wire its Active to 1 to accept charge"
	elseif not self.Active then
		status = "Collector off"
	elseif self.Connected then
		status = "PICKING UP  " .. math.Round(self.Throughput or 0, 1) .. " kW @ " .. math.Round(self.Voltage or 0, 0) .. " V  (wire " .. math.Round(self.SourceDist or 0, 0) .. "u)"
	elseif self.FoundSource then
		status = "Live line in range but no power flowing (battery full, or source/rate limited)"
	else
		status = "No grid in range (within " .. (ACF.GridCollectorRange or 400) .. "u of a LIVE station/transformer/wire)"
	end
	txt = txt .. "\nBattery: " .. (IsValid(self.Battery) and "linked" or "MISSING")
	txt = txt .. "\n" .. status
	self:SetOverlayText(txt)
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or 0.25
	self.LastThink = CurTime()
	self.Throughput  = 0
	self.Connected   = false
	self.FoundSource = false   -- a live line is in range (even if we can't charge into it)
	self.SourceDist  = -1      -- distance to the node we're drawing from (E2/SF), -1 = none
	self.Voltage     = 0       -- voltage of the line we're tapping

	if self.Active and IsValid(self.Battery) then
		-- Re-scan for a station only every half second; otherwise reuse the
		-- cached one as long as it's still valid, energized and in range.
		local range = ACF.GridCollectorRange or 400
		local src   = self.Source
		local okCached = IsValid(src)
			and nodeDistance(src, self:WorldSpaceCenter()) <= range
			and Sustain.GridHasSource(src)

		if not okCached and CurTime() >= self.NextScan then
			self.Source = self:FindSource()
			self.NextScan = CurTime() + 0.5
			src = self.Source
		end

		if IsValid(src) and Sustain.GridHasSource(src) then
			self.FoundSource = true
			self.SourceDist = nodeDistance(src, self:WorldSpaceCenter())
			self.Voltage    = src.Voltage or 0   -- the line's carried voltage (set upstream)
			local maxKW = ACF.GridCollectorMaxKW or 60
			local want  = maxKW * dt / 3600
			-- Pull through the grid (works whether `src` is the source station
			-- itself or one reached via relays). GridPull already bakes in the
			-- DC<->AC conversions and line loss, so what comes back is what lands.
			local got, volts = Sustain.GridPull(src, want, dt)
			if volts and volts > 0 then self.Voltage = volts end
			if got > 0 then
				local accepted = self.Battery:ChargeBattery(got, dt)
				self.Throughput = accepted / math.max(dt / 3600, 1e-9)
				self.Connected  = self.Throughput > 0
			end
		end
	end

	Sustain.NetworkViz(self, {
		kw = self.Throughput, dist = self.SourceDist,
		live = self.Connected, state = 0,
	})

	WireLib.TriggerOutput(self, "Connected", self.Connected and 1 or 0)
	WireLib.TriggerOutput(self, "Throughput", math.Round(self.Throughput, 2))
	WireLib.TriggerOutput(self, "Voltage", math.Round(self.Voltage or 0, 1))
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

do
	function ENT:PreEntityCopy()
		if IsValid(self.Battery) then
			duplicator.StoreEntityModifier(self, "CollectorLink", { battery = self.Battery:EntIndex() })
		end
	end

	function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.CollectorLink then return end
		local B = CreatedEntities[Ent.EntityMods.CollectorLink.battery]
		if IsValid(B) and B:GetClass() == "acf_fueltank" then self:Link(B) end
		Ent.EntityMods.CollectorLink = nil
	end
end
