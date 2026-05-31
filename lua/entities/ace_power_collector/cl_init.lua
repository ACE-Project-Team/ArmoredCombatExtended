include("shared.lua")

function ENT:Draw()
	-- DoNormalDraw (not DrawModel) so the wiremod port bubble shows on hover.
	self.BaseClass.DoNormalDraw(self)
	Wire_Render(self)
end
