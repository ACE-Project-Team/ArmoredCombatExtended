# ACE Points System Reference

This document describes the current points system as implemented in this repo. It is a standalone explanation of how points are calculated, cached, and displayed.

## Overview
- A contraption is a constrained set of entities treated as one vehicle.
- Armor points come from a line-of-sight (LOS) scan of the contraption, not from mass.
- Non-armor points are a mix of per-entity ACEPoints and ammo scoring.
- Guns and racks contribute rate-of-fire only; their direct point cost is zero.
- Fuel tanks are ignored for points.

## Core Contraption State
The legality system stores computed values on the contraption object:
- ACEPoints: Total points for the contraption.
- ACEPointsPerType: Per-category totals (Armor, Engines, Ammo, AmmoReady, AmmoBackup, Crew, Electronics, Firepower).
- ACEPointsNonArmor: Non-armor subtotal.
- ACEArmorFront / ACEArmorSide: Cached armor averages (mm) from the scan.
- ACEArmorPoints: Armor points derived from the scan.
- ACEArmorDirty: True when armor-affecting changes occur after initialization.
- ACEArmorCalculated: True after the first successful scan.
- ACENonArmorDirty: True when non-armor totals need rebuilding (ammo, guns, racks, etc.).
- ACEAmmoCache: Cached ROF and ready-rack data for ammo scoring.
- ACEPointsDetails: Readout details (ammo lines and trimmed items).

## Entity Classification
Entity classes are mapped into categories via ACE_GetPtsType:
- Armor: prop_physics, primitive_*, and any class not explicitly listed below.
- Engines: acf_engine
- Firepower: acf_gun, acf_rack (points zero, ROF only)
- Ammo: acf_ammo (custom scoring)
- Crew: ace_crewseat_driver, ace_crewseat_gunner, ace_crewseat_loader
- Electronics: ace_* radar/IRST/ECM devices and acf_opticalcomputer
- Ignore: acf_fueltank

ACE_GetEntPoints returns 0 for armor, ammo, guns, racks, and fuel tanks. All other entities contribute their ACEPoints value.

## When Calculations Run
Initialization (armor scan) is scheduled by these hooks:
- PlayerUnfrozeObject: when a player unfreezes part of the contraption.
- PlayerEnteredVehicle: when a player enters a seat in the contraption.
- AdvDupe_FinishPasting: multiple delayed passes to catch reparenting after paste.

Scheduling behavior:
- ACE_ScheduleInitArmor coalesces multiple triggers and uses the largest requested delay.
- Typical delay is 0.1 seconds. AdvDupe runs multiple delayed attempts.
- If ACEArmorCalculated is true and ACEArmorDirty is false, the scan is skipped.

Dirty behavior:
- Any armor-affecting change sets ACEArmorDirty = true.
- If the contraption is already initialized, dirty contraptions do not rescan.
- The readout warns that a respawn is required to apply new armor values.

Non-armor rebuild behavior:
- ACENonArmorDirty is set when ammo, guns, or racks change.
- Non-armor totals are rebuilt on demand when dirty or missing.

## Armor Scan
Armor is estimated by tracing toward critical components and measuring LOS thickness.

### 1) Entity Set
The scan uses the contraption entity list when available:
- Primary: contraption.ents.
- Fallback: base entity only.

Entities are sorted by EntIndex for determinism.

### 2) Direction Basis
A stable front/side/up basis is derived:
- Up comes from world gravity (physenv.GetGravity), inverted and normalized.
- Front comes from the main gun (largest caliber) forward vector, negated.
- If no gun is found, base entity forward is used.
- Front is flattened onto the gravity plane to avoid vertical bias.
- Side is derived from Axis constraints between the base and MakeSpherical wheels.
- If no wheel axis is found, side uses up x front.
- If that fails, side falls back to base right.
- The basis is orthonormalized to keep front and side perpendicular.

### 3) Critical Components
Armor is sampled around these components:
- acf_ammo, acf_fueltank, acf_engine
- ace_crewseat_driver, ace_crewseat_gunner, ace_crewseat_loader

If no critical components exist, the scan returns 0 for both front and side.

