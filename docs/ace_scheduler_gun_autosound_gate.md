# ACE Gun Auto-Sound Scheduler Gate

Date: 2026-08-23

Scope: `ACE.GunAutoSound`, `ACE.AmmoCookoffFlash`, and their `acf_gun`/`acf_ammo` integrations.
This is an offline behavioral gate; it does not claim native sound/effect-delivery or server-lag
results.

## Commands and results

| Gate | Command | Result |
| --- | --- | --- |
| Manifest unit tests | `python -m unittest discover -s tests/python -p 'test_scheduler_manifest.py' -q` | 7 tests passed |
| Strict source inventory | `python tools/ace_scheduler_manifest.py --strict` | 239 rows; 99 migrated, 87 engine-bound, 55 blocked, 0 pending |
| Functional LuaJIT suite | thirteen `tests/lua/*_scheduler_luajit_selftest.lua` fixtures, including the gun, ammo, and flare fixtures | all passed |
| Heap stress | `luajit tests/lua/ace_scheduler_luajit_stress_selftest.lua . 10000 100` | passed |
| Regression guard | `gmod_regression_guard.py --repo .` | PASS (7 files) |
| Regression guard, submitted surface | `gmod_regression_guard.py --repo . --base upstream/armor-durability-layering` | PASS (55 files) |
| Diff check | `git diff --check` | passed cleanly |

The focused fixtures cover disabled timer fallback, independent delayed records, dynamic position
lookup, sound/effect argument preservation, invalid-entity rejection, invalidation followed by
module reload cleanup, post-reload scheduling, and disable restoration. No srcds launch was used.
