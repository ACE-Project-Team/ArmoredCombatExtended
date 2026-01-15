# ACE Armor and Cost System (Current Behavior)

This document is a complete, no-context explanation of how the current ACE cost system works. It covers when calculations run, how armor and ammo are scored, what is shown in the readout, and which values can be tuned.

## Scope
- Contraption-level armor scanning and scoring.
- Ammo-driven firepower cost (guns and racks are zero-cost; ammo carries offense).
- Engine, crew, and electronics point rollups.
- Readout format, warnings, and debug behavior.

## Key Terms
- Contraption: A set of constrained entities treated as one vehicle.
- Critical component: Engine, ammo crate, fuel tank, or crew seat; used as sampling anchors for armor traces.
- Initialized: Armor scan has been performed and cached.
- Dirty: Contraption changed after initialization; armor cost is stale until respawn.

## High-Level Flow
1) When a contraption is initialized (unfreeze, vehicle entry, or dupe paste), an armor scan runs once.
2) The scan computes average front and side armor for the contraption.
3) Armor points are calculated from those averages.
4) Non-armor points are rebuilt, including ammo points based on penetration and total compatible ROF.
5) If the contraption changes afterward, it is marked dirty and a warning appears. No re-scan occurs until respawn.

## When Calculations Run
Initialization triggers:
- Player unfreezes an entity in the contraption.
- Player enters a vehicle seat in the contraption.
- Advanced Duplicator paste (runs multiple delayed attempts to catch reparenting).

Initialization details:
- The scan is delayed briefly (default 0.1s) to allow reparenting and tool adjustments.
- If the contraption is already initialized and not dirty, it is not recalculated.

Dirty behavior:
- Any armor-affecting change (mass/material changes, armor entity add/remove) sets ACEArmorDirty = true.
- Dirty contraptions do not re-scan; the readout warns that a respawn is required.

## Armor Scan Algorithm
### Entity Set
- Primary source: contraption.ents (framework list).
- Fallback: ACE.contraptionEnts filtered by contraption id.
- Final fallback: base entity only.

### Facing Detection
- The largest-caliber main gun is used to infer front/side directions.
- If no gun is found, the base entity forward/right vectors are used.

### Sampling
- Critical components (engine, ammo, fuel, crew) are used as sampling anchors.
- Each component contributes multiple sample points (OBB corners + center).
- Projected surface area is computed in front and side directions.
- Samples are area-weighted to reduce bias from small parts.

### Line-of-Sight Thickness
For each sample point:
- A hull trace is fired toward the component from the front direction.
- A hull trace is fired from both left and right for the side direction (lowest valid value wins).
- Armor thickness uses material effectiveness and slope correction.
- MakeSpherical props and non-armor classes are skipped.
- Effective armor blends KE/CHEM as: eff = 0.8 * KE + 0.2 * CHEM.

### Aggregation
- Samples are grouped by a coarse region key to prevent stacking the same armor multiple times.
- Weighted averages are computed for front and side.

### Armor Points
Final armor points are calculated as:
```
armor_pts = (front_avg + side_avg * 2) * 4
```
Side armor is intentionally weighted 2x.

## Ammo Cost Model (Firepower)
Firepower is represented by ammo only. Guns and racks are zero-cost entities.

### Steps
1) Collect total ROF per ammo id from all guns in the contraption.
   - Uses ReloadTime if present; otherwise RateOfFire in RPM.
2) If a rack is compatible with the ammo, add rack ReloadTime to the total ROF.
3) For each ammo crate, compute a per-round cost from penetration, caliber, and type.
4) Multiply per-round cost by crate capacity and ROF factor.

### Formula
```
round_pts = BaseRoundPts
            * (max_pen / RefPen) ^ PenExp
            * (caliber_mm / RefCaliber)
            * type_factor

crate_pts = round_pts * capacity * (rps_total / RpsRef) ^ RpsExp
```

### Current Constants
- BaseRoundPts = 111.1
- RefPen = 600
- RefCaliber = 120
- PenExp = 2
- RpsRef = 1 / 7
- RpsExp = 0.5

