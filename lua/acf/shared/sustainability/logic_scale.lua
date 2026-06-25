--- ACE Sustainability - Scale & shape logic (pure, no GMod globals).
--
-- Scalable power entities derive their stats from a single linear scale
-- factor (or explicit XYZ dimensions). This module centralises that maths and
-- the per-definition shape whitelist/blacklist check. Kept free of
-- Entity/Wire/CurTime so it can be unit-tested with plain lua.
-- @module logic_scale

local Scale = {}

-- Clamp helper (math.Clamp is a GMod global; reimplement locally).
local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end
Scale.clamp = clamp

--- Turn a scale factor into balanced stats.
-- Stats grow with volume (scale^3) so "bigger = proportionally heavier and
-- more capable" stays intuitive and dupe-stable.
-- @param scale number linear scale factor (e.g. 0.25 .. 5)
-- @param coeffs table base values at scale 1: { power=, torque=, mass=, points= }
-- @return table { MaxPower, MaxTorque, Mass, Points, Volume }
function Scale.ScaleStats(scale, coeffs)
	scale = scale or 1
	local s3 = scale * scale * scale
	return {
		MaxPower  = (coeffs.power  or 0) * s3,
		MaxTorque = (coeffs.torque or 0) * s3,
		Mass      = (coeffs.mass   or 0) * s3,
		Points    = (coeffs.points or 0) * s3,
		Volume    = s3,
	}
end

--- Whether a shape is permitted by a definition's shape rules.
-- The definition may carry `AllowedShapes` (whitelist - only these) and/or
-- `BlacklistShapes` (blacklist - anything but these). If neither is present
-- every shape is allowed (back-compat). Whitelist wins over blacklist.
-- @param shape string shape name (e.g. "Box", "Wedge")
-- @param def table the entity definition
-- @return boolean true if the shape may be used
function Scale.ShapeAllowed(shape, def)
	if not shape then return false end
	def = def or {}

	local white = def.AllowedShapes
	if white then
		return white[shape] == true
	end

	local black = def.BlacklistShapes
	if black and black[shape] then
		return false
	end

	return true
end

return Scale
