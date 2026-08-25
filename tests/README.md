# ACE tests

The goal of these tests is simple: make sure ACE still works for normal players and
does not fail outside its intended scope. A test should describe a useful player-facing
thing, not preserve an implementation detail just because it is easy to assert.

## Where tests run

Use the smallest runner that can prove the behavior:

| Runner | Use it for | Do not use it for |
| --- | --- | --- |
| Python | file layout, definitions, manifests, and static safety checks | pretending to run GMod |
| LuaJIT | pure calculations, serializers, and deterministic state transitions | physics, hooks, timers, or entities |
| Native GLuaTest | entities, registries, hooks, links, dupes, timers, and GMod APIs | testing a formula that needs no server |
| Headless | player-like combat and contraption scenarios | a small unit check that can run offline |

## What kind of check is this?

The check type describes the question. The runner describes where the answer can be
observed. Pick one primary type for every catalog entry; add tags only for useful search
words. Do not make a Python test behave like a fake GMod server just to use a particular type.

| Type | Use it when you want to prove | Small example |
| --- | --- | --- |
| `smoke` | ACE loads and a basic surface exists | “The addon starts and the main registry is present.” |
| `static` | a repository rule is true without running GMod | “No two files accidentally declare the same ACE name.” |
| `registry` | content is defined, unique, and discoverable | “Every ammo family has usable IDs.” |
| `behavior` | an input produces an observable result | “Changing a setting changes the calculated value.” |
| `compatibility` | an old public name or API still works | “The legacy tool alias forwards to the current tool.” |
| `lifecycle` | create/use/remove/cleanup works in order | “An entity can spawn, activate, and remove cleanly.” |
| `regression` | a small test prevents a previously fixed bug returning | “The old self-fire case stays blocked.” |
| `system` | several real systems work together like a player uses them | “Fire, impact, damage, and cleanup complete.” |
| `performance` | a bounded operation finishes without runaway work | “A representative fire-rate sample emits its artifact.” |

These are categories, not extra test frameworks. A regression can be a LuaJIT behavior
check, a native lifecycle check, or a headless system check. The catalog records the primary
type in `check_type` so people can find the right example quickly.

### The smallest useful examples

Static or registry check in Python:

```python
def test_registry_has_every_expected_family(self):
    for family in EXPECTED_FAMILIES:
        with self.subTest(family=family):
            self.assertTrue(definitions[family], f"{family} has no definitions")
```

Behavior check using the shared failure format:

```python
if observed != expected:
    self.fail(scenario_failure(
        scenario,
        "calculate points",
        f"points = {expected}",
        f"points = {observed}",
    ))
```

For native or headless tests, keep the same shape even though the setup differs:

```text
Given: a normal ACE entity or fixture
When:  the player-facing action happens
Then:  the useful result occurs and cleanup completes
```

Start with the smallest truthful type. If the test only checks a file rule, use `static`.
If it checks a real registry, use `registry`. If it needs entities, hooks, timers, physics,
or dependency behavior, move it to native or headless instead of building a fragile Python
simulation.

The headless scaffold is intentionally a dry run unless an explicit server command is supplied:

```text
python tests/run_headless_scenarios.py --srcds-command <server command and arguments>
```

The runner passes `ACE_HEADLESS_RUN_DIR` and `ACE_HEADLESS_MANIFEST` to that command. The scenario
adapter must write `boot.txt` when it starts and `done.txt` when the selected scenarios finish; the
runner then fails on a missing sentinel or timeout. CI uses `--dry-run` until a scenario adapter is
available.

For the standard local dedicated-server install, use `--use-local-srcds`. It discovers
`srcds_win64.exe` or `srcds.exe` from `SRCDS_PATH`, `GMODDS_SRCDS`, or
`%USERPROFILE%/gmodds/server`, and starts it from its own server directory. Use
`--srcds-command` for an explicit executable or custom launch arguments.

### Core-function checks: the ACF pattern to copy

For a core function, organize one small test group around that function instead of writing
one giant test for a whole subsystem. ACF’s tests follow this useful shape: a shared fixture,
then named cases for the normal result, invalid input, boundary/early-return behavior, and
important delegation or side effects, with cleanup after each case.

```text
Group: ACE.Points.Calculate
Given: a small known input fixture

Case: returns the normal result
Case: rejects missing or invalid input
Case: handles the boundary value
Case: calls the required invalidation/update hook

After each case: restore stubs, hooks, tables, and temporary state
```

Use `behavior` for these cases. The case name should say what a human can observe, such as
“returns zero for an invalid entity” or “invalidates points after linked ammo changes.” Keep
each case focused on one promise. If a function has ten independent promises, ten short named
cases are easier to understand than one loop-driven matrix with an opaque failure.

