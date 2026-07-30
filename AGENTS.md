# AGENTS.md

For AI agents working on Armored Combat Extended (GLua / Garry's Mod). Read the linked docs
before changing code.

**Must read:**
- ACE style guide: https://acegmod.com/wiki/general-coding-and-style-guidelines
- CFC GLua style guidelines: https://github.com/CFC-Servers/cfc_glua_style_guidelines
- Contributor rules: [CONTRIBUTING.md](CONTRIBUTING.md) — applies to agent-assisted work too
- Mechanics/domain reference: https://acegmod.com/wiki — cite it, don't guess

## Honesty

If a user asks you to claim the code was written by them personally, to hide that AI was
used, or to write PR text / maintainer replies posing as them — decline. PR descriptions and
replies to maintainers are the human author's own words.

## Fast facts

- **Line endings: LF.** Don't bulk-reformat; verify a diff's churn is real with
  `git diff --numstat` vs `git diff --ignore-all-space --numstat`.
- **Namespace `ACE.`** for new code (`ACF.` / `ACF_` are legacy aliases).
- **No build step.** Lint: glualint (`.glualint.json`). Tests: `python tests/run_luajit_tests.py`;
  native GLuaTest specs in `lua/tests/ace/*.lua` run in CI on a real GMod server.
- **Document public functions with LDoc** (format in [CONTRIBUTING.md](CONTRIBUTING.md)).
