include ("shared.lua")

ENT.RenderGroup		= RENDERGROUP_OPAQUE


local ACF_GunInfoWhileSeated = CreateClientConVar("ACF_GunInfoWhileSeated", 0, true, false)

function ENT:Initialize()

	self.BaseClass.Initialize( self )

end

function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not ACF_GunInfoWhileSeated:GetBool() and IsValid(lply) and lply:InVehicle()

	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end

function ACFRadarGUICreate( Table )

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
	acfmenupanel:CPanelText("ViewCone", "View cone : " .. ((Table.viewcone or 180) * 2) .. " degs")
	acfmenupanel:CPanelText("ViewRange", "View range : " .. (Table.range and (math.Round(Table.range / 39.37, 1) .. " m") or "unlimited"))
	acfmenupanel:CPanelText("Weight", "Weight : " .. Table.weight .. " kg")

	--acfmenupanel:CPanelText("GunParentable", "\nThis radar can be parented\n", "DermaDefaultBold")

	acfmenupanel.CustomDisplay:PerformLayout()

end
