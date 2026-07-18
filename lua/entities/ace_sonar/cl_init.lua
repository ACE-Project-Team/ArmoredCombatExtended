include("shared.lua")

local ACF_GunInfoWhileSeated = CreateClientConVar("ace_gun_info_while_seated", 0, true, false)

function ENT:Draw()
	local lply = LocalPlayer()
	local hideBubble = not ACF_GunInfoWhileSeated:GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)
end

function ACE.SonarGUICreate( Table )
	acfmenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	local RadarMenu = acfmenupanel.CData.DisplayModel

	RadarMenu = vgui.Create( "DModelPanel", acfmenupanel.CustomDisplay )
		RadarMenu:SetModel( Table.model )
		RadarMenu:SetCamPos( Vector( 250, 500, 250 ) )
		RadarMenu:SetLookAt( Vector( 0, 0, 0 ) )
		RadarMenu:SetFOV( 20 )
		RadarMenu:SetSize(acfmenupanel:GetWide(),acfmenupanel:GetWide())
		RadarMenu.LayoutEntity = function() end
	acfmenupanel.CustomDisplay:AddItem( RadarMenu )

	acfmenupanel:CPanelText("ClassDesc", ACF.Classes.Radar[Table.class].desc)
	acfmenupanel:CPanelText("GunDesc", Table.desc)
	acfmenupanel:CPanelText("MaxRange", "View range : " .. math.Round( 300 * Table.powerscale , 2) .. " m")
	acfmenupanel:CPanelText("NoiseFactor", "Relative noise factor : " .. math.Round(Table.noisemul,2))
	acfmenupanel:CPanelText("Washout", "Sonar speed for complete washout : " .. math.Round(35 / Table.washoutfactor,1) .. " mph / " .. math.Round(56.33 / Table.washoutfactor,1) .. "kph")
	acfmenupanel:CPanelText("Weight", "Weight : " .. Table.weight .. " kg")

	acfmenupanel.CustomDisplay:PerformLayout()

end
