include("shared.lua")

local ACE_ToolInfoWhileSeated = CreateClientConVar("ace_tool_info_while_seated", 0, true, false)

function ENT:Initialize()
    self.BaseClass.Initialize(self)
end

function ENT:Draw()
    local lply = LocalPlayer()
    local hideBubble = not ACE_ToolInfoWhileSeated:GetBool() and IsValid(lply) and lply:InVehicle()

    self.BaseClass.DoNormalDraw(self, false, hideBubble)
    Wire_Render(self)
end

function ACE.VHeatSourceGUICreate(Table)
    acemenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")
    acemenupanel:CPanelText("GunDesc", Table.desc)
    acemenupanel.CustomDisplay:PerformLayout()
end