### 4) Sampling Points and Weights
For each critical component:
- Use OBB corners (scaled to 75 percent) plus the center.
- Compute projected area in front and side directions.
- Each sample carries an area-based weight (area / sample count).

### 5) LOS Thickness
For each sample point:
- A hull trace is fired toward the component from the front direction.
- Two hull traces are fired for the side direction (left and right).
- The smaller valid side thickness is used.

LOS thickness accumulation:
- Non-ACF props, MakeSpherical props, ignored classes, and clipped surfaces are skipped.
- Each valid armor hit adds LOS thickness based on material effectiveness and slope:
  - Effective = 0.8 * KE_effectiveness + 0.2 * CHEM_effectiveness.
  - Slope correction uses ACF_GetHitAngle and ACF.SlopeEffectFactor.
  - Curved armor uses its Curve value (power term).
- The trace repeats until the target component is hit or no hits remain.
- Samples that do not hit the target component are ignored.

### 6) Region Deduplication
To avoid stacking multiple hits from the same area:
- Hits are bucketed into a 2-unit grid in the scan plane.
- For each region, only the maximum LOS value is kept.

### 7) Averaging
Front and side averages are weighted by projected area and accumulated across regions.
The scan returns raw averages in millimeters.

### Debug
When ace_armor_debugvis is enabled:
- Boxes are drawn at hit locations.
- Color scales from green to red based on the maximum LOS in that scan.

## Armor Points
Armor points are calculated from the averaged results:

```
armor_pts = (front_avg + side_avg * 2) * 4
```

Side armor is intentionally weighted 2x. Points are stored in ACEArmorPoints and ACEPointsPerType.Armor.

## Non-Armor Points
Non-armor points are computed by ACE_CalcNonArmorPoints:
- Engines, Crew, Electronics: sum of ACEPoints on each entity.
- Firepower: zero (guns/racks are tracked for ROF only).
- Ammo: custom scoring per crate (see next section).

The totals are written into ACEPointsPerType and cached in ACEPointsNonArmor.

## Ammo Scoring
Ammo points are derived from ammo crates, compatible guns, and rack ROF.

### Required Inputs
For each crate:
- BulletData (bdata) must exist.
- Capacity must be greater than zero.
- Max penetration or blast mass must be available.
- A compatible gun or rack must exist to supply ROF.

If any of these are missing, the crate scores 0 points.

### Penetration and Blast Inputs
Max penetration is resolved in this order:
1) BulletData.MaxPen or MaxPen2 (takes the max).
2) ACF.RoundTypes[Type].getDisplayData (MaxPen/MaxPen2).
3) HE blast penetration from filler mass (BoomFillerMass or FillerMass),
   using ACF.HEPower and ACF.HEBlastPenetration.

Blast mass is taken from BoomFillerMass or FillerMass.

Caliber (mm) is derived from:
- Caliber, SlugCaliber, SlugCaliber2, JetCaliber (max), or
- ACF_GetGunValue(Id, "caliber") fallback.

Values are converted from cm to mm (x10).

### Rate of Fire
ROF is the sum of:
- All guns with matching ammo Id (ReloadTime or RateOfFire/60).
- All compatible racks (ReloadTime only).

If ROF is 0, the crate scores 0 points.

### Threat and Round Cost
Penetration and blast are combined into a single threat factor:

```
penFactor   = (maxPen / RefPen) ^ PenExp
blastFactor = (blastMass / RefBlastMass) ^ BlastExp
threat      = penFactor + blastFactor * BlastWeight

roundPts = BaseRoundPts * threat * (calMm / RefCaliber) * TypeFactor
rpsFactor = (rpsTotal / RpsRef) ^ RpsExp
```

### Ready Rack vs Backup Ammo
Ready rounds and stowed rounds have different costs.

Ready rack cap (per ammo Id group):
- Base: ReadyRackBase / caliber_mm
- Clamp to [ReadyRackMin, ReadyRackMax]
- If caliber is below ReadyRackPivot, apply a low-caliber boost:
  baseCap *= 1 + ReadyRackLowBoost * ((pivot - cal) / pivot)
- Clamp to total rounds in the group

Ready allocation across crates:
- Each ammo Id group shares a single readyCap.
- Ready rounds are distributed proportionally by crate capacity.
- Fractional remainder is distributed deterministically.

