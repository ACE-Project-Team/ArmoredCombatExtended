#!/usr/bin/env bash
set -euo pipefail

# Compile the only maintainer-authored test surface into a GLuaTest group before
# the reusable native runner starts GMod. The generated Lua is ignored and never
# edited by maintainers.
mounted_project="${GITHUB_WORKSPACE}/garrysmod_override/addons/project"
mkdir --parents "$mounted_project/lua/tests/ace"
python3 project/tests/ace_test_compiler.py \
	project/tests/prototypes/acf_core_suite_applied.ace_test \
	--registry project/tests/prototypes/ace_core_fixture_registry.json \
	--actions project/tests/prototypes/ace_test_action_registry.json \
	--output "$mounted_project/lua/tests/ace/generated_core_validation.lua"

# GLuaTest's requirements file accepts branches, not immutable commit IDs. Clone
# the exact reviewed dependency commits into its override tree instead, so the
# native job does not silently change when a dependency's default branch moves.
override_root="${GITHUB_WORKSPACE}/garrysmod_override/addons"
mkdir --parents "$override_root"

# The reusable workflow's custom-overrides input is evaluated outside the caller's
# workspace context. Copy the guard from the checked-out project explicitly instead.
guard_root="${GITHUB_WORKSPACE}/garrysmod_override/lua/autorun"
mkdir --parents "$guard_root"
cp "${GITHUB_WORKSPACE}/project/tests/gluatest_overrides/lua/autorun/ace_gluatest_guard.lua" \
	"${guard_root}/ace_gluatest_guard.lua"

clone_at_commit() {
	local repository="$1"
	local commit="$2"
	local addon_name="$3"
	local destination="$override_root/$addon_name"

	rm --recursive --force "$destination"
	git clone --quiet --no-checkout --depth 1 "$repository" "$destination"
	git -C "$destination" fetch --quiet --depth 1 origin "$commit"
	git -C "$destination" checkout --quiet --detach "$commit"
}

clone_at_commit "https://github.com/ACF-Team/CFW.git" \
	"5bb6f9fec64d7aa62abd01b49b2a75acf5e7712d" "cfw"
clone_at_commit "https://github.com/wiremod/wire.git" \
	"6fdc26ac91264054e4587e58bcc4ec3d6c382abc" "wire"
clone_at_commit "https://github.com/wiremod/advdupe2.git" \
	"3c6dda8d8c47d399c010628255d0f63303562959" "advdupe2"
