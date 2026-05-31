AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain = ACE.Sustain

function ENT:Initialize()
	self.LinkedTank = nil   -- the supply tank this nozzle draws from
	self.Socket     = nil   -- the socket we're currently plugged into
	self.Legal      = true
	self.IsScalable = true
end

function MakeACE_FuelPlug(Owner, Pos, Angle, Id, Data1, Data2)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_fuel_plug") then return false end

	local def = ACF.Weapons.FuelPlugs[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Plug = ents.Create("ace_fuel_plug")
	if not IsValid(Plug) then return false end

	Plug:SetAngles(Angle)
	Plug:SetPos(Pos)
	Plug:Spawn()

	local info = Sustain.ApplyShape(Plug, scaleVec, Data2, def)
	if not info then Plug:Remove() return false end

	Plug:SetColor(Color(245, 215, 70))
	Plug.Id          = Id
	Plug.SizeId      = Data1
	Plug.Shape       = Data2
	Plug.Dimensions  = info.dims
	Plug.AttachRange = math.max(info.dims.x, info.dims.y, info.dims.z) * 0.5 + 6
	Plug.Mass        = math.max(info.volume * 0.003, 2)
	Plug.ACEPoints   = 0

	Sustain.FinishSpawn(Plug, Owner, "_ace_fuel_plug", def.name or "ACE Fuel Plug")

	return Plug
end

list.Set("ACFCvars", "ace_fuel_plug", {"id", "data1", "data2"})
duplicator.RegisterEntityClass("ace_fuel_plug", MakeACE_FuelPlug, "Pos", "Angle", "Id", "SizeId", "Shape")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_FuelPlug, "FuelPlugs")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if Target:GetClass() ~= "acf_fueltank" then return false, "Link a fuel tank / battery (the supply)!" end
	self.LinkedTank = Target
	self:UpdateOverlayText()
	return true, "Plug linked to supply tank!"
end

function ENT:Unlink(Target)
	if IsValid(Target) and Target == self.LinkedTank then
		self.LinkedTank = nil
		self:UpdateOverlayText()
		return true, "Unlink successful!"
	end
	return false, "That entity is not linked!"
end

function ENT:UpdateOverlayText()
	local txt = "Fuel Plug (supply nozzle)"
	if IsValid(self.LinkedTank) then
		txt = txt .. "\nSupply: " .. (self.LinkedTank.FuelType or "?")
	else
		txt = txt .. "\nNot linked to a tank"
	end
	txt = txt .. "\n" .. (IsValid(self.Socket) and "PLUGGED IN" or "Unplugged")
	self:SetOverlayText(txt)
end

function ENT:OnRemove()
	if IsValid(self.Socket) then self.Socket:Disconnect() end
end

do
	function ENT:PreEntityCopy()
		if IsValid(self.LinkedTank) then
			duplicator.StoreEntityModifier(self, "FuelPlugLink", { tank = self.LinkedTank:EntIndex() })
		end
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.FuelPlugLink then return end
		local T = CreatedEntities[Ent.EntityMods.FuelPlugLink.tank]
		if IsValid(T) and T:GetClass() == "acf_fueltank" then self:Link(T) end
		Ent.EntityMods.FuelPlugLink = nil
	end
end
