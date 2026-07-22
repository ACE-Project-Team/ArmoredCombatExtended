
function ACE_Missiles_MenuSlider(config, controlGroup, combo, conCmd, min, max)

	local slider = vgui.Create( "DNumSlider" )
		slider.Label:SetText(config.DisplayName or "")
		slider.Label:SetDark(true)
		slider:SetMin( min )
		slider:SetMax( max )
		slider:SetValue( config.Min )
		slider:SetDecimals( 2 )
		--slider:Dock(FILL)
		--slider:DockMargin(6,0,0,0)
		slider.Configurable = config

		slider.GetConfigValue = function( slider )
			local config = slider.Configurable
			return math.Round(math.Clamp(slider:GetValue(), config.Min, config.Max), 3)
		end

		slider.OnValueChanged = function()
			ACE_Missiles_SetCommand(combo, controlGroup, conCmd)
		end

		controlGroup[#controlGroup + 1] = slider

	return slider

end



function ACE_Missiles_SetCommand(combo, controlGroup, conCmd)

	if not controlGroup then
		local name = combo:GetValue()
		RunConsoleCommand( conCmd, tostring(name) )
	else
		local name = combo:GetValue()
		local kvString = ""

		if #controlGroup > 0 then
			local i = 1
			repeat
				local control = controlGroup[i]
				kvString = kvString .. ":" .. control.Configurable.CommandName .. "=" .. tostring(control:GetConfigValue())
				i = i + 1
			until i > #controlGroup
		end

		RunConsoleCommand( conCmd, tostring(name) .. tostring(kvString) )
	end

end




ACE.Missiles_ConfigurationFactory =
{
	number =	function(config, controlGroup, combo, conCmd, gundata)
					--print(config.MinConfig, gundata.armdelay, config.Min, gundata[config.MinConfig], gundata.id)
					local min = config.MinConfig and gundata.armdelay or config.Min
					return ACE_Missiles_MenuSlider(config, controlGroup, combo, conCmd, min, config.Max)
				end
}




function ACE_Missiles_CreateMenuConfiguration(tbl, combo, conCmd, existingPanel, gundata)

	local panel = existingPanel or vgui.Create("DScrollPanel")

	panel:Clear()

	if not tbl.Configurable or #tbl.Configurable < 1 then
		panel:SetTall(0)
		return panel
	end

	local controlGroup = {}

	local height = 0

	for _, config in pairs(tbl.Configurable) do
		local control = ACE.Missiles_ConfigurationFactory[config.Type](config, controlGroup, combo, conCmd, gundata)
		control:SetPos(6, height)

		panel:Add(control)

		control:StretchToParent(0,nil,0,nil)

		height = height + control:GetTall()
	end

	panel:SetTall(height + 2)

	combo.ControlGroup = controlGroup

	return panel

end


function ACE_Missiles_RemoveMenuConfiguration()
	ErrorNoHalt("TODO: ACE_Missiles_RemoveMenuConfiguration")
end
