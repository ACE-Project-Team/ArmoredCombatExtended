include("shared.lua")

local beamMat = Material("cable/rope")

-- Conductor terminal: the centre of the segment (the wire body).
local function nodeOf(ent)
	if not IsValid(ent) then return nil end
	return ent:WorldSpaceCenter()
end

function ENT:Draw()
	self.BaseClass.DoNormalDraw(self)
	Wire_Render(self)

	local cv = GetConVar("ace_draw_link_beams")
	if cv and not cv:GetBool() then return end

	-- Draw the conductor to each linked grid node (shared GL1..GLN networking),
	-- once per link from the lower EntIndex. A live line glows; a dead one is dull.
	local mine = nodeOf(self)
	if not mine then return end
	local n = self:GetNWInt("GLN", 0)
	if n <= 0 then return end

	local live = self:GetNWBool("Live", false)
	local col = live and Color(255, 230, 120) or Color(90, 90, 90)

	render.SetMaterial(beamMat)
	for i = 1, n do
		local other = self:GetNWEntity("GL" .. i)
		if IsValid(other) and self:EntIndex() < other:EntIndex() then
			local t = (other.WorldSpaceCenter and other:WorldSpaceCenter())
				or (other.LocalToWorld and other:LocalToWorld(Vector(0, 0, other:OBBMaxs().z)))
			if t then render.DrawBeam(mine, t, 2, 0, 1, col) end
		end
	end
end
