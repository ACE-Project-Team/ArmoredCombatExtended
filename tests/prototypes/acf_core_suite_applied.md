# Prototype: ACF-shaped core validation applied to ACE

This is an executable prototype. The maintainer-facing file is compiled into a native GLuaTest
group before the server job runs. It applies ACF's validation focus to ACE: one readable DSL
inventory covering each core entry point, compiled into one GLuaTest group with a shared fixture,
named normal and refusal cases, delegation or state-transition checks, useful failure reasons, and
cleanup.

## Group: `ACE.Check`

```text
TEST "A valid prop is accepted and classified"
USING a valid prop
WHEN Check on Prop
EXPECT result is "Prop"
EXPECT Prop.ACF exists
CLEANUP automatic
```

```text
TEST "An invalid entity is refused without activation"
USING an invalid prop
WHEN Check on Prop
EXPECT result is false
EXPECT Prop.ACF does not exist
CLEANUP automatic
```

```text
TEST "A stale prop is reactivated before it is accepted"
USING a prop with stale physics state
WHEN Check on Prop
EXPECT result is "Prop"
EXPECT Prop was reactivated
CLEANUP automatic
```

```text
TEST "Ignored and exploding entities are refused"
USING an ignored prop and an exploding prop
WHEN Check on each prop
EXPECT each result is false
CLEANUP automatic
```

```text
TEST "Players and vehicles receive their usable ACE classifications"
USING a test player and a test vehicle
WHEN Check on each entity
EXPECT player result is "Squishy"
EXPECT vehicle result is "Vehicle"
CLEANUP automatic
```

## Group: `ACE.Activate`

```text
TEST "Activation creates ACE state for a valid prop"
USING a fresh prop without ACE state
WHEN Activate on Prop
EXPECT Prop.ACF exists
EXPECT Prop.ACF has armor and health
CLEANUP automatic
```

The important ACF-style follow-up is not a private numeric snapshot. It is proving that activation
creates the state that later checks and damage paths require, then removing the native fixture.

## Group: `ACE.CheckLegal`

```text
TEST "A valid prop passes legality"
USING a legal prop
WHEN CheckLegal on Prop
EXPECT result is legal
CLEANUP automatic
```

```text
TEST "A non-solid prop fails with a useful reason"
USING a non-solid prop
WHEN CheckLegal on Prop
EXPECT result is not legal
EXPECT reason is "Not solid"
CLEANUP automatic
```

```text
TEST "A visually clipped prop fails with a useful reason"
USING a visually clipped prop
WHEN CheckLegal on Prop
EXPECT result is not legal
EXPECT reason is "Has visclip"
CLEANUP automatic
```

## What changed from the earlier ACE draft

The earlier draft centered on `ACE.Points.*` and manufacturing formulas. Those remain valuable
behavior groups, but they are no longer the core validation suite. The core suite now prioritizes
the things ACF validates first:

1. Can ACE recognize a usable entity?
2. Does it initialize required state?
3. Does it refuse invalid or out-of-scope entities safely?
4. Does it reinitialize stale state when needed?
5. Does legality report an understandable reason?
6. Does every native case clean up after itself?

The exact implementation details—entity creation, physics shims, activation spies, hook cleanup,
and removal—remain compiler/runtime responsibilities. Maintainers only name the fixture, action,
and observable result.

## Implemented prototype and next expansion order

```text
Phase 1: complete — native fixtures and ACE.Check / ACE.Activate observations
Phase 2: complete — ACE.CheckLegal reason assertions and state restoration
Phase 3: next — add contraption lifecycle and link/cache invalidation groups
Phase 4: keep points, manufacturing, and ballistics as separate behavior groups
Phase 5: add one player-like headless scenario covering activation through damage
```
