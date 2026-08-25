# ACE Damage Detonation Effect Scheduler Gate

Date: 2026-08-23

Scope: the delayed `ACE_Scaled_Detonation` presentation callback in `sv_acfdamage.lua` and its
opt-in `ACE.DamageDetonationEffect` adapter. The authoritative `ACE.HE` call remains synchronous.
This gate does not claim native effect delivery or server-lag results.

## Recorded results

| Gate | Command | Result |
| --- | --- | --- |
| Integration and manifest unit tests | `python -m unittest discover -s tests/python -p 'test_scheduler_manifest.py' -q` | 7 tests passed |
| Strict source inventory | `python tools/ace_scheduler_manifest.py --strict` | 239 rows; 99 migrated, 87 engine-bound, 55 blocked, 0 pending |
| Functional LuaJIT suite | thirteen `tests/lua/*_scheduler_luajit_selftest.lua` fixtures, including the flare fixture | all passed |
| Heap stress | `luajit tests/lua/ace_scheduler_luajit_stress_selftest.lua . 10000 100` | passed |
| Regression guard | `gmod_regression_guard.py --repo . --base upstream/armor-durability-layering` | PASS (55 files) |
| Diff check | `git diff --check` | passed cleanly |

The focused LuaJIT fixture covers fallback, independent heap records, timing, argument
preservation, adapter reload, and disable fallback. The Python integration assertion verifies
that `ACE.HE` remains before the optional scheduler call and that the original timer/effect
fallback remains present. The core scheduler fixture additionally verifies sorted adapter-key
activation for same-due nodes. No srcds launch was used.