Cost breakdown per crate:
```
readyCost = roundPts * readyCount * rpsFactor
stowCost  = roundPts * stowCount * StowFactor * rpsFactor
```

Optional tail discount:
- If TailFactor and TailStartMultiplier are set, rounds beyond
  readyCap * TailStartMultiplier reduce effective rounds.

### Ammo Type Factors
Ammo type factors are applied directly to roundPts:

```
AP = 0.5
APHE = 0.6
APDS = 0.9
APFSDS = 1.2
HVAP = 0.7
HEAT = 0.75
HEATFS = 0.9
THEAT = 0.95
THEATFS = 1.0
HESH = 0.4
HE = 0.5
HEFS = 0.6
HP = 0.1
CAP = 0.6
CHEAT = 0.8
CHE = 0.25
CHF = 0
SM = 0
FLR = 0
FL = 0.3
GLATGM = 0.75
GLATGM-HE = 0.25
Refill = 0
```

## Caches and Performance
### Non-Armor Cache
Contraption.ACEAmmoCache stores:
- GunRpsById
- Racks
- ReadyAlloc

When ACENonArmorDirty is false, ammo scoring uses this cached data.

### Dupe Armor Cache
Armor scan results can be cached per duplication:
- ACE.DupeArmorCache stores { Front, Side } by a hash of dupe content.
- Hash inputs include class, model, bounds, and armor data.
- ace_dupe_armor_cache_ttl (default 1800 seconds) clears the cache periodically.
- ace_dupe_armor_cache_clear manually clears the cache.

## Readout and UX
The armor tool readout reports:
- Total points and per-category percentages.
- Armor scan front/side values in mm.
- Ammo lines grouped by caliber and type, split into READY/BACKUP.
- Contraption mass, material breakdown, and power-to-weight.

Warnings:
- "ARMOR COST NOT INITIALIZED" if no scan has occurred.
- "Armor cost dirty" if the contraption was modified after initialization.

Preview mode (double-tap R):
- Double-tap reload within ACE.ArmorPreviewTapWindow (default 0.35s).
- Runs a hypothetical scan and non-armor rebuild.
- Does not apply points to the contraption.
- Cooldown is ACE.ArmorPreviewCooldown (default 5s).

## Global Warnings
When a contraption exceeds limits, the system broadcasts a global chat message:
- Over points limit (ACF.PointsLimit).
- Over max weight (ACF.MaxWeight).

When a contraption is modified after initialization, a global warning is sent
once per scan, and it resets after a successful rescan.

## Configuration Summary
Key tuning values live in lua/autorun/acf_globals.lua:

```
ACF.PointsLimit = 10000
ACF.MaxWeight = 200000

ACE.AmmoCostConfig = {
    BaseRoundPts = 80,
    RefPen = 600,
    RefCaliber = 120,
    PenExp = 1.6,
    RefBlastMass = 6,
    BlastExp = 1.1,
    BlastWeight = 0.25,
    RpsRef = 1 / 7,
    RpsExp = 0.5,
    ReadyRackBase = 2400,
    ReadyRackMin = 10,
    ReadyRackMax = 200,
    ReadyRackPivot = 60,
    ReadyRackLowBoost = 0.5,
    StowFactor = 0.35,
    TailFactor = 0,
    TailStartMultiplier = 2
}

ACE.ArmorPreviewTapWindow = 0.35
ACE.ArmorPreviewCooldown = 5

ace_armor_debugvis (cvar)
ace_dupe_armor_cache_ttl (cvar)
```

Entity ACEPoints are computed in the entity definitions (for example
acf_engine and acf_gun) and then summed by the contraption system.

## Known Behaviors and Edge Cases
- If no critical components exist, armor scan returns 0 front/side.
- If the main gun points straight up/down, the front vector is flattened.
- If no wheel axis is found, side uses cross(up, front), then base right.
- Non-ACF props, MakeSpherical wheels, and clipped surfaces are ignored in LOS.
- Ammo with no compatible gun/rack, missing penetration, or zero type factor
  contributes 0 points.
- Classes not explicitly categorized are treated as Armor and only affect
  points through the armor scan.
