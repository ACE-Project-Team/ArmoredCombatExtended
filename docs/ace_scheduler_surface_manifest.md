# ACE Scheduler Surface Manifest

Status: generated line-level inventory from the damage-stack base at `47075c43`.

This manifest is intentionally source-derived. It records where ACE schedules work, then separates
work that can eventually be represented by an ACE-owned due-time heap from callbacks whose timing or
ownership belongs to Garry's Mod, physics, entity lifecycle, weapons, or presentation. A `pending`
entry is not approved for migration; it means the call site needs a focused parity audit.

## Inventory counts

The first scan found 127 `hook.Add`/`hook.Run` references, 83 timer references, 38
`NextThink`/`SetNextThink` references, and 66 `:Think` references across Lua. These counts include
non-scheduling event hooks and compatibility aliases, so they are discovery counts, not migration
targets. The scan found 79 files with at least one timer, Think/NextThink, or Think/Tick hook.

The reproducible line-level generator `tools/ace_scheduler_manifest.py` currently emits 239
scheduling rows: 99 `migrated`, 87 `engine-bound`, 55 `blocked`, and zero `pending`. It records
the source file, line, occurrence, scheduling primitive, preceding-declaration hint, disposition,
reason, and—when routed—its current evidence state. The hint is a navigation aid, not an ownership
proof.
Run `python tools/ace_scheduler_manifest.py --strict` from the repository root; a nonzero result
means a new scheduling row has not yet received an explicit line-level disposition. Migrated rows
also carry an evidence state (`passing` or `partial`) and a concise gate note. CI runs this strict
check alongside the Python and LuaJIT offline suites.

The reviewed file hashes intentionally cover the full discovered scheduling surface, including
engine-bound and blocked files outside this first migration. That makes a future timing change
fail closed until its ownership and behavior are re-audited; it is a maintenance contract for the
mod-wide inventory, not an assertion that every listed file is routed through the heap.

The committed native JSON/probe records are historical controlled-environment evidence. Their
provenance identifiers refer to the measurement runs that produced them; they are not claims that
those development commits remain in this stacked branch.

The zero-pending result proves completeness only for the generator's recognized static call
patterns. It does not prove that dynamically constructed, aliased, or indirect timer/hook calls
are absent; those require a separate source audit before the manifest can be treated as exhaustive
beyond this grammar.

The heap ordering key is `(due time, priority, insertion sequence)`. Priority defaults to zero, so
existing adapters retain their FIFO order for equal due times; future phase adapters can use an
explicit integer priority without changing the timing contract of current callers.

## Classification rules

| Status | Meaning |
| --- | --- |
| `pending` | Scheduling surface found; exact ownership, cadence, and parity contract still need review. |
| `candidate` | ACE-owned due-time or coalescing work that is a plausible first migration target. |
| `engine-bound` | Keep on the engine callback until a separately measured adapter proves equivalent ordering. |
| `blocked` | Do not route through the shared heap without a new contract or experiment. |
| `migrated` | Routed through the heap. Evidence state is recorded separately because parity, teardown, and performance gates can be passing, partial, or still open. |

## High-confidence surfaces

