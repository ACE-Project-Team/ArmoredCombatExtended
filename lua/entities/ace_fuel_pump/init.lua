AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("base_wire_entity")

local Sustain   = ACE.Sustain
local PipeLogic = Sustain.Pipe

local PUMP_MODEL = "models/maxofs2d/thruster_propeller.mdl"
local MAX_LINKS  = 6

function ENT:Initialize()
	self.PipeLinks = {}    -- pipes / pumps / tanks
	self.BoreArea  = 400   -- wide throat: a pump never bottlenecks the line
	self.FlowCap   = PipeLogic.Bore(400).flowCap
	self.Legal     = true

	self:SetModel(PUMP_MODEL)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end

	self.Outputs = WireLib.CreateOutputs(self, {
		"Links [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_FuelPump(Owner, Pos, Angle, _Id)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_fuel_pump") then return false end
	local ent = ents.Create("ace_fuel_pump")
	if not IsValid(ent) then return false end
	ent:SetAngles(Angle)
	ent:SetPos(Pos)
	ent:Spawn()
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(true) end
	ent:CPPISetOwner(Owner)
	ent:SetNWString("WireName", "Fuel Pump")
	ent:UpdateOverlayText()
	if IsValid(Owner) then
		Owner:AddCount("_ace_fuel_pump", ent)
		Owner:AddCleanup("acfmenu", ent)
	end
	return ent
end

list.Set("ACFCvars", "ace_fuel_pump", {"id"})
duplicator.RegisterEntityClass("ace_fuel_pump", MakeACE_FuelPump, "Pos", "Angle", "Id")

function ENT:SpawnFunction(ply, tr)
	if not tr or not tr.Hit then return end
	return MakeACE_FuelPump(ply, tr.HitPos + tr.HitNormal * 12, Angle(0, IsValid(ply) and ply:EyeAngles().yaw or 0, 0), "FuelPump")
end

local function CanLink(ent)
	if not IsValid(ent) then return false end
	local c = ent:GetClass()
	return c == "acf_fueltank" or c == "ace_fuel_pipe" or c == "ace_fuel_pump"
		or c == "ace_field_generator"
end

function ENT:NetworkLinks()
	local n = 0
	for _, L in ipairs(self.PipeLinks) do
		if IsValid(L) and n < MAX_LINKS then n = n + 1 self:SetNWEntity("PL" .. n, L) end
	end
	self:SetNWInt("PLN", n)
	WireLib.TriggerOutput(self, "Links", n)
end

function ENT:AddPipeLink(other)
	for _, L in ipairs(self.PipeLinks) do if L == other then return end end
	table.insert(self.PipeLinks, other)
	self:NetworkLinks()
end

function ENT:RemovePipeLink(other)
	for k = #self.PipeLinks, 1, -1 do if self.PipeLinks[k] == other then table.remove(self.PipeLinks, k) end end
	self:NetworkLinks()
end

function ENT:Link(Target)
	if not CanLink(Target) then return false, "Link a Pipe, Tank, or another Pump." end
	if Target == self then return false, "Can't link to itself!" end
	for _, L in ipairs(self.PipeLinks) do if L == Target then return false, "Already linked!" end end
	if #self.PipeLinks >= (ACF.PipeMaxLinks or MAX_LINKS) then return false, "Maximum links reached!" end
	-- Surface gap (nearest point to nearest point), matching ace_fuel_pipe's own
	-- link rule, so a long scalable pipe links when its END reaches the pump.
	local pa = self:NearestPoint(Target:WorldSpaceCenter())
	local pb = Target:NearestPoint(pa)
	pa = self:NearestPoint(pb)
	local gap = pa:Distance(pb)
	if gap > (ACF.PipeLinkGap or 80) then
		return false, "Too far (" .. math.Round(gap, 0) .. "u gap). Move the pipe ends closer."
	end
	table.insert(self.PipeLinks, Target)
	self:NetworkLinks()
	if Target.AddPipeLink then Target:AddPipeLink(self) end
	self:UpdateOverlayText()
	return true, "Pump linked into the fuel network (extends range)."
end

function ENT:Unlink(Target)
	local removed = false
	for k = #self.PipeLinks, 1, -1 do
		if self.PipeLinks[k] == Target then table.remove(self.PipeLinks, k) removed = true end
	end
	if removed then
		if IsValid(Target) and Target.RemovePipeLink then Target:RemovePipeLink(self) end
		self:NetworkLinks()
		self:UpdateOverlayText()
		return true, "Unlinked."
	end
	return false, "That entity is not linked!"
end

function ENT:UpdateOverlayText()
	self:SetOverlayText("Fuel Pump (booster)\nLinks: " .. #self.PipeLinks .. "\nRe-pressurises the line to extend range.")
end

function ENT:Think()
	local changed = false
	for k = #self.PipeLinks, 1, -1 do
		if not IsValid(self.PipeLinks[k]) then table.remove(self.PipeLinks, k) changed = true end
	end
	if changed then self:NetworkLinks() self:UpdateOverlayText() end
	self:NextThink(CurTime() + 1)
	return true
end

function ENT:OnRemove()
	for _, L in ipairs(self.PipeLinks) do
		if IsValid(L) and L.RemovePipeLink then L:RemovePipeLink(self) end
	end
end

do
	function ENT:PreEntityCopy()
		local ids = {}
		for _, L in ipairs(self.PipeLinks) do if IsValid(L) then ids[#ids + 1] = L:EntIndex() end end
		if #ids > 0 then duplicator.StoreEntityModifier(self, "FuelPumpLinks", { links = ids }) end
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.FuelPumpLinks then return end
		for _, idx in ipairs(Ent.EntityMods.FuelPumpLinks.links or {}) do
			local L = CreatedEntities[idx]
			if IsValid(L) then self:Link(L) end
		end
		Ent.EntityMods.FuelPumpLinks = nil
	end
end
