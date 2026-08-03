-- cl_init.lua

include("shared.lua")

CreateClientConVar("ace_engine_info_while_seated", 0, true, false)

-- copied from base_wire_entity: DoNormalDraw's notip arg isn't accessible from ENT:Draw defined there.
function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not GetConVar("ace_engine_info_while_seated"):GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end

function ACE_EngineGUI_Update( Table )

	acemenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	if not acemenupanel.CData.DisplayModel then

		acemenupanel.CData.DisplayModel = vgui.Create( "DModelPanel", acemenupanel.CustomDisplay )
		acemenupanel.CData.DisplayModel:SetModel( Table.model )
		acemenupanel.CData.DisplayModel:SetCamPos( Vector( 250, 500, 250 ) )
		acemenupanel.CData.DisplayModel:SetLookAt( Vector( 0, 0, 0 ) )
		acemenupanel.CData.DisplayModel:SetFOV( 20 )
		acemenupanel.CData.DisplayModel:SetSize(acemenupanel:GetWide(),acemenupanel:GetWide())
		acemenupanel.CData.DisplayModel.LayoutEntity = function() end
		acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.DisplayModel )

	end

	acemenupanel.CData.DisplayModel:SetModel( Table.model )

	acemenupanel:CPanelText("Desc", Table.desc)

	local peakkw = Table.peakpower
	local peakkwrpm = Table.peakpowerrpm
	local peaktqrpm = Table.peaktqrpm
	local pbmin = Table.peakminrpm
	local pbmax = Table.peakmaxrpm

	acemenupanel:CPanelText("Power", "\nPeak Power: " .. math.floor(peakkw) .. " kW / " .. math.Round(peakkw * 1.34) .. " HP @ " .. math.Round(peakkwrpm) .. " RPM")
	acemenupanel:CPanelText("Torque", "Peak Torque: " .. Table.torque .. " n/m  / " .. math.Round(Table.torque * 0.73) .. " ft-lb @ " .. math.Round(peaktqrpm) .. " RPM")

	acemenupanel:CPanelText("RPM", "Idle: " .. Table.idlerpm .. " RPM\nPowerband : " .. (math.Round(pbmin / 10) * 10) .. "-" .. (math.Round(pbmax / 10) * 10) .. " RPM\nRedline : " .. Table.limitrpm .. " RPM")
	acemenupanel:CPanelText("Weight", "Weight: " .. Table.weight .. " kg")


	acemenupanel:CPanelText("FuelType", "\nFuel Type: " .. Table.fuel)

	if Table.fuel == "Electric" then
		local cons = ACE.ElecRate * peakkw / ACE.Efficiency[Table.enginetype]
		acemenupanel:CPanelText("FuelCons", "Peak energy use: " .. math.Round(cons,1) .. " kW / " .. math.Round(0.06 * cons,1) .. " MJ/min")
	elseif Table.fuel == "Multifuel" then
		local petrolcons = ACE.FuelRate * ACE.Efficiency[Table.enginetype] * peakkw / (60 * ACE.FuelDensity.Petrol)
		local dieselcons = ACE.FuelRate * ACE.Efficiency[Table.enginetype] * peakkw / (60 * ACE.FuelDensity.Diesel)
		acemenupanel:CPanelText("FuelConsP", "Petrol Use at " .. math.Round(peakkwrpm) .. " rpm: " .. math.Round(petrolcons,2) .. " liters/min / " .. math.Round(0.264 * petrolcons,2) .. " gallons/min")
		acemenupanel:CPanelText("FuelConsD", "Diesel Use at " .. math.Round(peakkwrpm) .. " rpm: " .. math.Round(dieselcons,2) .. " liters/min / " .. math.Round(0.264 * dieselcons,2) .. " gallons/min")
	else
		local fuelcons = ACE.FuelRate * ACE.Efficiency[Table.enginetype] * peakkw / (60 * ACE.FuelDensity[Table.fuel])
		acemenupanel:CPanelText("FuelCons", Table.fuel .. " Use at " .. math.Round(peakkwrpm) .. " rpm: " .. math.Round(fuelcons,2) .. " liters/min / " .. math.Round(0.264 * fuelcons,2) .. " gallons/min")
	end

	acemenupanel.CustomDisplay:PerformLayout()

end