| Surface | Source | Initial status | Reason / next evidence |
| --- | --- | --- | --- |
| Point invalidation flush | `lua/ace/server/sv_pointshandling.lua:465-470` | `migrated (opt-in; evidence partial)` | Existing coalescing queue now has a heap adapter; native load/enable/disable/teardown plus single-prop, two-prop, cross-contraption, and real linked `acf_gun`/`acf_ammo` ledger/dispatch parity fixtures passed. A 32-prop removal fixture also preserved point parity; its direct-vs-scheduled flush timings are preliminary dispatch samples, not server-lag measurements. Dynamic mutation sensitivity remains open because the native fixture stayed on the 13-point floor. |
| Visual damage coalescing | `lua/ace/server/sv_ace_renderqueue.lua:94` | `migrated (opt-in; evidence partial)` | Presentation-only queue now has a one-shot heap adapter with 1 ms spacing, duplicate suppression, fallback-hook restoration, enabled-reload protection, and deterministic coalescing/cadence/invalid-entity tests. Native packet parity remains a targeted gate. |
| Contraption periodic cleanup | `lua/ace/server/sv_contraption.lua:324` | `migrated (opt-in; evidence partial)` | Recurring heap node with explicit +3 s reschedule; native load/enable/disable/teardown round-trip passed. Active-contraption scaling remains a performance gate. |
| Permission-mode cadence | `lua/ace/server/sv_acfpermission.lua:509` | `migrated (opt-in; evidence passing)` | ACE-owned self-scheduling mode-think loop now has a heap adapter with explicit next-delay rescheduling and timer restoration on disable. Native registration/activation/teardown passed; measured reschedule interval was `0.009999999999999787` s (approximately 10 ms). |
| Safe-zone transition detector | `lua/ace/server/sv_ace_safezone.lua:120-136` | `migrated (opt-in; evidence partial)` | Tick-preserving heap node with exact Think-hook fallback on disable; persistent zone state survives enabled reload, and disconnect cleanup is module-owned. LuaJIT coverage and native activation, approximately 15.15 ms cadence, exactly two entry/exit callbacks, and teardown pass; relative hook-order parity remains open. |
| Safe-zone visualization delay | `lua/ace/server/sv_acfpermission.lua:111`, `lua/ace/server/sv_ace_safezone.lua:49-78` | `migrated (opt-in; evidence partial)` | One-shot five-second visualization delay routes through the heap when enabled and retains a generation-invalidated timer fallback otherwise. LuaJIT coverage passes fallback invalidation, reload replacement, one-shot retirement, and disable restoration; native v19 dispatch measured `0.04999999999999982` s for a requested 0.05 s and delivered once, while visualization packet ordering remains open. |
| Contraption legality cooldown | `lua/ace/server/sv_contraptionlegality.lua:77`, `lua/ace/server/sv_ace_legalcheck.lua:54-85` | `migrated (opt-in; evidence partial)` | Per-entity three-second warning cooldown uses a stable keyed one-shot node when enabled and preserves the original timer fallback otherwise. LuaJIT coverage passes validity guarding, reload replacement, one-shot completion, and disable restoration; native v20 measured `0.04999999999999982` s for a requested 0.05 s and reset entity state once, while full warning-scan parity remains open. |
| ACE internal clock | `lua/autorun/acf_globals.lua:606` | `engine-bound` | Clock source feeds unrelated consumers; do not replace with scheduler time. |
| Wind reset timer | `lua/autorun/acf_globals.lua:681-702` | `migrated (opt-in; evidence partial)` | Recurring heap node with explicit +60 s reschedule; native load/enable/disable/teardown round-trip passed. Wind broadcast/state parity and long-run cadence remain performance/behavior gates. |
| Wind sensor cadence | `lua/entities/ace_wind_sensor/init.lua:110-123`, `lua/ace/server/sv_ace_wind_sensor_scheduler.lua:49-121` | `migrated (opt-in; evidence partial)` | Per-instance 100 ms Wire/output cadence uses unique scheduler keys, immutable callback tokens, explicit `CallOnRemove`/`OnRemove` plus `EntityRemoved` detachment, preserved next-due phase, and engine Think fallback when disabled. LuaJIT adapter coverage passes cadence, fallback phase, removal, reload, and key-reuse checks; native v34 passes two real sensors with 100 ms cadence, one scheduled update each, one additional fallback update each, one resumed update each, output-snapshot parity, first-removal isolation, and deferred teardown. Connected Wire packet ordering and larger-scale load scaling remain open. |
| Scalable-entity resync | `lua/entities/ace_scalability/init.lua:131-153`, `lua/ace/server/sv_ace_scalability_scheduler.lua:1-144` | `migrated (opt-in; evidence partial)` | Per-player reverse-order resync uses one keyed heap job, the request-captured live table reference, one entity per engine tick, replacement/cancellation, disconnect cleanup, and timer fallback when disabled. LuaJIT coverage passes; native v36 with real entities and a bot recipient passed order, recipient assertions, scheduler/fallback toggle, teardown, and measured scheduled spacing of 14.971-15.379 ms plus fallback spacing of 15.009-30.029 ms. A real client-triggered request/packet-delivery path and disconnect-cancellation evidence remain open. |
| Virtual heat-source cadence | `lua/entities/ace_vheat_source/init.lua:133-159`, `lua/ace/server/sv_ace_vheat_source_scheduler.lua:1-126` | `migrated (opt-in; evidence partial)` | Self-contained fixed 100 ms heat integration uses one keyed heap node per entity, preserves the exact fixed-step update, Wire output/overlay order, entity removal, fallback phase, and enabled reload cleanup. LuaJIT coverage passes; native v46 first-step parity for the first scheduled source, real-entity cadence/removal, and clean scheduler disable/enable teardown path pass with 106.613 ms first spacing and 105.530-107.074 ms survivor spacing. Post-enable recurrence, connected Wire packet, and larger-scale load scaling remain open. |
| G-force-meter cadence | `lua/entities/ace_gforce_meter/init.lua:161-178`, `lua/ace/server/sv_ace_gforce_meter_scheduler.lua:1-119` | `migrated (opt-in; evidence partial)` | Self-contained fixed 50 ms position-delta acceleration, smoothing, five Wire outputs, and overlay update use one keyed heap node per entity while preserving output/overlay order and engine fallback. LuaJIT coverage passes cadence, fallback phase, removal, and enabled reload cleanup; native v51 real entities passed stationary first-step parity at `GForce=1`, 59.486-61.438 ms survivor cadence, removal isolation, and clean disable/enable teardown. Dynamic physics parity, connected Wire packet, and larger-scale load scaling remain open. |
| Flare signal cadence | `lua/entities/ace_flare/init.lua:57-75`, `lua/ace/server/sv_ace_flare_scheduler.lua:1-178` | `migrated (opt-in; evidence partial)` | The 200 ms thermal/radar signature update uses one keyed heap node per flare while retaining the native fallback. Underwater behavior is preserved: `Thermal` becomes zero, particles stop, `RadarSig` freezes, and the Think cadence continues so a flare that surfaces can resume its original signature updates. LuaJIT parity covers fallback phase, heap recurrence, disable, unregister, and enabled reload; native v2 real-entity cadence, disable-to-zero, re-enable fallback, and removal quiescence pass; see `docs/ace_scheduler_flare_native_v2.json`. Native underwater behavior and larger-scale cadence cost remain open. |
| Debris/flare lifetime removal | `lua/entities/ace_debris.lua:28-36`, `lua/entities/ace_flare/init.lua:34-58`, `lua/ace/server/sv_ace_debris_scheduler.lua:1-137` | `migrated (opt-in; evidence partial)` | One-shot validity-guarded removal uses stable heap keys for debris and flare when enabled and restores each original timer behavior when disabled or unavailable. LuaJIT coverage passes heap/fallback parity, replacement, cancellation, invalid-entity guard, and disable restoration. Native v2 explicitly observed fallback timer versus heap path selection, disable/re-enable lifecycle, deferred cancellation record/node removal, and post-cleanup quiescence; see `docs/ace_scheduler_debris_native_v2.json`. Larger-scale timer/dispatch cost remains open. |
| Gun delayed auto-sound | `lua/entities/acf_gun/init.lua:1174`, `lua/ace/server/sv_ace_gun_autosound_scheduler.lua:1-126` | `migrated (opt-in; evidence partial)` | Presentation-only 0.6 s post-muzzle sound keeps independent per-shot records, heap/timer fallback behavior, invalid-gun guarding, and the original sound arguments. The retained offline gate in `docs/ace_scheduler_gun_autosound_gate.md` passes; native sound delivery and larger-scale dispatch cost remain open. Gun reload, bodygroup, firing-state, and Think callbacks remain blocked. |
| Ammunition delayed mini-HE flash | `lua/entities/acf_ammo/init.lua:963`, `lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua:1-132` | `migrated (opt-in; evidence partial)` | Presentation-only 1 ms `ACE_Scaled_Explosion` effect retains independent records, dynamic position lookup, entity validity guarding, timer fallback, and disable/reload cleanup. LuaJIT parity passes; native effect delivery and larger-scale dispatch cost remain open. Cookoff state, explosion, and Think callbacks remain blocked. |
| Delayed HE detonation effect | `lua/ace/server/sv_acfdamage.lua:1682`, `lua/ace/server/sv_ace_damage_effect_scheduler.lua:1-123` | `migrated (opt-in; evidence partial)` | Authoritative `ACE.HE` work remains synchronous; only the 1 ms `ACE_Scaled_Detonation` presentation callback routes through the heap, preserving origin/radius arguments and timer fallback. LuaJIT heap/fallback, independent records, reload, disable parity, and a static integration assertion pass; native effect delivery and larger-scale dispatch cost remain open. Critical-entity trace retry remains blocked. |
| ACE scheduler dispatch | `lua/ace/server/sv_ace_scheduler.lua:310-319` | `migrated` | Shared dispatch now hosts opt-in point, cleanup, wind, permission, safe-zone, visual-damage, scalable-resync, virtual-heat-source, entity-lifetime, flare-signal, gun-sound, ammunition-flash, damage-effect, and sonar travel-sound adapters. The engine Think hook that invokes the dispatcher remains engine-bound; adapter activation/deactivation is sorted by adapter key so same-due insertion order is reproducible. Native v1 controlled-load evidence measured 21 repetitions at queue sizes 0-10,000; Tick-hook v4 additionally measured controlled high-load fault boundaries at 5,000 and 10,000 callbacks; see `docs/ace_scheduler_load_native_v1.json` and `docs/ace_scheduler_tick_load_native_v4_diagnostic.json`. |
| Bullet flight Tick | `lua/ace/server/sv_acfballistics.lua:335` | `blocked` | Physics, collision, damage, and authoritative event ordering. |
| Point/damage hook dispatch | `lua/ace/server/sv_acfbase.lua:100-132` | `blocked` | Hook return values are synchronous control flow. |
| Radar/IRST/sonar Think | `lua/entities/ace_searchradar/init.lua:267`, `ace_trackingradar/init.lua:475`, `ace_irst/init.lua:417`, `ace_sonar/init.lua:998` | `engine-bound / blocked` | Explicitly dispositioned by the generated line inventory: entity Think/NextThink ordering is engine-bound or blocked by target selection, traces, Wire outputs, and lifecycle contracts; no Think migration is approved. The isolated sonar presentation callbacks are listed separately below. |
| Sonar travel-sound presentation | `lua/entities/ace_sonar/init.lua:552-589`, `lua/ace/server/sv_ace_sonar_scheduler.lua:1-141` | `migrated (opt-in; evidence partial)` | The delayed contraption travel and return sound/debug callbacks use independent heap records through `ACE.SonarTravelSound`, retaining the original timer fallback, sound/debug arguments, invalid-base guard, reload cleanup, and disable fallback. LuaJIT behavioral parity passes; native v1 real-entity adapter evidence passes heap/timer selection, disable/re-enable fallback, due-time delivery, invalid-base cleanup, and post-cleanup quiescence (see `docs/ace_scheduler_sonar_native_v1.json` and its committed probe); audible delivery and larger-scale dispatch cost remain open. Adjacent sonar damage, ping expiry, return processing, and sensor-state callbacks remain blocked. |
| Sonar ping-cache expiry | `lua/entities/ace_sonar/init.lua:567-574`, `lua/ace/server/sv_ace_sonar_scheduler.lua:234-284` | `migrated (opt-in; evidence partial)` | The six-second `Contraption.SonarPings[MyID]` expiry uses per-contraption/ping coalescing, preserves the latest legacy timer when a ping refreshes, rejects invalid or same-frame-deleted bases, retains timer fallback, and cleans up on disable/re-enable and teardown. LuaJIT parity and native v6 pass functional phases; native scale v1 drained 1,000/5,000/10,000 records in 3.485/12.874/25.142 ms dispatch time with zero residual state. These are controlled adapter workload measurements, not universal whole-server lag thresholds. Adjacent sonar damage, return processing, and sensor-state callbacks remain blocked. |
| Missile and ammunition Think | `lua/entities/ace_missile/init.lua:114`, `lua/entities/acf_ammo/init.lua:786` | `blocked` | Guidance, flight, firing, and physics-sensitive state transitions. |
| Engine/gun/gearbox/rack Think | `lua/entities/acf_engine/init.lua:503`, `acf_gun/init.lua:745`, `acf_gearbox/init.lua:424`, `acf_rack/init.lua:327` | `blocked` | Physics and Wire ordering; retain engine callbacks pending proof. |
| Entity lifecycle hooks | `lua/ace/server/sv_contraption.lua:107-163`, `lua/ace/shared/sh_ace_functions.lua:982` | `engine-bound` | Creation/removal ordering and validity guarantees belong to engine hooks. |
| Client render/effect hooks | `lua/ace/client/cl_acfballistics.lua:14`, `lua/ace/client/cl_soundbase.lua:698` | `engine-bound` | Client presentation is outside the first server scheduler; the permission GUI uses SpawnMenuOpen/PopulateToolMenu hooks rather than Think. |

