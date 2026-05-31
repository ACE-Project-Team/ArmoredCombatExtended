AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain = ACE.Sustain

function ENT:Initialize()
	self.LinkedTank        = nil   -- the receiver tank we fill
	self.Plug              = nil   -- currently connected plug
	self.AttachRange       = 12
	self.NextTransferSound = 0
	self.FlowRate          = 0
	self.Legal             = true
	self.IsScalable        = true
end

function MakeACE_FuelSocket(Owner, Pos, Angle, Id, Data1, Data2)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_fuel_socket") then return false end

	local def = ACF.Weapons.FuelSockets[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Socket = ents.Create("ace_fuel_socket")
	if not IsValid(Socket) then return false end

	Socket:SetAngles(Angle)
	Socket:SetPos(Pos)
	Socket:Spawn()

	local info = Sustain.ApplyShape(Socket, scaleVec, Data2, def)
	if not info then Socket:Remove() return false end

	Socket:SetColor(Color(110, 130, 150))
	Socket.Id          = Id
	Socket.SizeId      = Data1
	Socket.Shape       = Data2
	Socket.Dimensions  = info.dims
	Socket.AttachRange = math.max(info.dims.x, info.dims.y, info.dims.z) * 0.5 + 6
	Socket.Mass        = math.max(info.volume * 0.003, 2)
	Socket.ACEPoints   = 0

	Sustain.FinishSpawn(Socket, Owner, "_ace_fuel_socket", def.name or "ACE Fuel Socket")

	return Socket
end

list.Set("ACFCvars", "ace_fuel_socket", {"id", "data1", "data2"})
duplicator.RegisterEntityClass("ace_fuel_socket", MakeACE_FuelSocket, "Pos", "Angle", "Id", "SizeId", "Shape")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_FuelSocket, "FuelSockets")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if Target:GetClass() ~= "acf_fueltank" then return false, "Link a fuel tank / battery (the receiver)!" end
	self.LinkedTank = Target
	self:UpdateOverlayText()
	return true, "Socket linked to receiver tank!"
end

function ENT:Unlink(Target)
	if IsValid(Target) and Target == self.LinkedTank then
		self.LinkedTank = nil
		self:UpdateOverlayText()
		return true, "Unlink successful!"
	end
	return false, "That entity is not linked!"
end

local WELD_FORCE = 5000   -- breakable: physgun can pull the plug back out

-- Find the nearest unplugged, tank-linked fuel plug presented to the socket's
-- FRONT FACE within attach range. Requiring the plug to be in front (not just
-- anywhere in a sphere) is what makes the connection read as face-to-face: you
-- have to bring the plug up to the socket's mouth, not just next to it.
-- Plugs a player is currently holding are skipped, so grabbing one to pull it
-- out doesn't immediately get re-grabbed by the socket.
function ENT:GetClosestPlug()
	local pos     = self:GetPos()
	local forward = self:GetForward()
	local best, bestDist
	for _, ent in ipairs(ents.FindInSphere(pos, self.AttachRange)) do
		if ent:GetClass() ~= "ace_fuel_plug" then continue end
		if IsValid(ent.Socket) then continue end
		if ent:IsPlayerHolding() then continue end

		local toPlug = ent:GetPos() - pos
		local d = toPlug:Length()
		if d < 0.1 then continue end
		-- Must sit in front of the socket's mouth (within ~60 deg of forward).
		if toPlug:GetNormalized():Dot(forward) < 0.5 then continue end

		if not bestDist or d < bestDist then best, bestDist = ent, d end
	end
	return best
end

function ENT:Connect(plug)
	self.Plug = plug
	plug.Socket = self

	-- Seat the plug in front of the socket and rotate it 180 so the two faces
	-- meet head-on (front-to-front) instead of pointing the same way.
	local socketDepth = (self.Dimensions and self.Dimensions.x or 12)
	local plugDepth   = (plug.Dimensions and plug.Dimensions.x or 10)
	local gap = (socketDepth + plugDepth) * 0.5

	local ang = self:GetAngles()
	ang:RotateAroundAxis(self:GetUp(), 180)
	plug:SetAngles(ang)
	plug:SetPos(self:GetPos() + self:GetForward() * gap)

	-- Breakable weld: a hard physgun pull snaps it (CallOnRemove disconnects).
	local weld = constraint.Weld(self, plug, 0, 0, WELD_FORCE, true)
	self.Weld = weld
	if IsValid(weld) then
		weld:CallOnRemove("ace_fuel_disconnect", function()
			if IsValid(self) then self:Disconnect() end
		end)
	end

	self:EmitSound("buttons/lightswitch2.wav", 60, 110)
	self:UpdateOverlayText()
	if IsValid(plug) then plug:UpdateOverlayText() end
end

