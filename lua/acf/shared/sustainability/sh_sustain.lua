--[[
	ACE Sustainability — scalable-spawn helpers (GMod side)

	NOTE: this is the trimmed scaffold that ships with the Scalable Explosives
	feature. It exposes ONLY the shared scale/shape/spawn glue under ACE.Sustain
	that scalable ACE entities (the explosive charge) need. The full
	sustainability system (power grid, fuel chain, faults) replaces this file
	with the complete loader that includes every logic_* module.

	The logic file stays GMod-free so it can be unit-tested with plain lua.
]]--

ACE = ACE or {}

local PATH = "acf/shared/sustainability/"

if SERVER then
	AddCSLuaFile(PATH .. "logic_scale.lua")
end

local Sustain = {}

Sustain.Scale = include(PATH .. "logic_scale.lua")

ACE.Sustain = Sustain

------------------------------------------------------------------
-- Server-side engine glue shared by the scalable entities.
-- Kept here (not in the pure module) because it touches Entity/ACF.
------------------------------------------------------------------
if SERVER then

	local SCALE_PATTERN = "^%d+%.?%d*:%d+%.?%d*:%d+%.?%d*$"

	-- Parse an "L:W:H" size string into a clamped Vector (crate size limits).
	-- Accepts a Vector unchanged. Returns nil if the string is malformed.
	-- maxSize (optional) tightens the upper clamp for entities whose definition
	-- caps them below the global crate limit (e.g. explosive charges), and is
	-- re-applied here so an edited dupe can't smuggle in an oversized one.
	function Sustain.ParseScale(str, maxSize)
		if isvector(str) then return str end
		if not isstring(str) or not string.match(str, SCALE_PATTERN) then return end

		local parts = string.Explode(":", str)
		local v = Vector(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0)

		local mn = ACF.SustainMinimumSize or ACF.CrateMinimumSize or 5
		local mx = ACF.CrateMaximumSize or 250
		if maxSize then mx = math.min(mx, maxSize) end
		v.x = math.Clamp(math.Round(v.x, 1), mn, mx)
		v.y = math.Clamp(math.Round(v.y, 1), mn, mx)
		v.z = math.Clamp(math.Round(v.z, 1), mn, mx)
		return v
	end

	-- Apply a ModelData shape at the given dimensions to a scalable entity,
	-- re-validating the shape against the definition's allow/block list so a
	-- hand-edited dupe can't smuggle in a disallowed shape.
	-- Returns { dims = Vector, volume = number, area = number } or nil.
	function Sustain.ApplyShape(ent, scaleVec, shape, def)
		if not Sustain.Scale.ShapeAllowed(shape, def or {}) then return end

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

		return {
			dims   = Vector(L, W, H),
			volume = md.volumefunction(L, W, H),
			area   = L * W,
		}
	end

	-- Common spawn boilerplate: limit check + ownership + cleanup + overlay.
	-- countKey is the "_class" string used for CheckLimit/AddCount.
	function Sustain.FinishSpawn(ent, owner, countKey, wireName)
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

return Sustain
