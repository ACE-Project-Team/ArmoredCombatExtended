# ACE Armor Cost System Changes

This document describes the recent armor cost pipeline changes, how the system now works end-to-end, the rationale, and the risk profile (including known exploit windows). It is intended to help maintainers evaluate adoption.

Contents
- Executive Summary
- Goals and Scope
- System Overview
- Calculation Pipeline (Step-by-step)
- What Changed (Detailed List)
- Debug Visualization Behavior
- Performance Profile
- Possible Exploits and Edge Cases
- Mitigation Options
- Suggested Test Plan

Executive Summary
The new pipeline makes armor cost calculation consistent and deterministic by doing a single contraption-level scan on first initialization (unfreeze or first vehicle entry), then freezing the armor cost unless the vehicle is respawned. Subsequent changes mark the cost as dirty and display a visible warning in the readout rather than silently recalculating. This avoids expensive re-scans, removes inconsistent behavior from on-demand tools, and blocks most "spam-rescan" approaches that previously allowed players to search for favorable snapshots.

Goals and Scope
- Consistency: The same vehicle configuration yields the same armor cost across sessions and tools.
- Performance: Avoid repeated trace-heavy scans during normal play.
- Transparency: Show explicit warnings when costs are stale or uninitialized.
- Exploit resistance: Make it harder to abuse timing-based recalculation without server admin intent.

Scope
- Contraption-level armor scanning and point rollups.
- Tool readout behavior for armor summary.
- Engine/ammo/missile point cost consistency fixes.
- Debug overlays for armor scan visualization.

System Overview
The armor cost system is now split into two phases:
1) Initialization scan: a single expensive scan computes front and side armor values and derives armor points. This is performed on first unfreeze or first vehicle entry (whichever happens first).
2) Steady state: after initialization, any later changes to armor mark the contraption as dirty and display a warning. The cost is not recomputed until a respawn.

This yields a stable cost snapshot used for legality checks and UI readouts, while still exposing when a player modified the vehicle afterward.

Calculation Pipeline (Step-by-step)
1) Contraption creation
   - `ACE_InitPts` initializes point totals.
   - `ACEArmorDirty = true` and `ACEArmorCalculated = false`.

2) Initialization trigger (first scan)
   - Triggered by `PlayerUnfrozeObject` or `PlayerEnteredVehicle` (first occurrence).
   - A 0.1s delay is applied to allow reparenting or tool-side adjustments to settle.
   - The scan runs once via `ACE_EnsureArmor`, computes:
     - Front armor average (line-of-sight thickness to critical components).
     - Side armor average (line-of-sight thickness, separate sample set).
   - Final armor points: `(front + side * 2) * 4`.
   - `ACEArmorCalculated = true`, `ACEArmorDirty = false`.

3) After initialization
   - Any changes (add/remove armor props, set mass) set `ACEArmorDirty = true`.
   - Costs are not recomputed. The readout explicitly warns that costs are dirty and require a respawn.

4) UI behavior
   - Armor tool readout uses the cached values if initialized.
   - If not initialized, it shows a warning: unfreeze or enter vehicle.
   - If dirty after initialization, it shows a respawn warning.

What Changed (Detailed List)
1) Armor scan side weighting
   - Side armor is now weighted only once. Previously, side was doubled in the scan and then doubled again when costing, over-weighting side by 4x.
   - Current formula: `(front + side * 2) * 4`.

2) Armor scan sampling and debug overlays
   - Debug squares now render at actual trace hit points (armor surface), not just OBB corners.
   - Marker size represents each sample’s share of the projected surface area.

3) Engine cost consistency
   - Engine cost is now recomputed on update using the same fallback cost formula and multiplier as initial spawn.
   - This avoids "update path" vs "spawn path" point divergence.

4) Ammo crate cost correctness
   - Ammo cost now uses the freshly computed `AmmoMaxMass` instead of stale values.

5) Missile guidance cost safety
   - Guidance multipliers are now guarded with a safe fallback to avoid nil math and zeroing cost when unknown guidance is used.

6) Scan triggering policy
   - The scan no longer runs on tool use or legality checks.
   - It runs once on unfreeze, or on first vehicle entry if that happens first.
   - Changes afterward only mark the cost as dirty and warn.

Debug Visualization Behavior
- Debug overlays are tied to the scan execution itself.
- Because scans are now single-shot and triggered on unfreeze/entry, debug overlays appear only when that initialization scan is performed (or when a manual debug scan is invoked).
- This is expected and prevents debug overlays from encouraging repeated scans.

Performance Profile
Prior behavior:
- Armor scanning could be triggered repeatedly by tools or legality checks.
- Resulted in multiple trace hull runs per frame, inconsistent timing, and potential spam.

Current behavior:
- One scan per contraption at initialization.
- No repeated scanning on normal gameplay.
- Dirty changes become a warning rather than a rescan.
- Reduced server load and more consistent gameplay performance.

Possible Exploits and Edge Cases
1) Post-init armor reduction
   - Player initializes vehicle, then removes armor to reduce actual weight and still keep the old higher cost.
   - Impact: vehicle pays more cost than needed, not a balance issue but could annoy players.

2) Post-init armor increase
   - Player initializes vehicle, then adds armor or changes materials to become tougher without cost increase.
   - Impact: balance exploit if building is allowed after init.

3) Unfreeze order manipulation
   - Player attaches "dummy" armor before unfreeze to inflate cost, then removes it.
   - Impact: opposite of exploit (cost too high), but may be used to avoid suspicion in legality systems.

4) Entry-before-unfreeze timing
   - If the player enters a seat before unfreeze, the scan will run at that time.
   - This is intentional to guarantee initialization even if unfreeze never fires.

5) Reparenting edge cases
   - Some entities reparent on spawn; the 0.1s delay is intended to reduce mis-scans, but complex setups may still require a manual respawn.

Mitigation Options
If maintainers want to close exploit windows without reintroducing heavy scans:
- Lock building after initialization
  - Example: disallow tool use or physgun on contraption entities once `ACEArmorCalculated` is true.
- Add an explicit "Recalculate Armor" admin command
  - Only server admins can force a rescan for a contraption.
- Enforce respawn on dirty
  - If `ACEArmorDirty == true` for longer than a threshold, force a respawn or mark the contraption illegal.
- Add a lightweight re-scan trigger
  - Example: rescan only on vehicle freeze or after a build session ends.

Suggested Test Plan
- Spawn a vehicle, do not unfreeze, check armor tool: see "not initialized" warning.
- Unfreeze vehicle: armor is computed and warning disappears.
- Enter vehicle before unfreeze: armor computes on entry.
- Add armor after init: see "dirty" warning; cost stays fixed.
- Update engine/ammo/missile definitions and verify costs remain consistent after entity updates.
- Enable `ace_armor_debugvis` and confirm squares appear at real hit points with scaled sizes during initialization scan.

Summary for Adoption
This system trades continuous recalculation for a consistent, stable cost snapshot. It is fast, avoids spam, and makes armor cost changes explicit to players. The remaining exploit window (post-init changes) is surfaced to users and can be hardened by server policy if desired, without reintroducing heavy tracing or inconsistent recalcs.
