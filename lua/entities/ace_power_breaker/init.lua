AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("base_wire_entity")

local Sustain = ACE.Sustain

local BREAKER_MODEL = "models/xqm/hydcontrolbox.mdl"

function ENT:Initialize()
	self.Station   = nil
	self.Rating    = ACF.BreakerDefaultRating or 120   -- kW trip threshold
	self.Tripped   = false
	self.OverTime  = 0          -- seconds spent over rating
	self.TripAt    = 0          -- CurTime it tripped (for auto-reset)
	self.FuseMode  = false      -- true = one-shot fuse (no auto-reclose; needs a Reset pulse)
	self.Legal     = true

	self:SetModel(BREAKER_MODEL)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end

	self.Inputs = WireLib.CreateInputs(self, {
		"Rating (Trip threshold in kW) [NORMAL]",
		"Reset (Any rising non-zero value re-closes it) [NORMAL]",
		"Fuse Mode (1 = one-shot FUSE: stays open after tripping until you pulse Reset; 0 = auto-reclosing BREAKER) [NORMAL]",
	})
	self.Outputs = WireLib.CreateOutputs(self, {
		"Tripped (1 when open) [NORMAL]",
		"Current (kW through the protected station) [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_PowerBreaker(Owner, Pos, Angle, _Id)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_power_breaker") then return false end
	local ent = ents.Create("ace_power_breaker")
	if not IsValid(ent) then return false end
	ent:SetAngles(Angle)
	ent:SetPos(Pos)
	ent:Spawn()
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(true) end
	ent:CPPISetOwner(Owner)
	ent:SetNWString("WireName", "Power Breaker")
	ent:UpdateOverlayText()
	if IsValid(Owner) then
		Owner:AddCount("_ace_power_breaker", ent)
		Owner:AddCleanup("acfmenu", ent)
	end
	return ent
end

list.Set("ACFCvars", "ace_power_breaker", {"id"})
duplicator.RegisterEntityClass("ace_power_breaker", MakeACE_PowerBreaker, "Pos", "Angle", "Id")

function ENT:SpawnFunction(ply, tr)
	if not tr or not tr.Hit then return end
	return MakeACE_PowerBreaker(ply, tr.HitPos + tr.HitNormal * 12, Angle(0, IsValid(ply) and ply:EyeAngles().yaw or 0, 0), "PowerBreaker")
end

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if Target:GetClass() ~= "ace_transfer_station" then return false, "Link a Transfer Station to protect." end
	self.Station = Target
	Target.Breaker = self   -- back-ref so a short in the chain can trip us
	self:UpdateOverlayText()
	return true, "Protecting that station."
end

function ENT:Unlink(Target)
	if IsValid(Target) and Target == self.Station then
		if IsValid(self.Station) then self.Station.BreakerOpen = false self.Station.Breaker = nil end
		self.Station = nil
		self:UpdateOverlayText()
		return true, "Unlinked."
	end
	return false, "That entity is not linked!"
end

function ENT:SetTripped(state)
	self.Tripped = state
	if IsValid(self.Station) then self.Station.BreakerOpen = state end
	if state then
		self.TripAt = CurTime()
		self:EmitSound("buttons/combine_button_locked.wav", 75, 90)
	else
		self.OverTime = 0
		self:EmitSound("buttons/combine_button1.wav", 70, 110)
	end
end

function ENT:TriggerInput(iname, value)
	if iname == "Rating" then
		self.Rating = math.max(0, value or 0)
	elseif iname == "Reset" then
		if value and value ~= 0 and self.Tripped then self:SetTripped(false) end
	elseif iname == "Fuse Mode" then
		self.FuseMode = value ~= 0
		self:UpdateOverlayText()
	end
end

function ENT:UpdateOverlayText()
	local txt = self.FuseMode and "Power Fuse (one-shot)" or "Power Breaker (auto-reclose)"
	txt = txt .. "\nProtecting: " .. (IsValid(self.Station) and "a station" or "MISSING")
	txt = txt .. "\nRating: " .. math.Round(self.Rating or 0, 0) .. " kW"
	if self.Tripped then
		txt = txt .. "\nTRIPPED (open) - " .. (self.FuseMode and "pulse Reset to replace" or "re-closes automatically")
	else
		txt = txt .. "\nclosed"
	end
	self:SetOverlayText(txt)
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or 0.25
	self.LastThink = CurTime()

	local current = IsValid(self.Station) and (self.Station.Throughput or 0) or 0

	if not self.Tripped then
		if current > self.Rating and self.Rating > 0 then
			self.OverTime = self.OverTime + dt
			if self.OverTime >= (ACF.BreakerTripDelay or 0.5) then
				self:SetTripped(true)
			end
		else
			self.OverTime = math.max(0, self.OverTime - dt)
		end
	elseif not self.FuseMode then
		-- BREAKER: auto-reclose after the cooldown (if enabled). A FUSE never
		-- auto-recloses - it stays open until a Reset pulse "replaces" it.
		local auto = ACF.BreakerAutoReset or 0
		if auto > 0 and CurTime() - self.TripAt >= auto then
			self:SetTripped(false)
		end
	end

	-- Publish state + the protected-station link so the ACE Grid Tool shows the
	-- protection in the overlay (open breakers read as "broken"/red).
	Sustain.NetworkViz(self, {
		kw = current, cap = self.Rating,
		live = not self.Tripped and IsValid(self.Station),
		state = self.Tripped and 2 or 0, role = "breaker",
	})
	Sustain.NetworkAux(self, { { ent = self.Station, label = "protects" } })

	WireLib.TriggerOutput(self, "Tripped", self.Tripped and 1 or 0)
	WireLib.TriggerOutput(self, "Current", math.Round(current, 2))
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

function ENT:OnRemove()
	if IsValid(self.Station) then self.Station.BreakerOpen = false self.Station.Breaker = nil end
end

do
	function ENT:PreEntityCopy()
		duplicator.StoreEntityModifier(self, "BreakerLink", {
			station = IsValid(self.Station) and self.Station:EntIndex() or nil,
			rating  = self.Rating,
		})
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.BreakerLink then return end
		local info = Ent.EntityMods.BreakerLink
		if info.rating then self.Rating = info.rating end
		if info.station then
			local S = CreatedEntities[info.station]
			if IsValid(S) then self:Link(S) end
		end
		self:UpdateOverlayText()
		Ent.EntityMods.BreakerLink = nil
	end
end
