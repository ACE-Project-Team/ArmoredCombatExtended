include("shared.lua")

local beamMat = Material("cable/cable2")

function ENT:Draw()
	self.BaseClass.DoNormalDraw(self)
	Wire_Render(self)

	local cv = GetConVar("ace_draw_link_beams")
	if cv and not cv:GetBool() then return end

	render.SetMaterial(beamMat)
	local mine = self:WorldSpaceCenter()
	local n = self:GetNWInt("PLN", 0)
	for i = 1, n do
		local other = self:GetNWEntity("PL" .. i)
		if IsValid(other) then
			local otherNode = other:GetClass() == "ace_fuel_pipe" or other:GetClass() == "ace_fuel_pump"
			if not otherNode or self:EntIndex() < other:EntIndex() then
				render.DrawBeam(mine, other:WorldSpaceCenter(), 4, 0, 1, Color(120, 160, 200))
			end
		end
	end
end
