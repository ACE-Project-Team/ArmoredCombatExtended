-- Keep a legacy view available for the intentionally unchanged E2 and
-- Starfall adapters only when the ACF addon did not create its own table.
local ACFAddonInstalled = file.Exists("autorun/acf_loader.lua", "LUA")
local ACECompatibilityView = not ACFAddonInstalled and (ACF == nil or rawget(ACF, "__ACECompatibilityView") == true)
ACF = ACF or {}

ACE               = ACE or {}

-- Resolve the remaining legacy function symbols through ACE. without copying
-- them into new globals. This keeps existing extensions working while callers
-- migrate to the table namespace; functions that have already been moved take
-- precedence over the fallback.
do
    local Meta = getmetatable(ACE) or {}
    local PreviousIndex = Meta.__index

    Meta.__index = function(Table, Key)
        local Value

        if type(PreviousIndex) == "function" then
            Value = PreviousIndex(Table, Key)
        elseif type(PreviousIndex) == "table" then
            Value = PreviousIndex[Key]
        end

        if Value ~= nil then return Value end

        return rawget(_G, "ACE_" .. Key)
    end

    setmetatable(ACE, Meta)
end

if ACECompatibilityView then
    rawset(ACF, "__ACECompatibilityView", true)
    setmetatable(ACF, {
        __index = function(_, key)
            return ACE[key]
        end
    })
end

ACE.LegacyCompatibility = ACECompatibilityView

function ACE_RunLegacyHook(Name, ...)
    if ACE.LegacyCompatibility then
        return hook.Run(Name, ...)
    end
end

-- ACF's loader can run later in the same autorun pass. If it does, remove the
-- temporary ACE compatibility view before ACF starts using its own namespace.
local function RemoveCompatibilityView()
    if not ACE.LegacyCompatibility then return end

    ACE.LegacyCompatibility = false
    rawset(ACF, "__ACECompatibilityView", nil)
    setmetatable(ACF, nil)
end

hook.Add("ACE_OnLoadAddon", "ACE_RemoveCompatibilityView", RemoveCompatibilityView)
hook.Add("ACF_OnLoadAddon", "ACE_RemoveCompatibilityView", function(...)
    RemoveCompatibilityView()
    return hook.Run("ACE_OnLoadAddon", ...)
end)

ACE.AmmoTypes = {}
ACE.MenuFunc = {}
ACE.AmmoBlacklist = {}
ACE.Version = 502        -- ACE current version
ACE.CurrentVersion = 0    -- just defining a variable, do not change

ACE.Year = 2023            -- Current Year

print("[ACE | INFO]- loading ACE. . .")

ACE.ArmorTypes    = {}
ACE.GSounds       = {}

ACE.Weapons       = ACE.Weapons or {}
ACE.Classes       = ACE.Classes or {}
ACE.RoundTypes    = ACE.RoundTypes or {}
ACE.IdRounds      = ACE.IdRounds or {}    --Lookup tables so i can get rounds classes from clientside with just an integer

ACE.Missile = ACE.Missile or {}

---------------------------------- Useless/Ignore ----------------------------------
ACE.Missile.FlareBurnMultiplier        = 0.5
ACE.Missile.FlareDistractMultiplier    = 1 / 35

---------------------------------- General ----------------------------------

ACE.EnableKillicons       = true                    -- Enable killicons overwriting.
ACE.GunfireEnabled        = true
ACE.MeshCalcEnabled       = false

ACE.SpreadScale           = 16                        -- The maximum amount that damage can decrease a gun's accuracy.  Default 4x
ACE.GunInaccuracyScale    = 1                        -- A multiplier for gun accuracy.
ACE.GunInaccuracyBias     = 2                        -- Higher numbers make shots more likely to be inaccurate.  Choose between 0.5 to 4. Default is 2 (unbiased).
ACE.SWEPInaccuracyMul      = 0.5

---------------------------------- Debris ----------------------------------

ACE.DebrisIgniteChance    = 0.25
ACE.DebrisScale           = 10                        -- Ignore debris that is less than this bounding radius.
ACE.DebrisChance          = 1
ACE.DebrisLifeTime        = 30

---------------------------------- Fuel & fuel Tank config ----------------------------------

ACE.LiIonED             = 0.27                    -- li-ion energy density: kw hours / liter --BEFORE to balance: 0.458
ACE.CuIToLiter          = 0.0163871                -- cubic inches to liters

