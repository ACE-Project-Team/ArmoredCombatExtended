ACF = ACF or {}

ACF.AmmoTypes = {}
ACF.MenuFunc = {}
ACF.AmmoBlacklist = {}
ACF.Version = 502        -- ACE current version
ACF.CurrentVersion = 0    -- just defining a variable, do not change

ACF.Year = 2023            -- Current Year

print("[ACE | INFO]- loading ACE. . .")

ACE               = ACE or {}
ACE.ArmorTypes    = {}
ACE.GSounds       = {}

ACF.Weapons       = {}
ACF.Classes       = {}
ACF.RoundTypes    = {}
ACF.IdRounds      = {}    --Lookup tables so i can get rounds classes from clientside with just an integer

ACFM = ACFM or {}

---------------------------------- Useless/Ignore ----------------------------------
ACFM.FlareBurnMultiplier        = 0.5
ACFM.FlareDistractMultiplier    = 1 / 35

---------------------------------- General ----------------------------------

ACF.EnableKillicons       = true                    -- Enable killicons overwriting.
ACF.GunfireEnabled        = true
ACF.MeshCalcEnabled       = false

ACF.SpreadScale           = 16                        -- The maximum amount that damage can decrease a gun's accuracy.  Default 4x
ACF.GunInaccuracyScale    = 1                        -- A multiplier for gun accuracy.
ACF.GunInaccuracyBias     = 2                        -- Higher numbers make shots more likely to be inaccurate.  Choose between 0.5 to 4. Default is 2 (unbiased).
ACF.SWEPInaccuracyMul      = 0.5

---------------------------------- Debris ----------------------------------

ACF.DebrisIgniteChance    = 0.25
ACF.DebrisScale           = 10                        -- Ignore debris that is less than this bounding radius.
ACF.DebrisChance          = 1
ACF.DebrisLifeTime        = 30

---------------------------------- Fuel & fuel Tank config ----------------------------------

ACF.LiIonED             = 0.27                    -- li-ion energy density: kw hours / liter --BEFORE to balance: 0.458
ACF.CuIToLiter          = 0.0163871                -- cubic inches to liters

ACF.DriverTorqueBoost   = 1.25                    -- torque multiplier from having a driver
ACF.FuelRate            = 10                        -- multiplier for fuel usage, 1.0 is approx real world
-- Electric motor consumption multiplier. FuelUse = ElecRate/(Efficiency*3600), and
-- consumption = kW_mech * FuelUse * dt. At 0.8 (with Efficiency 0.8) the draw equals
-- the mechanical output put to the wheels (~100% effective) - realistic, and slightly
-- BELOW a real motor's ~1.11x draw (90% efficient), so it's a touch generous. The old
-- value of 4 made motors burn ~5x their mechanical output.
ACF.ElecRate            = 0.8                      -- multiplier for electrics (0.8 ≈ realistic, slightly generous)
ACF.TankVolumeMul       = 1                        -- multiplier for fuel tank capacity, 1.0 is approx real world

---------------------------------- Sustainability / power generation config ----------------------------------
-- These feed the pure-logic modules in acf/shared/sustainability. All are
-- tunable; balance curves can be eyeballed with `python tests/sim.py`.

-- Alternator (brake-based generator). Stats scale with shape volume (cu in).
-- Real reference: a car alternator is ~1-2 kW; this is EV/genset-scale. A default
-- 20^3 box = 8000 cu in -> 32 kW rated. Output is DC (rectified), to match the
-- DC batteries it charges. The grid (cables) is the only AC part.
ACF.AlternatorPowerDensity    = 0.004           -- kW per cu in (rated DC output)
ACF.AlternatorRefPower        = 32              -- rated output of a default-size unit (for brake scaling)
ACF.AlternatorRatedRPM        = 3000            -- RPM at which rated output is reached
ACF.AlternatorBrakeCoeff      = 8               -- base drag strength (scaled by alternator size)
ACF.AlternatorMassPerVolume   = 0.004           -- kg per cu in
ACF.AlternatorEfficiency      = 0.85            -- mechanical -> electrical (0-1)
ACF.AlternatorPointsPerVolume = 0.05            -- points per cu in

-- Solar panel (area-based). "Box only" flat slab.
ACF.SolarEfficiency           = 0.20            -- conversion efficiency (0-1)
ACF.SolarIrradiance           = 1.0             -- kW/m^2 peak sunlight
ACF.SolarMassPerArea          = 5               -- kg per m^2 of panel area
ACF.SolarPointsPerArea        = 50              -- ACF points per m^2
ACF.SolarMapLightFloor        = 0.3             -- a dark/night map never drops solar output below this fraction

-- Electric fuel synthesizer (electricity -> liquid fuel).
ACF.SynthPowerDensity         = 0.02            -- kW electrical draw per cu in
ACF.SynthEfficiency           = 0.55            -- electrical -> chemical (0-1)
ACF.SynthEnergyPerLiter       = 9.7             -- kWh chemical per litre of fuel
ACF.SynthMassPerVolume        = 0.005           -- kg per cu in
ACF.SynthPointsPerVolume      = 0.05            -- ACF points per cu in