## File-level discovery ledger

The following files were found by the source scan. Group status is deliberately conservative; each
file must be reduced to individual call-site status before the manifest can be considered complete.

### Explicit dispositions for non-migrated ACE-owned scheduling

The first source scan grouped these files as candidates, but the current disposition is now
explicit. Point flushing, periodic cleanup, wind reset, and permission-mode cadence are the
`migrated (opt-in)` rows above. The remaining ACE-owned files in this group are blocked or
engine-bound for the following reasons:

- `lua/ace/server/sv_ace_safezone.lua` safe-zone transition hook and visualization delay: migrated
  opt-in; the transition detector polls live players at `engine.TickInterval()` through a keyed
  recurring node and restores the original `Think` hook when disabled. The five-second visualization
  delay uses a keyed one-shot node when enabled and a generation-invalidated timer fallback otherwise.
  LuaJIT fallback/load-order/cadence/transition/reload/teardown coverage passes; native transition
  delivery/cadence/teardown pass, while visualization packet ordering and relative Think hook order
  remain open.
- `lua/ace/server/sv_contraption.lua:107-163` and `lua/ace/server/sv_crewseat_base.lua:103-115`,
  together with `lua/ace/shared/sh_ace_functions.lua` and `lua/autorun/server/sv_acf_missiles.lua`,
  remain `engine-bound`; their delayed work is tied to entity creation, duplicator/model-data
  application, compatibility initialization, or lifecycle callbacks rather than an independent ACE
  cadence. Replacing the zero-delay engine callbacks with the heap would change the post-create
  ordering contract, so no migration is approved without a dedicated ordering fixture.
