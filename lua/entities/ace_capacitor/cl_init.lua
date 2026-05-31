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

	local mine = topOf(self)
	if not mine then return end
	local n = self:GetNWInt("GLN", 0)
	if n <= 0 then return end

	render.SetMaterial(beamMat)
	for i = 1, n do
		local other = self:GetNWEntity("GL" .. i)
		if IsValid(other) and self:EntIndex() < other:EntIndex() then
			local t = (other.WorldSpaceCenter and other:WorldSpaceCenter())
				or (other.LocalToWorld and other:LocalToWorld(Vector(0, 0, other:OBBMaxs().z)))
			if t then render.DrawBeam(mine, t, 3, 0, 1, Color(180, 230, 255)) end
		end
	end
end
