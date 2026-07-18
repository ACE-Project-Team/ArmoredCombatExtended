
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
	local TankTable = ACF.Weapons
	local Tanks = TankTable.FuelTanksSize

	for n in pairs(Tanks) do
		table.insert(SortedTanks,n)
	end
	table.sort(SortedTanks)

	local function CreateIdForCrate()

		if not acfmenupanel.FuelPanelConfig["LegacyFuels"] then

		   local X = math.Round( acfmenupanel.FuelPanelConfig["Crate_Length"], 1 )
		   local Y = math.Round( acfmenupanel.FuelPanelConfig["Crate_Width"], 1 )
		   local Z = math.Round( acfmenupanel.FuelPanelConfig["Crate_Height"], 1)

		   local Id = X .. ":" .. Y .. ":" .. Z

		   ACE.FuelTankGUIUpdate( Table )
		   acfmenupanel.FuelTankData["Id"] = Id
		   RunConsoleCommand( "acfmenu_data1", Id )

		end

	 end

	function ACE.FuelTankGUICreate( Table )
		if not acfmenupanel.CustomDisplay then return end

		local MainPanel = acfmenupanel.CustomDisplay

		if not acfmenupanel.FuelTankData then
			acfmenupanel.FuelTankData          = {}
			acfmenupanel.FuelTankData.Id       = "10:10:10"
			acfmenupanel.FuelTankData.IdLegacy = "Tank_4x4x2"
			acfmenupanel.FuelTankData.FuelID   = "Petrol"
		end

		if not acfmenupanel.FuelPanelConfig then

			acfmenupanel.FuelPanelConfig = {}
			acfmenupanel.FuelPanelConfig["ExpandedCatNew"] = true
			acfmenupanel.FuelPanelConfig["ExpandedCatOld"] = false
			acfmenupanel.FuelPanelConfig["LegacyFuels"]   = false
			acfmenupanel.FuelPanelConfig["Crate_Length"]  = 10
			acfmenupanel.FuelPanelConfig["Crate_Width"]   = 10
			acfmenupanel.FuelPanelConfig["Crate_Height"]  = 10
			acfmenupanel.FuelPanelConfig["Crate_Shape"] = "Box"

		 end

		acfmenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")
		acfmenupanel:CPanelText("Desc", Table.desc)

		----------- fuel type dropbox -----------
		do

			acfmenupanel:CPanelText("Fueltype_desc", "\nChoose a fuel type" )

			local FuelTypeComboList = vgui.Create( "DComboBox", MainPanel )
			FuelTypeComboList:SetSize(100, 30)
			for Key, _ in pairs( ACF.FuelDensity ) do
				FuelTypeComboList:AddChoice( Key )
			end

			FuelTypeComboList.OnSelect = function( _, _, data )
				RunConsoleCommand( "acfmenu_data2", data )
				acfmenupanel.FuelTankData.FuelID = data
				ACE.FuelTankGUIUpdate( Table )
			end

			FuelTypeComboList:SetText(acfmenupanel.FuelTankData.FuelID)
			RunConsoleCommand( "acfmenu_data2", acfmenupanel.FuelTankData.FuelID )
			MainPanel:AddItem( FuelTypeComboList )

			acfmenupanel:CPanelText("Cap", "")
			acfmenupanel:CPanelText("Mass", "")

		end

		local CrateNewCat = vgui.Create( "DCollapsibleCategory" )	-- Create a collapsible category
		acfmenupanel.CustomDisplay:AddItem(CrateNewCat)
		CrateNewCat:SetLabel( "Tank Config" )						-- Set the name ( label )
		CrateNewCat:SetPos( 25, 50 )		-- Set position
		CrateNewCat:SetSize( 250, 100 )	-- Set size
		CrateNewCat:SetExpanded( acfmenupanel.FuelPanelConfig["ExpandedCatNew"] )

		function CrateNewCat:OnToggle( bool )
		   acfmenupanel.FuelPanelConfig["ExpandedCatNew"] = bool
		end

		local CrateNewPanel = vgui.Create( "DPanelList" )
		CrateNewPanel:SetSpacing( 10 )
		CrateNewPanel:EnableHorizontal( false )
		CrateNewPanel:EnableVerticalScrollbar( true )
		CrateNewPanel:SetPaintBackground( false )
		CrateNewCat:SetContents( CrateNewPanel )

		local CrateOldCat = vgui.Create( "DCollapsibleCategory" )
		acfmenupanel.CustomDisplay:AddItem(CrateOldCat)
		CrateOldCat:SetLabel( "Tank Config (legacy)" )
		CrateOldCat:SetPos( 25, 50 )
		CrateOldCat:SetSize( 250, 100 )
		CrateOldCat:SetExpanded( acfmenupanel.FuelPanelConfig["ExpandedCatOld"] )

		function CrateOldCat:OnToggle( bool )
		   acfmenupanel.FuelPanelConfig["ExpandedCatOld"] = bool
		end

		local CrateOldPanel = vgui.Create( "DPanelList" )
		CrateOldPanel:SetSpacing( 10 )
		CrateOldPanel:EnableHorizontal( false )
		CrateOldPanel:EnableVerticalScrollbar( true )
		CrateOldPanel:SetPaintBackground( false )
		CrateOldCat:SetContents( CrateOldPanel )


		--------------- NEW CONFIG ---------------
		do

			local MinCrateSize = ACF.CrateMinimumSize or 5
			local MaxCrateSize = ACF.CrateMaximumSize

			acfmenupanel:CPanelText("Crate_desc_new", "\nAdjust the dimensions for your tank. In inches.", nil, CrateNewPanel)

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
				acfmenupanel.FuelPanelConfig["Crate_Shape"] = data
				RunConsoleCommand( "acfmenu_data3", data )
				ACE.FuelTankGUIUpdate( Table )
			end

			RunConsoleCommand( "acfmenu_data3", acfmenupanel.FuelPanelConfig["Crate_Shape"] )
			ShapeComboList:SetText(acfmenupanel.FuelPanelConfig["Crate_Shape"])
			CrateNewPanel:AddItem( ShapeComboList )

			-- X Slider
			local LenghtSlider = vgui.Create( "DNumSlider" )
			LenghtSlider:SetText( "Length" )
			LenghtSlider:SetDark( true )
			LenghtSlider:SetMin( MinCrateSize )
			LenghtSlider:SetMax( MaxCrateSize )
			LenghtSlider:SetValue( acfmenupanel.FuelPanelConfig["Crate_Length"] or 10 )
			LenghtSlider:SetDecimals( 1 )

			function LenghtSlider:OnValueChanged( value )
			acfmenupanel.FuelPanelConfig["Crate_Length"] = value
			CreateIdForCrate()
			end
			CrateNewPanel:AddItem(LenghtSlider)

			-- Y Slider
			local WidthSlider = vgui.Create( "DNumSlider" )
			WidthSlider:SetText( "Width" )
			WidthSlider:SetDark( true )
			WidthSlider:SetMin( MinCrateSize )
			WidthSlider:SetMax( MaxCrateSize )
			WidthSlider:SetValue( acfmenupanel.FuelPanelConfig["Crate_Width"] or 10 )
			WidthSlider:SetDecimals( 1 )

			function WidthSlider:OnValueChanged( value )
			acfmenupanel.FuelPanelConfig["Crate_Width"] = value
			CreateIdForCrate()
			end
			CrateNewPanel:AddItem(WidthSlider)

			-- Z Slider
			local HeightSlider = vgui.Create( "DNumSlider" )
			HeightSlider:SetText( "Height" )
			HeightSlider:SetDark( true )
			HeightSlider:SetMin( MinCrateSize )
			HeightSlider:SetMax( MaxCrateSize )
			HeightSlider:SetValue( acfmenupanel.FuelPanelConfig["Crate_Height"] or 10 )
			HeightSlider:SetDecimals( 1 )

			function HeightSlider:OnValueChanged( value )
			acfmenupanel.FuelPanelConfig["Crate_Height"] = value
			CreateIdForCrate()
			end
			CrateNewPanel:AddItem(HeightSlider)

		end
		----------- legacy tank size dropbox -----------
		do

			acfmenupanel:CPanelText("Fuel_desc_legacy", "\nChoose a fueltank in the legacy way. Remember to enable the checkbox below to do so.", nil, CrateOldPanel)

			-- The checkbox
			local LegacyCheck = vgui.Create( "DCheckBoxLabel" ) -- Create the checkbox
			LegacyCheck:SetPos( 25, 50 )						      -- Set the position
			LegacyCheck:SetText("Use Legacy Mode")					   -- Set the text next to the box
			LegacyCheck:SetDark( true )
			LegacyCheck:SetChecked( acfmenupanel.FuelPanelConfig.LegacyFuels or false )						   -- Initial value
			LegacyCheck:SizeToContents()						      -- Make its size the same as the contents

			function LegacyCheck:OnChange( val )
				acfmenupanel.FuelPanelConfig["LegacyFuels"] = val
				if val then
					acfmenupanel.FuelTankData.Id =  acfmenupanel.FuelTankData.IdLegacy
					RunConsoleCommand( "acfmenu_data1", acfmenupanel.FuelTankData.Id )
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
				acfmenupanel.FuelTankData.Id = data
				acfmenupanel.FuelTankData.IdLegacy = data
				RunConsoleCommand( "acfmenu_data1", data )
				ACE.FuelTankGUIUpdate( Table )

				if acfmenupanel.CData.DisplayModel then

					local Model = Tanks[acfmenupanel.FuelTankData.IdLegacy].model
					acfmenupanel.CData.DisplayModel:SetModel(Model)
					acfmenupanel:CPanelText("CrateDesc", Tanks[acfmenupanel.FuelTankData.Id].desc, nil, CrateOldPanel)

				end
			end

			FuelTankComboList:SetText(acfmenupanel.FuelTankData.IdLegacy)
			RunConsoleCommand( "acfmenu_data1", acfmenupanel.FuelTankData.Id )
			CrateOldPanel:AddItem( FuelTankComboList )

			acfmenupanel:CPanelText("TankName", "", nil, CrateOldPanel)
			acfmenupanel:CPanelText("TankDesc", "", nil, CrateOldPanel)

			acfmenupanel.CData.DisplayModel = vgui.Create( "DModelPanel", CrateOldPanel )
			acfmenupanel.CData.DisplayModel:SetModel( Tanks[acfmenupanel.FuelTankData.IdLegacy].model )
			acfmenupanel.CData.DisplayModel:SetCamPos( Vector( 250, 500, 200 ) )
			acfmenupanel.CData.DisplayModel:SetLookAt( Vector( 0, 0, 0 ) )
			acfmenupanel.CData.DisplayModel:SetFOV( 10 )
			acfmenupanel.CData.DisplayModel:SetSize(acfmenupanel:GetWide(),acfmenupanel:GetWide() / 2)
			acfmenupanel.CData.DisplayModel.LayoutEntity = function( _, _ ) end
			CrateOldPanel:AddItem( acfmenupanel.CData.DisplayModel )

		end

		----------- The rest below -----------

		ACE.FuelTankGUIUpdate( Table )

		MainPanel:PerformLayout()

	end

	function ACE.FuelTankGUIUpdate( _ )

		if not acfmenupanel.CustomDisplay then return end

		if acfmenupanel.FuelPanelConfig["LegacyFuels"] then

			local TankID    = acfmenupanel.FuelTankData.Id
			local FuelID    = acfmenupanel.FuelTankData.FuelID
			local Dims      = Tanks[TankID].dims

			local Volume    = Dims.V - (Dims.S * Wall)                              -- total volume of tank (cu in), reduced by wall thickness
			local Capacity  = Volume * ACF.CuIToLiter * ACF.TankVolumeMul * 0.4774  -- internal volume available for fuel in liters, with magic realism number
			local EmptyMass = ((Dims.S * Wall) * 16.387) * ( 7.9 / 1000 )                   -- total wall volume * cu in to cc * density of steel (kg/cc)
			local Mass      = EmptyMass + Capacity * ACF.FuelDensity[FuelID]        -- weight of tank + weight of fuel

			--fuel and tank info
			if FuelID == "Electric" then
				local kwh = Capacity * ACF.LiIonED
				acfmenupanel:CPanelText("TankName", Tanks[TankID].name .. " Li-Ion Battery")
				acfmenupanel:CPanelText("TankDesc", Tanks[TankID].desc .. "\n")
				acfmenupanel:CPanelText("Cap", "Charge: " .. math.Round(kwh,1) .. " kW hours / " .. math.Round( kwh * 3.6,1) .. " MJ")
				acfmenupanel:CPanelText("Mass", "Mass: " .. math.Round(Mass,1) .. " kg")
			else
				acfmenupanel:CPanelText("TankName", Tanks[TankID].name .. " fuel tank")
				acfmenupanel:CPanelText("TankDesc", Tanks[TankID].desc .. "\n")
				acfmenupanel:CPanelText("Cap", "Capacity: " .. math.Round(Capacity,1) .. " liters / " .. math.Round(Capacity * 0.264172,1) .. " gallons")
				acfmenupanel:CPanelText("Mass", "Full mass: " .. math.Round(Mass,1) .. " kg, Empty mass: " .. math.Round(EmptyMass,1) .. " kg")
			end

			local text = "\n"
			if Tanks[TankID].nolinks then
				text = "\nThis fuel tank won\'t link to engines. It's intended to resupply fuel to other fuel tanks."
			end
			acfmenupanel:CPanelText("Links", text)

			--fuel tank model display
			acfmenupanel.CData.DisplayModel:SetModel( Tanks[TankID].model )

		else

			local Length = acfmenupanel.FuelPanelConfig["Crate_Length"]
			local Width = acfmenupanel.FuelPanelConfig["Crate_Width"]
			local Height = acfmenupanel.FuelPanelConfig["Crate_Height"]
			local Shape = acfmenupanel.FuelPanelConfig["Crate_Shape"]

			local ModelData = ACE.ModelData[Shape]

			local CrateVolume = ModelData.volumefunction( Length, Width, Height)
			local ContentVolume = ModelData.volumefunction( Length - (Wall * 2), Width - (Wall * 2), Height - (Wall * 2))

			local Capacity  = ContentVolume * ACF.CuIToLiter * ACF.TankVolumeMul * 0.4774  -- internal volume available for fuel in liters, with magic realism number
			local EmptyMass = (CrateVolume - ContentVolume) * 16.387 * ( 7.9 / 1000 )               -- total wall volume * cu in to cc * density of steel (kg/cc)
			local Mass      = EmptyMass + Capacity * ACF.FuelDensity[acfmenupanel.FuelTankData.FuelID]        -- weight of tank + weight of fuel

			--fuel and tank info
			if acfmenupanel.FuelTankData.FuelID == "Electric" then
				local kwh = Capacity * ACF.LiIonED
				acfmenupanel:CPanelText("Cap", "Charge: " .. math.Round(kwh,1) .. " kW hours / " .. math.Round( kwh * 3.6,1) .. " MJ")
				acfmenupanel:CPanelText("Mass", "Mass: " .. math.Round(Mass,1) .. " kg")
			else
				acfmenupanel:CPanelText("Cap", "Capacity: " .. math.Round(Capacity,1) .. " liters / " .. math.Round(Capacity * 0.264172,1) .. " gallons")
				acfmenupanel:CPanelText("Mass", "Full mass: " .. math.Round(Mass,1) .. " kg, Empty mass: " .. math.Round(EmptyMass,1) .. " kg")
			end

		end

	end
end