- `lua/entities/ace_scalability/init.lua`: migrated behind the programmatic scheduler enable
  boundary; this branch does not create a server convar. The adapter keeps
  the per-player reverse-order request-time table reference and one-entity-per-engine-tick pacing.
  Native order, recipient, cadence, toggle, and teardown evidence passes in v36; a real
  client-triggered request and packet-delivery path plus actual-disconnect cancellation remain open.
- `lua/entities/ace_scalability/init.lua:147` `timer.RepsLeft` is part of that preserved timer
  fallback's repetition accounting and is included in the migrated adapter evidence; it is not an
  independent callback surface.
- `lua/ace/shared/armor/era.lua:105` `timer.Exists` guards a physics-critical ERA global reset timer;
  it remains blocked with the adjacent ERA scheduling call rather than being routed through the heap.
- `lua/entities/ace_vheat_source/init.lua`: migrated as a low-risk characterization adapter; its
  fixed 100 ms self-only heat update has no traces or target selection. Native v46 first-step parity
  for the first scheduled source, real-entity cadence/removal, and clean scheduler disable/enable
  teardown path pass, but post-enable recurrence, connected Wire packet behavior, and larger-scale
  load scaling remain required before treating it as a performance improvement.
- `lua/entities/ace_gforce_meter/init.lua`: migrated as a low-risk characterization adapter; its
  50 ms Think samples only local position-derived acceleration, applies smoothing/gravity
  compensation, emits five Wire values, and updates its overlay. LuaJIT cadence/fallback/removal/
  reload coverage passes. Native v51 real entities passed stationary first-step parity at
  `GForce=1`, 59.486-61.438 ms survivor cadence, removal isolation, and clean disable/enable
  teardown. Dynamic physics parity, connected Wire packets, and larger-scale load scaling remain
  open; v50 remains diagnostic-only because its first probe used the descriptive Wire name.
