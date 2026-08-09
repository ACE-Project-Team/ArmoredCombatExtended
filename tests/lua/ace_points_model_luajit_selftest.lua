local root = assert(arg[1], "usage: ace_points_model_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
function istable(value) return type(value) == "table" end
function ACE.IsEnt(value) return value ~= nil end
function ACE.ResolveAmmoType(_, data) return data.Type or data.RoundType end
function ACE.GetAmmoMaxPen(data) return data.MaxPen or data.MaxPen2 or 0 end
function ACE.GetAmmoBlastMass(data) return data.BoomFillerMass or data.FillerMass or 0 end
function ACE.IsGLATGMAmmoType() return false end

dofile(root .. "/lua/acf/shared/sh_ace_points_model.lua")

assert(ACE.PointsModel.ArmorMassAlpha == 0.5, "armor mass alpha must default to 0.5")
local expectedBaseArmorCost = ACE.PointsModel.kArmor * 100.0 * ACE.PointsModel.Scale * 10.0
assert(math.abs(ACE.Points.ArmorProp(50, 75, 1) - expectedBaseArmorCost) < 1e-9,
	"armor HP pricing must use the 10x balance multiplier")
assert(math.abs(ACE.Points.ArmorProp(50, 150, 1) / ACE.Points.ArmorProp(50, 75, 1) - 2.0) < 1e-9,
	"linear HP pricing must remain split-neutral")

local empty = { Type = "APHE", maxPen = 200, FrArea = math.pi * 5 ^ 2, blastMass = 0 }
local loaded = { Type = "APHE", maxPen = 200, FrArea = math.pi * 5 ^ 2, blastMass = 60 }

assert(ACE.Points.IntrinsicValueMul(empty) == 1.0,
	"zero-filler APHE must not receive HE utility value")
assert(ACE.Points.GatePen(empty) == empty.maxPen,
	"zero-filler APHE must retain only its kinetic penetration gate")
assert(ACE.Points.IntrinsicValueMul(loaded) == 1.5,
	"loaded APHE must receive HE payload value")
assert(ACE.Points.GatePen(loaded) > ACE.Points.GatePen(empty),
	"loaded APHE filler must add HE-equivalent threat reach")
assert(ACE.Points.BaseRoundCost(loaded) > ACE.Points.BaseRoundCost(empty),
	"loaded APHE filler must add round cost")

local primitive = {
	GetClass = function() return "prop_physics" end,
	ACF = { MaxArmour = 100, MaxHealth = 100, Material = "Ti" },
}
local threatRHAe, health, massEfficiency = ACE.Points.PropArmor(primitive)
assert(threatRHAe ~= nil and health == 100 and massEfficiency > 1,
	"ordinary prop armor must return a lightweight-material premium")
primitive.ACE_PrimitivePropertiesPending = true
assert(ACE.Points.PropArmor(primitive) == nil,
	"Primitive armor must stay out of pricing while its properties are pending")

ACE.PointsModel.ArmorMassAlpha = 1.0
local titanium = ACE.Points.ArmorProp(threatRHAe, health, massEfficiency)
ACE.PointsModel.ArmorMassAlpha = 0.5
local relaxed = ACE.Points.ArmorProp(threatRHAe, health, massEfficiency)
ACE.PointsModel.ArmorMassAlpha = 2.0
local strict = ACE.Points.ArmorProp(threatRHAe, health, massEfficiency)
ACE.PointsModel.ArmorMassAlpha = 0.5
assert(relaxed < titanium and strict > titanium,
	"armor mass alpha must control the lightweight-material premium")

local unknown = {
	GetClass = primitive.GetClass,
	ACF = { MaxArmour = 100, MaxHealth = 100, Material = "Unknown" },
}
local _, _, unknownMassEfficiency = ACE.Points.PropArmor(unknown)
assert(math.abs(unknownMassEfficiency - 1) < 1e-12,
	"unknown materials must use neutral mass efficiency")

local gunWithGunner = ACE.Points.GunCost(1, 10, 0.5, 1)
local gunWithoutGunner = ACE.Points.GunCost(1, 10, 0.5, 2)
assert(math.abs(gunWithoutGunner / gunWithGunner - 2) < 1e-12,
	"ungunned guns must cost exactly twice as much firepower")

local minimumWithGunner = ACE.Points.GunCost(0, 0, 0, 1)
local minimumWithoutGunner = ACE.Points.GunCost(0, 0, 0, 2)
assert(math.abs(minimumWithoutGunner / minimumWithGunner - 2) < 1e-12,
	"the ungunned multiplier must apply to the flat firepower minimum")

local illegalLoader = { Legal = false, GetClass = function() return "ace_crewseat_loader" end }
local legalLoader = { Legal = true, GetClass = function() return "ace_crewseat_loader" end }
local illegalGunner = { Legal = false, GetClass = function() return "ace_crewseat_gunner" end }
local crewedGun = {
	LoaderCount = 2,
	HasGunner = true,
	CrewLink = { illegalLoader, legalLoader, illegalGunner },
}
assert(ACE.Points.LegalLoaderCount(crewedGun) == 1,
	"illegal linked loaders must not grant firepower reload credit")
assert(not ACE.Points.HasLegalGunner(crewedGun),
	"an illegal linked gunner must not remove the ungunned multiplier")

-- Crate configuration charge: linear in round score, one delivery per engagement window,
-- and zero for an unscored (utility) configuration.
local model = ACE.PointsModel
local windowRate = ACE.Points.RateFloor()
assert(math.abs(ACE.Points.CrateCost(300) - model.kGun * windowRate * 300 * model.Scale) < 1e-9,
	"crate config cost must be one window-delivery of the round score")
assert(math.abs(ACE.Points.CrateCost(600) / ACE.Points.CrateCost(300) - 2) < 1e-12,
	"crate config cost must be linear in round score")
assert(ACE.Points.CrateCost(0) == 0 and ACE.Points.CrateCost(-5) == 0,
	"unscored configurations must bill zero crate points")

-- Definition rate of fire: reload law parity with the configured-rps path, plus the maxrof cap.
local vol = 800
local expectedReload = ((vol / 500) ^ 0.60) * 1.4
assert(math.abs(ACE.Points.DefinitionRps(vol, 100, 1.4, 0) - 1 / expectedReload) < 1e-12,
	"definition rps must follow the gun reload law")
assert(math.abs(ACE.Points.DefinitionRps(vol, 100, nil, 0) - ACE.Points.DefinitionRps(vol, 100, 1, 0)) < 1e-12,
	"missing definition rate modifiers must retain the neutral legacy cadence")
assert(math.abs(ACE.Points.DefinitionRps(1, 1, 0.01, 600) - 10) < 1e-12,
	"definition rps must cap at the definition maxrof")
assert(ACE.Points.DefinitionRps(400, 800, 1, 0) < ACE.Points.DefinitionRps(800, 800, 1, 0) + 1e-12
	and math.abs(ACE.Points.DefinitionRps(400, 800, 1, 0) - ACE.Points.DefinitionRps(800, 800, 1, 0)) < 1e-12,
	"the definition minimum round volume must floor the reload time")
assert(ACE.Points.DefinitionRps(0, 0, 1, 600) == 0,
	"a definition with no round volume must not produce a rate")

local nan = 0 / 0
assert(ACE.Points.SafeNumber(nan, 7) == 7 and ACE.Points.SafeNonNegative(-5) == 0,
	"non-finite and negative pricing inputs must fail closed")
ACE.PointsOperationalVersion = 10
assert(ACE.Points.BumpOperationalVersion() == 11 and ACE.PointsOperationalVersion == 11,
	"operational point version bumps must be executable and monotonic")
assert(ACE.Points.Gate(nan) == 0 and ACE.Points.BaseRoundCost({ maxPen = nan, FrArea = nan }) == 1,
	"invalid round data must not propagate NaN into points")
assert(ACE.Points.RoundFromBullet({ Type = "AP", FrArea = 0 / 0, MaxPen = 0 }) == nil,
	"non-damaging or corrupt rounds must not become cheap priced candidates")

-- Best practical synthesis resolves nothing without definition tables and caches the miss.
assert(ACE.Points.BestPracticalRound(nil) == nil, "nil gun ids must not synthesize")
assert(ACE.Points.BestPracticalRound("missing-gun") == nil,
	"unknown gun ids must not synthesize")
assert(ACE.Points.BestPracticalRound("missing-gun") == nil,
	"cached definition misses must stay nil")
ACE.Points.ClearBestPracticalCache()

print("ACE points model LuaJIT self-test: PASS")
