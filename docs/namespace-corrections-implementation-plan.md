# ACE Namespace Corrections — Full Conversion Plan

Status: implementation plan only; no ACE runtime changes in this commit.

Base: `upstream/dev` at `b9ee24d9814d6db87b75cddd84556eea4172fb67`.

Branch: `namespace-corrections`.

## 1. Final contract

The canonical public namespace is exactly one global table:

```lua
ACE = ACE or {}

function ACE.CheckLegal(...) end
function ACE.Ballistics.CreateBullet(...) end

local function ACE_NormalizeDefinition(...) end
```

Rules:

- Public/general-use functions are members of `ACE` or an explicitly owned `ACE.*`
  subsystem table.
- Private helpers are `local function ACE_*` only.
- No canonical global `ACE_*` function assignments.
- No canonical `ACF` table, `ACF.*` table API, or `ACF_*` globals.
- No metatable fallback from `ACE.Name` to `ACE_Name`.
- No global alias installer, global hook replacement, or compatibility auto-discovery.
- The ACE repository itself contains no legacy compatibility bridge. A host integration that
  must migrate independently owns its adapter outside ACE and includes it explicitly.

## 2. Source-derived inventory gate

Before changing runtime code, generate and commit a machine-readable ledger from the exact
branch head. The inventory must include:

```text
global ACE_* declarations and assignments
global ACF_* declarations and assignments
ACE.* and ACF.* reads/writes
local function declarations
all lua/acf paths and acf_* entity directories
ent.ACF / Entity.ACF fields
quoted acf_* entity, tool, net, dupe, and convar identifiers
duplicator registrations and factory callbacks
E2/Starfall host registrations and API names
server/shared/client load sites
tests that assert any removed alias or global
```

Required commands are run from the repository root and must write stable sorted output:

```powershell
rg -n --glob '*.lua' '(^|[^A-Za-z0-9_])(function\s+)?(ACF|ACE)_[A-Za-z0-9_]+' lua tests > artifacts/namespace-corrections/functions.txt
rg -n --glob '*.lua' '\b(ACF|ACE)\.[A-Za-z0-9_]+' lua tests > artifacts/namespace-corrections/table-refs.txt
rg --files lua | Sort-Object > artifacts/namespace-corrections/files.txt
rg -n --glob '*.lua' 'ACF|acf_' lua tests > artifacts/namespace-corrections/legacy-refs.txt
```

The ledger is the authority for completion. A hand-written list of “important” symbols is
not sufficient. Every symbol gets one disposition: `ACE.table`, `ACE.subsystem`, `local
ACE_*`, `serialized migration`, `external consumer`, or `delete`.

## 3. Canonical namespace and collision policy

Do not remove the metatable fallback until all callers and declarations have moved. The
conversion is staged as an atomic pair per subsystem:

1. Define the final `ACE.*` member.
2. Convert every caller and loader reference in that subsystem.
3. Run its realm fixture.
4. Remove the old global declaration and compatibility dependency in the same commit.

Mapping rules:

| Current form | Final form | Rule |
| --- | --- | --- |
| `ACE_CheckLegal` | `ACE.CheckLegal` | Direct public API move. |
| `ACE_Missile_CreateConfigurable` | `ACE.Missile.CreateConfigurable` | Subsystem is chosen from the owning module, not string prefix alone. |
| `ACE_Points_*` | `ACE.Points.*` | One explicit ledger row per symbol; collisions block the wave. |
| `function ACE_Helper` | `local function ACE_Helper` | Private helper only; no global export. |
| `ACF_*`, `ACF.*` | `ACE.*` or `local ACE_*` | No compatibility alias in the ACE repository. |
| `ent.ACF` | `ent.ACE` | Canonical entity state migration; serialized import is versioned separately. |

If two old globals map to one target, create an explicit resolver in the ledger and update
all callers; never let Lua assignment order decide which implementation wins.

## 4. Implementation phases

### Phase 0 — inventory and safety harness

Files:

- `tools/namespace_corrections_inventory.py`
- `tests/python/test_namespace_corrections_inventory.py`
- `artifacts/namespace-corrections/*`

Create the source-derived ledger, caller counts, realm matrix, collision report, and
baseline test manifest. Add static checks rejecting top-level `function ACE_*`,
`ACE_* = function`, `ACF_*`, `ACF =`, `ACF.*`, ACE metatable fallback, `_G` alias writes,
and global `hook.Call` replacement in canonical ACE paths.

Rollback: delete only the new inventory tool and artifacts; runtime is untouched.

### Phase 1 — table foundation and loader order

Files:

- `lua/autorun/acf_globals.lua` → final ACE bootstrap location
- `lua/acf/shared/sh_ace_loader.lua` → `lua/ace/core/sh_loader.lua`
- all direct loader callers found by the ledger

Create the canonical `ACE` table and subsystem tables. Convert declarations and callers
before removing fallback behavior. Then delete:

- `ACF = ACF or {}`;
- ACE-to-`ACE_*` metatable fallback;
- ACF-to-ACE metatable proxy;
- `ACE.LegacyCompatibility`;
- `ACE_InstallLegacyGlobal`;
- `ACE_RunLegacyHook`;
- delayed compatibility-removal hooks.

Rollback: revert the single foundation commit if any realm fails to load; do not re-add a
partial fallback. The previous upstream commit remains the known-good reference.

### Phase 2 — public function conversion

Process the ledger by dependency order:

