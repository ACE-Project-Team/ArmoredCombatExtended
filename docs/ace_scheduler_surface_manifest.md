# ACE Scheduler Surface Manifest

This file records the scheduler boundary. The complete line-level inventory is generated from
the current source by `tools/ace_scheduler_manifest.py`; it is intentionally kept in code so
line changes fail closed in CI.

Run:

```text
python tools/ace_scheduler_manifest.py --strict
```

The current inventory contains 239 scheduling rows:

- 99 migrated through the opt-in ACE heap;
- 87 engine-bound because timing or ownership belongs to GMod, physics, lifecycle, or presentation;
- 55 blocked pending a dedicated behavior contract;
- 0 pending dispositions.

The heap orders work by `(due time, priority, insertion sequence)`. Existing adapters use priority
zero, preserving FIFO order for equal due times. Every migrated adapter retains its original timer
or engine fallback when the scheduler is disabled or unavailable. Authoritative damage, physics,
entity lifecycle, input, and client presentation callbacks remain outside the heap until their
ordering and compatibility contracts are independently proven.

The manifest is a source-coverage and ownership contract, not a claim that the mod-wide migration
is complete or that controlled adapter timings represent universal server-lag thresholds.
