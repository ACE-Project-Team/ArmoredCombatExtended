# Contributing to ACE

ACE is maintained by a small volunteer team, so keep pull requests easy to review.

- Discord: https://discord.gg/Y8aEYU6 — discuss non-trivial changes first
- Wiki: https://acegmod.com/wiki
- Issues: https://github.com/ACE-Project-Team/ArmoredCombatExtended/issues

## Workflow

- Branch off `dev` and open PRs against `dev` (not `master`).
- One issue, or a closely related set, per PR. Split unrelated work.
- Say what changed, why, and how you verified it — in your own words.
- Gameplay changes (damage, penetration, mobility, cost) need before/after numbers or a repro.

## Code style

Follow the [ACE style guide](https://acegmod.com/wiki/general-coding-and-style-guidelines) and
the [CFC GLua guidelines](https://github.com/CFC-Servers/cfc_glua_style_guidelines) it builds
on. Lint rules live in [`.glualint.json`](.glualint.json) and are enforced by CI. Use LF line
endings and keep diffs free of unrelated whitespace changes.

## Documenting code (LDoc)

Public functions you add or change (on `ACE.` / `ACF.`, or entity/SWEP methods) get an
[LDoc](https://stevedonovan.github.io/ldoc/) `---` doc-comment:

```lua
--- Computes kinetic penetration for a projectile impact.
-- @param velocity number Impact speed in source units/s.
-- @param mass number Projectile mass in kg.
-- @return number Penetration depth in mm RHA.
function ACE.CalcPenetration( velocity, mass )
```

Summary line, then `@param name type description` per argument and `@return type description`.
Keep annotations truthful; document what you touch rather than backfilling everything.

## Testing

| What | Command / where |
|------|-----------------|
| Lint (glualint) | CI `.github/workflows/glualint.yml`, config `.glualint.json` |
| LuaJIT self-tests | `python tests/run_luajit_tests.py` |
| Native GMod tests | GLuaTest specs in `lua/tests/ace/*.lua`, run in CI on a real server |

Prefer adding a GLuaTest spec in `lua/tests/ace/` over a pure-Python test when demonstrating
in-engine behavior.

## AI-assisted Contributions

AI tools may be used as coding tools, but they must not replace the author's own understanding or judgment.

Authors must:

- Be honest and disclose when AI tools were used.
- Use AI only to help with coding. PR text and replies must be written by the author; maintainers need to be talking to the contributor, not an AI toolchain.
- Understand the submitted code well enough to explain it, justify it, audit it for side effects, and make requested changes themselves.
- Make requested changes that actually fix the problem, rather than blindly resubmitting tool output.
- Keep each contribution focused on one issue or a closely related set of issues per PR. Large all-in-one PRs are not accepted when AI is doing the coding.

AI use does not relax ACE's style, cleanliness, or review requirements. Slop is slop regardless of how it was made.

Maintainers are not LLM code auditors. Breaking these rules, or giving maintainers reason to believe they are being broken, may result in a repository ban.

If you develop with an agent, see [`AGENTS.md`](AGENTS.md).
