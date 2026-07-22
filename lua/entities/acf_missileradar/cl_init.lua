include ("shared.lua")

ENT.RenderGroup		= RENDERGROUP_OPAQUE


local ACE_GunInfoWhileSeated = CreateClientConVar("ace_gun_info_while_seated", 0, true, false)

function ENT:Initialize()

	self.BaseClass.Initialize( self )

end

function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not ACE_GunInfoWhileSeated:GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end

function ACE_RadarGUICreate( Table )

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
	acemenupanel:CPanelText("ViewCone", "View cone : " .. ((Table.viewcone or 180) * 2) .. " degs")
	acemenupanel:CPanelText("ViewRange", "View range : " .. (Table.range and (math.Round(Table.range / 39.37, 1) .. " m") or "unlimited"))
	acemenupanel:CPanelText("Weight", "Weight : " .. Table.weight .. " kg")

	--acemenupanel:CPanelText("GunParentable", "\nThis radar can be parented\n", "DermaDefaultBold")

	acemenupanel.CustomDisplay:PerformLayout()

end
