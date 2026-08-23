
include("shared.lua")

CreateClientConVar("ace_gearbox_info_while_seated", 0, true, false)

-- copied from base_wire_entity: DoNormalDraw's notip arg isn't accessible from ENT:Draw defined there.
function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not GetConVar("ace_gearbox_info_while_seated"):GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end

function ACE_GearboxGUICreate( Table )

	if not acemenupanel.Serialize then
		acemenupanel.Serialize = function( tbl, factor )
			local str = ""
			for i = 1,7 do
				str = str .. math.Round(tbl[i] * factor,1) .. ","
			end
			RunConsoleCommand( "acemenu_data9", str )
		end
	end

	if not acemenupanel.GearboxData then
		acemenupanel.GearboxData = {}
	end

	if not acemenupanel.GearboxData[Table.id] then
		acemenupanel.GearboxData[Table.id] = {}
		acemenupanel.GearboxData[Table.id].GearTable = Table.geartable
	end

	if Table.auto and not acemenupanel.GearboxData[Table.id].ShiftTable then
		acemenupanel.GearboxData[Table.id].ShiftTable = {10,20,30,40,50,60,70}
	end

	acemenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	acemenupanel.CData.DisplayModel = vgui.Create( "DModelPanel", acemenupanel.CustomDisplay )
		acemenupanel.CData.DisplayModel:SetModel( Table.model )
		acemenupanel.CData.DisplayModel:SetCamPos( Vector( 250, 500, 250 ) )
		acemenupanel.CData.DisplayModel:SetLookAt( Vector( 0, 0, 0 ) )
		acemenupanel.CData.DisplayModel:SetFOV( 20 )
		acemenupanel.CData.DisplayModel:SetSize(acemenupanel:GetWide(),acemenupanel:GetWide())
		acemenupanel.CData.DisplayModel.LayoutEntity = function() end
	acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.DisplayModel )

	acemenupanel:CPanelText("Desc", Table.desc) --Description (Name, Desc)

	if Table.auto and not acemenupanel.CData.UnitsInput then
		acemenupanel.CData.UnitsInput = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )
			acemenupanel.CData.UnitsInput.ID = Table.id
			acemenupanel.CData.UnitsInput.Gears = Table.gears
			acemenupanel.CData.UnitsInput:SetSize( 60,22 )
			acemenupanel.CData.UnitsInput:SetTooltip( "If using the shift point generator, recalc after changing units." )
			acemenupanel.CData.UnitsInput:AddChoice( "KPH", 10.936, true )
			acemenupanel.CData.UnitsInput:AddChoice( "MPH", 17.6 )
			acemenupanel.CData.UnitsInput:AddChoice( "GMU", 1 )
			acemenupanel.CData.UnitsInput:SetDark( true )
			acemenupanel.CData.UnitsInput.OnSelect = function( panel, _, _, data )
				acemenupanel.Serialize( acemenupanel.GearboxData[panel.ID].ShiftTable, data )  --dot intentional
			end
		acemenupanel.CustomDisplay:AddItem(acemenupanel.CData.UnitsInput)
	end

	if Table.cvt then
		ACE_GearsSlider(2, acemenupanel.GearboxData[Table.id].GearTable[2], Table.id)
		ACE_GearsSlider(3, acemenupanel.GearboxData[Table.id].GearTable[-3], Table.id, "Min Target RPM",true)
		ACE_GearsSlider(4, acemenupanel.GearboxData[Table.id].GearTable[-2], Table.id, "Max Target RPM",true)
		ACE_GearsSlider(10, acemenupanel.GearboxData[Table.id].GearTable[-1], Table.id, "Final Drive")
		RunConsoleCommand( "acemenu_data1", 0.01 )
	else
		for ID,Value in pairs(acemenupanel.GearboxData[Table.id].GearTable) do
			if ID > 0 and not (Table.auto and ID == 8) then
				ACE_GearsSlider(ID, Value, Table.id)
				if Table.auto then
					ACE_ShiftPoint(ID, acemenupanel.GearboxData[Table.id].ShiftTable[ID], Table.id, "Gear " .. ID .. " upshift speed: ")
				end
			elseif Table.auto and (ID == -2 or ID == 8) then
				ACE_GearsSlider(8, Value, Table.id, "Reverse")
			elseif ID == -1 then
				ACE_GearsSlider(10, Value, Table.id, "Final Drive")
			end
		end
	end

	--
	local InvertButton = vgui.Create("DButton")
	InvertButton:SetText( "Invert Final drive" )
	InvertButton:SetIcon( "icon16/arrow_refresh.png" )
	InvertButton.DoClick = function()
		if acemenupanel.CData[10] then ---10 gear is the final drive

			local oldValue = acemenupanel.CData[10]:GetValue()
			acemenupanel.CData[10]:SetValue( oldValue * -1 )
		end
	end
	acemenupanel.CustomDisplay:AddItem(InvertButton)

	acemenupanel:CPanelText("Desc", Table.desc)
	acemenupanel:CPanelText("MaxTorque", "Clutch Maximum Torque Rating : " .. Table.maxtq .. "n-m / " .. math.Round(Table.maxtq * 0.73) .. "ft-lb")
	acemenupanel:CPanelText("Weight", "Weight : " .. Table.weight .. "kg\n")

	if Table.auto then
		acemenupanel:CPanelText( "ShiftPointGen", "Shift Point Generator:", "DermaDefaultBold" )

		if not acemenupanel.CData.ShiftGenPanel then
			acemenupanel.CData.ShiftGenPanel = vgui.Create( "DPanel" )
				acemenupanel.CData.ShiftGenPanel:SetPaintBackground( false )
				acemenupanel.CData.ShiftGenPanel:DockPadding( 4, 0, 4, 0 )
				acemenupanel.CData.ShiftGenPanel:SetTall( 60 )
				acemenupanel.CData.ShiftGenPanel:SizeToContentsX()
				acemenupanel.CData.ShiftGenPanel.Gears = Table.gears

			acemenupanel.CData.ShiftGenPanel.Calc = acemenupanel.CData.ShiftGenPanel:Add( "DButton" )
				acemenupanel.CData.ShiftGenPanel.Calc:SetText( "Calculate" )
				acemenupanel.CData.ShiftGenPanel.Calc:Dock( BOTTOM )
				acemenupanel.CData.ShiftGenPanel.Calc:SetTall( 20 )

				acemenupanel.CData.ShiftGenPanel.Calc.DoClick = function()
					local _, factor = acemenupanel.CData.UnitsInput:GetSelected()
					local mul = math.pi * acemenupanel.CData.ShiftGenPanel.RPM:GetValue() * acemenupanel.CData.ShiftGenPanel.Ratio:GetValue() * acemenupanel.CData[10]:GetValue() * acemenupanel.CData.ShiftGenPanel.Wheel:GetValue() / (60 * factor)
					for i = 1,acemenupanel.CData.ShiftGenPanel.Gears do
						acemenupanel.CData[10 + i].Input:SetValue( math.Round( math.abs( mul * acemenupanel.CData[i]:GetValue() ), 2 ) )
						acemenupanel.GearboxData[acemenupanel.CData.UnitsInput.ID].ShiftTable[i] = tonumber(acemenupanel.CData[10 + i].Input:GetValue())
					end
					acemenupanel.Serialize( acemenupanel.GearboxData[acemenupanel.CData.UnitsInput.ID].ShiftTable, factor )  --dot intentional
				end

				acemenupanel.CData.WheelPanel = acemenupanel.CData.ShiftGenPanel:Add( "DPanel" )
					acemenupanel.CData.WheelPanel:SetPaintBackground( false )
					acemenupanel.CData.WheelPanel:DockMargin( 4, 0, 4, 0 )
					acemenupanel.CData.WheelPanel:Dock( RIGHT )
					acemenupanel.CData.WheelPanel:SetWide( 76 )
					acemenupanel.CData.WheelPanel:SetTooltip( "If you use default spherical settings, add 0.5 to your wheel diameter.\nFor treaded vehicles, use the diameter of road wheels, not drive wheels." )

					acemenupanel.CData.ShiftGenPanel.WheelLabel = acemenupanel.CData.WheelPanel:Add( "DLabel" )
						acemenupanel.CData.ShiftGenPanel.WheelLabel:Dock( TOP )
						acemenupanel.CData.ShiftGenPanel.WheelLabel:SetDark( true )
						acemenupanel.CData.ShiftGenPanel.WheelLabel:SetText( "Wheel Diameter:" )

					acemenupanel.CData.ShiftGenPanel.Wheel = acemenupanel.CData.WheelPanel:Add( "DNumberWang" )
						acemenupanel.CData.ShiftGenPanel.Wheel:HideWang()
						acemenupanel.CData.ShiftGenPanel.Wheel:SetDrawBorder( false )
						acemenupanel.CData.ShiftGenPanel.Wheel:Dock( BOTTOM )
						acemenupanel.CData.ShiftGenPanel.Wheel:SetDecimals( 2 )
						acemenupanel.CData.ShiftGenPanel.Wheel:SetMinMax( 0, 9999 )
						acemenupanel.CData.ShiftGenPanel.Wheel:SetValue( 30 )

				acemenupanel.CData.RatioPanel = acemenupanel.CData.ShiftGenPanel:Add( "DPanel" )
					acemenupanel.CData.RatioPanel:SetPaintBackground( false )
					acemenupanel.CData.RatioPanel:DockMargin( 4, 0, 4, 0 )
					acemenupanel.CData.RatioPanel:Dock( RIGHT )
					acemenupanel.CData.RatioPanel:SetWide( 76 )
					acemenupanel.CData.RatioPanel:SetTooltip( "Total ratio is the ratio of all gearboxes (excluding this one) multiplied together.\nFor example, if you use engine to automatic to diffs to wheels, your total ratio would be (diff gear ratio * diff final ratio)." )

					acemenupanel.CData.ShiftGenPanel.RatioLabel = acemenupanel.CData.RatioPanel:Add( "DLabel" )
						acemenupanel.CData.ShiftGenPanel.RatioLabel:Dock( TOP )
						acemenupanel.CData.ShiftGenPanel.RatioLabel:SetDark( true )
						acemenupanel.CData.ShiftGenPanel.RatioLabel:SetText( "Total ratio:" )

					acemenupanel.CData.ShiftGenPanel.Ratio = acemenupanel.CData.RatioPanel:Add( "DNumberWang" )
						acemenupanel.CData.ShiftGenPanel.Ratio:HideWang()
						acemenupanel.CData.ShiftGenPanel.Ratio:SetDrawBorder( false )
						acemenupanel.CData.ShiftGenPanel.Ratio:Dock( BOTTOM )
						acemenupanel.CData.ShiftGenPanel.Ratio:SetDecimals( 2 )
						acemenupanel.CData.ShiftGenPanel.Ratio:SetMinMax( 0, 9999 )
						acemenupanel.CData.ShiftGenPanel.Ratio:SetValue( 0.1 )

				acemenupanel.CData.RPMPanel = acemenupanel.CData.ShiftGenPanel:Add( "DPanel" )
					acemenupanel.CData.RPMPanel:SetPaintBackground( false )
					acemenupanel.CData.RPMPanel:DockMargin( 4, 0, 4, 0 )
					acemenupanel.CData.RPMPanel:Dock( RIGHT )
					acemenupanel.CData.RPMPanel:SetWide( 76 )
					acemenupanel.CData.RPMPanel:SetTooltip( "Target engine RPM to upshift at." )

					acemenupanel.CData.ShiftGenPanel.RPMLabel = acemenupanel.CData.RPMPanel:Add( "DLabel" )
						acemenupanel.CData.ShiftGenPanel.RPMLabel:Dock( TOP )
						acemenupanel.CData.ShiftGenPanel.RPMLabel:SetDark( true )
						acemenupanel.CData.ShiftGenPanel.RPMLabel:SetText( "Upshift RPM:" )

					acemenupanel.CData.ShiftGenPanel.RPM = acemenupanel.CData.RPMPanel:Add( "DNumberWang" )
						acemenupanel.CData.ShiftGenPanel.RPM:HideWang()
						acemenupanel.CData.ShiftGenPanel.RPM:SetDrawBorder( false )
						acemenupanel.CData.ShiftGenPanel.RPM:Dock( BOTTOM )
						acemenupanel.CData.ShiftGenPanel.RPM:SetDecimals( 2 )
						acemenupanel.CData.ShiftGenPanel.RPM:SetMinMax( 0, 9999 )
						acemenupanel.CData.ShiftGenPanel.RPM:SetValue( 5000 )

			acemenupanel.CustomDisplay:AddItem(acemenupanel.CData.ShiftGenPanel)
		end
	end

	acemenupanel.CustomDisplay:PerformLayout()
	maxtorque = Table.maxtq
