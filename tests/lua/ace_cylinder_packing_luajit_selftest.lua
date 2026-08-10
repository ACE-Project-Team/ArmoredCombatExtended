-- Offline coverage for ACE.Scalable's cross-section packing maths.
--
-- The point of this file is that capacity for a non-box crate is a real packing
-- count, not a volume fraction. It checks the section derived from the shipped
-- Cylinder mesh, and cross-checks ACE.Scalable.SectionFit against a brute-force
-- counter written independently of the span/half-plane routine it is testing.
local repo = assert(arg[1], "usage: luajit ace_cylinder_packing_luajit_selftest.lua <ace-repo>")

ACE = {}
ACE.ModelData = {}
ACE.Weapons = { Ammo = {}, LegacyAmmo = {}, Guns = {} }

function Vector(x, y, z)
	return { x = x or 0, y = y or 0, z = z or 0 }
end

function ACE.DefineModelData(id, data)
	data.id = id
	ACE.ModelData[id] = data
	ACE.ModelData[data.Model] = data
end
ACE_DefineModelData = ACE.DefineModelData

dofile(repo .. "/lua/acf/shared/sh_ace_scalable.lua")
dofile(repo .. "/lua/acf/shared/ammocrates/acfcratelist.lua")

local Scalable = ACE.Scalable
local Cylinder = assert(ACE.ModelData["Cylinder"], "Cylinder ModelData missing")

local checks = 0
local function check(ok, msg)
	checks = checks + 1
	if not ok then
		io.stderr:write("FAIL: " .. msg .. "\n")
		os.exit(1)
	end
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9)
end

------------------------------------------------------------------
-- The section itself
------------------------------------------------------------------

check(Cylinder.ExtrudeAxis == "z", "Cylinder must declare ExtrudeAxis for the packer to see a section")