1. shared primitives, materials, timing, and validation;
2. ballistics and damage;
3. points/manufacturing/legality;
4. rounds, guns, racks, ammo, engines, gearboxes, fuel tanks;
5. missiles, guidance, sensors, crew, effects, and UI;
6. tools and external integration entry points.

For each symbol, move the implementation to `ACE.*`, update every caller, add LDoc for
public members, and make private helpers `local function ACE_*`. Remove reverse exports
such as `ACE_Points_* = ACE.Points.*` after all consumers move.

Explicit collision checkpoints include `ACE_HeatFromEngine`, `ACE_TrackRadarGUICreate`,
`ACE_RoundBaseGunpowder`, and `ACE_ChatMessageGlobal`.

Rollback: one commit per subsystem; a failing subsystem reverts independently while prior
subsystems remain table-based.

### Phase 3 — paths, entities, and runtime state

Move canonical implementation paths from `lua/acf/**` to `lua/ace/**` in dependency waves.
Rename canonical entity directories and registrations from `acf_*` to `ace_*`, then update:

- `scripted_ents.Register` names;
- tool registrations and spawn-menu references;
- CFW registrations;
- Wire and Starfall type checks;
- effects, sounds, and net receivers;
- duplicator factories and modifier keys;
- all server/shared/client includes.

Convert canonical entity state from `ent.ACF` to `ent.ACE`. Dupe imports use a versioned,
explicit migration function at the dupe boundary; they do not recreate `ent.ACF` or an ACF
global. Saved identifiers that must break are listed in the release notes and tested as
forward-only migrations.

Rollback: each entity family has a path/registration commit and a dupe migration commit.
Never mix a path move, state rename, and balance change. A failed family rolls back its
registration and import commits together.

### Phase 4 — remove process-wide legacy bridges

Delete or rewrite these upstream files as part of the complete ACE conversion:

- `lua/autorun/ace_legacy_tools.lua`: remove old tool modes and the `hook.Call` replacement;
  canonical tools are ACE-only.
- `lua/autorun/ace_legacy_vehicles.lua`: remove vehicle-registry metatable interception;
  canonical registry keys are ACE-only.
- `lua/autorun/ace_legacy_convars.lua`: remove old/new synchronization; all convars are
  ACE-named.
- the global alias block in `lua/autorun/acf_globals.lua`;
- loader-time `ACE_InstallLegacyGlobal` calls in `sh_ace_loader.lua`.

E2 and Starfall integrations are converted to ACE API names at their host registration
boundaries. Their host-required file paths may remain only when Wire/Starfall discovery
requires them; their contents must use `ACE.*` and `ent.ACE`, with no ACF global fallback.

Rollback: bridge removal is a deliberate breaking boundary. If an external integration is
not ready, stop the phase and fix that integration; do not restore a process-wide alias.

### Phase 5 — tests and documentation conversion

Rewrite tests that currently require removed behavior:

- `tests/python/test_namespace_refactor.py` — require no metatable fallback and require
  `ACE.*` public members.
- `tests/python/test_legacy_extension_compat.py` — replace legacy-global assertions with
  fail-closed assertions.
- `tests/lua/ace_legacy_compatibility_luajit_selftest.lua` — replace with ACE-only boot and
  no-global-surface self-tests.
- native ACE tests that patch `_G.ACE_*` — patch `ACE.*` or local helpers instead.
- `lua/tests/ace/spall_rubber.lua` and all other fixtures — remove global function setup.

Add fixtures for shared/server/client loading, entity activation, points/legality, rounds,
ballistics, tools, convars, E2, Starfall, effects, and dupe import. Each fixture asserts
that an ACE-only process works without any adapter or compatibility global.

## 5. Required migration matrices

Before Phase 2 is marked complete, commit these artifacts:

- `docs/namespace-corrections/function-ledger.csv` — every public/private function;
- `docs/namespace-corrections/path-ledger.csv` — old path, new path, loader, realm;
- `docs/namespace-corrections/entity-ledger.csv` — old class/state, new class/state, dupe;
- `docs/namespace-corrections/integration-ledger.csv` — E2, Starfall, Wire, tools, CFW;
- `docs/namespace-corrections/test-ledger.csv` — old assertion, new assertion, fixture;
- `docs/namespace-corrections/rollback-ledger.csv` — commit, dependency, failure trigger,
  reversal command, known-good reference.

No phase may claim complete while a ledger row is unclassified.

## 6. Validation gates

Run in this order:

1. inventory and collision checks;
2. Python test suite;
3. LuaJIT syntax and self-tests;
4. GLuaLint;
5. `git diff --check`;
6. GMod regression guard;
7. native shared/server/client ACE fixtures;
8. one final headless server run for the branch;
9. client/tool/UI validation because this conversion changes client convars, tool modes,
   GUI functions, effects, and entity registrations.

The branch must remain unpushed until a read-only review passes the exact final diff.

## 7. Completion definition

The conversion is complete only when:

- the only canonical public global is `ACE`;
- every public/general-use function is reachable through `ACE.*`;
- every private helper is `local function ACE_*`;
- no top-level `ACE_*` or `ACF_*` functions remain in canonical ACE code;
- no `ACF` table or `ent.ACF` canonical state remains;
- canonical paths, entity classes, tools, convars, effects, and registrations are ACE-named;
- E2, Starfall, Wire, CFW, and dupe paths use explicit ACE contracts;
- all ledgers are complete;
- all realm and integration fixtures pass;
- the final review passes; and
- the branch is still local and unpushed.
