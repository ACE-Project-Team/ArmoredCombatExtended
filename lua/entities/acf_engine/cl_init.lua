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

function ACE.EngineGUI_Update( Table )

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
		local engineEfficiency = ACF.Efficiency[Table.enginetype] * (1 + (peakkw * 1.34/2000)*0.1)
		local cons = ACF.ElecRate * peakkw / engineEfficiency
		acfmenupanel:CPanelText("FuelCons", "Peak energy use: " .. math.Round(cons,1) .. " kW / " .. math.Round(0.06 * cons,1) .. " MJ/min")
	elseif Table.fuel == "Multifuel" then
		local engineEfficiency = ACF.Efficiency[Table.enginetype] * (1 + (peakkw * 1.34/2000)*0.1)
		local petrolcons = ACF.FuelRate * engineEfficiency * peakkw / (60 * ACF.FuelDensity.Petrol) * ACF.PerFuelRelativeEfficiency.Petrol
		local dieselcons = ACF.FuelRate * engineEfficiency * peakkw / (60 * ACF.FuelDensity.Diesel) * ACF.PerFuelRelativeEfficiency.Diesel
		local HeatPerLiterUsedPetrol = engineEfficiency * ACF.FuelPowerDensity["Petrol"] * 0.4 * 1000 / 60 / ACF.FuelRate --Heat generated per liter burned. Assume 60% heat lost to the air as exhaust.
		local HeatPerLiterUsedDiesel = engineEfficiency * ACF.FuelPowerDensity["Diesel"] * 0.4 * 1000 / 60 / ACF.FuelRate --Heat generated per liter burned. Assume 60% heat lost to the air as exhaust.
		acfmenupanel:CPanelText("FuelConsP", "Petrol Use at " .. math.Round(peakkwrpm) .. " rpm: " .. math.Round(petrolcons,2) .. " liters/min / " .. math.Round(0.264 * petrolcons,2) .. " gallons/min")
		acfmenupanel:CPanelText("EngHeatP", "Producing ".. math.Round(petrolcons * HeatPerLiterUsedPetrol,2) .. "kJ / Second of heat")
		acfmenupanel:CPanelText("FuelConsD", "Diesel Use at " .. math.Round(peakkwrpm) .. " rpm: " .. math.Round(dieselcons,2) .. " liters/min / " .. math.Round(0.264 * dieselcons,2) .. " gallons/min")
		acfmenupanel:CPanelText("EngHeatD", "Producing ".. math.Round(dieselcons * HeatPerLiterUsedDiesel,2) .. "kJ / Second of heat")
	else
		local engineEfficiency = ACF.Efficiency[Table.enginetype] * (1 + (peakkw * 1.34/2000)*0.1)
		local fuelcons = ACF.FuelRate * engineEfficiency * peakkw / (60 * ACF.FuelDensity[Table.fuel])  * ACF.PerFuelRelativeEfficiency[Table.fuel]
		acfmenupanel:CPanelText("FuelCons", Table.fuel .. " Use at " .. math.Round(peakkwrpm) .. " rpm: " .. math.Round(fuelcons,2) .. " liters/min / " .. math.Round(0.264 * fuelcons,2) .. " gallons/min")
		local HeatPerLiterUsed = engineEfficiency * ACF.FuelPowerDensity[Table.fuel] * 0.4 * 1000 / 60 / ACF.FuelRate --Heat generated per liter burned. Assume 60% heat lost to the air as exhaust.
		acfmenupanel:CPanelText("EngHeat", "Producing ".. math.Round(fuelcons * HeatPerLiterUsed,2) .. "kJ / Second of heat")
	end

	acfmenupanel.CustomDisplay:PerformLayout()

end

ACE_EngineGUI_Update = ACE.EngineGUI_Update






