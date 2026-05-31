include("shared.lua")

local beamMat = Material("cable/cable2")

local function topOf(ent)
	if not IsValid(ent) then return nil end
	return ent:LocalToWorld(Vector(0, 0, ent:OBBMaxs().z))
end

function ENT:Draw()
	self.BaseClass.DoNormalDraw(self)
	Wire_Render(self)

	local cv = GetConVar("ace_draw_link_beams")
	if cv and not cv:GetBool() then return end

	-- Draw a line to each linked grid node (shared GL1..GLN networking with
	-- stations), rendering each link once from the lower EntIndex endpoint.
	local mine = topOf(self)
	if not mine then return end
	local n = self:GetNWInt("GLN", 0)
	if n <= 0 then return end

	render.SetMaterial(beamMat)
	for i = 1, n do
		local other = self:GetNWEntity("GL" .. i)
		if IsValid(other) and self:EntIndex() < other:EntIndex() then
			local t = topOf(other)
			if t then render.DrawBeam(mine, t, 3, 0, 1, Color(210, 180, 140)) end
		end
	end
end