function ENT:Disconnect()
	local plug = self.Plug
	if IsValid(plug) then
		plug.Socket = nil
		if plug.UpdateOverlayText then plug:UpdateOverlayText() end
	end
	-- Actually remove the constraint so the two physically come apart.
	if IsValid(self.Weld) then self.Weld:Remove() end
	self.Plug = nil
	self.Weld = nil
	self.FlowRate = 0
	self.NextAttach = CurTime() + 1   -- brief cooldown before it can grab again
	self:UpdateOverlayText()
end

-- Move fuel/energy from the plug's supply tank into our receiver tank.
function ENT:TransferFuel(dt)
	self.FlowRate = 0
	local recv = self.LinkedTank
	local supply = IsValid(self.Plug) and self.Plug.LinkedTank or nil
	if not IsValid(recv) or not IsValid(supply) then return end
	if recv == supply then return end
	-- Compatible if same type, or the receiver is a still-empty Universal tank.
	if recv.FuelType == "Electric" then
		if supply.FuelType ~= "Electric" then return end
	elseif not (recv.CanReceiveFuel and recv:CanReceiveFuel(supply.FuelType)) then
		return
	end
	if supply.Fuel <= 0 then return end

	local moved = 0
	local electric = recv.FuelType == "Electric"

	if electric then
		-- A charging cable still loses energy to charge/discharge inefficiency.
		local loss = ACF.FuelLinkLoss or 0.04
		local want = (ACF.FuelLinkRateElec or 4) * dt / 3600
		local drawn = supply.DrawEnergy and supply:DrawEnergy(want, dt) or 0
		if drawn > 0 and recv.ChargeBattery then
			recv:ChargeBattery(drawn * (1 - loss), dt)
			moved = drawn
			self.FlowRate = drawn / (dt / 3600)   -- kW
		end
	else
		-- A sealed hose moves liquid with negligible loss (no "evaporating petrol").
		local room = recv.Capacity - recv.Fuel
		if room <= 0 then return end
		local amount = math.min((ACF.FuelLinkRate or 12) * dt, supply.Fuel, room)
		if amount > 0 then
			supply.Fuel = supply.Fuel - amount
			if recv.AddFuel then recv:AddFuel(amount, supply.FuelType)
			else recv.Fuel = math.min(recv.Capacity, recv.Fuel + amount) end
			moved = amount
			self.FlowRate = amount / dt           -- L/s
		end
	end

	if moved > 0 and CurTime() > self.NextTransferSound then
		if electric then
			self:EmitSound("ambient/energy/newspark0" .. math.random(1, 9) .. ".wav", 55, 120, 0.4)
		else
			self:EmitSound("ambient/water/water_spray" .. math.random(1, 2) .. ".wav", 60, 105, 0.5)
		end
		self.NextTransferSound = CurTime() + 1.5
	end
end

function ENT:UpdateOverlayText()
	local txt = "Fuel Socket (receiver port)"
	if IsValid(self.LinkedTank) then
		txt = txt .. "\nReceiver: " .. (self.LinkedTank.FuelType or "?")
	else
		txt = txt .. "\nNot linked to a tank"
	end
	if IsValid(self.Plug) then
		txt = txt .. "\nCONNECTED - flow: " .. math.Round(self.FlowRate or 0, 2)
	else
		txt = txt .. "\nNo plug connected"
	end
	self:SetOverlayText(txt)
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or 0.2
	self.LastThink = CurTime()

	if not IsValid(self.Plug) then
		self:SetNWBool("AceConnected", false)
		self:SetNWFloat("AceFlow", 0)
		-- Looking for a plug to connect to (after any disconnect cooldown).
		if self.Plug ~= nil then self:Disconnect() end
		if CurTime() >= (self.NextAttach or 0) then
			local plug = self:GetClosestPlug()
			if IsValid(plug) then self:Connect(plug) end
		end
		self:NextThink(CurTime() + 0.1)
		return true
	end

	-- Grabbing the plug with the physgun/grav gun pops it out cleanly.
	if self.Plug:IsPlayerHolding() then
		self:Disconnect()
		self:NextThink(CurTime() + 0.1)
		return true
	end

	self:TransferFuel(dt)
	self:SetNWBool("AceConnected", IsValid(self.Plug))
	self:SetNWFloat("AceFlow", self.FlowRate or 0)
	self:SetNWBool("AceElectric", IsValid(self.LinkedTank) and self.LinkedTank.FuelType == "Electric")
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.2)
	return true
end

function ENT:OnRemove()
	if IsValid(self.Plug) then self.Plug.Socket = nil end
end

do
	function ENT:PreEntityCopy()
		if IsValid(self.LinkedTank) then
			duplicator.StoreEntityModifier(self, "FuelSocketLink", { tank = self.LinkedTank:EntIndex() })
		end
	end

	function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.FuelSocketLink then return end
		local T = CreatedEntities[Ent.EntityMods.FuelSocketLink.tank]
		if IsValid(T) and T:GetClass() == "acf_fueltank" then self:Link(T) end
		Ent.EntityMods.FuelSocketLink = nil
	end
end