### Max Pen Source
- If BulletData.MaxPen exists, it is used.
- Otherwise the round type display data is queried (ACF.RoundTypes[type].getDisplayData).
- If no MaxPen can be resolved, the crate contributes 0 points.

### Ammo Type Factors
```
AP=1
APHE=1
APDS=1
APFSDS=1.05
HVAP=1
HEAT=0.75
HEATFS=0.75
THEAT=0.82
THEATFS=0.82
HESH=0.55
HE=0.25
HEFS=0.25
HP=0.25
CAP=1
CHEAT=0.75
CHE=0.25
CHF=0
SM=0
FLR=0
FL=1
GLATGM=0.75
GLATGM-HE=0.25
Refill=0
```

## Other Point Categories
- Armor: contraption-level scan result only.
- Engines: uses existing per-entity ACEPoints.
- Ammo: calculated as above from crates.
- Crew: uses per-entity ACEPoints (crew seats).
- Electronics: uses per-entity ACEPoints.
- Fuel: ignored (0 points).
- Firepower: guns/racks are tracked for ROF only and cost 0 points.

## Readout Format
The armor tool shows a cost breakdown and a summary. Example format:
```
<||============|[- Cost Breakdown -]|============||>
Total Cost: 12826.6pts  -  2826.6 pts over
Armor scan: front=548.49mm  side=70.97mm
Armor: (22%) - 2761.7/12826.6
Engines: (11%) - 1409/12826.6
Ammo: (58%) - 7453.9/12826.6
Crew: (9%) - 1202/12826.6
Electronics: (0%) - 0/12826.6
- Top Cost Items:
Ammo: 42x140mm APFSDS - Pen: 857, RPS: 0.06 - 4936.1pts
Ammo: 36x140mm HEATFS - Pen: 1300, RPS: 0.08 - 3432.5pts
Engines: 20.7L Flat 6 Multifuel - 1409.0pts
Crew: Alex Popov - 400.0pts
<||============|[- Contraption Summary -]|============||>
...
```

Top Cost Items behavior:
- Sorted by points descending, stable by entity index.
- Any item >= 300 pts is listed.
- Ammo entries are formatted as: cap x caliber type - Pen: X, RPS: Y.

Warnings:
- If not initialized: "Armor cost not initialized; unfreeze or enter vehicle."
- If dirty: "Armor cost dirty; respawn to recalc."

## Debug and Diagnostics
- `ace_armor_debugvis` draws debug boxes at armor hit locations during a scan.
- Colors scale from green to red relative to the max LOS value in that scan.
- Console prints a single-line summary if debug is enabled.

## Performance and Consistency
- One scan per contraption at initialization; no continuous tracing during play.
- Cached values are deterministic for a given contraption state.
- Dirty changes are explicit rather than silent re-scans.

## Edge Cases and Limitations
- If a gun or rack has no compatible ammo in the contraption, ammo ROF is zero and crates score 0 points.
- If MaxPen cannot be resolved for a round type, that crate scores 0.
- Main-gun direction inference can be wrong on unconventional builds; fallback uses base entity orientation.
- Post-init modifications can change actual protection without updating cost; this is intentional and surfaced as a warning.

## Tuning Knobs
- AmmoCostConfig: BaseRoundPts, RefPen, RefCaliber, PenExp, RpsRef, RpsExp.
- AmmoTypeFactors: per-type multipliers.
- Armor cost scale: `(front + side * 2) * 4`.
- Initialization timing: delay in ACE_ScheduleInitArmor.

## Suggested Test Checklist
- Spawn a contraption, do not unfreeze: readout shows "not initialized" warning.
- Unfreeze: armor initializes and warning disappears.
- Enter vehicle before unfreeze: armor initializes on entry.
- Modify armor after init: readout shows "dirty" warning and costs remain fixed.
- Test ammo crates with and without compatible guns/racks; confirm ROF scaling and label formatting.
- Enable `ace_armor_debugvis` and verify debug boxes render at trace hit locations.
