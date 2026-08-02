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
-- Cross-section geometry.
--
-- A shape whose ModelData carries an `ExtrudeAxis` is a prism: constant
-- cross-section swept along that axis. Everything below derives that
-- cross-section from the shape's own `CustomMesh`, so the packing maths and
-- the volume maths can never drift from the collision hull the game builds.
-- Shapes without an ExtrudeAxis are treated as their full bounding box.
------------------------------------------------------------------

local SectionCache = {}

local AxisPlane = {
	x = { "y", "z" },
	y = { "x", "z" },
	z = { "x", "y" },
}

-- Monotone chain hull of 2D points, returned counter-clockwise.
local function ConvexHull(pts)
	table.sort(pts, function(a, b)
		if a[1] ~= b[1] then return a[1] < b[1] end
		return a[2] < b[2]
	end)

	local function Cross(o, a, b)
		return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
	end

	local function Build(source)
		local out = {}
		for i = 1, #source do
			local p = source[i]
			while #out >= 2 and Cross(out[#out - 1], out[#out], p) <= 0 do
				out[#out] = nil
			end
			out[#out + 1] = p
		end
		out[#out] = nil -- drop the shared endpoint
		return out
	end

	local reversed = {}
	for i = #pts, 1, -1 do reversed[#reversed + 1] = pts[i] end

	local lower, upper = Build(pts), Build(reversed)
	for i = 1, #upper do lower[#lower + 1] = upper[i] end
	return lower
end

--- Normalized convex cross-section of a prism shape.
-- Projects the shape's CustomMesh onto the plane perpendicular to its
-- ExtrudeAxis and hulls it, then divides out the mesh's half-extent so the
-- result is expressed in units of "fraction of the bounding box half-width".
-- @param md ModelData table (see ACE.DefineModelData).
-- @return Array of {u, v} points counter-clockwise, or nil for a plain box.
function Scalable.SectionPolygon(md)
	if not md or not md.ExtrudeAxis then return end

	local cached = SectionCache[md]
	if cached ~= nil then
		return cached or nil
	end

	local plane = AxisPlane[md.ExtrudeAxis]
	local half  = (md.DefaultSize or 12) * 0.5
	if not plane or half <= 0 or not md.CustomMesh then
		SectionCache[md] = false
		return
	end

	local seen, pts = {}, {}
	for _, hull in ipairs(md.CustomMesh) do
		for _, vert in ipairs(hull) do
			local u, v = vert[plane[1]] / half, vert[plane[2]] / half
			-- Collapse the two end caps onto one another; they are identical.
			local key = string.format("%.4f:%.4f", u, v)
			if not seen[key] then
				seen[key] = true
				pts[#pts + 1] = { u, v }
			end
		end
	end

	if #pts < 3 then
		SectionCache[md] = false
		return
	end

	local poly = ConvexHull(pts)
	SectionCache[md] = poly
	return poly
end

--- Fraction of its bounding box a prism shape's cross-section fills.
-- 1 for a box, 2*sqrt(2)/4 ~= 0.707 for the eight-sided cylinder hull.
-- Use this rather than a hand-written constant so the number always describes
-- the mesh that actually exists.
function Scalable.SectionAreaRatio(md)
	local poly = Scalable.SectionPolygon(md)
	if not poly then return 1 end

	local area = 0
	for i = 1, #poly do
		local a, b = poly[i], poly[(i % #poly) + 1]
		area = area + (a[1] * b[2] - b[1] * a[2])
	end
	-- Normalized coords span [-1, 1] on both axes, so the bounding box area is 4.
	return math.abs(area) * 0.5 / 4
end

local EPS = 1e-9
local MAX_ROWS = 4096

-- Convex polygon as inward half-planes a*u + b*v <= c, scaled to the real
-- half-extents. Cached per (md, halfU, halfV) would churn; building it is cheap
-- (eight edges) and capacity is only rebuilt on a crate edit.
local function HalfPlanes(poly, halfU, halfV)
	local planes = {}
	for i = 1, #poly do
		local p1, p2 = poly[i], poly[(i % #poly) + 1]
		local u1, v1 = p1[1] * halfU, p1[2] * halfV
		local u2, v2 = p2[1] * halfU, p2[2] * halfV
		local du, dv = u2 - u1, v2 - v1
		planes[#planes + 1] = { dv, -du, dv * u1 - du * v1 }
	end
	return planes
end

-- Horizontal extent of the section at a given v, or nil if that v is outside.
local function SpanAt(planes, v)
	local lo, hi = -math.huge, math.huge
	for i = 1, #planes do
		local a, b, c = planes[i][1], planes[i][2], planes[i][3]
		if math.abs(a) < EPS then
			if b * v > c + EPS then return end
		else
			local bound = (c - b * v) / a
			if a > 0 then
				if bound < hi then hi = bound end
			else
				if bound > lo then lo = bound end
			end
		end
	end
	if lo > hi then return end
	return lo, hi
end

-- Cells of cellU x cellV that fit entirely inside the section, for one grid phase.
local function CountPhase(planes, halfV, cellU, cellV, offU, offV)
	local jMin = math.floor((-halfV - offV) / cellV)
	local jMax = math.ceil((halfV - offV) / cellV)
	if jMax - jMin > MAX_ROWS then return end

	local total = 0
	for j = jMin, jMax do
		local vLo = j * cellV + offV
		local vHi = vLo + cellV

		local loA, hiA = SpanAt(planes, vLo)
		if loA then
			local loB, hiB = SpanAt(planes, vHi)
			if loB then
				local lo = math.max(loA, loB)
				local hi = math.min(hiA, hiB)
				if hi > lo then
					-- Cells are [k*cellU + offU, (k+1)*cellU + offU].
					local kMin = math.ceil((lo - offU) / cellU - EPS)
					local kMax = math.floor((hi - offU) / cellU + EPS) - 1
					if kMax >= kMin then total = total + (kMax - kMin + 1) end
				end
			end
		end
	end
	return total
end

--- How many cellU x cellV cells fit entirely inside a shape's cross-section.
-- This is a real packing count, not a volume fraction: a cell whose corner
-- falls outside the section is lost completely, which is what actually happens
-- to a shell that overhangs the wall of a cylindrical crate.
-- Falls back to the plain box count for shapes with no cross-section.
-- @param md ModelData table, or nil for a box.
-- @param sizeU, sizeV Full bounding-box extents on the section's two axes.
-- @param cellU, cellV Footprint of one item on those same two axes.
-- @return Integer cell count.
function Scalable.SectionFit(md, sizeU, sizeV, cellU, cellV)
	if cellU <= 0 or cellV <= 0 then return 0 end

	local poly = Scalable.SectionPolygon(md)
	if not poly then
		return math.floor(sizeU / cellU) * math.floor(sizeV / cellV)
	end

	local halfU, halfV = sizeU * 0.5, sizeV * 0.5
	local planes = HalfPlanes(poly, halfU, halfV)

	-- Phase matters: for few items across, a grid centred on the axis and one
	-- straddling it give different counts. Take whichever packs better.
	local best = 0
	for _, offU in ipairs({ 0, -cellU * 0.5 }) do
		for _, offV in ipairs({ 0, -cellV * 0.5 }) do
			local count = CountPhase(planes, halfV, cellU, cellV, offU, offV)
			if not count then
				-- Section too finely divided to enumerate; fall back to the area
				-- estimate, which is accurate in exactly that limit.
				local ratio = Scalable.SectionAreaRatio(md)
				return math.floor(math.floor(sizeU / cellU) * math.floor(sizeV / cellV) * ratio)
			end
			if count > best then best = count end
		end
	end

	return best
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
		local mn = bounds.min or ACE.CrateMinimumSize or 5
		local mx = bounds.max or ACE.CrateMaximumSize or 250
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
		owner:AddCleanup("acemenu", ent)
	end
end