do
	--Maybe add override capability to this later to handle turbines?
	local TypeList = {}
	local LookupList = {}
	
	TypeList.Inline = {}
	TypeList.Inline.Text = "Inline"
	TypeList.Inline.Shorthand = "I"
	TypeList.Inline.Validtypes = {1,2,3,4,5,6,8,12}
	LookupList["Inline"] = "Inline"

	TypeList.Boxer = {}
	TypeList.Boxer.Text = "Boxer"
	TypeList.Boxer.Shorthand = "B"
	TypeList.Boxer.Validtypes = {2,4,6,8,10,12}
	LookupList["Boxer"] = "Boxer"

	TypeList.VBlock = {}
	TypeList.VBlock.Text = "V-Block"
	TypeList.VBlock.Shorthand = "V"
	TypeList.VBlock.Validtypes = {2,4,6,8,10,12}
	LookupList["V-Block"] = "VBlock"

	TypeList.XBlock = {}
	TypeList.XBlock.Text = "X-Block"
	TypeList.XBlock.Shorthand = "X"
	TypeList.XBlock.Validtypes = {4,8,12,16,20,24}
	LookupList["X-Block"] = "XBlock"

	TypeList.WBlock = {}
	TypeList.WBlock.Text = "W-Block"
	TypeList.WBlock.Shorthand = "W"
	TypeList.WBlock.Validtypes = {16}
	LookupList["W-Block"] = "WBlock"

	TypeList.VRBlock = {}
	TypeList.VRBlock.Text = "VR-Block"
	TypeList.VRBlock.Shorthand = "VR"
	TypeList.VRBlock.Validtypes = {4,6,8}
	LookupList["VR-Block"] = "VRBlock"

	TypeList.VBlockHeavy = {}
	TypeList.VBlockHeavy.Text = "V-Block Heavy"
	TypeList.VBlockHeavy.Shorthand = "VH"
	TypeList.VBlockHeavy.Validtypes = {10}
	LookupList["V-Block Heavy"] = "VBlockHeavy"

	TypeList.Radial = {}
	TypeList.Radial.Text = "Radial"
	TypeList.Radial.Shorthand = "R"
	TypeList.Radial.Validtypes = {3,5,7,9}
	LookupList["Radial"] = "Radial"

	TypeList.Rotary = {}
	TypeList.Rotary.Text = "Rotary"
	TypeList.Rotary.Shorthand = "RT"
	TypeList.Rotary.Validtypes = {2,4}
	LookupList["Rotary"] = "Rotary"



	local Cylinderlist = {4}

	local function CreateIdForCrate()

		if not acfmenupanel.FuelPanelConfig["LegacyFuels"] then

		   local X = math.Round( acfmenupanel.FuelPanelConfig["Crate_Length"], 1 )
		   local Y = math.Round( acfmenupanel.FuelPanelConfig["Crate_Width"], 1 )
		   local Z = math.Round( acfmenupanel.FuelPanelConfig["Crate_Height"], 1)

		   local Id = X .. ":" .. Y .. ":" .. Z

		   ACE.CusEngineGUI_Update( Table )
		   acfmenupanel.FuelTankData["Id"] = Id
		   RunConsoleCommand( "acfmenu_data1", Id )

		end

	 end

	function ACE.CusEngineGUI_Create( Table )
		if not acfmenupanel.CustomDisplay then return end

		local MainPanel = acfmenupanel.CustomDisplay

		if not acfmenupanel.CusEngineData then
			acfmenupanel.CusEngineData          = {}
			acfmenupanel.CusEngineData.Type = "Inline"
			acfmenupanel.CusEngineData.CylinderCount = 4
			acfmenupanel.CusEngineData.FuelID = "Petrol"
		end

		if not acfmenupanel.CusEngineConfig then
			acfmenupanel.CusEngineConfig = {}
		 end

		acfmenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")
		acfmenupanel:CPanelText("Desc", Table.desc)

		do --Engine Type Selection
			local CylinderCountComboList = nil

			acfmenupanel:CPanelText("Enginetype_desc", "\nChoose an engine type" )

			local EngineTypeComboList = vgui.Create( "DComboBox", MainPanel )
			EngineTypeComboList:SetSortItems( false )
			EngineTypeComboList:SetSize(100, 30)
			for Key, _ in pairs( LookupList ) do --ACE.CustomEngineList
				EngineTypeComboList:AddChoice( Key )
			end

			EngineTypeComboList.OnSelect = function( _, _, data )
				RunConsoleCommand( "acfmenu_data2", data )
				acfmenupanel.CusEngineData.Type = LookupList[data]
				ACE.CusEngineGUI_Update( Table )

				--print(acfmenupanel.CusEngineData.Type)
				Cylinderlist = TypeList[acfmenupanel.CusEngineData.Type].Validtypes or {4}
				PrintTable(Cylinderlist)

				CylinderCountComboList:clear()
				for _, Key in pairs( Cylinderlist ) do --ACE.CustomEngineList
					CylinderCountComboList:AddChoice( Key )
				end

			end--

			EngineTypeComboList:SetText(acfmenupanel.CusEngineData.Type)
			RunConsoleCommand( "acfmenu_data2", acfmenupanel.CusEngineData.Type )
			MainPanel:AddItem( EngineTypeComboList )



			--Cylinder Count Selection

			acfmenupanel:CPanelText("Cylindercount_desc", "\nHow many cylinders" )

			local CylinderCountComboList = vgui.Create( "DComboBox", MainPanel )
			CylinderCountComboList:SetSortItems( false )
			CylinderCountComboList:SetSize(100, 30)
			for _, Key in pairs( Cylinderlist ) do --ACE.CustomEngineList
				CylinderCountComboList:AddChoice( Key )
			end

			CylinderCountComboList.OnSelect = function( _, _, data )
				RunConsoleCommand( "acfmenu_data2", data )
				acfmenupanel.CusEngineData.CylinderCount = data
				ACE.CusEngineGUI_Update( Table )
				
			end--

			CylinderCountComboList:SetText(acfmenupanel.CusEngineData.CylinderCount)
			RunConsoleCommand( "acfmenu_data2", acfmenupanel.CusEngineData.CylinderCount )
			MainPanel:AddItem( CylinderCountComboList )

		end

		do --Engine Fuel Selection

			acfmenupanel:CPanelText("Fueltype_desc", "\nChoose a fuel type" )

			local FuelTypeComboList = vgui.Create( "DComboBox", MainPanel )
			FuelTypeComboList:SetSize(100, 30)
			for Key, _ in pairs( ACF.FuelDensity ) do
				if Key == "Electric" then continue end --Electric is excluded from custom engines for now.
				FuelTypeComboList:AddChoice( Key )
			end

			FuelTypeComboList.OnSelect = function( _, _, data )
				RunConsoleCommand( "acfmenu_data2", data )
				acfmenupanel.CusEngineData.FuelID = data
				ACE.CusEngineGUI_Update( Table )
			end

			FuelTypeComboList:SetText(acfmenupanel.CusEngineData.FuelID)
			RunConsoleCommand( "acfmenu_data2", acfmenupanel.CusEngineData.FuelID )
			MainPanel:AddItem( FuelTypeComboList )

		end

		----------- The rest below -----------

		ACE.CusEngineGUI_Update( Table )

		MainPanel:PerformLayout()

	end

	function ACE.CusEngineGUI_Update( _ )

	end
end