- `ace_explosive/init.lua`, `ace_explosive_prebuilt/init.lua`,
  `ace_mine/init.lua`, `ace_slammine/init.lua`, and
  `ace_smokegrenade/init.lua`: `blocked`; delayed removal, arming, and detonation callbacks
  capture entities and must preserve validity, damage, and effect ordering.
- `lua/ace/shared/rounds/roundclusterap.lua`, `roundclusterhe.lua`, `roundclusterheat.lua`,
  and `lua/ace/shared/fuses/e_plunging.lua`: `blocked`; delayed callbacks are part of projectile,
  fuse, or impact sequencing and cannot be detached from the physics event contract.

### Sensor cadence: intentionally engine-bound or blocked

`lua/entities/ace_ecm/init.lua`, `lua/entities/ace_irst/init.lua`,
`lua/entities/ace_rwr_dir/init.lua`, `lua/entities/ace_rwr_sphere/init.lua`,
`lua/entities/ace_searchradar/init.lua`, `lua/entities/ace_sonar/init.lua`,
`lua/entities/ace_trackingradar/init.lua`,
`lua/entities/acf_missileradar/init.lua`,
`lua/entities/ace_gforce_meter/init.lua`, and `lua/entities/acf_opticalcomputer/init.lua` are
`engine-bound` or `blocked` pending a sensor-specific parity contract. Their `NextThink` methods
read live entity state, perform traces/target selection, update Wire outputs, or participate in
entity removal. A heap adapter could reduce callback registration overhead, but no safe route is
approved without independent targeting, lifecycle, output-order, and scan-cost evidence.

