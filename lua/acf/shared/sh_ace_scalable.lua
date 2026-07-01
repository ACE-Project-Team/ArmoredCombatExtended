--[[
	ACE scalable-spawn helpers.

	Shared glue for scalable ACE entities (currently the explosive charge):
	the shape allow/block check, an "L:W:H" size-string parser, the ModelData
	shape apply, and the common spawn boilerplate. Defined as ACE.Scalable
	globals like the rest of ACE's shared tables - no module/return indirection.
]]--

ACE = ACE or {}
ACE.Scalable = ACE.Scalable or {}

local Scalable = ACE.Scalable

--- Whether a shape is permitted by a definition's shape rules.
-- The definition may carry `AllowedShapes` (whitelist - only these) and/or
-- `BlacklistShapes` (blacklist - anything but these). If neither is present
-- every shape is allowed (back-compat). Whitelist wins over blacklist.
function Scalable.ShapeAllowed(shape, def)
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

------------------------------------------------------------------
-- Server-side spawn glue. Kept behind SERVER because it touches
-- Entity/ACF; ShapeAllowed above stays shared so the menu can use it.
------------------------------------------------------------------
if SERVER then

	local SCALE_PATTERN = "^%d+%.?%d*:%d+%.?%d*:%d+%.?%d*$"

	-- Parse an "L:W:H" size string into a clamped Vector.
	-- Accepts a Vector unchanged. Returns nil if the string is malformed.
	-- bounds (optional) = { min = number, max = number }. Each caller passes its
	-- own limits, so explosives, ammo crates and fuel tanks can disagree on size
	-- without sharing a global. Re-applied here so an edited dupe can't smuggle in
	-- an out-of-range one. Falls back to the crate limits when bounds are omitted.
	function Scalable.ParseScale(str, bounds)
		if isvector(str) then return str end
		if not isstring(str) or not string.match(str, SCALE_PATTERN) then return end

		local parts = string.Explode(":", str)
		local v = Vector(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0)

		bounds = bounds or {}
		local mn = bounds.min or ACF.CrateMinimumSize or 5
		local mx = bounds.max or ACF.CrateMaximumSize or 250
		v.x = math.Clamp(math.Round(v.x, 1), mn, mx)
		v.y = math.Clamp(math.Round(v.y, 1), mn, mx)
		v.z = math.Clamp(math.Round(v.z, 1), mn, mx)
		return v
	end

	-- Apply a ModelData shape at the given dimensions to a scalable entity,
	-- re-validating the shape against the definition's allow/block list so a
	-- hand-edited dupe can't smuggle in a disallowed shape.
	-- Returns { dims = Vector, volume = number, area = number } or nil.
	function Scalable.ApplyShape(ent, scaleVec, shape, def)
		if not Scalable.ShapeAllowed(shape, def or {}) then return end

		local md = ACE.ModelData[shape]
		if not md then return end

		local L, W, H = scaleVec.x, scaleVec.y, scaleVec.z
		local entScale = Vector(L / md.DefaultSize, W / md.DefaultSize, H / md.DefaultSize)

		ent:SetModel(md.Model)
		ent:PhysicsInit(SOLID_VPHYSICS)
		ent:SetMoveType(MOVETYPE_VPHYSICS)
		ent:SetSolid(SOLID_VPHYSICS)

		ent.ScaleData = {
			Mesh     = md.CustomMesh,
			Scale    = entScale,
			Size     = md.DefaultSize,
			Material = md.physMaterial,
		}
		ent.IsScalable = true
		ent:ACE_SetScale(ent.ScaleData)

		-- Read the volume straight off the scaled collision mesh the game actually
		-- uses, instead of a hand-written volumefunction that can drift from the
		-- hull (e.g. the coarse cylinder/sphere hulls). Falls back to the formula
		-- only if the physics object failed to build.
		local phys = ent:GetPhysicsObject()
		local volume = (IsValid(phys) and phys:GetVolume()) or md.volumefunction(L, W, H)

		return {
			dims   = Vector(L, W, H),
			volume = volume,
			area   = L * W,
		}
	end

	-- Common spawn boilerplate: limit check + ownership + cleanup + overlay.
	-- countKey is the "_class" string used for CheckLimit/AddCount.
	function Scalable.FinishSpawn(ent, owner, countKey, wireName)
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(true)
			phys:SetMass(ent.Mass or 50)
		end

		ent:CPPISetOwner(owner)
		ent:SetNWString("WireName", wireName)
		ent:UpdateOverlayText()

		owner:AddCount(countKey, ent)
		owner:AddCleanup("acfmenu", ent)
	end
end