end

function ACE_GearsSlider(Gear, Value, ID, Desc, CVT)

	if Gear and not acemenupanel.CData[Gear] then

		acemenupanel.CData[Gear] = vgui.Create( "DNumSlider", acemenupanel.CustomDisplay )
			acemenupanel.CData[Gear]:SetText( Desc or "Gear " .. Gear )
			acemenupanel.CData[Gear].Label:SizeToContents()
			acemenupanel.CData[Gear]:SetDark( true )
			acemenupanel.CData[Gear]:SetMin( CVT and 1 or -2 )
			acemenupanel.CData[Gear]:SetMax( CVT and 20000 or 2 )
			acemenupanel.CData[Gear]:SetDecimals( (not CVT) and 2 or 0 )
			acemenupanel.CData[Gear].Gear = Gear
			acemenupanel.CData[Gear].ID = ID
			acemenupanel.CData[Gear]:SetValue(Value)
			RunConsoleCommand( "acemenu_data" .. Gear, Value )
			acemenupanel.CData[Gear].OnValueChanged = function( slider, val )
				acemenupanel.GearboxData[slider.ID].GearTable[slider.Gear] = val
				RunConsoleCommand( "acemenu_data" .. Gear, val )
			end
		acemenupanel.CustomDisplay:AddItem( acemenupanel.CData[Gear] )
	end