### Engine-bound or blocked simulation / lifecycle

`lua/ace/server/sv_acfballistics.lua`, `lua/ace/server/sv_acfbase.lua`,
`lua/ace/server/sv_acfdamage.lua`, `lua/entities/ace_missile/init.lua`,
`lua/entities/acf_ammo/init.lua`, `lua/entities/acf_engine/init.lua`,
`lua/entities/acf_gun/init.lua`, `lua/entities/acf_gearbox/init.lua`,
`lua/entities/acf_rack/init.lua`, `lua/entities/acf_fueltank/init.lua`,
`lua/entities/acf_explosive/init.lua`, `lua/entities/acf_missile_to_rack/init.lua`,
`lua/entities/ace_crewseat_driver/init.lua`, `lua/entities/ace_crewseat_gunner/init.lua`,
`lua/entities/ace_crewseat_loader/init.lua`.

### Client, tools, weapons, compatibility, and initialization: engine-bound or blocked

`lua/ace/client/cl_acemenu_gui.lua`, `lua/ace/client/cl_acfballistics.lua`,
`lua/ace/client/cl_soundbase.lua`, `lua/autorun/client/cl_acfm_menuinject.lua`,
`lua/autorun/client/cl_ace_vignette.lua`, `lua/ace/shared/sh_acfm_roundinject.lua`,
`lua/ace/shared/sh_ace_sound_loader.lua`, `lua/ace/shared/compatibility/cppiCompatibility.lua`,
`lua/ace/shared/armor/du.lua`, `lua/ace/shared/armor/era.lua`,
`lua/weapons/gmod_tool/stools/acearmorprop.lua`, `lua/weapons/gmod_tool/stools/acechaircam.lua`,
`lua/weapons/weapon_ace_base/init.lua`, `lua/weapons/weapon_ace_base/shared.lua`,
`lua/weapons/weapon_ace_antipersonmine/shared.lua`, `lua/weapons/weapon_ace_antitankmine/shared.lua`,
`lua/weapons/weapon_ace_boundingmine/shared.lua`, `lua/weapons/weapon_ace_flaregun/shared.lua`,
`lua/weapons/weapon_ace_grenade/shared.lua`, `lua/weapons/weapon_ace_javelin/shared.lua`,
`lua/weapons/weapon_ace_minedetector/init.lua`, `lua/weapons/weapon_ace_minedetector/shared.lua`,
`lua/weapons/weapon_ace_portablemortar/shared.lua`, `lua/weapons/weapon_ace_slam/shared.lua`,
`lua/weapons/weapon_ace_smokegrenade/shared.lua`, `lua/weapons/weapon_ace_stinger/shared.lua`,
`lua/weapons/weapon_ace_torch/shared.lua`, `lua/weapons/weapon_szcreator/shared.lua`,
`lua/entities/acf_gun/cl_init.lua`, and `lua/entities/ace_slammine/cl_init.lua` are
`engine-bound` or `blocked` by realm, rendering, input, weapon, or lifecycle contracts; they are
not first-server-heap targets.

The discovery set also includes these event-only or compatibility files; they are intentionally
listed even though their matches are not all due-time work: `lua/cfw/extensions/ace_sv.lua`,
`lua/ace/client/cl_acfpermission.lua`, `lua/ace/client/gui/cl_acfsetpermission.lua`,
`lua/ace/client/cl_acfrender.lua`, `lua/autorun/ace_legacy_vehicles.lua`,
`lua/autorun/ace_legacy_tools.lua`, `lua/autorun/ace_legacy_convars.lua`,
`lua/autorun/server/sv_ace_primitive_compat.lua`, `lua/ace/server/permissionmodes/acf_pmode_battle.lua`,
`lua/ace/shared/compatibility/cppiCompatibility.lua`, and the ACE test hook fixtures under
`lua/tests/ace/`. These are `engine-bound` or `blocked` because they are event-only, compatibility,
test, or hook-order surfaces; they are not implicit heap migration targets.

## Completion gates

The generated line-level disposition is complete for the current source scan; a migration batch must
pass the LuaJIT contract/stress tests, `python -m unittest discover -s tests/python`, the regression guard,
and a focused parity/teardown benchmark. A server gate is one bounded launch for the batch; no client
launch is implied. Any changed public-repository head receives a fresh read-only review before push.
