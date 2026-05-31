include("shared.lua")

local beamMat = Material("cable/cable2")

function ENT:Draw()
	self.BaseClass.DoNormalDraw(self)

	local cv = GetConVar("ace_draw_link_beams")
	if cv and not cv:GetBool() then return end

	local cond = math.Clamp(self:GetNWFloat("Condition", 1), 0, 1)
	-- Green (healthy) through to red (failing).
	local col = Color(255 * (1 - cond) + 40, 200 * cond + 20, 40, 255)

	render.SetMaterial(beamMat)
	local mine = self:GetPos()
	local n = self:GetNWInt("PLN", 0)
	for i = 1, n do
		local other = self:GetNWEntity("PL" .. i)
		if IsValid(other) then
			-- Pipe<->pipe links: draw once (lower index). Pipe<->tank: always draw.
			local otherPipe = other:GetClass() == "ace_fuel_pipe" or other:GetClass() == "ace_fuel_pump"
			if not otherPipe or self:EntIndex() < other:EntIndex() then
				render.DrawBeam(mine, other:WorldSpaceCenter(), 4, 0, 1, col)
			end
		end
	end
end
