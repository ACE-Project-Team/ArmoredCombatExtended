-- cl_init.lua

include("shared.lua")

CreateClientConVar("ACF_EngineInfoWhileSeated", 0, true, false)

-- copied from base_wire_entity: DoNormalDraw's notip arg isn't accessible from ENT:Draw defined there.
function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not GetConVar("ACF_EngineInfoWhileSeated"):GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end

function ACE_EngineGUI_Update( Table )

	acfmenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	if not acfmenupanel.CData.DisplayModel then

		acfmenupanel.CData.DisplayModel = vgui.Create( "DModelPanel", acfmenupanel.CustomDisplay )
		acfmenupanel.CData.DisplayModel:SetModel( Table.model )
		acfmenupanel.CData.DisplayModel:SetCamPos( Vector( 250, 500, 250 ) )
		acfmenupanel.CData.DisplayModel:SetLookAt( Vector( 0, 0, 0 ) )
		acfmenupanel.CData.DisplayModel:SetFOV( 20 )
		acfmenupanel.CData.DisplayModel:SetSize(acfmenupanel:GetWide(),acfmenupanel:GetWide())
		acfmenupanel.CData.DisplayModel.LayoutEntity = function() end
		acfmenupanel.CustomDisplay:AddItem( acfmenupanel.CData.DisplayModel )

	end

	acfmenupanel.CData.DisplayModel:SetModel( Table.model )

	acfmenupanel:CPanelText("Desc", Table.desc)

	local peakkw = Table.peakpower
	local peakkwrpm = Table.peakpowerrpm
	local peaktqrpm = Table.peaktqrpm
	local pbmin = Table.peakminrpm
	local pbmax = Table.peakmaxrpm

	acfmenupanel:CPanelText("Power", "\nPeak Power: " .. math.floor(peakkw) .. " kW / " .. math.Round(peakkw * 1.34) .. " HP @ " .. math.Round(peakkwrpm) .. " RPM")
	acfmenupanel:CPanelText("Torque", "Peak Torque: " .. Table.torque .. " n/m  / " .. math.Round(Table.torque * 0.73) .. " ft-lb @ " .. math.Round(peaktqrpm) .. " RPM")

	acfmenupanel:CPanelText("RPM", "Idle: " .. Table.idlerpm .. " RPM\nPowerband : " .. (math.Round(pbmin / 10) * 10) .. "-" .. (math.Round(pbmax / 10) * 10) .. " RPM\nRedline : " .. Table.limitrpm .. " RPM")
	acfmenupanel:CPanelText("Weight", "Weight: " .. Table.weight .. " kg")


	acfmenupanel:CPanelText("FuelType", "\nFuel Type: " .. Table.fuel)

	if Table.fuel == "Electric" then
		local cons = ACF.ElecRate * peakkw / ACF.Efficiency[Table.enginetype]
		acfmenupanel:CPanelText("FuelCons", "Peak energy use: " .. math.Round(cons,1) .. " kW / " .. math.Round(0.06 * cons,1) .. " MJ/min")
	elseif Table.fuel == "Multifuel" then
		local petrolcons = ACF.FuelRate * ACF.Efficiency[Table.enginetype] * peakkw / (60 * ACF.FuelDensity.Petrol)
		local dieselcons = ACF.FuelRate * ACF.Efficiency[Table.enginetype] * peakkw / (60 * ACF.FuelDensity.Diesel)
		acfmenupanel:CPanelText("FuelConsP", "Petrol Use at " .. math.Round(peakkwrpm) .. " rpm: " .. math.Round(petrolcons,2) .. " liters/min / " .. math.Round(0.264 * petrolcons,2) .. " gallons/min")
		acfmenupanel:CPanelText("FuelConsD", "Diesel Use at " .. math.Round(peakkwrpm) .. " rpm: " .. math.Round(dieselcons,2) .. " liters/min / " .. math.Round(0.264 * dieselcons,2) .. " gallons/min")
	else
		local fuelcons = ACF.FuelRate * ACF.Efficiency[Table.enginetype] * peakkw / (60 * ACF.FuelDensity[Table.fuel])
		acfmenupanel:CPanelText("FuelCons", Table.fuel .. " Use at " .. math.Round(peakkwrpm) .. " rpm: " .. math.Round(fuelcons,2) .. " liters/min / " .. math.Round(0.264 * fuelcons,2) .. " gallons/min")
	end

	acfmenupanel.CustomDisplay:PerformLayout()

end