ACE.DriverTorqueBoost   = 1.25                    -- torque multiplier from having a driver
ACE.FuelRate            = 10                        -- multiplier for fuel usage, 1.0 is approx real world
ACE.ElecRate            = 4                        -- multiplier for electrics                                --BEFORE to balance: 0.458
ACE.TankVolumeMul       = 1                        -- multiplier for fuel tank capacity, 1.0 is approx real world

---------------------------------- Ammo Crate config ----------------------------------

ACE.CrateMaximumSize    = 250
ACE.CrateMinimumSize    = 5
ACE.ScalableMinimumSize = 1               -- scalable ACE ents (e.g. explosive charges) may scale down to 1x1x1

ACE.RefillDistance      = 400                    -- Distance in which ammo crate starts refilling.
ACE.RefillSpeed         = 250                    -- (ACE.RefillSpeed / RoundMass) / Distance

---------------------------------- Explosive config ----------------------------------

ACE.HEDamageFactor    = 50
ACE.BoomMult          = 1                    -- How much more do ammocrates/fueltanks blow up, useful since crates detonate all at once now.
ACE.APAmmoDetonateFactor = 2                --Multiplier for the explosion power of AP proppelant. To make AP rounds(the most common round) less underwhelming.

ACE.HEPower           = 8000                    -- HE Filler power per KG in KJ
ACE.HEDensity         = 1.65                    -- HE Filler density (That's TNT density)

-- Scalable explosive charge (detonates on a wire input). Uses the same HE
-- filler/frag maths as HE rounds (ACE.HEDensity etc.) so its blast performance
-- is identical for an equivalent payload.
ACE.ExplosiveFillerFraction   = 0.65            -- share of the charge volume that is filler
ACE.ExplosiveHEMul            = 0.12            -- scales filler mass down so charges aren't absurd for their size
ACE.ExplosiveCasingMul        = 0.08            -- the charge's PHYSICAL weight is filler + casing*this (a charge is mostly filler + thin casing, not a solid steel billet - keeps it light enough to carry)
ACE.ExplosiveCookoffMul       = 4               -- per-hit cook-off chance = (damage/maxHP)*this ... a couple of solid hits set it off
ACE.ExplosiveCookoffLowHP     = 0.25            -- ...plus this * (1 - health fraction), so a badly damaged charge is on a hair trigger
ACE.HEFrag            = 2500                    -- Mean fragment number for equal weight TNT and casing
ACE.HEFragDragFactor  = 0.2                        --Lower = less drag. Higher = more. Adjust this to affect the penetration and lethality of fragments. If frags pen infantry die.
ACE.HEFragRadiusMul   = 2                        --Hard cap on frag radius. Multiplies HE Radius.
ACE.HEBlastPen        = 0.4                    -- Blast penetration exponent based of HE power
ACE.HEFeatherExp      = 0.5                    -- exponent applied to HE dist/maxdist feathering, <1 will increasingly bias toward max damage until sharp falloff at outer edge of range
ACE.HEBlastPenMinPow  = 35000                --Minimum HE filler in KJ to start testing for blast penetrations. Don't even bother on something that doesn't even have 10mm of pen
ACE.HEBlastPenetration  = 3500                --KJ per mm penetrated
ACE.HEBlastPenRadiusMul  = 3                --Fraction of the HE radius to apply penetrations to. 2 is half. 4 is 1/4th.
ACE.HEBlastPenLossAtMaxDist = 0.35                --HE penetration against targets at the max penetration distance
ACE.HEBlastPenLossExponent = 1.5                    --Exponent for pen loss. For example, with a 0.25x pen loss, 2 means 0.25^2 = 0.0625 loss. Higher means less falloff.
ACE.HEATMVScale       = 0.75                    -- Filler KE to HEAT slug KE conversion expotential
ACE.HEATMVScaleTan    = 0.75                    -- Filler KE to HEAT slug KE conversion expotential
ACE.HEATMulAmmo       = 30                        -- HEAT slug damage multiplier; 13.2x roughly equal to AP damage
ACE.HEATMulFuel       = 4                        -- needs less multiplier, much less health than ammo
ACE.HEATMulEngine     = 20                        -- likewise
ACE.HEATPenLayerMul   = 0.95                    -- HEAT base energy multiplier
ACE.HEATAirGapFactor  = 0.15                        --% velocity loss for every meter traveled. 0.2x means HEAT loses 20% of its energy every 2m traveled. 1m is about typical for the sideskirt spaced armor of most tanks.
ACE.HEATBoomConvert   = 1 / 3                    -- percentage of filler that creates HE damage at detonation
ACE.HEATPlungingReduction = 4                    --Multiplier for the penarea of HEAT shells. 2x is a 50% reduction in penetration, 4x 25% and so on.
ACE.GlatgmPenMul = 1.3                            --Multiplier for the penetration of GLATGM rounds
ACE.ShellPenMul = 1                                --Multiplier for the penetration of HEAT rounds

ACE.ScaledHEMax       = 75
ACE.ScaledEntsMax     = 5

---------------------------------- Ballistic config ----------------------------------

ACE.Bullet              = {} --When ACF is loaded, this table holds bullets
ACE.CurBulletIndex    = 0    -- used to track where to insert bullets
ACE.BulletIndexLimit  = 5000    -- The maximum number of bullets in flight at any one time TODO: fix the typo
ACE.SkyboxGraceZone   = 100    -- grace zone for the high angle fire
ACE.SkyboxMinCaliber  = 5

ACE.TraceFilter       = {        -- entities that cause issue with acf and should be not be processed at all

    prop_vehicle_crane   = true,
    prop_dynamic         = true,
    npc_strider          = true,
    -- sent_prop2mesh       = true,
    worldspawn           = true, --The worldspawn in infinite maps is fake. Since the IsWorld function will not do something to avoid this case, that i will put it here.

}

ACE.DragDiv           = 40                        -- Drag fudge factor
ACE.VelScale          = 1                        -- Scale factor for the shell velocities in the game world
ACE.PBase             = 1050                    -- 1KG of propellant produces this much KE at the muzzle, in kj
ACE.PScale            = 1                        -- Gun Propellant power expotential
ACE.MVScale           = 0.5                    -- Propellant to MV convertion expotential
ACE.PDensity          = 1.6                    -- Gun propellant density (Real powders go from 0.7 to 1.6, i'm using higher densities to simulate case bottlenecking)
ACE.PhysMaxVel        = 8000


ACE.NormalizationFactor = 0.15                    -- at 0.1(10%) a round hitting a 70 degree plate will act as if its hitting a 63 degree plate, this only applies to capped and LRP ammunition.

---------------------------------- Rules & Legality ----------------------------------
ACE.EnginesRequireFuel = 1 --Should all engines require fuel to run? Modified by console commands.
ACE.LargeEnginesRequireDrivers = 1 --Should engines over a certain hp need a driver? Modified by console commands.
ACE.LargeEngineThreshold = 100 --Engine size in hp required to need a driver
ACE.LargeGunsRequireGunners = 1 --Should engines over a certain hp need a driver? Modified by console commands.
ACE.LargeGunsThreshold = 40 --Cannon size in mm required to need a driver

ACE.PointsLimit = 10000 -- The maximum legal point value.
ACE.MaxWeight   = 200000 -- The max weight in kg.

---------------------------------- Misc & other ----------------------------------

ACE.LargeCaliber        = 10 --Gun caliber in CM to be considered a large caliber gun, 10cm = 100mm

ACE.SpallDamageMult     = 0.01
ACE.APDamageMult        = 2                        -- AP Damage Multipler            -1.1
ACE.APHEDamageMult      = 1.75                    -- APHE Damage Multipler
ACE.APDSDamageMult      = 3                    -- APDS Damage Multipler
ACE.HVAPDamageMult      = 2                    -- HVAP/APCR Damage Multipler
ACE.FLDamageMult        = 1.4                    -- FL Damage Multipler
ACE.HEATDamageMult      = 6                        -- HEAT Damage Multipler
ACE.HEDamageMult        = 2                        -- HE Damage Multipler
ACE.HESHDamageMult      = 1.2                    -- HESH Damage Multipler
ACE.HPDamageMult        = 8                        -- HP Damage Multipler

ACE.AllowCSLua          = 0

ACE.Threshold           = 264.7                    -- Health Divisor (don't forget to update cvar function down below)
ACE.PartialPenPenalty   = 5                        -- Exponent for the damage penalty for partial penetration
ACE.PenAreaMod          = 0.85
ACE.KinFudgeFactor      = 2.1                    -- True kinetic would be 2, over that it's speed biaised, below it's mass biaised
ACE.KEtoRHA             = 0.25                    -- Empirical conversion from (kinetic energy in KJ)/(Area in Cm2) to RHA penetration
ACE.GroundtoRHA         = 0.15                    -- How much mm of steel is a mm of ground worth (Real soil is about 0.15)
ACE.KEtoSpall           = 1
ACE.AmmoMod             = 2.6                    -- Ammo modifier. 1 is 1x the amount of ammo
ACE.AmmoLengthMul       = 1
ACE.AmmoWidthMul        = 1
ACE.ArmorMod            = 1
ACE.SlopeEffectFactor   = 1.0                    -- Sloped armor effectiveness: armor / cos(angle) ^ factor
ACE.Spalling            = 1
ACE.SpallMult           = 1

--In case the recoil torque broke too many tanks, allows the owner to disable recoil torque. Has CVAR
ACE.UseLegacyRecoil = 0

if CLIENT then
    ACE.KillIconColor    = Color(200, 200, 48)
else
    ACE.RestrictInfo    = true
end

--Math in globals????

--UNLESS YOU WANT SPALL TO FLY BACKWARDS, BE ABSOLUTELY SURE TO MAKE SURE THIS VECTOR LENGTH IS LESS THAN 1
--The vector controls the spread pattern. The multiplier adjusts the tightness of the spread cone. ABSOLUTELY DO NOT MAKE THE MULTIPLIER MORE THAN 1. A Vector of 1,1,0.5. Results in half the vertical spall spread
ACE.SpallingDistribution = Vector(1,1,0.5):GetNormalized() * 1


---------------------------------- Particle colors  ----------------------------------

ACE.DustMaterialColor = {
    Concrete   = Color(150,130,130,150),
    Dirt       = Color(93,80,56,150),
    Sand       = Color(225,202,130,150),
    Glass      = Color(255,255,255,50),
    Snow       = Color(255,255,255,50),
    Wood       = Color(117,101,70,150)
}

--------------------------------------------------------------------------------------

---------------------------------- Serverside Convars ----------------------------------
if SERVER then

    --Sbox Limits
    CreateConVar("sbox_max_ace_gun", 32)                    -- Gun limit
    CreateConVar("sbox_max_ace_rapidgun", 6)                -- Guns like RACs, MGs, and ACs
    CreateConVar("sbox_max_ace_largegun", 4)                -- Guns with a caliber above 100mm
    CreateConVar("sbox_max_ace_smokelauncher", 40)            -- smoke launcher limit
    CreateConVar("sbox_max_ace_ammo", 100)                    -- ammo limit
    CreateConVar("sbox_max_ace_misc", 100)                    -- misc ents limit
    CreateConVar("sbox_max_ace_rack", 24)                    -- Racks limit
    CreateConVar("sbox_max_ace_crewseat", 100)
    CreateConVar("sbox_max_ace_explosive", 20)             -- scalable + prebuilt explosive charge limit
    CreateConVar("ace_mines_max", 50)                        -- The mine limit
    CreateConVar("ace_meshvalue", 1)

    CreateConVar("ace_restrictinfo", 1)                -- 0=any, 1=owned
    -- The unchanged Starfall adapter still reads the legacy name. Create this
    -- default-only compatibility cvar only when ACF did not provide it.
    if ACECompatibilityView then
        CreateConVar("acf_restrictinfo", 1)
        cvars.AddChangeCallback("ace_restrictinfo", function(_, _, new)
            local legacy = GetConVar("acf_restrictinfo")
            if legacy then legacy:SetInt(new) end
        end, "ACE_LegacyRestrictInfo")
    end
    cvars.RemoveChangeCallback("ace_restrictinfo", "ACE_CVarChangeCallback")
    cvars.AddChangeCallback("ace_restrictinfo", function(_, _, new)
        ACE.RestrictInfo = tobool(new)
    end, "ACE_CVarChangeCallback")

    -- Toggles for vehicle legality restrictions
    CreateConVar( "ace_legality_enginesrequirefuel", 1 , FCVAR_ARCHIVE)

    CreateConVar( "ace_legality_largeenginesneeddriver", 1 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legality_largeenginethreshold", 100 , FCVAR_ARCHIVE)

    CreateConVar( "ace_legality_largegunsneedgunner", 1 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legality_largegunthreshold", 40 , FCVAR_ARCHIVE)

    -- Cvars for legality checking
    CreateConVar( "ace_legalcheck", 1 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legal_ignore_model", 0 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legal_ignore_solid", 0 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legal_ignore_mass", 0 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legal_ignore_material", 0 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legal_ignore_inertia", 0 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legal_ignore_makesphere", 0 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legal_ignore_visclip", 0 , FCVAR_ARCHIVE)
    CreateConVar( "ace_legal_ignore_parent", 0 , FCVAR_ARCHIVE)

    -- Prop Protection system
    CreateConVar( "ace_enable_dp", 0 , FCVAR_ARCHIVE )    -- Enable the inbuilt damage protection system.

    -- Cvars for recoil/he push
    CreateConVar("ace_kepush", 1, FCVAR_ARCHIVE)
    CreateConVar("ace_hepush", 1, FCVAR_ARCHIVE)
    CreateConVar("ace_recoilpush", 1, FCVAR_ARCHIVE)

    -- New healthmod/armormod/ammomod cvars
    CreateConVar("ace_healthmod", 1, FCVAR_ARCHIVE)
    CreateConVar("ace_armormod", 1, FCVAR_ARCHIVE)
    CreateConVar("ace_ammomod", 1, FCVAR_ARCHIVE)
    CreateConVar("ace_gunfire", 1, FCVAR_ARCHIVE)

    -- Debris
    CreateConVar("ace_debris_lifetime", 30, FCVAR_ARCHIVE)
    CreateConVar("ace_debris_children", 1, FCVAR_ARCHIVE)

    -- Spalling
    CreateConVar("ace_spalling", 1, FCVAR_ARCHIVE)
    CreateConVar("ace_spalling_multipler", 1, FCVAR_ARCHIVE)

    -- Scaled Explosions
    CreateConVar("ace_explosions_scaled_he_max", 100, FCVAR_ARCHIVE)
    CreateConVar("ace_explosions_scaled_ents_max", 5, FCVAR_ARCHIVE)

    --Smoke
    CreateConVar("ace_wind", 600, FCVAR_ARCHIVE)

    --Uses non-torqueing recoil if there are problems
    CreateConVar("ace_legacyrecoil", 0, FCVAR_ARCHIVE)

    function ACE_CVarChangeCallback(CVar, _, New)

        if CVar == "ace_healthmod" then
            ACE.Threshold = 264.7 / math.max(New, 0.01)
        elseif CVar == "ace_armormod" then
            ACE.ArmorMod = 1 * math.max(New, 0)
        elseif CVar == "ace_ammomod" then
            ACE.AmmoMod = 1 * math.max(New, 0.01)
        elseif CVar == "ace_spalling" then
            ACE.Spalling = math.floor(math.Clamp(New, 0, 1))
        elseif CVar == "ace_spalling_multipler" then
            ACE.SpallMult = math.Clamp(New, 1, 5)
        elseif CVar == "ace_gunfire" then
            ACE.GunfireEnabled = tobool( New )
        elseif CVar == "ace_debris_lifetime" then
            ACE.DebrisLifeTime = math.max( New,0)
        elseif CVar == "ace_debris_children" then
            ACE.DebrisChance = math.Clamp(New,0,1)
        elseif CVar == "ace_explosions_scaled_he_max" then
            ACE.ScaledHEMax = math.max(New,50)
        elseif CVar == "ace_explosions_scaled_ents_max" then
            ACE.ScaledEntsMax = math.max(New,1)
        elseif CVar == "ace_legacyrecoil" then
            ACE.UseLegacyRecoil = math.floor(math.Clamp(New, 0, 1))
        elseif CVar == "ace_legality_enginesrequirefuel" then
            ACE.EnginesRequireFuel = math.ceil(math.Clamp(New, 0, 1))
        elseif CVar == "ace_legality_largeenginesneeddriver" then
            ACE.LargeEnginesRequireDrivers = math.ceil(math.Clamp(New, 0, 1))
        elseif CVar == "ace_legality_largeenginethreshold" then
            ACE.LargeEngineThreshold = math.ceil(math.Clamp(New, 0, 10000))
        elseif CVar == "ace_legality_largegunsneedgunner" then
            ACE.LargeGunsRequireGunners = math.ceil(math.Clamp(New, 0, 1))
        elseif CVar == "ace_legality_largegunthreshold" then
            ACE.LargeGunsThreshold = math.ceil(math.Clamp(New, 0, 10000))
        elseif CVar == "ace_enable_dp" then
            if ACE.SendDPStatus then
                ACE.SendDPStatus()
            end
        end
    end

cvars.AddChangeCallback("ace_healthmod", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_armormod", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_ammomod", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_spalling", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_spalling_multipler", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_gunfire", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_debris_lifetime", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_debris_children", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_explosions_scaled_he_max", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_explosions_scaled_ents_max", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_legacyrecoil", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_legality_enginesrequirefuel", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_legality_largeenginesneeddriver", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_legality_largeenginethreshold", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_legality_largegunsneedgunner", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_legality_largegunthreshold", ACE_CVarChangeCallback)
cvars.AddChangeCallback("ace_enable_dp", ACE_CVarChangeCallback)

-- Apply archived/server convars at startup so values persist across restarts and reconnects.
local startupSync = {
    "ace_healthmod",
    "ace_armormod",
    "ace_ammomod",
    "ace_spalling",
    "ace_spalling_multipler",
    "ace_gunfire",
    "ace_debris_lifetime",
    "ace_debris_children",
    "ace_explosions_scaled_he_max",
    "ace_explosions_scaled_ents_max",
    "ace_legacyrecoil",
    "ace_legality_enginesrequirefuel",
    "ace_legality_largeenginesneeddriver",
    "ace_legality_largeenginethreshold",
    "ace_legality_largegunsneedgunner",
    "ace_legality_largegunthreshold",
    "ace_enable_dp"
}

for _, name in ipairs(startupSync) do
    local convar = GetConVar(name)
    if convar then
        ACE.CVarChangeCallback(name, nil, convar:GetString())
    end
end

elseif CLIENT then
---------------------------------- Clientside Convars ----------------------------------

    CreateClientConVar( "ace_enable_lighting", 1, true ) --Should missiles emit light while their motors are burning?  Looks nice but hits framerate. Set to 1 to enable, set to 0 to disable, set to another number to set minimum light-size.
    CreateClientConVar( "ace_sens_irons", 0.5, true, false, "Reduce mouse sensitivity by this amount when zoomed in with iron sights on ACE SWEPs.", 0.01, 1)
    CreateClientConVar( "ace_sens_scopes", 0.2, true, false, "Reduce mouse sensitivity by this amount when zoomed in with scopes on ACE SWEPs.", 0.01, 1)
    CreateClientConVar( "ace_tinnitus", 1, true, false, "Allows the ear tinnitus effect to be applied when an explosive was detonated too close to your position, improving the inmersion during combat.", 0, 1 )
    CreateClientConVar( "ace_sound_volume", 100, true, false, "Adjusts the volume of explosions and gunshots.", 0, 100 )

end


if ACE.AllowCSLua > 0 then
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
include("acf/shared/sh_ace_loader.lua")
AddCSLuaFile("acf/shared/sh_ace_scalable.lua")
include("acf/shared/sh_ace_scalable.lua")
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
    include("acf/server/sv_adminsettings.lua")
    AddCSLuaFile("acf/client/cl_acfballistics.lua")
    AddCSLuaFile("acf/client/cl_acemenu_gui.lua")
    AddCSLuaFile("acf/client/cl_acfrender.lua")
    AddCSLuaFile("acf/client/cl_soundbase.lua")

    AddCSLuaFile("acf/client/cl_acemenu_missileui.lua")

    AddCSLuaFile("acf/client/cl_acfpermission.lua")
    AddCSLuaFile("acf/client/gui/cl_acfsetpermission.lua")


elseif CLIENT then

    include("acf/client/cl_acfballistics.lua")
    include("acf/client/cl_acfrender.lua")
    include("acf/client/cl_soundbase.lua")

    include("acf/client/cl_acfpermission.lua")
    include("acf/client/gui/cl_acfsetpermission.lua")

    CreateClientConVar("ace_mobility_rope_links", "1", true, true)

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
--if ACE.Year > 1920 then

--end
--A surprising amount of things were made during WW2
if ACE.Year > 1939 then

    include("acf/shared/rounds/roundhesh.lua")
    include("acf/shared/rounds/roundheat.lua")
    include("acf/shared/rounds/roundaphe.lua")
    include("acf/shared/rounds/roundhvap.lua")

end
--Cold war
if ACE.Year > 1960 then

    include("acf/shared/rounds/roundapds.lua")
    include("acf/shared/rounds/roundapfsds.lua")
    include("acf/shared/rounds/roundheatfs.lua")
    include("acf/shared/rounds/roundhefs.lua")
    include("acf/shared/rounds/roundflare.lua")
    include("acf/shared/rounds/roundglgm.lua")

end
--almost finishing cold war
if ACE.Year > 1989 then

    include("acf/shared/rounds/roundtheat.lua")
    include("acf/shared/rounds/roundtheatfs.lua")

end

game.AddDecal("GunShot1", "decals/METAL/shot5")

-- Add the ACF tool category
if CLIENT then

    ACE.CustomToolCategory = CreateClientConVar( "ace_tool_category", 0, true, false );

    if ACE.CustomToolCategory:GetBool() then

        language.Add( "spawnmenu.tools.acf", "ACF" );

        -- We use this hook so that the ACF category is always at the top
        hook.Add( "AddToolMenuTabs", "CreateACECategory", function()

            spawnmenu.AddToolCategory( "Main", "ACF", "#spawnmenu.tools.acf" );

        end );

    end

end

timer.Simple( 0, function()
    for _, Table in pairs(ACE.Classes["GunClass"]) do
        PrecacheParticleSystem(Table["muzzleflash"])
    end
end)

--Stupid workaround red added to precache timescaling.
hook.Add( "Think", "ACE_InternalClock", function()
    ACE.CurTime = CurTime()
    ACE.SysTime = SysTime()
end )


if SERVER then

    function ACE_SendDPStatus()

        local Cvar = GetConVar("ace_enable_dp"):GetInt()
        local bool = tobool(Cvar)

        net.Start("ACE_DPStatus")
            net.WriteBool(bool)
        net.Broadcast()

    end

    function ACE_SendNotify( ply, success, msg )
        net.Start( "ACE_Notify" )
        net.WriteBit( success )
        net.WriteString( msg or "" )
        net.Send( ply )
    end
else

    local function notify()
        local Type = NOTIFY_ERROR
        if tobool( net.ReadBit() ) then Type = NOTIFY_GENERIC end

        GAMEMODE:AddNotify( net.ReadString(), Type, 7 )
    end
    net.Receive( "ACE_Notify", notify )
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
            net.Start("ACE_RenderDamage")
                net.WriteTable(Table)
            net.Send(ply)
        end
    end
    hook.Add( "PlayerInitialSpawn", "ACE_RenderDamageInitialSpawn", OnInitialSpawn )

end


if CLIENT then
    ACE.Wind = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0):GetNormalized()

    net.Receive("ACE_Wind", function()
        ACE.Wind = Vector(net.ReadFloat(), net.ReadFloat(), 0)
    end)
else
    local curveFactor = 2.5
    local reset_timer = 60
    ACE.Wind = Vector()
    timer.Create("ACE_Wind", reset_timer, 0, function()
        local smokeDir = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0):GetNormalized()
        ACE.Wind = (math.random() ^ curveFactor) * smokeDir * GetConVar("ace_wind"):GetFloat()
        net.Start("ACE_Wind")
            net.WriteFloat(ACE.Wind.x)
            net.WriteFloat(ACE.Wind.y)
        net.Broadcast()
    end)
end




cleanup.Register( "aceexplosives" )

-- The deferred E2 and Starfall adapters still use the dotted ACE table API.
-- Keep that adapter surface on ACE without reintroducing ACF-owned globals.
ACE.GetMaterialData = ACE_GetMaterialData
ACE.CheckRound = ACE_CheckRound
ACE.HeatFromGun = ACE_HeatFromGun
ACE.HeatFromEngine = ACE_HeatFromEngine
ACE.MarkArmorDirty = ACE_MarkArmorDirty

-- The unchanged adapters still call these legacy global entry points. Preserve
-- an independently loaded ACF implementation, otherwise route them to ACE.
if ACECompatibilityView then
    ACF_CalcArmor = ACF_CalcArmor or ACE_CalcArmor
    ACF_Check = ACF_Check or ACE_Check
    ACF_CheckClips = ACF_CheckClips or ACE_CheckClips
    ACF_GetHitAngle = ACF_GetHitAngle or ACE_GetHitAngle
    ACF_GetLinkedWheels = ACF_GetLinkedWheels or ACE_GetLinkedWheels
    ACF_SendNotify = ACF_SendNotify or ACE_SendNotify
end

AddCSLuaFile("autorun/acf_missile/folder.lua")
include("autorun/acf_missile/folder.lua")

print("[ACE | INFO]- Done!")