local poly = Scalable.SectionPolygon(Cylinder)
check(poly ~= nil, "Cylinder must produce a section polygon")
check(#poly == 8, "Cylinder hull is eight-sided, got " .. tostring(#poly))

-- The mesh puts vertices at (+-1, 0), (0, +-1) and (+-k, +-k) with k = 4.24/6.
-- Shoelace over those eight points collapses to exactly k, so the fraction of the
-- bounding box the hull fills is derivable by hand and does not need the code
-- under test to agree with itself.
local k = 4.24 / 6
local ratio = Scalable.SectionAreaRatio(Cylinder)
check(near(ratio, k, 1e-9), string.format("octagon area ratio: expected %.9f, got %.9f", k, ratio))

-- The bug this replaced: PI/4 describes a circle, not the hull the game builds.
check(not near(ratio, math.pi / 4, 1e-3), "area ratio must not be the old PI/4 constant")
check(ratio < math.pi / 4, "octagon must fill less of its box than a circle would")

-- A box has no section and must fill its bounding box exactly.
check(Scalable.SectionPolygon(nil) == nil, "nil ModelData has no section")
check(Scalable.SectionAreaRatio(nil) == 1, "a box fills its whole bounding box")

------------------------------------------------------------------
-- Independent brute-force packer
--
-- Deliberately written the naive way: build the scaled polygon, walk every
-- candidate cell, and accept it only when all four corners are inside. It shares
-- no code with SectionFit's span/half-plane path.
------------------------------------------------------------------

local EPS = 1e-9

local function scaledPoly(p, halfU, halfV)
	local out = {}
	for i = 1, #p do
		out[i] = { p[i][1] * halfU, p[i][2] * halfV }
	end
	return out
end

-- CCW polygon: a point is inside when it is left of (or on) every edge.
local function inside(sp, u, v)
	for i = 1, #sp do
		local a, b = sp[i], sp[(i % #sp) + 1]
		local cross = (b[1] - a[1]) * (v - a[2]) - (b[2] - a[2]) * (u - a[1])
		if cross < -EPS then return false end
	end
	return true
end

local function bruteFit(md, sizeU, sizeV, cellU, cellV)
	local p = Scalable.SectionPolygon(md)
	if not p then
		return math.floor(sizeU / cellU) * math.floor(sizeV / cellV)
	end

	local halfU, halfV = sizeU * 0.5, sizeV * 0.5
	local sp = scaledPoly(p, halfU, halfV)

	local best = 0
	for _, offU in ipairs({ 0, -cellU * 0.5 }) do
		for _, offV in ipairs({ 0, -cellV * 0.5 }) do
			local total = 0
			local kMin = math.floor((-halfU - offU) / cellU) - 1
			local kMax = math.ceil((halfU - offU) / cellU) + 1
			local jMin = math.floor((-halfV - offV) / cellV) - 1
			local jMax = math.ceil((halfV - offV) / cellV) + 1

			for j = jMin, jMax do
				local v0 = j * cellV + offV
				local v1 = v0 + cellV
				for kk = kMin, kMax do
					local u0 = kk * cellU + offU
					local u1 = u0 + cellU
					if inside(sp, u0, v0) and inside(sp, u1, v0)
						and inside(sp, u0, v1) and inside(sp, u1, v1) then
						total = total + 1
					end
				end
			end

			if total > best then best = total end
		end
	end

	return best
end

------------------------------------------------------------------
-- Cross-check across a sweep
------------------------------------------------------------------

local sizes = { 24, 36, 48, 60, 96, 100, 137.5 }
local cells = { 2, 3, 4, 4.5, 6, 8, 11, 14 }

local compared, clipped = 0, 0
for _, sizeU in ipairs(sizes) do
	for _, sizeV in ipairs(sizes) do
		for _, cellU in ipairs(cells) do
			for _, cellV in ipairs(cells) do
				local got = Scalable.SectionFit(Cylinder, sizeU, sizeV, cellU, cellV)
				local want = bruteFit(Cylinder, sizeU, sizeV, cellU, cellV)
				check(got == want, string.format(
					"SectionFit(%.1f x %.1f, cell %.1f x %.1f): expected %d, got %d",
					sizeU, sizeV, cellU, cellV, want, got))

				-- A cylinder can never hold more than its bounding box, and for
				-- these sizes it must actually lose something to the wall.
				local box = math.floor(sizeU / cellU) * math.floor(sizeV / cellV)
				check(got <= box, "cylinder count must not exceed the box count")
				if got < box then clipped = clipped + 1 end

				compared = compared + 1
			end
		end
	end
end

check(clipped > compared * 0.9, "the sweep should be dominated by cases the wall actually clips")

------------------------------------------------------------------
-- Box shapes must be untouched
------------------------------------------------------------------

for _, sizeU in ipairs(sizes) do
	for _, cellU in ipairs(cells) do
		local got = Scalable.SectionFit(nil, sizeU, sizeU, cellU, cellU)
		local want = math.floor(sizeU / cellU) * math.floor(sizeU / cellU)
		check(got == want, string.format(
			"box SectionFit(%.1f, cell %.1f): expected %d, got %d", sizeU, cellU, want, got))
	end
end

------------------------------------------------------------------
-- Properties a volume fraction could not reproduce
------------------------------------------------------------------

-- A cell the size of the whole bounding box fits a box and never a cylinder:
-- its corners are the four points the octagon cuts off.
check(Scalable.SectionFit(Cylinder, 48, 48, 48, 48) == 0, "bbox-sized cell cannot fit in the hull")
check(Scalable.SectionFit(nil, 48, 48, 48, 48) == 1, "bbox-sized cell fits a box exactly once")

-- Degenerate input must not divide by zero or loop.
check(Scalable.SectionFit(Cylinder, 48, 48, 0, 4) == 0, "zero cell width yields no cells")
check(Scalable.SectionFit(Cylinder, 48, 48, 4, -1) == 0, "negative cell height yields no cells")

-- The packed fraction is not a constant: it depends on how many cells span the
-- section, which is the whole reason a single scalar was wrong. Few cells across
-- lose proportionally more than many do.
local function fraction(size, cell)
	local box = math.floor(size / cell) * math.floor(size / cell)
	return Scalable.SectionFit(Cylinder, size, size, cell, cell) / box
end

local coarse = fraction(48, 12)  -- 4 across
local fine   = fraction(480, 12) -- 40 across
check(fine > coarse, string.format(
	"a finer grid must waste less of the section (4 across %.3f, 40 across %.3f)", coarse, fine))
check(fine < ratio + 1e-6, "even a fine grid cannot beat the section's own area fraction")

-- The section stretches with the crate, so transposing both the crate and the
-- cell must land on the same count. This is the symmetry the old flat ratio did
-- have; breaking it would mean the axes had got crossed somewhere.
for _, case in ipairs({
	{ 24, 96, 14, 4 },
	{ 48, 48, 14, 4 },
	{ 96, 36, 6, 11 },
	{ 137.5, 60, 4.5, 8 },
}) do
	local sizeU, sizeV, cellU, cellV = case[1], case[2], case[3], case[4]
	check(Scalable.SectionFit(Cylinder, sizeU, sizeV, cellU, cellV)
		== Scalable.SectionFit(Cylinder, sizeV, sizeU, cellV, cellU),
		string.format("transposing %.1fx%.1f cell %.1fx%.1f must not change the count",
			sizeU, sizeV, cellU, cellV))
end

-- Orientation changes what the wall costs, which is exactly what one scalar
-- could not express. These two are the figures quoted in the writeup for a 48
-- crate: shells stood on end keep 56% of the box count, laid flat only 50%.
local standing = Scalable.SectionFit(Cylinder, 48, 48, 4, 4)
local flat     = Scalable.SectionFit(Cylinder, 48, 48, 14, 4)
check(standing == 81, "48 crate, 4x4 section: expected 81, got " .. standing)
check(flat == 18, "48 crate, 14x4 section: expected 18, got " .. flat)
check(near(standing / 144, 0.5625, 1e-9), "standing shells should keep 56% of the box count")
check(near(flat / 36, 0.5, 1e-9), "flat shells should keep 50% of the box count")
check(standing / 144 > flat / 36, "the wall must cost the two orientations differently")

print(string.format("ACE cylinder packing self-test: PASS (%d assertions, %d packings cross-checked)",
	checks, compared))