Reference: [ACF’s core validation tests](https://github.com/ACF-Team/ACF-3/tree/master/lua/tests/acf/core/validation_sv)
and [ballistics function tests](https://github.com/ACF-Team/ACF-3/tree/master/lua/tests/acf/ballistics/ballistics_sv).

### Native function checks: the GLuaTest pattern to copy

When a function needs real GMod entities, hooks, timers, physics, or load order, use a
GLuaTest group instead of a Python imitation. GLuaTest’s useful authoring shape is:

- one file per function or small module;
- a `groupName` that says what is being tested;
- `beforeEach` state for a fresh fixture;
- short named `cases` with expectations focused on one promise;
- `afterEach` cleanup for hooks, stubs, entities, and shared tables;
- `async = true` only when the case genuinely waits on a timer, hook, or callback.

Use explicit expectations such as “returns false for an invalid entity” and “does not call
Activate.” This makes the test output readable without requiring the reader to understand
the runner. The copyable starting point is
`tests/templates/gluatest_core_function.lua`.

For ordinary result checks, the intended authoring experience is just:

```lua
returns("returns the normal result", function(State)
    return ACE.Area.Function(State.Subject)
end, ExpectedValue)
```

The framework wrapper owns the test-case table and equality assertion. Contributors provide
the callback that performs the action and the result that should come back. Only unusual checks—
such as “this callback must not run”—need a more explicit case body.

Reference: [GLuaTest’s test-group and test-case guide](https://github.com/CFC-Servers/GLuaTest#writing-tests).

### Readable comparison checks

Exact equality is only one kind of result. The core-function template provides a small,
deliberately limited vocabulary for relational behavior:

```lua
greaterThan("stronger armor costs more", function(State)
    return ACE.Points.ArmorProp(State.StrongerArmor, State.Health)
end, State.WeakerCost)

lessThan("a slower rack costs less", function(State)
    return ACE.Points.RackCost(State.SlowerReload, State.Tubes, State.Score)
end, State.FasterCost)

changesWhen("changing guidance changes the score", function(State)
    return ACE.Points.RoundScore(State.Round)
end, function(State)
    State.Round.guidance = "Beam_Riding"
    return ACE.Points.RoundScore(State.Round)
end)
```

Use the weakest truthful comparison. Prefer `greater than` or `less than` when the contract is
directional. Use `changes when` only when the contract is specifically that an input must affect
the result. Use exact equality only when the value itself is stable and intentional.

### Native fixtures

Native tests should use real entities and a fixture-owned cleanup list. The prototype helper is
`tests/templates/native_fixtures.lua`:

```lua
local Fixtures = include("tests/templates/native_fixtures.lua")

beforeEach = function(State)
    State.Source = Fixtures.Entity(State, "acf_ammo")
    State.Target = Fixtures.Entity(State, "prop_physics")
end

afterEach = function(State)
    Fixtures.Cleanup(State)
end
```

Contraptions intentionally take a `create` callback. The fixture layer must use the real CFW
construction path for the test environment; it must not invent a table that merely resembles a
contraption. Once the shared ACE native adapter has a pinned construction entry point, that
callback can be replaced with a named fixture such as `Fixtures.Contraption(State, Tank)`, while
the test cases remain unchanged.

### Snapshot policy: what should be stable

Snapshots are correct only when they protect a deliberate compatibility contract. Before adding
one, classify the observed value:

| Value | Snapshot? | Correct assertion |
| --- | --- | --- |
| Public serialized schema or network ID | Yes | Exact value plus migration/compatibility reason |
| Stable published round/material identifier | Yes | Exact identifier and required shape |
| A pure formula's invariant relationship | Usually no | Compare direction, bounds, or conservation rule |
| A calculated armor/points total | Usually no | Check monotonicity, positivity, and player-facing invariants |
| Physics-derived entity value | Rarely | Use tolerance and a fixed fixture/environment |
| Full table containing incidental fields | No | Assert only the fields that are part of the contract |

When an exact snapshot is justified, make it reproducible and reviewable:

```text
SNAPSHOT "round schema remains compatible"
USING frozen serialized round fixture version 3
WHEN DecodeRound
EXPECT exact public fields and network identifiers
IGNORE runtime handles, ordering, timestamps, and derived cache fields
RECORD source fixture, units, rounding rule, and compatibility reason
```

Correct snapshots should therefore be:

1. based on a named fixture, not whatever entity happened to be spawned;
2. limited to public or intentionally frozen fields;
3. normalized for ordering, units, and numeric precision;
4. compared with an explicit tolerance when floating-point output is the contract;
5. updated only alongside a written behavior change, never merely to make CI green.

The ACF-style cube activation snapshot is useful as a characterization probe, but it should not
become ACE's default points test. A formula change should first be reviewed as a behavior change;
only a deliberately promised compatibility value should receive an exact snapshot.

### Practical snapshot examples

Public schema snapshot with an allowlist:

```python
spec = SnapshotSpec(
    name="round schema remains compatible",
    fields=("Type", "NetID", "Caliber", "Guidance"),
)

observed = get_round_schema()
differences = compare_snapshot(expected_schema, observed, spec)
if differences:
    self.fail(snapshot_failure(spec, differences))
```

Calculated value with tolerance:

```python
spec = SnapshotSpec(
    name="representative armor readout",
    fields=("Armor", "Health"),
    tolerances={"Armor": 0.01, "Health": 0.1},
)
```

The helper is in `tests/python/ace_test_support/snapshots.py`. It projects only the declared
fields, sorts nested mapping keys, rounds floats to the declared precision, and reports only the
changed fields. A runtime entity handle or cache field can exist in the observed result without
ever entering the snapshot.

### Interpreted maintainer tests

The intended final authoring surface is the prototype format in
`tests/prototypes/acf_core_suite_applied.ace_test`. It is deliberately not Lua. A maintainer names
fixtures, actions, result names, expectations, changes, and cleanup; the interpreter resolves those
names through ACE's fixture/action/observation registries and generates the native GLuaTest case.

```text
new Test "Guided ammunition costs more"
scenario ace.native.example.guided_cost
uses unguided AP round as UnguidedRound
uses guided AP round as GuidedRound
do ACE.Manufacturing.RoundCost on UnguidedRound as UnguidedCost
do ACE.Manufacturing.RoundCost on GuidedRound as GuidedCost
expect GuidedCost is greater than UnguidedCost
cleanup automatic
```

The maintainer does not write `beforeEach`, `ents.Create`, `expect(...)`, stubs, hooks, or entity
removal. Those are compiler/runtime responsibilities. `tests/ace_test_compiler.py` parses the DSL,
rejects unknown fixtures and actions, and emits a generated GLuaTest group. Actions are registered
in `tests/prototypes/ace_test_action_registry.json`; adding a new ACE function there makes it
available to the same DSL template without teaching maintainers another test language. The
generated group
uses `lua/ace/test_dsl_runtime.lua` for native fixtures, actions, observations, assertions, and
cleanup. The generated Lua is ignored and is recreated by the native preparation workflow.

The smallest useful native test is:

```text
new Test "A valid prop is accepted"
scenario ace.native.example.valid_prop
requires native
uses valid_prop as Prop
do ACE.Check on Prop as EntityType
expect EntityType is "Prop"
cleanup automatic
```

To extend the framework, its test-framework maintainer adds a fixture to
`tests/prototypes/ace_core_fixture_registry.json`, register the callable action in
`tests/prototypes/ace_test_action_registry.json`, and express the observable result with `expect`.
The runtime resolves registered dotted globals (for example `ACE.Manufacturing.RoundCost`) and
passes the named fixture arguments to them. Fixture definitions are also emitted into the generated
group, so a native entity fixture's class, model, invalid-physics state, clipping, solidity, and
cleanup behavior come from the registry rather than a second hard-coded list. Run
`python tests/ace_test_compiler.py` locally to see the
generated group. CI compiles it again before the GLuaTest job, so maintainers never need to edit
the generated Lua.

Once a fixture and action are registered, ordinary ACE maintainers only edit the `.ace_test` DSL;
registry/runtime changes are framework work, not per-test authoring.

The runner is part of the contract. A passing test must not merely load a file: it must
reach its useful check, fail on a Lua error, and clean up anything it creates.

### ACF-shaped core validation

The core suite now follows ACF's validation focus rather than starting with formulas. Each ACE
entry point gets named cases for normal acceptance, refusal or invalid state, important delegation,
useful failure reasons, and automatic cleanup.

The current prototype covers:

- `ACE.Check`: valid props, missing/invalid physics, ignored classes, exploding entities, stale
  state, and entity classification for props, players, and vehicles;
- `ACE.Activate`: activation of a native prop and cleanup of the resulting ACE state;
- `ACE.CheckLegal`: valid props, non-solid props, and visual clipping with readable reasons.

This is a real test inventory draft executed through the generated GLuaTest group. Point and
manufacturing tests can remain as
separate behavior groups, but they are no longer the core validation suite.

## Naming a scenario

Every new or migrated scenario gets a stable ID in
`tests/fixtures/scenario_catalog.json`:

`ace.<layer>.<area>.<result>`

Use a short plain-English title, then write the reason in one sentence. A reader should
be able to answer “what player-facing problem does this protect?” without reading Lua.
The expected outcome states what a passing run must visibly prove.
The catalog also records the runner, dependencies, timeout, and whether the scenario is
implemented or only planned. Planned entries are allowed so the long-term coverage is
visible, but they do not count as passing tests.

## Adding or changing a test

1. Start with the player action or failure you want to prevent.
2. Choose the smallest truthful runner from the table above.
3. Add a catalog entry with a stable ID, title, reason, and expected outcome for catalog-level
   scenarios; native DSL cases additionally declare their unique per-case `scenario` ID immediately
   below `new Test`.
4. Choose one `check_type` from the table above and the smallest truthful runner.
5. Keep the test setup obvious; use a named step such as “create round” or “remove entity”.
6. On failure, report the scenario ID, failed step, expected result, and observed result.
7. Run the offline checks, the relevant LuaJIT/native/headless runner, and `git diff --check`.

The catalog is the framework’s first migration step. The legacy namespace-refactor suite remains
as compatibility coverage while new behavior is added through the readable scenario and DSL
templates. Future refactors should map each useful guarantee to a readable scenario before
changing or deleting coverage.
