include("shared.lua")

function ENT:Draw()
	self:DrawModel()
	Wire_Render(self)
end
