include("shared.lua")

local ACE_GunInfoWhileSeated = CreateClientConVar("ace_gun_info_while_seated", 0, true, false)

function ENT:Draw()
	local lply = LocalPlayer()
	local hideBubble = not ACE_GunInfoWhileSeated:GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)
end

function ACE_SonarGUICreate( Table )
	acemenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	local RadarMenu = acemenupanel.CData.DisplayModel

	RadarMenu = vgui.Create( "DModelPanel", acemenupanel.CustomDisplay )
		RadarMenu:SetModel( Table.model )
		RadarMenu:SetCamPos( Vector( 250, 500, 250 ) )
		RadarMenu:SetLookAt( Vector( 0, 0, 0 ) )
		RadarMenu:SetFOV( 20 )
		RadarMenu:SetSize(acemenupanel:GetWide(),acemenupanel:GetWide())
		RadarMenu.LayoutEntity = function() end
	acemenupanel.CustomDisplay:AddItem( RadarMenu )

	acemenupanel:CPanelText("ClassDesc", ACE.Classes.Radar[Table.class].desc)
	acemenupanel:CPanelText("GunDesc", Table.desc)
	acemenupanel:CPanelText("MaxRange", "View range : " .. math.Round( 300 * Table.powerscale , 2) .. " m")
	acemenupanel:CPanelText("NoiseFactor", "Relative noise factor : " .. math.Round(Table.noisemul,2))
	acemenupanel:CPanelText("Washout", "Sonar speed for complete washout : " .. math.Round(35 / Table.washoutfactor,1) .. " mph / " .. math.Round(56.33 / Table.washoutfactor,1) .. "kph")
	acemenupanel:CPanelText("Weight", "Weight : " .. Table.weight .. " kg")

	acemenupanel.CustomDisplay:PerformLayout()

end