-- Refinery: crude Oil + electricity -> Petrol/Diesel (the output tank's type).
ACF.RefineryRate              = 0.06            -- max output litres/sec
ACF.RefineryOilPerLiter       = 1.25           -- litres of crude consumed per litre of product (refining loss)
ACF.RefineryEnergyPerLiter    = 0.4            -- kWh of electricity per litre of product
ACF.RefineryHeatFrac          = 1.0            -- fraction of electrical draw (W) turned into process heat while running
ACF.RefineryThermalMass       = 60             -- kg thermal mass for the heat model (small enough that it actually warms up)

-- Self-powered field generator ("thumper"): slow free fuel, lots of heat.
ACF.FieldGenRate              = 0.0000015       -- litres/sec per cu in
ACF.FieldGenHeatDensity       = 6               -- watts of heat per cu in while running (runs HOT)
ACF.FieldGenMassPerVolume     = 0.004           -- kg per cu in
ACF.FieldGenPointsPerVolume   = 0.04            -- points per cu in
ACF.FieldGenThumperModel      = "models/props_combine/combinethumper002.mdl" -- optional real model

-- Battery (extends the Electric fuel tank). See logic_battery for behaviour.
ACF.BatteryChargeEff          = 0.95            -- one-way charge/discharge efficiency
ACF.BatteryDegradePerCycle    = 0.0006          -- usable capacity lost per full cycle
ACF.BatteryMinHealth          = 0.50            -- floor for capacity fade
-- Charge/discharge power cap = capacity(kWh) * this. Real Li-ion is ~1-3C, but
-- GMod time is compressed, so this is a GAMEPLAY value: at 50C a 77 kWh battery
-- accepts up to 3850 kW, charging to 80% (61.6 kWh) in ~60 s on a fast charger.
-- It only CAPS the rate; motors still draw their realistic kW well under it.
ACF.BatteryChargeRateC        = 50              -- charge/discharge rate cap (C); high = arcade-fast charging
ACF.BatteryRadiusPenalty      = 0.35            -- efficiency multiplier for radius (wireless) charging
ACF.BatteryRadiusRate         = 2000            -- kW base wireless charge rate (penalised; ~700 kW effective)

-- Wireless (radius) liquid refuel: a Supply-mode liquid tank tops up nearby
-- same-type tanks. Deliberately slower than a physical plug so the plug stays
-- the better option for serious logistics.
ACF.FuelRadiusRate            = 4               -- litres/sec wireless (vs 12 L/s through a plug)

-- Fuel plug/socket physical transfer.
ACF.FuelLinkRate              = 12              -- litres/sec transferred through a plug (gas)
ACF.FuelLinkRateElec          = 4000           -- kW transferred through a plug (electric; a "supercharger" cable)
ACF.FuelLinkLoss              = 0.04            -- fraction lost (as heat) during transfer

-- Fuel pipe (link between two tanks/sockets). Wears slowly while in use;
-- condition is the pipe's ACF health, so the ACE torch repairs it.
ACF.PipeDecayPerSec           = 1 / 36000       -- condition lost per second while flowing (~10h of continuous flow to break)
ACF.PipeFlowMul               = 0.75            -- pipe throughput vs a direct plug (slightly less)
ACF.PipeMaxLength             = 1000            -- max link distance for one pipe segment (chain pipe->pipe for longer)
ACF.PipeMaxLinks              = 6               -- max links per pipe/pump node
ACF.PipeMaxHops               = 14              -- max pipe-graph search depth
ACF.PipeBasePressure          = 1.0             -- pressure budget a supply provides (spends down with friction)
ACF.PipePumpPressure          = 1.0             -- pressure budget each Pump/Booster adds (place them to extend range)

-- Electric grid: stations are linked directly to each other (no cable entity);
-- distance loss is computed from world positions in logic_grid. Voltage is the
-- single IRL lever - higher voltage carries more power AND loses less.
ACF.GridStationDefaultVoltage = 5               -- default station AC voltage (1-10)
ACF.GridStationMaxVoltage     = 10
ACF.GridStationBaseKW         = 30              -- (legacy) kept for back-compat; capacity now comes from size
ACF.GridStationCapacityPerVolume = 0.0056       -- throughput capacity (kW) per cu in of station hardware (build-fixed; voltage no longer multiplies it)
-- 3-phase vs single-phase (a station/build option). Real 3-phase delivers smooth,
-- denser power, so here it's a flag (NOT a waveform sim): 3-phase carries ~sqrt(3)x
-- more for the same hardware and runs cooler per kW. Single-phase is the default.
ACF.GridStation3PhaseMul      = 1.732           -- capacity multiplier when wired 3-phase
ACF.GridStation3PhaseHeatMul  = 0.6             -- waste-heat multiplier when 3-phase (smoother = cooler)
ACF.GridStationLinkRange      = 1500            -- max distance for one station<->station link (chain relays to go further)
ACF.GridStationMaxLinks       = 6               -- max direct links per station (perf + realism)
ACF.GridMaxHops               = 10              -- max relay depth a pull will search
ACF.GridCollectorRange        = 400             -- pickup range for vehicle collectors
ACF.GridCollectorMaxKW        = 1000            -- max pickup rate for collectors (fast tram catenary; still capped by wire ampacity*voltage)

-- Station heat / failure: conversion loss becomes heat (idle = cool, busy hub =
-- hot); pushing past rated capacity overheats it, which slowly damages its ACF
-- health until it sparks and trips offline (torch-repair to revive). No boom.
ACF.GridStationHeatPerKW      = 9               -- waste heat (J/s) per kW of throughput (the conversion loss)
ACF.GridStationOverloadHeatMul= 6               -- heat multiplier on the throughput ABOVE capacity
ACF.GridStationOverheatTemp   = 140             -- deg C above which it takes damage
ACF.GridStationDamagePerSec   = 0.03            -- fraction of max health lost per second while overheating
ACF.GridStationTripHealth     = 0.15            -- health fraction at/below which it trips offline
ACF.GridStationReviveHealth   = 0.40            -- health fraction it must be torch-repaired back to before it re-energises

-- Transformer: changes AC voltage (step up for transmission, step down for
-- utilization). It's a grid relay node whose OUTPUT voltage you set; ampacity
-- (and thus power capacity = ampacity * voltage) comes from its physical size,
-- so a bigger transformer carries more - voltage is not a free capacity dial.
-- Voltage is an abstract unit shared with stations and consumer MinVoltage.
ACF.TransformerAmpacityPerVolume = 0.0009       -- ampacity per cu in of hardware
ACF.TransformerEff               = 0.97         -- conversion efficiency per pass
ACF.TransformerDefaultVoltage    = 30           -- default output voltage
ACF.TransformerMaxVoltage        = 100          -- highest output voltage you can set (HV transmission)
ACF.TransformerMassPerVolume     = 0.01         -- kg per cu in
ACF.TransformerPointsPerVolume   = 0.05         -- ACF points per cu in
ACF.TransformerHeatPerKW         = 6            -- waste heat (J/s) per kW of throughput (the conversion loss)
ACF.TransformerLinkRange         = 1500         -- max distance to link to another grid node
ACF.TransformerMaxLinks          = 6            -- max direct links
ACF.TransformerOverheatTemp      = 150          -- deg C above which it takes damage
ACF.TransformerDamagePerSec      = 0.03         -- fraction of max health lost per second while overheating
ACF.TransformerTripHealth        = 0.15         -- health fraction at/below which it trips offline
ACF.TransformerReviveHealth      = 0.40         -- health it must be torch-repaired back to before re-energising

-- Power line (physical conductor / catenary). A scalable grid node that carries
-- power WITHOUT a conversion (it's a wire, not a transformer). Cross-section sets
-- ampacity; a thinner/longer run is more resistive. Chain them along a track for
-- a tram catenary that collectors pick up from.
-- Ampacity (A) per sq-in of CROSS-SECTION (two shorter dims). Power a wire can
-- carry = ampacity x voltage (P=VI), so this tunes the absolute kW a wire moves.
-- A default 6x6x72 wire (36 sq-in) at voltage 5 carries 36*0.6*5 = ~108 kW, and
-- ~216 kW at voltage 10 - raising voltage pushes more power through the SAME
-- wire (the real reason grids transmit at high voltage). The old 0.06 made even
-- a fat wire cap at single-digit kW, which throttled collectors to ~1 kW.
ACF.PowerLineAmpacityPerArea  = 0.6             -- ampacity (A) per sq-in of conductor CROSS-SECTION (the two shorter dims)
ACF.PowerLineResistivity      = 1.25            -- conductor resistivity (copper-ish). Loss = R/voltage^2, R = rho*length/area*(temp). Low voltage bleeds power - step up with a transformer for long runs.
ACF.PowerLineMassPerVolume    = 0.004           -- kg per cu in
ACF.PowerLinePointsPerVolume  = 0.02
ACF.PowerLineHeatPerKW        = 4               -- resistive waste heat (J/s) per kW carried
ACF.PowerLineLinkRange        = 1200            -- max link distance to another grid node
ACF.PowerLineMaxLinks         = 6
ACF.PowerLineOverheatTemp     = 130             -- deg C above which it takes damage
ACF.PowerLineDamagePerSec     = 0.03
ACF.PowerLineTripHealth       = 0.10            -- a wire breaks (stops carrying) at this condition
ACF.PowerLineReviveHealth     = 0.40

-- Capacitor: a fast grid buffer. Tiny energy, huge power - it discharges hard on
-- a spike and refills slowly from the grid, so a load near it sees smooth power
-- (peak-shaving) while the grid behind only carries the average. It's a source
-- node the solver prefers when it's the closest, and it tops itself up each tick.
ACF.CapacitorEnergyPerVolume  = 0.000015        -- kWh of store per cu in (small)
ACF.CapacitorRatePerVolume    = 0.02            -- kW charge/discharge cap per cu in (high)
ACF.CapacitorMassPerVolume    = 0.006           -- kg per cu in
ACF.CapacitorPointsPerVolume  = 0.04
ACF.CapacitorEff              = 0.97            -- round-trip efficiency (better than a battery)
ACF.CapacitorHeatPerKW        = 3               -- waste heat (J/s) per kW of throughput

-- Electric consumer ("house"/machine load).
ACF.ConsumerDefaultDraw       = 20              -- fallback load (kW) if size can't be read
ACF.ConsumerDrawPerVolume     = 0.02            -- kW of default load per cu in of consumer (size sets the load; wire "Draw" overrides)
ACF.ConsumerMinVoltage        = 0               -- default minimum delivered voltage a consumer needs (0 = none; raise per build/def)
ACF.BatteryNominalVoltage     = 1               -- nominal DC voltage a raw Electric battery presents (low-voltage; can't feed a high-Vmin load without a transformer)

-- Electric breaker / fuse: protects a station; trips it offline on sustained
-- overcurrent, resets by wire or after a cooldown.
ACF.BreakerDefaultRating      = 120             -- default trip threshold (kW) until wired
ACF.BreakerTripDelay          = 0.5             -- seconds over rating before it trips
ACF.BreakerAutoReset          = 5               -- seconds after tripping before it auto-recloses (0 = manual only)

-- Explosive charge (detonates on a wire input). Uses the same HE filler/frag
-- maths as HE rounds (ACF.HEDensity etc.) so its blast performance is identical.
ACF.ExplosiveFillerFraction   = 0.65            -- share of the charge volume that is filler
ACF.ExplosiveHEMul            = 0.12            -- scales filler mass down so charges aren't absurd for their size
ACF.ExplosivePointsPerKg      = 28              -- score per kg of filler (deliberately steep)
ACF.ExplosiveCasingMul        = 0.08            -- the charge's PHYSICAL weight is filler + casing*this (a charge is mostly filler + thin casing, not a solid steel billet - keeps it light enough to carry)
ACF.ExplosiveCookoffMul       = 4               -- per-hit cook-off chance = (damage/maxHP)*this ... a couple of solid hits set it off
ACF.ExplosiveCookoffLowHP     = 0.25            -- ...plus this * (1 - health fraction), so a badly damaged charge is on a hair trigger

---------------------------------- Ammo Crate config ----------------------------------

ACF.CrateMaximumSize    = 250
ACF.CrateMinimumSize    = 5
ACF.SustainMinimumSize  = 1               -- sustainability ents (and batteries/tanks) may scale down to 1x1x1

ACF.RefillDistance      = 400                    -- Distance in which ammo crate starts refilling.
ACF.RefillSpeed         = 250                    -- (ACF.RefillSpeed / RoundMass) / Distance

---------------------------------- Explosive config ----------------------------------

ACF.HEDamageFactor    = 50
ACF.BoomMult          = 1                    -- How much more do ammocrates/fueltanks blow up, useful since crates detonate all at once now.
ACF.APAmmoDetonateFactor = 2                --Multiplier for the explosion power of AP proppelant. To make AP rounds(the most common round) less underwhelming.

ACF.HEPower           = 8000                    -- HE Filler power per KG in KJ
ACF.HEDensity         = 1.65                    -- HE Filler density (That's TNT density)
ACF.HEFrag            = 2500                    -- Mean fragment number for equal weight TNT and casing
ACF.HEFragDragFactor  = 0.2                        --Lower = less drag. Higher = more. Adjust this to affect the penetration and lethality of fragments. If frags pen infantry die.
ACF.HEFragRadiusMul   = 2                        --Hard cap on frag radius. Multiplies HE Radius.
ACF.HEBlastPen        = 0.4                    -- Blast penetration exponent based of HE power
ACF.HEFeatherExp      = 0.5                    -- exponent applied to HE dist/maxdist feathering, <1 will increasingly bias toward max damage until sharp falloff at outer edge of range
ACF.HEBlastPenMinPow  = 35000                --Minimum HE filler in KJ to start testing for blast penetrations. Don't even bother on something that doesn't even have 10mm of pen
ACF.HEBlastPenetration  = 3500                --KJ per mm penetrated
ACF.HEBlastPenRadiusMul  = 3                --Fraction of the HE radius to apply penetrations to. 2 is half. 4 is 1/4th.
ACF.HEBlastPenLossAtMaxDist = 0.35                --HE penetration against targets at the max penetration distance
ACF.HEBlastPenLossExponent = 1.5                    --Exponent for pen loss. For example, with a 0.25x pen loss, 2 means 0.25^2 = 0.0625 loss. Higher means less falloff.
ACF.HEATMVScale       = 0.75                    -- Filler KE to HEAT slug KE conversion expotential
ACF.HEATMVScaleTan    = 0.75                    -- Filler KE to HEAT slug KE conversion expotential
ACF.HEATMulAmmo       = 30                        -- HEAT slug damage multiplier; 13.2x roughly equal to AP damage
ACF.HEATMulFuel       = 4                        -- needs less multiplier, much less health than ammo
ACF.HEATMulEngine     = 20                        -- likewise
ACF.HEATPenLayerMul   = 0.95                    -- HEAT base energy multiplier
ACF.HEATAirGapFactor  = 0.15                        --% velocity loss for every meter traveled. 0.2x means HEAT loses 20% of its energy every 2m traveled. 1m is about typical for the sideskirt spaced armor of most tanks.
ACF.HEATBoomConvert   = 1 / 3                    -- percentage of filler that creates HE damage at detonation
ACF.HEATPlungingReduction = 4                    --Multiplier for the penarea of HEAT shells. 2x is a 50% reduction in penetration, 4x 25% and so on.
ACF.GlatgmPenMul = 1.3                            --Multiplier for the penetration of GLATGM rounds
ACF.ShellPenMul = 1                                --Multiplier for the penetration of HEAT rounds

ACF.ScaledHEMax       = 75
ACF.ScaledEntsMax     = 5

---------------------------------- Ballistic config ----------------------------------

ACF.Bullet              = {} --When ACF is loaded, this table holds bullets
ACF.CurBulletIndex    = 0    -- used to track where to insert bullets
ACF.BulletIndexLimit  = 5000    -- The maximum number of bullets in flight at any one time TODO: fix the typo
ACF.SkyboxGraceZone   = 100    -- grace zone for the high angle fire
ACF.SkyboxMinCaliber  = 5

ACF.TraceFilter       = {        -- entities that cause issue with acf and should be not be processed at all

    prop_vehicle_crane   = true,
    prop_dynamic         = true,
    npc_strider          = true,
    -- sent_prop2mesh       = true,
    worldspawn           = true, --The worldspawn in infinite maps is fake. Since the IsWorld function will not do something to avoid this case, that i will put it here.

}

ACF.DragDiv           = 40                        -- Drag fudge factor
ACF.VelScale          = 1                        -- Scale factor for the shell velocities in the game world
ACF.PBase             = 1050                    -- 1KG of propellant produces this much KE at the muzzle, in kj
ACF.PScale            = 1                        -- Gun Propellant power expotential
ACF.MVScale           = 0.5                    -- Propellant to MV convertion expotential
ACF.PDensity          = 1.6                    -- Gun propellant density (Real powders go from 0.7 to 1.6, i'm using higher densities to simulate case bottlenecking)
ACF.PhysMaxVel        = 8000


ACF.NormalizationFactor = 0.15                    -- at 0.1(10%) a round hitting a 70 degree plate will act as if its hitting a 63 degree plate, this only applies to capped and LRP ammunition.

---------------------------------- Rules & Legality ----------------------------------
ACF.EnginesRequireFuel = 1 --Should all engines require fuel to run? Modified by console commands.
ACF.LargeEnginesRequireDrivers = 1 --Should engines over a certain hp need a driver? Modified by console commands.
ACF.LargeEngineThreshold = 100 --Engine size in hp required to need a driver
ACF.LargeGunsRequireGunners = 1 --Should engines over a certain hp need a driver? Modified by console commands.
ACF.LargeGunsThreshold = 40 --Cannon size in mm required to need a driver

ACF.PointsLimit = 10000 -- The maximum legal point value.
ACF.MaxWeight   = 200000 -- The max weight in kg.

ACE.PointCostConfig = ACE.PointCostConfig or {
    ArmorFrontWeight = 1.0, -- Front armor contribution in armor points.
    ArmorSideWeight  = 1.8, -- Side armor contribution in armor points.
    ArmorScale       = 4.0, -- Final armor points multiplier.
    CrewSeatFlat     = 250, -- Flat point cost per crew seat entity.
    MinDetailPoints  = 300 -- Minimum points to list an entry in armor tool breakdown.
}

ACE.GunPointCostMultiplier    = tonumber(ACE.GunPointCostMultiplier) or tonumber(ACE.CannonPointMul) or 0.85 -- Multiplier for gun/cannon point cost.
ACE.EnginePointCostMultiplier = tonumber(ACE.EnginePointCostMultiplier) or tonumber(ACE.EnginePointMul) or 0.69 -- Multiplier for engine point cost.
ACF.LegacyManufacturingPointsPerTon = tonumber(ACF.LegacyManufacturingPointsPerTon) or tonumber(ACF.PointsPerTon) or 42 -- Legacy manufacturing cost coefficient per ton.
ACE.LegacyAmmoPointsPerTon    = tonumber(ACE.LegacyAmmoPointsPerTon) or tonumber(ACE.AmmoPerTon) or 100 -- Legacy non-missile ammo points per ton.
ACE.CrewSeatPointCost         = tonumber(ACE.CrewSeatPointCost)
    or tonumber(ACE.CrewSeatCostFlat)
    or tonumber(ACE.PointCostConfig and ACE.PointCostConfig.CrewSeatFlat)
    or 250 -- Flat point cost per crew seat.

-- Backward-compatible aliases (deprecated names).
ACE.CannonPointMul = ACE.GunPointCostMultiplier
ACE.EnginePointMul = ACE.EnginePointCostMultiplier
ACF.PointsPerTon = ACF.LegacyManufacturingPointsPerTon
ACE.AmmoPerTon = ACE.LegacyAmmoPointsPerTon
ACE.CrewSeatCostFlat = ACE.CrewSeatPointCost

-- Deprecated: armor mass-based cost has been replaced by LOS armor scan.
--
-- Ammo cost scoring config for the ACE legality system.
ACE.AmmoTypeFactors = {
    AP = 0.5,
    APHE = 0.6,
    APDS = 1.0,
    APFSDS = 1.05,
    HVAP = 0.7,
    HEAT = 0.75,
    HEATFS = 0.8,
    THEAT = 0.95,
    THEATFS = 1.0,
    HESH = 0.4,
    HE = 0.66,
    HEFS = 0.715,
    HP = 0.1,
    CAP = 0.6,
    CHEAT = 0.8,
    CHE = 0.25,
    CHF = 1,
    SM = 1,
    FLR = 1,
    FL = 0.3,
    GLATGM = 0.75,
    ["GLATGM-HE"] = 0.25,
    Refill = 0
}

ACE.LegacyMatCostTables = ACE.LegacyMatCostTables or {
    Alum = 1.2 * (0.221 / 0.34), -- 20% cost increase for ~25% weight reduction.
    CHA = 0.8 * (0.98 / 1.25), -- 25% heavier for ~20% cost reduction.
    Cer = 1.4 * (2.05 / 1.4), -- 50% more protection/kg for ~40% cost increase.
    ERA = 2.0 * (2.5 / 2.0),
    Rub = 1.5 * (0.05 / 0.2),
    Texto = 1.4 * (0.5 / 0.35),
    RHA = 1
}
ACE.AmmoCostConfig = {
    BaseRoundPts = 340, -- Base per-round scaling before penetration, caliber, ammo type, and RoF threat are applied.
    RefPen = 700, -- Reference penetration (mm) for pen scaling.
    RefCaliber = 100, -- Reference caliber (mm) for caliber scaling.
    RofKneeRpm = 22, -- RoF knee for saturation: RoF/(RoF+k), using RPM.
    MinRofRpm = 4, -- Minimum RPM factored into ROF threat scaling. Set to 0 to use actual sustained RPM.
    RefBlastMass = 6, -- Reference HE filler mass (kg) for blast scaling.
    BlastExp = 1.1, -- Blast curve exponent.
    BlastWeight = 0.25, -- Blend weight for blast vs penetration threat.
    HeUtilWeight = 1.3, -- HE utility weight from filler mass per caliber.
    HeUtilExp = 0.5, -- HE utility exponent for filler per caliber.
    ReadyRackBase = 3000, -- Ready rack baseline: base / caliber(mm).
    ReadyRackPivot = 60, -- Caliber (mm) where low-caliber boost stops.
    ReadyRackLowBoost = 1.5, -- Low-caliber boost (20mm hits 300 at base 3000).
    StowFactor = 0.0, -- Cost multiplier for stowed rounds.
    TailFactor = 0, -- Extra discount per round beyond tail start (0 disables).
    TailStartMultiplier = 2 -- Tail start = readyCap * multiplier.
}

-- ATGM rack/ammo pricing blend.
-- Performance uses the same ammo threat model as guns; legacy keeps continuity with existing per-missile pointcost.
ACE.ATGMCostConfig = {
    PerformanceMul = 1.0, -- Multiplier for performance-derived base points.
    LegacyWeight = 0.2, -- 0 = pure performance, 1 = pure legacy pointcost.
    MinBase = 1 -- Safety floor before guidance multiplier.
}

-- Guidance multipliers applied on top of missile base cost.
ACE.MissileGuidanceFactors = {
    Dumb = 0.3,
    Straight_Running = 0.45,
    GPS = 0.6,
    Antimissile = 1,
    AntiRadiation = 0.7,
    Beam_Riding = 0.7,
    GPS_TerrainAvoidant = 0.8,
    SACLOS = 0.75,
    Semiactive = 0.85,
    Wire = 1.0,
    Acoustic_Straight = 1.0,
    Acoustic_Helical = 1.0,
    Laser = 1.2,
    Infrared = 2.7,
    Top_Attack_IR = 3,
    Radar = 1.2
}

-- Armor tool UX timing.
ACE.ArmorPreviewTapWindow = ACE.ArmorPreviewTapWindow or 0.35 -- Seconds between reload taps to trigger preview.
ACE.ArmorPreviewCooldown = ACE.ArmorPreviewCooldown or 5 -- Seconds between preview requests per player.

-- Armor scan tuning values for LOS trace consistency.
ACE.ArmorScanConfig = ACE.ArmorScanConfig or {
    RegionSnap = 2,
    TraceHullSize = 3,
    TraceMaxSteps = 128,
    ResultQuantizeMm = 1.0 -- Quantize scan outputs to reduce tiny trace jitter.
}

---------------------------------- Misc & other ----------------------------------

ACF.LargeCaliber        = 10 --Gun caliber in CM to be considered a large caliber gun, 10cm = 100mm

ACF.SpallDamageMult        = 0.01
ACF.APDamageMult        = 2                        -- AP Damage Multipler            -1.1
ACF.APHEDamageMult      = 1.75                    -- APHE Damage Multipler
ACF.APDSDamageMult      = 3                    -- APDS Damage Multipler
ACF.HVAPDamageMult      = 2                    -- HVAP/APCR Damage Multipler
ACF.FLDamageMult        = 1.4                    -- FL Damage Multipler
ACF.HEATDamageMult      = 6                        -- HEAT Damage Multipler
ACF.HEDamageMult        = 2                        -- HE Damage Multipler
ACF.HESHDamageMult      = 1.2                    -- HESH Damage Multipler
ACF.HPDamageMult        = 8                        -- HP Damage Multipler

ACF.AllowCSLua          = 0

ACF.Threshold           = 264.7                    -- Health Divisor (don't forget to update cvar function down below)
ACF.PartialPenPenalty   = 5                        -- Exponent for the damage penalty for partial penetration
ACF.PenAreaMod          = 0.85
ACF.KinFudgeFactor      = 2.1                    -- True kinetic would be 2, over that it's speed biaised, below it's mass biaised
ACF.KEtoRHA             = 0.25                    -- Empirical conversion from (kinetic energy in KJ)/(Area in Cm2) to RHA penetration
ACF.GroundtoRHA         = 0.15                    -- How much mm of steel is a mm of ground worth (Real soil is about 0.15)
ACF.KEtoSpall           = 1
ACF.AmmoMod             = 2.6                    -- Ammo modifier. 1 is 1x the amount of ammo
ACF.AmmoLengthMul       = 1
ACF.AmmoWidthMul        = 1
ACF.ArmorMod            = 1
ACF.SlopeEffectFactor   = 1.0                    -- Sloped armor effectiveness: armor / cos(angle) ^ factor
ACF.Spalling            = 1
ACF.SpallMult           = 1

--In case the recoil torque broke too many tanks, allows the owner to disable recoil torque. Has CVAR
ACF.UseLegacyRecoil = 0

if CLIENT then
    ACF.KillIconColor    = Color(200, 200, 48)
else
    ACF.RestrictInfo    = true
end

--Math in globals????

--UNLESS YOU WANT SPALL TO FLY BACKWARDS, BE ABSOLUTELY SURE TO MAKE SURE THIS VECTOR LENGTH IS LESS THAN 1
--The vector controls the spread pattern. The multiplier adjusts the tightness of the spread cone. ABSOLUTELY DO NOT MAKE THE MULTIPLIER MORE THAN 1. A Vector of 1,1,0.5. Results in half the vertical spall spread
ACF.SpallingDistribution = Vector(1,1,0.5):GetNormalized() * 1


---------------------------------- Particle colors  ----------------------------------

ACE.DustMaterialColor = {
    Concrete   = Color(150,130,130,150),
    Dirt       = Color(93,80,56,150),
    Sand       = Color(225,202,130,150),
    Glass      = Color(255,255,255,50),
    Snow      = Color(255,255,255,50),
    Wood       = Color(117,101,70,150)
}

--------------------------------------------------------------------------------------

---------------------------------- Serverside Convars ----------------------------------
if SERVER then

    --Sbox Limits
    CreateConVar("sbox_max_acf_gun", 32)                    -- Gun limit
    CreateConVar("sbox_max_acf_rapidgun", 6)                -- Guns like RACs, MGs, and ACs
    CreateConVar("sbox_max_acf_largegun", 4)                -- Guns with a caliber above 100mm
    CreateConVar("sbox_max_acf_smokelauncher", 40)            -- smoke launcher limit
    CreateConVar("sbox_max_acf_ammo", 100)                    -- ammo limit
    CreateConVar("sbox_max_acf_misc", 100)                    -- misc ents limit
    CreateConVar("sbox_max_acf_rack", 24)                    -- Racks limit
    CreateConVar("sbox_max_ace_crewseat", 100)
    CreateConVar("sbox_max_ace_alternator", 10)
    CreateConVar("sbox_max_ace_solarpanel", 10)
    CreateConVar("sbox_max_ace_fuel_synth", 10)
    CreateConVar("sbox_max_ace_field_generator", 10)
    CreateConVar("sbox_max_ace_fuel_plug", 20)
    CreateConVar("sbox_max_ace_fuel_socket", 20)
    CreateConVar("sbox_max_ace_explosive", 20)
    CreateConVar("sbox_max_ace_fuel_pipe", 30)
    CreateConVar("sbox_max_ace_transfer_station", 20)
    CreateConVar("sbox_max_ace_transformer", 20)
    CreateConVar("sbox_max_ace_power_line", 60)
    CreateConVar("sbox_max_ace_power_consumer", 30)
    CreateConVar("sbox_max_ace_capacitor", 20)
    CreateConVar("sbox_max_ace_power_breaker", 20)
    CreateConVar("sbox_max_ace_refinery", 20)
    CreateConVar("sbox_max_ace_fuel_pump", 30)
    CreateConVar("sbox_max_ace_power_collector", 20)
    CreateConVar("sbox_max_ace_ecm", 20)
    CreateConVar("sbox_max_ace_rwr_dir", 20)
    CreateConVar("sbox_max_ace_rwr_sphere", 20)
    CreateConVar("sbox_max_acf_opticalcomputer", 20)

    -- When 1, every fuel tank/battery spawns empty regardless of the client's
    -- per-spawn "Spawn Empty" checkbox. Server-wide logistics toggle.
    CreateConVar("acf_fueltank_forceempty", 0, FCVAR_ARCHIVE + FCVAR_NOTIFY, "Force all ACE fuel tanks and batteries to spawn empty.")

    -- Draws each solar panel's sun trace, orientation arrows and live values.
    -- Needs 'developer 1' on the viewing client to render the overlays.
    CreateConVar("acf_solar_debug", 0, FCVAR_ARCHIVE, "Draw ACE solar panel sun-trace debug overlays (requires developer 1).")

    -- Sun direction for solar panels. Reliable and controllable: set the sun's
    -- elevation (degrees above the horizon) and compass yaw here. If
    -- acf_solar_use_envsun is 1 and the map (or you) has an env_sun pointing
    -- upward, that is used instead.
    CreateConVar("acf_solar_sun_pitch", 60, FCVAR_ARCHIVE, "Solar: sun elevation above the horizon, degrees (0-90).", 0, 90)
    CreateConVar("acf_solar_sun_yaw", 45, FCVAR_ARCHIVE, "Solar: sun compass direction, degrees (0-360).", 0, 360)
    CreateConVar("acf_solar_use_envsun", 1, FCVAR_ARCHIVE, "Solar: use the map's env_sun direction when it points upward.", 0, 1)
    CreateConVar("acf_solar_use_maplight", 1, FCVAR_ARCHIVE, "Solar: scale output by overall map brightness (a dark/night map yields less). 0 disables.", 0, 1)
    CreateConVar("acf_mines_max", 50)                        -- The mine limit
    CreateConVar("acf_meshvalue", 1)

    CreateConVar("acf_restrictinfo", 1)                -- 0=any, 1=owned
    cvars.RemoveChangeCallback("acf_restrictinfo", "ACF_CVarChangeCallback")
    cvars.AddChangeCallback("acf_restrictinfo", function(_, _, new)
        ACF.RestrictInfo = tobool(new)
    end, "ACF_CVarChangeCallback")

    -- Toggles for vehicle legality restrictions
    CreateConVar( "acf_legality_enginesrequirefuel", 1 , FCVAR_ARCHIVE)

    CreateConVar( "acf_legality_largeenginesneeddriver", 1 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legality_largeenginethreshold", 100 , FCVAR_ARCHIVE)

    CreateConVar( "acf_legality_largegunsneedgunner", 1 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legality_largegunthreshold", 40 , FCVAR_ARCHIVE)

    -- Cvars for legality checking
    CreateConVar( "acf_legalcheck", 1 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legal_ignore_model", 0 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legal_ignore_solid", 0 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legal_ignore_mass", 0 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legal_ignore_material", 0 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legal_ignore_inertia", 0 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legal_ignore_makesphere", 0 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legal_ignore_visclip", 0 , FCVAR_ARCHIVE)
    CreateConVar( "acf_legal_ignore_parent", 0 , FCVAR_ARCHIVE)

    -- Prop Protection system
    CreateConVar( "acf_enable_dp", 0 , FCVAR_ARCHIVE )    -- Enable the inbuilt damage protection system.

    -- Cvars for recoil/he push
    CreateConVar("acf_kepush", 1, FCVAR_ARCHIVE)
    CreateConVar("acf_hepush", 1, FCVAR_ARCHIVE)
    CreateConVar("acf_recoilpush", 1, FCVAR_ARCHIVE)

    -- New healthmod/armormod/ammomod cvars
    CreateConVar("acf_healthmod", 1, FCVAR_ARCHIVE)
    CreateConVar("acf_armormod", 1, FCVAR_ARCHIVE)
    CreateConVar("acf_ammomod", 1, FCVAR_ARCHIVE)
    CreateConVar("acf_gunfire", 1, FCVAR_ARCHIVE)

    -- Debris
    CreateConVar("acf_debris_lifetime", 30, FCVAR_ARCHIVE)
    CreateConVar("acf_debris_children", 1, FCVAR_ARCHIVE)

    -- Spalling
    CreateConVar("acf_spalling", 1, FCVAR_ARCHIVE)
    CreateConVar("acf_spalling_multipler", 1, FCVAR_ARCHIVE)

    -- Scaled Explosions
    CreateConVar("acf_explosions_scaled_he_max", 100, FCVAR_ARCHIVE)
    CreateConVar("acf_explosions_scaled_ents_max", 5, FCVAR_ARCHIVE)

    --Smoke
    CreateConVar("acf_wind", 600, FCVAR_ARCHIVE)

    --Uses non-torqueing recoil if there are problems
    CreateConVar("acf_legacyrecoil", 0, FCVAR_ARCHIVE)

    function ACF_CVarChangeCallback(CVar, _, New)

        if CVar == "acf_healthmod" then
            ACF.Threshold = 264.7 / math.max(New, 0.01)
        elseif CVar == "acf_armormod" then
            ACF.ArmorMod = 1 * math.max(New, 0)
        elseif CVar == "acf_ammomod" then
            ACF.AmmoMod = 1 * math.max(New, 0.01)
        elseif CVar == "acf_spalling" then
            ACF.Spalling = math.floor(math.Clamp(New, 0, 1))
        elseif CVar == "acf_spalling_multipler" then
            ACF.SpallMult = math.Clamp(New, 1, 5)
        elseif CVar == "acf_gunfire" then
            ACF.GunfireEnabled = tobool( New )
        elseif CVar == "acf_debris_lifetime" then
            ACF.DebrisLifeTime = math.max( New,0)
        elseif CVar == "acf_debris_children" then
            ACF.DebrisChance = math.Clamp(New,0,1)
        elseif CVar == "acf_explosions_scaled_he_max" then
            ACF.ScaledHEMax = math.max(New,50)
        elseif CVar == "acf_explosions_scaled_ents_max" then
            ACF.ScaledEntsMax = math.max(New,1)
        elseif CVar == "acf_legacyrecoil" then
            ACF.UseLegacyRecoil = math.floor(math.Clamp(New, 0, 1))
        elseif CVar == "acf_legality_enginesrequirefuel" then
            ACF.EnginesRequireFuel = math.ceil(math.Clamp(New, 0, 1))
        elseif CVar == "acf_legality_largeenginesneeddriver" then
            ACF.LargeEnginesRequireDrivers = math.ceil(math.Clamp(New, 0, 1))
        elseif CVar == "acf_legality_largeenginethreshold" then
            ACF.LargeEngineThreshold = math.ceil(math.Clamp(New, 0, 10000))
        elseif CVar == "acf_legality_largegunsneedgunner" then
            ACF.LargeGunsRequireGunners = math.ceil(math.Clamp(New, 0, 1))
        elseif CVar == "acf_legality_largegunthreshold" then
            ACF.LargeGunsThreshold = math.ceil(math.Clamp(New, 0, 10000))
        elseif CVar == "acf_enable_dp" then
            if ACE_SendDPStatus then
                ACE_SendDPStatus()
            end
        end
    end

    cvars.AddChangeCallback("acf_healthmod", ACF_CVarChangeCallback)
    cvars.AddChangeCallback("acf_armormod", ACF_CVarChangeCallback)
    cvars.AddChangeCallback("acf_ammomod", ACF_CVarChangeCallback)
    cvars.AddChangeCallback("acf_spalling", ACF_CVarChangeCallback)
    cvars.AddChangeCallback("acf_spalling_multipler", ACF_CVarChangeCallback)
    cvars.AddChangeCallback("acf_gunfire", ACF_CVarChangeCallback)
    cvars.AddChangeCallback("acf_debris_lifetime", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_debris_children", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_explosions_scaled_he_max", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_explosions_scaled_ents_max", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_legacyrecoil", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_legality_enginesrequirefuel", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_legality_largeenginesneeddriver", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_legality_largeenginethreshold", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_legality_largegunsneedgunner", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_legality_largegunthreshold", ACF_CVarChangeCallback)
cvars.AddChangeCallback("acf_enable_dp", ACF_CVarChangeCallback)

-- Apply archived/server convars at startup so values persist across restarts and reconnects.
local startupSync = {
    "acf_healthmod",
    "acf_armormod",
    "acf_ammomod",
    "acf_spalling",
    "acf_spalling_multipler",
    "acf_gunfire",
    "acf_debris_lifetime",
    "acf_debris_children",
    "acf_explosions_scaled_he_max",
    "acf_explosions_scaled_ents_max",
    "acf_legacyrecoil",
    "acf_legality_enginesrequirefuel",
    "acf_legality_largeenginesneeddriver",
    "acf_legality_largeenginethreshold",
    "acf_legality_largegunsneedgunner",
    "acf_legality_largegunthreshold",
    "acf_enable_dp"
}

for _, name in ipairs(startupSync) do
    local convar = GetConVar(name)
    if convar then
        ACF_CVarChangeCallback(name, nil, convar:GetString())
    end
end

elseif CLIENT then
---------------------------------- Clientside Convars ----------------------------------

    CreateClientConVar( "acf_enable_lighting", 1, true ) --Should missiles emit light while their motors are burning?  Looks nice but hits framerate. Set to 1 to enable, set to 0 to disable, set to another number to set minimum light-size.
    CreateClientConVar( "acf_sens_irons", 0.5, true, false, "Reduce mouse sensitivity by this amount when zoomed in with iron sights on ACE SWEPs.", 0.01, 1)
    CreateClientConVar( "acf_sens_scopes", 0.2, true, false, "Reduce mouse sensitivity by this amount when zoomed in with scopes on ACE SWEPs.", 0.01, 1)
    CreateClientConVar( "acf_tinnitus", 1, true, false, "Allows the ear tinnitus effect to be applied when an explosive was detonated too close to your position, improving the inmersion during combat.", 0, 1 )
    CreateClientConVar( "acf_sound_volume", 100, true, false, "Adjusts the volume of explosions and gunshots.", 0, 100 )
    CreateClientConVar( "acf_armor_readout_full", 0, true, false, "Show full armor readout in the ACF armor tool.", 0, 1 )
    CreateClientConVar( "acf_fueltank_spawnempty", 0, true, false, "Default the fuel tank menu's 'Spawn Empty' checkbox to on.", 0, 1 )

end


if ACF.AllowCSLua > 0 then
    AddCSLuaFile("autorun/translation/ace_translationpacks.lua")
    RunConsoleCommand( "sv_allowcslua", 1 )
    include("autorun/translation/ace_translationpacks.lua") --File that is overwritten to install a translation pack
else
    RunConsoleCommand( "sv_allowcslua", 0 )
    include("autorun/translation/ace_translationpacks.lua")
    AddCSLuaFile("autorun/translation/ace_translationpacks.lua")
end

include("acf/shared/sh_ace_particles.lua")
include("acf/shared/sh_ace_sound_loader.lua")
include("autorun/acf_missile/folder.lua")
include("acf/shared/sh_ace_functions.lua")
AddCSLuaFile("acf/shared/sustainability/sh_sustain.lua")
include("acf/shared/sustainability/sh_sustain.lua")
include("acf/shared/sh_ace_loader.lua")
include("acf/shared/sh_ace_concommands.lua")
include("acf/shared/sh_acfm_roundinject.lua")
include("acf/shared/compatibility/cppiCompatibility.lua")
include("acf/shared/sh_crewseat_base.lua")
AddCSLuaFile("acf/shared/sh_crewseat_base.lua")
AddCSLuaFile("acf/shared/compatibility/cppiCompatibility.lua")

if SERVER then

    include("acf/shared/sv_ace_networking.lua")
    include("acf/server/sv_acfbase.lua")
    include("acf/server/sv_acfdamage.lua")
    include("acf/server/sv_acfballistics.lua")
    include("acf/server/sv_contraption.lua")
    include("acf/server/sv_heat.lua")
    include("acf/server/sv_crewseat_base.lua")
    include("acf/server/sv_legality.lua")
    include("acf/server/sv_acfpermission.lua")
    include("acf/server/sv_contraptionlegality.lua")

    AddCSLuaFile("acf/client/cl_acfballistics.lua")
    AddCSLuaFile("acf/client/cl_acfmenu_gui.lua")
    AddCSLuaFile("acf/client/cl_acfrender.lua")
    AddCSLuaFile("acf/client/cl_soundbase.lua")

    AddCSLuaFile("acf/client/cl_acfmenu_missileui.lua")

    AddCSLuaFile("acf/client/cl_acfpermission.lua")
    AddCSLuaFile("acf/client/gui/cl_acfsetpermission.lua")


elseif CLIENT then

    include("acf/client/cl_acfballistics.lua")
    include("acf/client/cl_acfrender.lua")
    include("acf/client/cl_soundbase.lua")

    include("acf/client/cl_acfpermission.lua")
    include("acf/client/gui/cl_acfsetpermission.lua")

    CreateClientConVar("ACF_MobilityRopeLinks", "1", true, true)
    -- Draw the link "cables" between ACE sustainability nodes (power lines, pipes,
    -- stations, transformers, capacitors). Client-side cosmetic, off = no beams.
    CreateClientConVar("ace_draw_link_beams", "1", true, false)

end


--[[--------------------------------------
    RoundType Loader
]]----------------------------------------

include("acf/shared/rounds/ace_roundfunctions.lua")

include("acf/shared/rounds/roundap.lua")
include("acf/shared/rounds/roundhe.lua")
include("acf/shared/rounds/roundfl.lua")
include("acf/shared/rounds/roundhp.lua")
include("acf/shared/rounds/roundsmoke.lua")
include("acf/shared/rounds/roundrefill.lua")


--interwar period
--if ACF.Year > 1920 then

--end
--A surprising amount of things were made during WW2
if ACF.Year > 1939 then

    include("acf/shared/rounds/roundhesh.lua")
    include("acf/shared/rounds/roundheat.lua")
    include("acf/shared/rounds/roundaphe.lua")
    include("acf/shared/rounds/roundhvap.lua")

end
--Cold war
if ACF.Year > 1960 then

    include("acf/shared/rounds/roundapds.lua")
    include("acf/shared/rounds/roundapfsds.lua")
    include("acf/shared/rounds/roundheatfs.lua")
    include("acf/shared/rounds/roundhefs.lua")
    include("acf/shared/rounds/roundflare.lua")
    include("acf/shared/rounds/roundglgm.lua")

end
--almost finishing cold war
if ACF.Year > 1989 then

    include("acf/shared/rounds/roundtheat.lua")
    include("acf/shared/rounds/roundtheatfs.lua")

end

game.AddDecal("GunShot1", "decals/METAL/shot5")

-- Add the ACF tool category
if CLIENT then

    ACF.CustomToolCategory = CreateClientConVar( "acf_tool_category", 0, true, false );

    if ACF.CustomToolCategory:GetBool() then

        language.Add( "spawnmenu.tools.acf", "ACF" );

        -- We use this hook so that the ACF category is always at the top
        hook.Add( "AddToolMenuTabs", "CreateACFCategory", function()

            spawnmenu.AddToolCategory( "Main", "ACF", "#spawnmenu.tools.acf" );

        end );

    end

end

timer.Simple( 0, function()
    for _, Table in pairs(ACF.Classes["GunClass"]) do
        PrecacheParticleSystem(Table["muzzleflash"])
    end
end)

--Stupid workaround red added to precache timescaling.
hook.Add( "Think", "Update ACF Internal Clock", function()
    ACF.CurTime = CurTime()
    ACF.SysTime = SysTime()
end )


if SERVER then

    function ACE_SendDPStatus()

        local Cvar = GetConVar("acf_enable_dp"):GetInt()
        local bool = tobool(Cvar)

        net.Start("ACE_DPStatus")
            net.WriteBool(bool)
        net.Broadcast()

    end

    function ACF_SendNotify( ply, success, msg )
        net.Start( "ACF_Notify" )
        net.WriteBit( success )
        net.WriteString( msg or "" )
        net.Send( ply )
    end
else

    local function ACF_Notify()
        local Type = NOTIFY_ERROR
        if tobool( net.ReadBit() ) then Type = NOTIFY_GENERIC end

        GAMEMODE:AddNotify( net.ReadString(), Type, 7 )
    end
    net.Receive( "ACF_Notify", ACF_Notify )
end

do

    local function OnInitialSpawn( ply )
        local Table = {}
        for _, v in pairs( ents.GetAll() ) do
            if v.ACF and v.ACF.PrHealth then
                table.insert(Table,{ID = v:EntIndex(), Health = v.ACF.Health, v.ACF.MaxHealth})
            end
        end
        if Table ~= {} then
            net.Start("ACF_RenderDamage")
                net.WriteTable(Table)
            net.Send(ply)
        end
    end
    hook.Add( "PlayerInitialSpawn", "renderdamage", OnInitialSpawn )

end


if CLIENT then
    ACF.Wind = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0):GetNormalized()

    net.Receive("ACE_Wind", function()
        ACF.Wind = Vector(net.ReadFloat(), net.ReadFloat(), 0)
    end)
else
    local curveFactor = 2.5
    local reset_timer = 60
    ACF.Wind = Vector()
    timer.Create("ACE_Wind", reset_timer, 0, function()
        local smokeDir = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0):GetNormalized()
        ACF.Wind = (math.random() ^ curveFactor) * smokeDir * GetConVar("acf_wind"):GetFloat()
        net.Start("ACE_Wind")
            net.WriteFloat(ACF.Wind.x)
            net.WriteFloat(ACF.Wind.y)
        net.Broadcast()
    end)
end




cleanup.Register( "aceexplosives" )

AddCSLuaFile("autorun/acf_missile/folder.lua")
include("autorun/acf_missile/folder.lua")

print("[ACE | INFO]- Done!")




