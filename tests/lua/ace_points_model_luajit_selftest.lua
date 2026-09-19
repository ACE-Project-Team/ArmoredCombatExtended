local root = assert(arg[1], "usage: ace_points_model_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
function istable(value) return type(value) == "table" end
function isstring(value) return type(value) == "string" end
function ACE.IsEnt(value) return value ~= nil end
dofile(root .. "/lua/ace/shared/sh_ace_entity_state.lua")

dofile(root .. "/lua/ace/shared/sh_ace_points_model.lua")

local loaded = { Type = "APHE", ProjLength = 40 }
for _, name in ipairs({ "SM", "FLR", "CHF", "Refill", "HP", "FL", "AP", "CAP", "HE", "HEFS",
	"CHE", "HESH", "APHE", "HVAP", "APDS", "APFSDS", "HEAT", "HEATFS", "CHEAT", "GLATGM",
	"THEAT", "THEATFS", "GLATGM-HE", "Unknown" }) do
	local round = { Type = name, PropLength = 80, ProjLength = 60 }
	local base = ACE.Points.BaseRoundCost(round)
	local specialist = name == "SM" or name == "FLR" or name == "CHF" or name == "FL"
	assert(base >= (specialist and 1 or 140), "combat shells retain the full length baseline")
	round.maxPen, round.FrArea, round.SlugCaliber, round.blastMass, round.Caliber = 9999, 9999, 9999, 9999, 9999
	assert(ACE.Points.BaseRoundCost(round) == base, "old damage/penetration inputs must not affect cost")
	round.ProjLength, round.PropLength = 30, 40
	assert(ACE.Points.BaseRoundCost(round) == base / 2, "halving length must halve round value")
	round.ProjLength, round.PropLength = 10, 25
	assert(ACE.Points.BaseRoundCost(round) == base / 4, "halving total length again must halve round value")
end
assert(ACE.Points.BaseRoundCost({}) == 1, "missing dimensions retain the round floor")
assert(ACE.Points.BaseRoundCost({ PropLength = -80, ProjLength = -60 }) == 1,
	"invalid dimensions must not multiply into a positive size")

-- Conversion must use the clamped shell dimensions without evaluating damage or caliber.
ACE.ResolveAmmoType = function(_, bullet) return bullet.Type or bullet.RoundType end
local sourceFile = assert(io.open(root .. "/lua/ace/shared/sh_ace_functions.lua", "r"))
local ammoSource = sourceFile:read("*a")
sourceFile:close()
for _, name in ipairs({ "GetAmmoGunClass", "IsGLATGMAmmoType", "IsAmmoMissileType", "GetConfigurableName" }) do
	assert(loadstring(assert(ammoSource:match("(function ACE%." .. name .. "%b().-\nend)"))))()
end
ACE.Classes = { GunClass = { ATGM = { type = "missile" }, C = { type = "Gun" } } }
ACE.Weapons = { Guns = { missile = { gunclass = "ATGM" }, cannon = { gunclass = "C" } } }
local converted = ACE.Points.RoundFromBullet({ Type = "HE", ProjLength = 60, PropLength = 80,
	Caliber = 14, SlugCaliber = 0.1, maxPen = 0 })
assert(converted.ProjLength == 60 and converted.PropLength == 80 and converted.Caliber == nil)
local convertedCost = ACE.Points.BaseRoundCost(converted)
assert(ACE.Points.BaseRoundCost({ Type = "HE", ProjLength = 80, PropLength = 60 }) == convertedCost,
	"redistributing a fixed total length between projectile and propellant must preserve round value")

local primitive = {
	GetClass = function() return "prop_physics" end,
	ACE = { MaxArmour = 100, MaxHealth = 100 },
}
local pricedMm, pricedHp = ACE.Points.PropArmor(primitive)
assert(pricedMm and pricedHp == 100, "ordinary prop armor must retain its normal health")
primitive.ACE_PrimitivePropertiesPending = true
assert(ACE.Points.PropArmor(primitive) == nil,
	"Primitive armor must stay out of pricing while its properties are pending")

local function near(actual, expected, message)
	assert(math.abs(actual - expected) <= 1e-9 * math.max(1, math.abs(expected)), message)
end

do
	local bullet = { Id = "missile", Type = "HE", ProjLength = 30, PropLength = 3, Data7 = "Laser" }
	local missile = ACE.Points.RoundFromBullet(bullet)
	near(ACE.Points.BaseRoundCost(missile, true), 63, "missiles double projectile length, not propellant")
	near(bullet.ProjLength, 30, "pricing must not mutate real round dimensions")
	near(missile.ProjLength, 30, "pricing readouts retain the configured projectile length")
	for _, guidance in ipairs({ "Dumb", "Laser", "Radar" }) do
		missile.guidance = guidance
		near(ACE.Points.BaseRoundCost(missile, true), 63, "unguided and guided missiles share the length rule")
	end
	bullet.Id = "cannon"
	near(ACE.Points.BaseRoundCost(ACE.Points.RoundFromBullet(bullet), true), 33, "gun shells retain total length pricing")
	bullet.Id, bullet.Type = "missile", "GLATGM"
	near(ACE.Points.BaseRoundCost(ACE.Points.RoundFromBullet(bullet), true), 33 * 1.75,
		"gun-launched guided rounds retain their existing length rule")
	bullet.Id, bullet.Type, bullet.GunClass = nil, "HE", "ATGM"
	near(ACE.Points.BaseRoundCost(ACE.Points.RoundFromBullet(bullet), true), 63,
		"explicit ammo classes must resolve without a definition ID")
	local atCap, ready = ACE.Points.RackCostFromRate(4 / 30, 63, 63, 4, 1)
	local slower, sameReady = ACE.Points.RackCostFromRate(1 / 30, 63, 63, 4, 1)
	near(sameReady, ready, "rack cadence must not change the ready payload charge")
	near((slower - ready) / (atCap - ready), (1 / 4) ^ 0.25,
		"racks and guns must share the quarter-power cadence curve")
end

near(ACE.Points.FireRateMul(5 / 60), 1, "five rpm is the reference cadence")
near(ACE.Points.FireRateMul(80 / 60), 2, "sixteen times the RPM must double the rate premium")
local referenceGun = ACE.Points.GunCost(5 / 60, 140)
near(ACE.Points.GunCost(80 / 60, 140), 2 * referenceGun,
	"the billing path must apply the mild rate premium")
assert(ACE.Points.GunCost(10 / 60, 140) > referenceGun, "increasing RPM must still cost more")
near(ACE.Points.GunCost(1 / 300, 140), ACE.Points.GunCost(1 / 30, 140),
	"tiny configured ROFLimits must retain the delivery floor")

do
	local model = ACE.PointsModel
	local gunScale, rackScale = model.kGun, model.kRack
	local gun = ACE.Points.GunCost(5 / 60, 140)
	local rack = ACE.Points.RackCost(2, 4, 140, 140, 2.5)
	local legacyRack = ACE.Points.RackCost(2, 4, 140, 140)
	local minimum = ACE.Points.GunCost(0, 0)
	model.kGun = gunScale * 1.25
	near(ACE.Points.GunCost(5 / 60, 140), gun * 1.25, "gun scale must raise armed gun prices")
	near(ACE.Points.GunCost(0, 0), minimum, "gun scale must preserve the empty weapon minimum")
	near(ACE.Points.RackCost(2, 4, 140, 140, 2.5), rack, "gun tuning must not raise guided racks")
	near(ACE.Points.RackCost(2, 4, 140, 140), legacyRack, "gun tuning must not raise legacy racks")
	model.kGun, model.kRack = gunScale, rackScale * 2
	near(ACE.Points.GunCost(5 / 60, 140), gun, "rack tuning must not change guns")
	near(ACE.Points.RackCost(2, 4, 140, 140, 2.5), rack * 2, "rack scale must price ready and delivery terms")
	model.kRack = nil
	dofile(root .. "/lua/ace/shared/sh_ace_points_model.lua")
	near(model.kRack, gunScale, "older configuration tables must retain their shared rack scale")
	model.kRack = rackScale
end

for _, fuel in ipairs({ "Petrol", "Diesel", "Multifuel", "Electric", "Unknown" }) do
	near(ACE.Points.EngineCost(1000, fuel), ACE.Points.EngineCost(1000),
		"equal peak power must cost the same across fuel types")
end
near(ACE.Points.EngineCost(2000), 2 * ACE.Points.EngineCost(1000),
	"engine points must remain linear in power")
assert(ACE.Points.CrewCost(false) == 0 and ACE.Points.CrewCost(true) == 0,
	"all required crew must be free")
for _, class in ipairs({ "SBC", "C", "HW", "AL" }) do
	for loaders = 0, 4 do
		near(ACE.Points.SustainedRps(0.1, 1, 0, class, loaders), 0.1,
			"crew count must not change priced cadence")
		near(ACE.Points.SustainedRps(2, 4, 6, class, loaders), 0.5,
			"magazine reload must still reduce priced cadence")
	end
end

local configuredGunRps = ACE.GetGunConfiguredRps
ACE.GetGunConfiguredRps = function(_, limit) return limit / 60 end
local pricingGun = { MagSize = 1, MagReload = 0, Class = "SBC", ROFLimit = 60 }
for loaders = 0, 4 do
	pricingGun.LoaderCount = loaders
	near(ACE.Points.GunSustainedRps(pricingGun, {}, {}), 1,
		"gun adapter must not reintroduce loader pricing")
end
pricingGun.ROFLimit = 30
near(ACE.Points.GunSustainedRps(pricingGun, {}, {}), 0.5,
	"gun adapter must retain the configured rate limit")
ACE.GetGunConfiguredRps = configuredGunRps

ACE.ArmorTypes = {}
for _, file in ipairs({ "rha", "cast", "ceramic", "du", "titanium", "aluminum", "era", "rubber", "textolite" }) do
	dofile(root .. "/lua/ace/shared/armor/" .. file .. ".lua")
end

-- Execute the billing and preview callers as well as the shared model, so dropping the
-- third pricing input at either call site cannot pass a pure-model-only test.
local function readSource(path)
	local file = assert(io.open(root .. "/lua/" .. path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end
local shared = readSource("ace/shared/sh_ace_functions.lua")
local pricingSource = shared:sub(assert(shared:find("local function resolveGunPricingCandidate", 1, true)),
	assert(shared:find("-- Tells a player when their weapon priced", 1, true)) - 1)
assert(loadstring(pricingSource))()
local convertRound, configuredRate = ACE.Points.RoundFromBullet, ACE.GetGunConfiguredRps
ACE.Points.RoundFromBullet = function(round) return round end
ACE.GetGunConfiguredRps = function(_, _, round) return round.rate end
local lowRound = { Type = "APFSDS", maxPen = 200, rate = 0.2, ProjLength = 10 }
local highRound = { Type = "THEATFS", maxPen = 1000, rate = 0.1, ProjLength = 10 }
local function ammo(round, capacity, index)
	return { BulletData = round, Capacity = capacity, Ammo = capacity,
		EntIndex = function() return index end }
end
local lowCrate, highCrate = ammo(lowRound, 9, 1), ammo(highRound, 3, 2)
local mixedGun = { GetClass = function() return "acf_gun" end, AmmoLink = { lowCrate } }
local lowCost = ACE.GetGunFirepowerPoints(mixedGun)
mixedGun.AmmoLink = { highCrate }
local highCost = ACE.GetGunFirepowerPoints(mixedGun)
mixedGun.AmmoLink = { lowCrate, highCrate }
local maximum = math.max(lowCost, highCost)
near(ACE.GetGunFirepowerPoints(mixedGun), maximum,
	"linked ammunition must bill the most expensive complete configuration")
local mixedReadout = ACE.GetGunFirepowerReadout(mixedGun)
near(mixedReadout.FirepowerScale, ACE.PointsModel.kGun * ACE.PointsModel.Scale,
	"gun readouts must use the gun coefficient")
assert(mixedReadout.Round == (lowCost > highCost and lowRound or highRound),
	"readout must identify the selected round with its own cadence")
assert(loadstring(assert(shared:match("(function ACE.GetRoundLethalityLine%b().-\nend)"))))()
local shellLine = ACE.GetRoundLethalityLine(converted, true)
assert(shellLine:find("60.0 cm projectile + 80.0 cm propellant", 1, true)
	and not shellLine:find("caliber", 1, true), "round explanation must show both billed lengths")
local comma, roundNumber = string.Comma, math.Round
string.Comma, math.Round = tostring, function(value) return math.floor(value + 0.5) end
assert(ACE.GetGunFirepowerPricingLine(mixedReadout, true):find("rpm", 1, true),
	"tool explanation must describe the selected configuration")
string.Comma, math.Round = comma, roundNumber
highRound.ProjLength = 30
near(ACE.GetGunFirepowerPoints(mixedGun), math.max(lowCost, highCost * 3),
	"a newly more expensive linked round must become the selected configuration")
lowCrate.Capacity, lowRound.ProjLength = 900, 1
near(ACE.GetGunFirepowerPoints(mixedGun), highCost * 3,
	"cheap densely packed rounds must not dilute the expensive configuration")
lowCrate.Capacity, lowRound.ProjLength, highRound.ProjLength = 9, 10, 10
lowCrate.Ammo, highCrate.Ammo = 0, 0
near(ACE.GetGunFirepowerPoints(mixedGun), maximum, "depletion must not change design points")
lowCrate.Capacity, highCrate.Capacity = 0, nil
near(ACE.GetGunFirepowerPoints(mixedGun), maximum, "capacity must not select or exclude ammunition")
mixedGun.AmmoLink = { highCrate, lowCrate, ammo(lowRound, 900, 3) }
near(ACE.GetGunFirepowerPoints(mixedGun), maximum, "order and duplicate links must preserve cost")
mixedGun.AmmoLink = { ammo(lowRound, 0, 8), ammo(lowRound, 0, 4) }
local tieReadout = ACE.GetGunFirepowerReadout(mixedGun)
near(tieReadout.Points, lowCost, "equal candidates must preserve their configuration cost")
local tiedRound = { Type = lowRound.Type, ProjLength = lowRound.ProjLength, rate = lowRound.rate }
mixedGun.AmmoLink = { ammo(lowRound, 1, 8), ammo(tiedRound, 1, 4) }
assert(ACE.GetGunFirepowerReadout(mixedGun).Round == tiedRound,
	"equal candidates must select the lowest source index regardless of link order")
lowRound.rate, highRound.rate, highRound.ProjLength = 20, 0.001, 20
mixedGun.AmmoLink = { highCrate, lowCrate }
assert(ACE.Points.BaseRoundCost(highRound) > ACE.Points.BaseRoundCost(lowRound))
local cadenceWinner = ACE.GetGunFirepowerReadout(mixedGun)
assert(cadenceWinner.Round == lowRound and cadenceWinner.Rate == 20,
	"selection must compare final weapon cost and retain the winning round's cadence")
lowRound.rate, highRound.rate, highRound.ProjLength = 0.2, 0.1, 10
mixedGun.AmmoLink = { highCrate }
near(ACE.GetGunFirepowerPoints(mixedGun), highCost, "unlinking the winner must select the remainder")
mixedGun.AmmoLink = {}
near(ACE.GetGunFirepowerPoints(mixedGun), ACE.Points.GunCost(0, 0, 0),
	"unlinked guns must retain the weapon minimum")
local rackReload = ACE.GetRackConfiguredReloadTime
ACE.GetRackConfiguredReloadTime = function() return 2 end
local rack = { GetClass = function() return "acf_rack" end, MaxMissile = 1,
	AmmoLink = { lowCrate, highCrate } }
local rate = ACE.Points.RackRate(2, 1)
local rackExpected = math.max(
	ACE.Points.RackCostFromRate(rate, ACE.Points.RoundScore(lowRound), ACE.Points.BaseRoundCost(lowRound), 1, 1),
	ACE.Points.RackCostFromRate(rate, ACE.Points.RoundScore(highRound), ACE.Points.BaseRoundCost(highRound), 1, 1))
near(ACE.GetGunFirepowerPoints(rack), rackExpected, "racks must retain strongest-candidate pricing")
for _, tubes in ipairs({ 1, 2, 4 }) do
	rack.MaxMissile = tubes
	local function expected(round)
		return tubes * math.max(ACE.PointsModel.kRack * ACE.Points.BaseRoundCost(round), 20)
			* ACE.PointsModel.Scale
	end
	local readout = ACE.GetGunFirepowerReadout(rack)
	near(readout.FirepowerScale, ACE.PointsModel.kRack * ACE.PointsModel.Scale,
		"rack readouts must use the independent rack coefficient")
	near(readout.Points, math.max(expected(lowRound), expected(highRound)),
		"rack candidate selection and billing must charge every ready tube")
	near(readout.BaseRoundCostPoints, 0.6 * readout.Points,
		"readout must expose all ready-missile points")
	near(readout.DeliveryPoints + readout.BaseRoundCostPoints, readout.Points,
		"rack readout components must reconcile")
	rack.CurMissile = 0
	near(ACE.GetGunFirepowerPoints(rack), readout.Points, "empty tubes retain design points")
end
local dumb = { Type = "HEAT", ProjLength = 90, guidance = "Dumb" }
local seeker = { Type = "HEAT", ProjLength = 50, guidance = "Radar" }
rack.MaxMissile, rack.AmmoLink = 4, { ammo(dumb, 1, 7), ammo(seeker, 1, 8) }
assert(ACE.GetGunFirepowerReadout(rack).Round == seeker,
	"candidate ordering must apply the new guidance ratios before selecting ammo")
for _, pen in ipairs({ 0, 1, 100, 840, 2000 }) do
	local round = { Type = "HEAT", ProjLength = pen }
	local base = ACE.Points.BaseRoundCost(round, true)
	local reference = math.max(ACE.PointsModel.kRack * base, 20) * ACE.PointsModel.Scale
	for name, ratio in pairs({ Dumb = 0.7, Laser = 1.1, Infrared = 2.5, Radar = 2.5, Top_Attack_IR = 3.5 }) do
		round.guidance = name
		near(ACE.Points.BaseRoundCost(round, true), base, "rack payload must exclude legacy guidance")
		for _, tubes in ipairs({ 1, 2, 4 }) do
			rack.MaxMissile, rack.AmmoLink = tubes, { ammo(round, 1, 9) }
			local readout = ACE.GetGunFirepowerReadout(rack)
			near(readout.Points, reference * ratio * tubes,
				"actual rack billing must hit total-price targets including flat minima and tube scaling")
			near(readout.DeliveryPoints + readout.BaseRoundCostPoints, readout.Points,
				"guidance-adjusted readout must reconcile")
			near(readout.GuidanceMultiplier, ratio, "readout must expose the final guidance ratio")
			near(ACE.Points.RackCost(2, tubes, base, base, ratio), readout.Points,
				"wrapper must pass the guidance ratio")
		end
	end
end
local fast = ACE.GetGunFirepowerPoints(rack)
math.Round = function(value) return math.floor(value + 0.5) end
string.Comma = tostring
mixedGun.AmmoLink = { lowCrate }
local singleReadout = ACE.GetGunFirepowerReadout(mixedGun)
near(singleReadout.RawPoints, singleReadout.Points, "raw gun readout must use the billed rate curve")
for _, compact in ipairs({ true, false }) do
	local line = ACE.GetGunFirepowerPricingLine(singleReadout, compact)
	assert(line:find("x rate", 1, true) and not line:find("threat", 1, true),
		"both readouts must explain the rate premium without the removed threat term")
end
local rackReadout = ACE.GetGunFirepowerReadout(rack)
assert(ACE.GetGunFirepowerPricingLine(rackReadout, true):find(
	string.format("includes %.2fx guidance", rackReadout.GuidanceMultiplier), 1, true),
	"rack pricing text must show the billed guidance ratio")
ACE.GetRackConfiguredReloadTime = function() return 120 end
local slow = ACE.GetGunFirepowerPoints(rack)
assert(slow <= fast and slow >= fast * 0.6,
	"slow racks retain per-tube value while delivery cost may decrease")
rack.MaxMissile, rack.AmmoLink = nil, {}
near(ACE.GetGunFirepowerPoints(rack), ACE.Points.GunCost(5 / 60, 0, 0),
	"empty racks with missing tube capacity must retain the reference minimum")
for _, name in ipairs({ "Beam_Riding", "GPS", "Unknown" }) do
	near(ACE.Points.RackGuidanceMul({ guidance = name }), ACE.Points.GuidanceMul({ guidance = name }),
		"guidance outside the agreed tiers retains its relative factor")
end
ACE.Points.RoundFromBullet = convertRound
ACE.GetRackConfiguredReloadTime = function() return 2 end
local longWarhead = { Id = "missile", Type = "HE", ProjLength = 30, PropLength = 3, Data7 = "Laser" }
local longMotor = { Id = "missile", Type = "HE", ProjLength = 10, PropLength = 30, Data7 = "Laser" }
rack.MaxMissile, rack.AmmoLink = 1, { ammo(longMotor, 1, 10), ammo(longWarhead, 1, 11) }
local missileReadout = ACE.GetGunFirepowerReadout(rack)
near(missileReadout.Round.ProjLength, 30, "candidate selection must rank the new missile length price")
near(missileReadout.Points, 6 * 63 * 0.65 * 1.1, "actual missile billing must apply the length premium once")
near(missileReadout.BaseRoundCostPoints, missileReadout.Points * 0.6,
	"the ready charge and delivery must both include the missile premium")
near(missileReadout.BaseRoundCost, 63, "readout and billing must share the priced length")
near(longWarhead.ProjLength, 30, "billing must leave the linked crate dimensions unchanged")
ACE.GetRackConfiguredReloadTime = rackReload
ACE.Points.RoundFromBullet, ACE.GetGunConfiguredRps = convertRound, configuredRate
assert(loadstring(assert(shared:match("(function ACE.GetSurvivabilityIndex%b().-\nend)"))))()
local tool = readSource("weapons/gmod_tool/stools/acearmorprop.lua")
local previewSource = assert(tool:match("(local function getArmorPointPreview%b().-\n\tend)"))
local preview = assert(loadstring(previewSource .. "\nreturn getArmorPointPreview"))()

for mat, material in pairs(ACE.ArmorTypes) do
	for _, thickness in ipairs({ 0.1, 1, 10, 100, 1000 }) do
		local ke, chem = ACE.Points.MaterialEff(mat)
		local curve = mat == "ERA" and 1 or material.curve
		local effective, efficiency = ACE.Points.MaterialArmor(thickness, mat)
		near(effective, thickness ^ curve * (0.7 * ke + 0.3 * chem),
			"pricing must use the material's ordinary curve or ERA's active linear path")
		near(efficiency * thickness * material.massMod, effective,
			"efficiency must equal RHA mass divided by material mass at equal protection")

		local prop = {
			GetClass = function() return "prop_physics" end,
			ACE = { MaxArmour = thickness, MaxHealth = 100, Material = mat, Armour = 0, Health = 0 },
		}
		local points = ACE.Points.ArmorProp(effective, 100, efficiency)
		near(ACE.GetSurvivabilityIndex(prop), points, "server billing must include mass efficiency")
		near(preview(thickness, 100, mat), points, "preview must match server billing")
		near(2 * ACE.Points.ArmorProp(effective, 50, efficiency), points,
			"splitting an equal-thickness plate's area/health must preserve total points")
	end
end

local rhaMm, rhaEfficiency = ACE.Points.MaterialArmor(100, "RHA")
local tiMm, tiEfficiency = ACE.Points.MaterialArmor(100 / 1.7, "Ti")
local castMm, castEfficiency = ACE.Points.MaterialArmor(100 / 0.98, "CHA")
near(tiMm, rhaMm, "fixture must compare equal protection")
near(castMm, rhaMm, "fixture must compare equal protection")
near(rhaEfficiency, 1, "RHA is the mass-efficiency baseline")
assert(ACE.Points.ArmorProp(tiMm, 100, tiEfficiency) > ACE.Points.ArmorProp(rhaMm, 100),
	"mass-reducing titanium must pay a premium at equal protection")
assert(ACE.Points.ArmorProp(castMm, 100, castEfficiency) < ACE.Points.ArmorProp(rhaMm, 100),
	"mass-inefficient cast armor must receive a discount at equal protection")
near(ACE.Points.EffectiveMm(100, 1, 1), 100, "legacy three-argument thickness calls must remain valid")
local unknownMm, unknownEfficiency = ACE.Points.MaterialArmor(100, "Unknown")
near(unknownMm, rhaMm, "unknown materials must keep the RHA billing fallback")
near(unknownEfficiency, 1, "unknown materials must have no mass adjustment")
near(preview(100, 100, "Unknown"), ACE.Points.ArmorProp(100, 100),
	"unknown-material preview and billing must agree")
for _, thickness in ipairs({ 0, -1 }) do
	local effective, efficiency = ACE.Points.MaterialArmor(thickness, "Rub")
	assert(effective == 0 and efficiency == 1, "empty armor must not divide by zero")
	assert(preview(thickness, 100, "Rub") == 0, "empty preview must be free")
end

local rackRate = ACE.Points.RackRate(2, 1)
local rackScore = ACE.Points.RoundScore(loaded)
local rackBaseCost = ACE.Points.BaseRoundCost(loaded)
local rackPricedRate = math.max(rackRate, 1 / 30)
local rackWithoutRound = math.max(ACE.PointsModel.kRack * rackPricedRate * rackScore, 100)
local rackWithRound = ACE.Points.RackCostFromRate(rackRate, rackScore, rackBaseCost)
local rackExpected = (rackWithoutRound + rackBaseCost) * ACE.PointsModel.Scale
assert(math.abs(rackWithRound - rackExpected) < 1e-9,
	"rack firepower must add the selected round's base cost exactly once")
assert(math.abs(rackWithoutRound * ACE.PointsModel.Scale
	+ rackBaseCost * ACE.PointsModel.Scale - rackWithRound) < 1e-9,
	"rack delivery and base-round points must sum to the billed total")
assert(math.abs(ACE.Points.RackCostFromRate(rackRate, rackScore)
	- rackWithoutRound * ACE.PointsModel.Scale) < 1e-9,
	"rack pricing without the optional base cost must preserve the old result")
assert(math.abs(ACE.Points.RackCost(2, 1, rackScore)
	- rackWithoutRound * ACE.PointsModel.Scale) < 1e-9,
	"rack wrapper without the optional base cost must preserve the old result")
local rackFloor = ACE.Points.RackCostFromRate(0, 0, rackBaseCost)
assert(math.abs(rackFloor - (100 + rackBaseCost) * ACE.PointsModel.Scale) < 1e-9,
	"rack flat floor must apply before the base-round addition")
near(ACE.Points.RackCostFromRate(0, 0, rackBaseCost, 4), (100 + 4 * rackBaseCost) * ACE.PointsModel.Scale,
	"ready payload must scale even when delivery hits its minimum")
near(ACE.Points.RackCost(6, 4, rackScore, rackBaseCost),
	ACE.Points.RackCostFromRate(ACE.Points.RackRate(6, 4), rackScore, rackBaseCost, 4),
	"reload-time wrapper must forward tube capacity")

print("ACE points model LuaJIT self-test: PASS")
