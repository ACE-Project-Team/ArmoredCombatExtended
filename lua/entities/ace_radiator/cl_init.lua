
include("shared.lua")

CreateClientConVar("ACF_FuelInfoWhileSeated", 0, true, false)

-- copied from base_wire_entity: DoNormalDraw's notip arg isn't accessible from ENT:Draw defined there.
function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not GetConVar("ACF_FuelInfoWhileSeated"):GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end

do

	local Wall = 0.75 -- wall thickness in inches

	local function CreateIdForCrate()

		   local X = math.Round( acfmenupanel.RadiatorPanelConfig["Crate_Length"], 1 )
		   local Y = math.Round( acfmenupanel.RadiatorPanelConfig["Crate_Width"], 1 )
		   local Z = math.Round( acfmenupanel.RadiatorPanelConfig["Crate_Height"], 1)

		   local Id = X .. ":" .. Y .. ":" .. Z

		   ACFRadiatorGUIUpdate( Table )
		   acfmenupanel.RadiatorData["Id"] = Id
		   RunConsoleCommand( "acfmenu_data1", Id )

	 end

	function ACFRadiatorGUICreate( Table )
		if not acfmenupanel.CustomDisplay then return end

		local MainPanel = acfmenupanel.CustomDisplay

		if not acfmenupanel.RadiatorData then
			acfmenupanel.RadiatorData          = {}
			acfmenupanel.RadiatorData.Id       = "10:10:10"
		end

		if not acfmenupanel.RadiatorPanelConfig then

			acfmenupanel.RadiatorPanelConfig = {}
			acfmenupanel.RadiatorPanelConfig["Crate_Length"]  = 1
			acfmenupanel.RadiatorPanelConfig["Crate_Width"]   = 10
			acfmenupanel.RadiatorPanelConfig["Crate_Height"]  = 10
			acfmenupanel.RadiatorPanelConfig["Crate_Shape"] = "Radiator"

		 end

		acfmenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")
		acfmenupanel:CPanelText("Desc", Table.desc)

		--------------- NEW CONFIG ---------------
		do

			local CrateNewCat = vgui.Create( "DCollapsibleCategory" )	-- Create a collapsible category
			acfmenupanel.CustomDisplay:AddItem(CrateNewCat)
			CrateNewCat:SetLabel( "Radiator Config" )						-- Set the name ( label )
			CrateNewCat:SetPos( 25, 50 )		-- Set position
			CrateNewCat:SetSize( 250, 100 )	-- Set size
			CrateNewCat:SetExpanded( acfmenupanel.RadiatorPanelConfig["ExpandedCatNew"] )
	
			function CrateNewCat:OnToggle( bool )
			   acfmenupanel.RadiatorPanelConfig["ExpandedCatNew"] = bool
			end

			local CrateNewPanel = vgui.Create( "DPanelList" )
			CrateNewPanel:SetSpacing( 10 )
			CrateNewPanel:EnableHorizontal( false )
			CrateNewPanel:EnableVerticalScrollbar( true )
			CrateNewPanel:SetPaintBackground( false )
			CrateNewPanel:AddItem(LengthSlider)
			CrateNewCat:SetContents( CrateNewPanel )

			local MinCrateSize = ACF.CrateMinimumSize or 1
			local MaxCrateSize = ACF.CrateMaximumSize

			acfmenupanel:CPanelText("Crate_desc_new", "\nAdjust the dimensions for the radiator. In inches.", nil, CrateNewPanel)

			-- X Slider
			local LengthSlider = vgui.Create( "DNumSlider" )
			LengthSlider:SetText( "Length" )
			LengthSlider:SetDark( true )
			LengthSlider:SetMin( MinCrateSize )
			LengthSlider:SetMax( MaxCrateSize )
			LengthSlider:SetValue( acfmenupanel.RadiatorPanelConfig["Crate_Length"] or 10 )
			LengthSlider:SetDecimals( 1 )

			function LengthSlider:OnValueChanged( value )
				acfmenupanel.RadiatorPanelConfig["Crate_Length"] = value
				CreateIdForCrate()
			end
			CrateNewPanel:AddItem(LengthSlider)
	
			-- Y Slider
			local WidthSlider = vgui.Create( "DNumSlider" )
			WidthSlider:SetText( "Width" )
			WidthSlider:SetDark( true )
			WidthSlider:SetMin( MinCrateSize )
			WidthSlider:SetMax( MaxCrateSize )
			WidthSlider:SetValue( acfmenupanel.RadiatorPanelConfig["Crate_Width"] or 10 )
			WidthSlider:SetDecimals( 1 )

			function WidthSlider:OnValueChanged( value )
			acfmenupanel.RadiatorPanelConfig["Crate_Width"] = value
			CreateIdForCrate()
			end
			CrateNewPanel:AddItem(WidthSlider)

			-- Z Slider
			local HeightSlider = vgui.Create( "DNumSlider" )
			HeightSlider:SetText( "Height" )
			HeightSlider:SetDark( true )
			HeightSlider:SetMin( MinCrateSize )
			HeightSlider:SetMax( MaxCrateSize )
			HeightSlider:SetValue( acfmenupanel.RadiatorPanelConfig["Crate_Height"] or 10 )
			HeightSlider:SetDecimals( 1 )

			function HeightSlider:OnValueChanged( value )
			acfmenupanel.RadiatorPanelConfig["Crate_Height"] = value
			CreateIdForCrate()
			end
			CrateNewPanel:AddItem(HeightSlider)

		end

		----------- The rest below -----------

		ACFRadiatorGUIUpdate( Table )

		MainPanel:PerformLayout()

	end

	function ACFRadiatorGUIUpdate( _ )

		if not acfmenupanel.CustomDisplay then return end

			local Length = acfmenupanel.RadiatorPanelConfig["Crate_Length"]
			local Width = acfmenupanel.RadiatorPanelConfig["Crate_Width"]
			local Height = acfmenupanel.RadiatorPanelConfig["Crate_Height"]
			local Shape = "Box" --Box

			local ModelData = ACE.ModelData[Shape]

			local CrateVolume = ModelData.volumefunction( Length, Width, Height)
			local ContentVolume = math.max(ModelData.volumefunction( Length, Width - (Wall * 2), Height - (Wall * 2)) * 0.7,0) --Assume 2/3rds volume radiator fins, 1/3rd water

			local Capacity  = ContentVolume * ACF.CuIToLiter * ACF.TankVolumeMul * 0.4774  -- internal volume available for fuel in liters, with magic realism number
			local EmptyMass = (CrateVolume - ContentVolume) * 16.387 * ( 2.6 / 1000 )               -- total wall volume * cu in to cc * density of aluminum (kg/cc)
			local Mass      = EmptyMass + Capacity --* 1   Conversion Ommited    -- weight of tank + weight of contained water. Water is 1kg/Liter

			local FinsPerInch = 15
			local FinPackRatio = 0.5 --Ratio of volume fins to volume air in radiator

			local FinHeight = (1/FinsPerInch) * FinPackRatio --Air/Fin ratio.

			local finSize = Length * Width * 2 + Width * FinHeight * 2 --Surface area of one fin(Top and bottom)

			local FinCount = Height / FinsPerInch

			local TotalSurfaceArea = finSize * FinCount / 1550

			--local AirflowRestrictiveness = 1-(1-(1/Length))^2 --Airflow ratio of the radiator. Difficulty air flowing through it will have cooling anything.

			acfmenupanel:CPanelText("Mass", "Full mass: " .. math.Round(Mass,1) .. " kg, Empty mass: " .. math.Round(EmptyMass,1) .. " kg")
			acfmenupanel:CPanelText("Cap", "Capacity: " .. math.Round(Capacity,1) .. " liters / " .. math.Round(Capacity * 0.264172,1) .. " gallons")

			--acfmenupanel:CPanelText("RestrictedFlow", "Airflow restriction: " .. math.Round(AirflowRestrictiveness * 100,1) .. "%")

			acfmenupanel:CPanelText("Area", "Total Fin Surface Area: " .. math.Round(TotalSurfaceArea,1) .. " m^2")
			local specificHeat = (EmptyMass * 0.9211 + Capacity * 4.184) / Mass
			local KJTo100C = Mass * specificHeat * 100 * ACF.RadiatorHeatCap --Heat capacity of the radiator. Joules needed to raise the radiator to 100C.
			acfmenupanel:CPanelText("ThermalStorage", "" .. math.Round(KJTo100C,1) .. " kilojoules needed to raise the radiator to 100C")


	end
end