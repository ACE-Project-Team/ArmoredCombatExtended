---
title: ACE Namespace Corrections Source Inventory
kind: workflow
tags: [gmod, ace, namespace]
updated: 2026-08-21
---

# ACE Namespace Corrections Source Inventory

The source-derived inventory is the starting checklist for namespace-corrections validation. It
covers every Lua file under `lua/` and `tests/`, every named function definition or function assignment, every
anonymous function expression, and every literal or tokenized `hook.Add`, `hook.Remove`,
`hook.Run`, and `hook.Call` operation found by the inventory scanner.

The current snapshot contains 467 Lua files, 2,336 named functions, 304 anonymous function
expressions, 2,640 total function rows, and 158 hook operations. The JSON is the machine-readable source; the CSV
files are review-friendly projections. Locations are source line numbers and realm is a static
path-based classification, so dynamic registration and runtime reachability remain separate
runtime checks.

The inventory also records remaining `ACE_*` flat-token references separately from function
definitions, so namespace finalization can distinguish intentional serialized/network names from
live callers that still need conversion.

Generated artifacts:

- `artifacts/namespace-corrections/inventory.json` — complete source inventory and references.
- `artifacts/namespace-corrections/functions.csv` — one row per named or anonymous function.
- `artifacts/namespace-corrections/hooks.csv` — one row per hook operation.
- `artifacts/namespace-corrections/runtime-probe.json` — last provenance-bound dedicated-server evidence
  for public ACE functions, all 36 registered server hooks, all 9 legacy server entity classes, tank-part
  activation, CFW tank contraption lifecycle, firing, and native GLuaTest results. The current run
  records 101/101 checks, including six ACE-named aliases and canonical entity state parity, 6/6
  factory spawns with exact class/ID mappings, 35/35 native tests across 9 groups, one bullet
  creation and removal, and zero ACE/external console error lines. Factory
  ownership uses explicit headless-only CPPI/UniqueID shims because the dedicated server has no
  player or CPPI addon; this does not replace the client/player-backed validation below. Rebind
  these artifacts after the current state/entity migration wave; the current capture passes the
  expanded 101-check contract and is bound to the current source manifest. Inventory/ledger-only
  changes made after the capture are not treated as runtime parity evidence.
- `artifacts/namespace-corrections/runtime-console.log` and
  `artifacts/namespace-corrections/runtime-probe-raw.json` — retained raw dedicated-server
  evidence used by the provenance generator.
- `artifacts/namespace-corrections/client-probe.json` — provenance-bound isolated live-client
  evidence from `gmod.exe -condebug -noworkshop +map gm_construct`: the current run passed 32/32
  client checks, covering all 5 client ACE functions, 9 client hook registrations, 15 legacy and
  ACE-named entity registrations, with `ACF-Extras` active. The artifact records three unrelated
  external material/Starfall errors and zero ACE errors.
- `artifacts/namespace-corrections/client-console.log` — retained console excerpt beginning at
  the latest ACE load marker; the artifact generator records its hash, reports zero ACE error
  lines, and preserves three unrelated external-addon error lines for transparency.
- `artifacts/namespace-corrections/client-probe-raw.json` — exact raw file written by the live
  probe before provenance augmentation.
- `tests/client/ace_namespace_client_probe.lua` — manual live-client probe for client-only ACE
  functions, client hook registration, and client scripted-entity registration. It is not an
  autorun production file; the temporary installation is removed after each run.
- `tools/namespace_corrections_client_artifact.py` — reproducibly binds the raw client result to
  the source manifest, worktree diff, command line, and retained console excerpt.
- `tools/namespace_corrections_runtime_artifact.py` — equivalent provenance binder for the
  dedicated-server probe.
- `docs/namespace-corrections/*.csv` — generated function, path, entity, integration, test, and
  rollback ledgers. Rows are explicit and currently marked `review-required`; their existence
  closes the missing-ledger gap but does not claim that the full conversion is complete.

Regenerate with:

```text
python tools/namespace_corrections_inventory.py --repo . \
  --output artifacts/namespace-corrections/inventory.json \
  --csv-dir artifacts/namespace-corrections
```

This inventory is intentionally static and exhaustive over the scanner's supported Lua syntax,
including same-line named/anonymous functions, embedded hook calls, quoted strings, and all Lua
long-bracket string/comment delimiters. It is a source checklist, not proof that every symbol is
runtime-reachable; the headless gate must still verify that the public ACE table, registered hooks,
entity classes, and representative functions exist at runtime and execute without errors.

## Sources

- `tools/namespace_corrections_inventory.py` — scanner and artifact generator.
- `tests/python/test_namespace_corrections_inventory.py` — deterministic inventory regression tests.
