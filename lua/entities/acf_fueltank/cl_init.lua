
include("shared.lua")

CreateClientConVar("ace_fuel_info_while_seated", 0, true, false)

-- copied from base_wire_entity: DoNormalDraw's notip arg isn't accessible from ENT:Draw defined there.
function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not GetConVar("ace_fuel_info_while_seated"):GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end

do

	local Wall = 0.03937 -- wall thickness in inches (1mm). Meant to be a global var
	local SortedTanks = {}
	local TankTable = ACE.Weapons
	local Tanks = TankTable.FuelTanksSize

	for n in pairs(Tanks) do
		table.insert(SortedTanks,n)
	end
	table.sort(SortedTanks)

	local function CreateIdForCrate()

		if not acemenupanel.FuelPanelConfig["LegacyFuels"] then

		   local X = math.Round( acemenupanel.FuelPanelConfig["Crate_Length"], 1 )
		   local Y = math.Round( acemenupanel.FuelPanelConfig["Crate_Width"], 1 )
		   local Z = math.Round( acemenupanel.FuelPanelConfig["Crate_Height"], 1)

		   local Id = X .. ":" .. Y .. ":" .. Z

		   ACE.FuelTankGUIUpdate( Table )
		   acemenupanel.FuelTankData["Id"] = Id
		   RunConsoleCommand( "acemenu_data1", Id )

		end

	 end

	function ACE.FuelTankGUICreate( Table )
		if not acemenupanel.CustomDisplay then return end

		local MainPanel = acemenupanel.CustomDisplay

		if not acemenupanel.FuelTankData then
			acemenupanel.FuelTankData          = {}
			acemenupanel.FuelTankData.Id       = "10:10:10"
			acemenupanel.FuelTankData.IdLegacy = "Tank_4x4x2"
			acemenupanel.FuelTankData.FuelID   = "Petrol"
		end

		if not acemenupanel.FuelPanelConfig then

			acemenupanel.FuelPanelConfig = {}
			acemenupanel.FuelPanelConfig["ExpandedCatNew"] = true
			acemenupanel.FuelPanelConfig["ExpandedCatOld"] = false
			acemenupanel.FuelPanelConfig["LegacyFuels"]   = false
			acemenupanel.FuelPanelConfig["Crate_Length"]  = 10
			acemenupanel.FuelPanelConfig["Crate_Width"]   = 10
			acemenupanel.FuelPanelConfig["Crate_Height"]  = 10
			acemenupanel.FuelPanelConfig["Crate_Shape"] = "Box"

		 end

		acemenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")
		acemenupanel:CPanelText("Desc", Table.desc)

		----------- fuel type dropbox -----------
		do

			acemenupanel:CPanelText("Fueltype_desc", "\nChoose a fuel type" )

			local FuelTypeComboList = vgui.Create( "DComboBox", MainPanel )
			FuelTypeComboList:SetSize(100, 30)
			for Key, _ in pairs( ACE.FuelDensity ) do
				FuelTypeComboList:AddChoice( Key )
			end

			FuelTypeComboList.OnSelect = function( _, _, data )
				RunConsoleCommand( "acemenu_data2", data )
				acemenupanel.FuelTankData.FuelID = data
				ACE.FuelTankGUIUpdate( Table )
			end

			FuelTypeComboList:SetText(acemenupanel.FuelTankData.FuelID)
			RunConsoleCommand( "acemenu_data2", acemenupanel.FuelTankData.FuelID )
			MainPanel:AddItem( FuelTypeComboList )

			acemenupanel:CPanelText("Cap", "")
			acemenupanel:CPanelText("Mass", "")

		end

		local CrateNewCat = vgui.Create( "DCollapsibleCategory" )	-- Create a collapsible category
		acemenupanel.CustomDisplay:AddItem(CrateNewCat)
		CrateNewCat:SetLabel( "Tank Config" )						-- Set the name ( label )
		CrateNewCat:SetPos( 25, 50 )		-- Set position
		CrateNewCat:SetSize( 250, 100 )	-- Set size
		CrateNewCat:SetExpanded( acemenupanel.FuelPanelConfig["ExpandedCatNew"] )

		function CrateNewCat:OnToggle( bool )
		   acemenupanel.FuelPanelConfig["ExpandedCatNew"] = bool
		end

		local CrateNewPanel = vgui.Create( "DPanelList" )
		CrateNewPanel:SetSpacing( 10 )
		CrateNewPanel:EnableHorizontal( false )
		CrateNewPanel:EnableVerticalScrollbar( true )
		CrateNewPanel:SetPaintBackground( false )
		CrateNewCat:SetContents( CrateNewPanel )

		local CrateOldCat = vgui.Create( "DCollapsibleCategory" )
		acemenupanel.CustomDisplay:AddItem(CrateOldCat)
		CrateOldCat:SetLabel( "Tank Config (legacy)" )
		CrateOldCat:SetPos( 25, 50 )
		CrateOldCat:SetSize( 250, 100 )
		CrateOldCat:SetExpanded( acemenupanel.FuelPanelConfig["ExpandedCatOld"] )

		function CrateOldCat:OnToggle( bool )
		   acemenupanel.FuelPanelConfig["ExpandedCatOld"] = bool
		end

		local CrateOldPanel = vgui.Create( "DPanelList" )
		CrateOldPanel:SetSpacing( 10 )
		CrateOldPanel:EnableHorizontal( false )
		CrateOldPanel:EnableVerticalScrollbar( true )
		CrateOldPanel:SetPaintBackground( false )
		CrateOldCat:SetContents( CrateOldPanel )


		--------------- NEW CONFIG ---------------
		do

			local MinCrateSize = ACE.CrateMinimumSize or 5
			local MaxCrateSize = ACE.CrateMaximumSize

			acemenupanel:CPanelText("Crate_desc_new", "\nAdjust the dimensions for your tank. In inches.", nil, CrateNewPanel)

			-- The ComboList
			local ShapeComboList = vgui.Create( "DComboBox" )
			ShapeComboList:SetSize(100, 30)

			local OnList = {}
			for _,v in pairs(ACE.ModelData) do
				if v.volumefunction and not OnList[v.Shape] then
					OnList[v.Shape] = true
					ShapeComboList:AddChoice( v.Shape or "no name" )
				end
			end

			ShapeComboList.OnSelect = function( _, _, data )
				acemenupanel.FuelPanelConfig["Crate_Shape"] = data
				RunConsoleCommand( "acemenu_data3", data )
				ACE.FuelTankGUIUpdate( Table )
			end

			RunConsoleCommand( "acemenu_data3", acemenupanel.FuelPanelConfig["Crate_Shape"] )
			ShapeComboList:SetText(acemenupanel.FuelPanelConfig["Crate_Shape"])
			CrateNewPanel:AddItem( ShapeComboList )

			-- X Slider
			local LenghtSlider = vgui.Create( "DNumSlider" )
			LenghtSlider:SetText( "Length" )
			LenghtSlider:SetDark( true )
			LenghtSlider:SetMin( MinCrateSize )
			LenghtSlider:SetMax( MaxCrateSize )
			LenghtSlider:SetValue( acemenupanel.FuelPanelConfig["Crate_Length"] or 10 )
			LenghtSlider:SetDecimals( 1 )

			function LenghtSlider:OnValueChanged( value )
			acemenupanel.FuelPanelConfig["Crate_Length"] = value
			CreateIdForCrate()
			end
			CrateNewPanel:AddItem(LenghtSlider)

			-- Y Slider
			local WidthSlider = vgui.Create( "DNumSlider" )
			WidthSlider:SetText( "Width" )
			WidthSlider:SetDark( true )
			WidthSlider:SetMin( MinCrateSize )
			WidthSlider:SetMax( MaxCrateSize )
			WidthSlider:SetValue( acemenupanel.FuelPanelConfig["Crate_Width"] or 10 )
			WidthSlider:SetDecimals( 1 )

			function WidthSlider:OnValueChanged( value )
			acemenupanel.FuelPanelConfig["Crate_Width"] = value
			CreateIdForCrate()
			end
			CrateNewPanel:AddItem(WidthSlider)

			-- Z Slider
			local HeightSlider = vgui.Create( "DNumSlider" )
			HeightSlider:SetText( "Height" )
			HeightSlider:SetDark( true )
			HeightSlider:SetMin( MinCrateSize )
			HeightSlider:SetMax( MaxCrateSize )
			HeightSlider:SetValue( acemenupanel.FuelPanelConfig["Crate_Height"] or 10 )
			HeightSlider:SetDecimals( 1 )

			function HeightSlider:OnValueChanged( value )
			acemenupanel.FuelPanelConfig["Crate_Height"] = value
			CreateIdForCrate()
			end
			CrateNewPanel:AddItem(HeightSlider)

		end
		----------- legacy tank size dropbox -----------
		do

			acemenupanel:CPanelText("Fuel_desc_legacy", "\nChoose a fueltank in the legacy way. Remember to enable the checkbox below to do so.", nil, CrateOldPanel)

			-- The checkbox
			local LegacyCheck = vgui.Create( "DCheckBoxLabel" ) -- Create the checkbox
			LegacyCheck:SetPos( 25, 50 )						      -- Set the position
			LegacyCheck:SetText("Use Legacy Mode")					   -- Set the text next to the box
			LegacyCheck:SetDark( true )
			LegacyCheck:SetChecked( acemenupanel.FuelPanelConfig.LegacyFuels or false )						   -- Initial value
			LegacyCheck:SizeToContents()						      -- Make its size the same as the contents

			function LegacyCheck:OnChange( val )
				acemenupanel.FuelPanelConfig["LegacyFuels"] = val
				if val then
					acemenupanel.FuelTankData.Id =  acemenupanel.FuelTankData.IdLegacy
					RunConsoleCommand( "acemenu_data1", acemenupanel.FuelTankData.Id )
					ACE.FuelTankGUIUpdate( Table )
				else
					CreateIdForCrate()
				end

			end
			CrateOldPanel:AddItem(LegacyCheck)

			-- The ComboList
			local FuelTankComboList = vgui.Create( "DComboBox", MainPanel )
			FuelTankComboList:SetSize(100, 30)
			for _,v in ipairs(SortedTanks) do
				FuelTankComboList:AddChoice( v )
			end

			FuelTankComboList.OnSelect = function( _, _, data )
				acemenupanel.FuelTankData.Id = data
				acemenupanel.FuelTankData.IdLegacy = data
				RunConsoleCommand( "acemenu_data1", data )
				ACE.FuelTankGUIUpdate( Table )

				if acemenupanel.CData.DisplayModel then

					local Model = Tanks[acemenupanel.FuelTankData.IdLegacy].model
					acemenupanel.CData.DisplayModel:SetModel(Model)
					acemenupanel:CPanelText("CrateDesc", Tanks[acemenupanel.FuelTankData.Id].desc, nil, CrateOldPanel)

				end
			end

			FuelTankComboList:SetText(acemenupanel.FuelTankData.IdLegacy)
			RunConsoleCommand( "acemenu_data1", acemenupanel.FuelTankData.Id )
			CrateOldPanel:AddItem( FuelTankComboList )

			acemenupanel:CPanelText("TankName", "", nil, CrateOldPanel)
			acemenupanel:CPanelText("TankDesc", "", nil, CrateOldPanel)

			acemenupanel.CData.DisplayModel = vgui.Create( "DModelPanel", CrateOldPanel )
			acemenupanel.CData.DisplayModel:SetModel( Tanks[acemenupanel.FuelTankData.IdLegacy].model )
			acemenupanel.CData.DisplayModel:SetCamPos( Vector( 250, 500, 200 ) )
			acemenupanel.CData.DisplayModel:SetLookAt( Vector( 0, 0, 0 ) )
			acemenupanel.CData.DisplayModel:SetFOV( 10 )
			acemenupanel.CData.DisplayModel:SetSize(acemenupanel:GetWide(),acemenupanel:GetWide() / 2)
			acemenupanel.CData.DisplayModel.LayoutEntity = function( _, _ ) end
			CrateOldPanel:AddItem( acemenupanel.CData.DisplayModel )

		end

		----------- The rest below -----------

		ACE.FuelTankGUIUpdate( Table )

		MainPanel:PerformLayout()

	end

	function ACE.FuelTankGUIUpdate( _ )

		if not acemenupanel.CustomDisplay then return end

		if acemenupanel.FuelPanelConfig["LegacyFuels"] then

			local TankID    = acemenupanel.FuelTankData.Id
			local FuelID    = acemenupanel.FuelTankData.FuelID
			local Dims      = Tanks[TankID].dims

			local Volume    = Dims.V - (Dims.S * Wall)                              -- total volume of tank (cu in), reduced by wall thickness
			local Capacity  = Volume * ACE.CuIToLiter * ACE.TankVolumeMul * 0.4774  -- internal volume available for fuel in liters, with magic realism number
			local EmptyMass = ((Dims.S * Wall) * 16.387) * ( 7.9 / 1000 )                   -- total wall volume * cu in to cc * density of steel (kg/cc)
			local Mass      = EmptyMass + Capacity * ACE.FuelDensity[FuelID]        -- weight of tank + weight of fuel

			--fuel and tank info
			if FuelID == "Electric" then
				local kwh = Capacity * ACE.LiIonED
				acemenupanel:CPanelText("TankName", Tanks[TankID].name .. " Li-Ion Battery")
				acemenupanel:CPanelText("TankDesc", Tanks[TankID].desc .. "\n")
				acemenupanel:CPanelText("Cap", "Charge: " .. math.Round(kwh,1) .. " kW hours / " .. math.Round( kwh * 3.6,1) .. " MJ")
				acemenupanel:CPanelText("Mass", "Mass: " .. math.Round(Mass,1) .. " kg")
			else
				acemenupanel:CPanelText("TankName", Tanks[TankID].name .. " fuel tank")
				acemenupanel:CPanelText("TankDesc", Tanks[TankID].desc .. "\n")
				acemenupanel:CPanelText("Cap", "Capacity: " .. math.Round(Capacity,1) .. " liters / " .. math.Round(Capacity * 0.264172,1) .. " gallons")
				acemenupanel:CPanelText("Mass", "Full mass: " .. math.Round(Mass,1) .. " kg, Empty mass: " .. math.Round(EmptyMass,1) .. " kg")
			end

			local text = "\n"
			if Tanks[TankID].nolinks then
				text = "\nThis fuel tank won\'t link to engines. It's intended to resupply fuel to other fuel tanks."
			end
			acemenupanel:CPanelText("Links", text)

			--fuel tank model display
			acemenupanel.CData.DisplayModel:SetModel( Tanks[TankID].model )

		else

			local Length = acemenupanel.FuelPanelConfig["Crate_Length"]
			local Width = acemenupanel.FuelPanelConfig["Crate_Width"]
			local Height = acemenupanel.FuelPanelConfig["Crate_Height"]
			local Shape = acemenupanel.FuelPanelConfig["Crate_Shape"]

			local ModelData = ACE.ModelData[Shape]

			local CrateVolume = ModelData.volumefunction( Length, Width, Height)
			local ContentVolume = ModelData.volumefunction( Length - (Wall * 2), Width - (Wall * 2), Height - (Wall * 2))

			local Capacity  = ContentVolume * ACE.CuIToLiter * ACE.TankVolumeMul * 0.4774  -- internal volume available for fuel in liters, with magic realism number
			local EmptyMass = (CrateVolume - ContentVolume) * 16.387 * ( 7.9 / 1000 )               -- total wall volume * cu in to cc * density of steel (kg/cc)
			local Mass      = EmptyMass + Capacity * ACE.FuelDensity[acemenupanel.FuelTankData.FuelID]        -- weight of tank + weight of fuel

			--fuel and tank info
			if acemenupanel.FuelTankData.FuelID == "Electric" then
				local kwh = Capacity * ACE.LiIonED
				acemenupanel:CPanelText("Cap", "Charge: " .. math.Round(kwh,1) .. " kW hours / " .. math.Round( kwh * 3.6,1) .. " MJ")
				acemenupanel:CPanelText("Mass", "Mass: " .. math.Round(Mass,1) .. " kg")
			else
				acemenupanel:CPanelText("Cap", "Capacity: " .. math.Round(Capacity,1) .. " liters / " .. math.Round(Capacity * 0.264172,1) .. " gallons")
				acemenupanel:CPanelText("Mass", "Full mass: " .. math.Round(Mass,1) .. " kg, Empty mass: " .. math.Round(EmptyMass,1) .. " kg")
			end

		end

	end
end
