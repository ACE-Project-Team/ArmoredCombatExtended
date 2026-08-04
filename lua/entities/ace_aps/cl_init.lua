include("shared.lua")

function ENT:Draw()
	self:DoNormalDraw(false, false)
	Wire_Render(self)
end