end

function ACE_ShiftPoint(Gear, Value, ID, Desc)
	local Index = Gear + 10
	if Gear and not acemenupanel.CData[Index] then
		acemenupanel.CData[Index] = vgui.Create( "DPanel" )
			acemenupanel.CData[Index]:SetPaintBackground( false )
			acemenupanel.CData[Index]:SetTall( 20 )
			acemenupanel.CData[Index]:SizeToContentsX()

		acemenupanel.CData[Index].Input = acemenupanel.CData[Index]:Add( "DNumberWang" )
			acemenupanel.CData[Index].Input.Gear = Gear
			acemenupanel.CData[Index].Input.ID = ID
			acemenupanel.CData[Index].Input:HideWang()
			acemenupanel.CData[Index].Input:SetDrawBorder( false )
			acemenupanel.CData[Index].Input:SetDecimals( 2 )
			acemenupanel.CData[Index].Input:SetMinMax( 0, 9999 )
			acemenupanel.CData[Index].Input:SetValue( Value )
			acemenupanel.CData[Index].Input:Dock( RIGHT )
			acemenupanel.CData[Index].Input:SetWide( 45 )
			acemenupanel.CData[Index].Input.OnValueChanged = function( box, value )
				acemenupanel.GearboxData[box.ID].ShiftTable[box.Gear] = value
				local _, factor = acemenupanel.CData.UnitsInput:GetSelected()
				acemenupanel.Serialize( acemenupanel.GearboxData[acemenupanel.CData.UnitsInput.ID].ShiftTable, factor )  --dot intentional
			end
			RunConsoleCommand( "acemenu_data9", "10,20,30,40,50,60,70" )

		acemenupanel.CData[Index].Label = acemenupanel.CData[Index]:Add( "DLabel" )
			acemenupanel.CData[Index].Label:Dock( RIGHT )
			acemenupanel.CData[Index].Label:SetWide( 120 )
			acemenupanel.CData[Index].Label:SetDark( true )
			acemenupanel.CData[Index].Label:SetText( Desc )

		acemenupanel.CustomDisplay:AddItem(acemenupanel.CData[Index])
	end
end
