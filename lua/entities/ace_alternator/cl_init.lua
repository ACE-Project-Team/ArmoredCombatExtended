include("shared.lua")

function ENT:Draw()
	self.BaseClass.DoNormalDraw(self)
	Wire_Render(self)
end