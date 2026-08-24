"""Compile ACE's maintainer-facing .ace_test files into GLuaTest groups.

Maintainers edit the DSL. This compiler owns parsing and emits a generated Lua file that
uses the shared native runtime. Unknown syntax is an error instead of being silently ignored.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


TEST_RE = re.compile(r'^new Test "(?P<name>.*)"$')
SCENARIO_RE = re.compile(r"^scenario (?P<id>[a-z0-9]+(?:[._-][a-z0-9]+)*)$")
USES_RE = re.compile(r"^uses (?P<fixture>[a-z0-9_]+) as (?P<alias>[A-Za-z][A-Za-z0-9_]*)$")
DO_RE = re.compile(
    r"^do (?P<action>[A-Za-z_][A-Za-z0-9_.]*) (?P<mode>on|with) "
    r"(?P<args>[A-Za-z][A-Za-z0-9_]*(?: and [A-Za-z][A-Za-z0-9_]*)*) as "
    r"(?P<result>[A-Za-z][A-Za-z0-9_]*)$"
)
EXPECT_RE = re.compile(r"^expect (?P<subject>.+?) (?P<operator>does not exist|exists|was reactivated|was activated|has armor and health|is not legal|is legal|is greater than|is less than|is) ?(?P<value>.*)$")


def parse(path: Path, registry: dict, action_registry: dict | None = None) -> list[dict]:
    tests: list[dict] = []
    current: dict | None = None
    scenario_ids: set[str] = set()

    def finish(line_no: int) -> None:
        nonlocal current
        if current is None:
            return
        if not current.get("cleanup"):
            raise ValueError(f"{path}:{line_no}: every test needs 'cleanup automatic'")
        if not current.get("scenarioId"):
            raise ValueError(f"{path}:{line_no}: every test needs a stable scenario id")
        if current["scenarioId"] in scenario_ids:
            raise ValueError(f"{path}:{line_no}: duplicate scenario id '{current['scenarioId']}'")
        scenario_ids.add(current["scenarioId"])
        tests.append(current)
        current = None

    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = TEST_RE.match(line)
        if match:
            finish(line_no - 1)
            current = {"name": match.group("name"), "requires": [], "fixtures": [], "actions": [], "expects": [], "cleanup": False, "scenarioId": None}
            continue
        if current is None:
            raise ValueError(f"{path}:{line_no}: statement outside a test")
        if line == "requires native":
            current["requires"].append("native")
            continue
        match = SCENARIO_RE.match(line)
        if match:
            if current.get("scenarioId"):
                raise ValueError(f"{path}:{line_no}: duplicate scenario id")
            current["scenarioId"] = match.group("id")
            continue
        match = USES_RE.match(line)
        if match:
            fixture = match.group("fixture")
            if fixture not in registry["fixtures"]:
                raise ValueError(f"{path}:{line_no}: unknown fixture '{fixture}'")
            if any(item["alias"] == match.group("alias") for item in current["fixtures"]):
                raise ValueError(f"{path}:{line_no}: duplicate fixture alias '{match.group('alias')}'")
            if any(item["result"] == match.group("alias") for item in current["actions"]):
                raise ValueError(f"{path}:{line_no}: fixture alias collides with action result '{match.group('alias')}'")
            current["fixtures"].append({"fixture": fixture, "alias": match.group("alias")})
            continue
        match = DO_RE.match(line)
        if match:
            action = match.group("action")
            known_actions = (action_registry or {}).get("actions", {})
            if action not in known_actions:
                raise ValueError(f"{path}:{line_no}: unknown native action '{action}'")
            args = match.group("args").split(" and ")
            aliases = {item["alias"] for item in current["fixtures"]}
            for argument in args:
                if argument not in aliases:
                    raise ValueError(f"{path}:{line_no}: unknown action argument '{argument}'")
            if any(item["result"] == match.group("result") for item in current["actions"]):
                raise ValueError(f"{path}:{line_no}: duplicate action result '{match.group('result')}'")
            if match.group("result") in aliases:
                raise ValueError(f"{path}:{line_no}: action result collides with fixture alias '{match.group('result')}'")
            current["actions"].append({"action": action, "mode": match.group("mode"), "args": args, "result": match.group("result")})
            continue
        match = EXPECT_RE.match(line)
        if match:
            subject = match.group("subject")
            operator = match.group("operator")
            if operator == "is" and subject.endswith(" reason"):
                subject = subject[:-7]
                operator = "reason is"
            value = match.group("value").strip()
            if operator in {"is", "is greater than", "is less than", "reason is"} and not value:
                raise ValueError(f"{path}:{line_no}: expectation needs a value")
            roots = {item["alias"] for item in current["fixtures"]}
            roots.update(item["result"] for item in current["actions"])
            root, _, suffix = subject.partition(".")
            if root not in roots:
                raise ValueError(f"{path}:{line_no}: unknown expectation subject '{subject}'")
            if suffix:
                fixture_item = next((item for item in current["fixtures"] if item["alias"] == root), None)
                action_item = next((item for item in current["actions"] if item["result"] == root), None)
                if fixture_item:
                    definition = registry["fixtures"][fixture_item["fixture"]]
                    allowed = set(definition.get("observations", []))
                    allowed.update(registry.get("observations", {}).get(definition.get("kind"), []))
                else:
                    action_definition = (action_registry or {}).get("actions", {}).get(action_item["action"], {})
                    allowed = set(action_definition.get("returns", []))
                if suffix not in allowed:
                    raise ValueError(f"{path}:{line_no}: unknown observation '{subject}'")
            elif operator == "reason is":
                action_item = next((item for item in current["actions"] if item["result"] == root), None)
                action_definition = (action_registry or {}).get("actions", {}).get(action_item["action"], {}) if action_item else {}
                if not action_item or "reason" not in action_definition.get("returns", []):
                    raise ValueError(f"{path}:{line_no}: unknown observation '{match.group('subject')}'")
            current["expects"].append({"subject": subject, "operator": operator, "value": value})
            continue
        if line == "cleanup automatic":
            current["cleanup"] = True
            continue
        raise ValueError(f"{path}:{line_no}: unrecognized DSL statement: {line}")

    finish(len(path.read_text(encoding="utf-8").splitlines()))
    if not tests:
        raise ValueError(f"{path}: no tests found")
    return tests


def lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def lua_value(value):
    if isinstance(value, str):
        return lua_string(value)
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "nil"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, list):
        return "{" + ", ".join(lua_value(item) for item in value) + "}"
    if isinstance(value, dict):
        return "{" + ", ".join(f"[{lua_string(str(k))}] = {lua_value(v)}" for k, v in value.items()) + "}"
    raise TypeError(type(value))


def compile_suite(source: Path, registry_path: Path, output: Path, action_registry_path: Path | None = None) -> int:
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    action_registry = json.loads(action_registry_path.read_text(encoding="utf-8")) if action_registry_path else {"actions": {}}
    tests = parse(source, registry, action_registry)
    for test in tests:
        for action in test["actions"]:
            action["path"] = action_registry["actions"][action["action"]].get("path", action["action"])
    expected_cases = {
        test["scenarioId"]: f'[{test["scenarioId"]}] {test["name"]}'
        for test in tests
    }
    payload = "local Suite = " + lua_value({"groupName": "ACE interpreted core validation", "fixtures": registry["fixtures"], "actions": action_registry["actions"], "tests": tests}) + "\n"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        "ACE_GLuaTestExpectedCases = " + lua_value(expected_cases) + "\n"
        + "local Runtime = include(\"ace/test_dsl_runtime.lua\")\n"
        + payload
        + "local cases = {}\n"
        + "for _, spec in ipairs(Suite.tests) do\n"
        + "    spec.fixturesRegistry = Suite.fixtures\n"
        + "    local caseName = \"[\" .. spec.scenarioId .. \"] \" .. spec.name\n"
        + "    cases[#cases + 1] = { name = caseName, func = function(State) Runtime.Run(State, spec, expect) end, cleanup = function(State) Runtime.Cleanup(State) end }\n"
        + "end\n"
        + "return { groupName = Suite.groupName, cases = cases }\n",
        encoding="utf-8",
    )
    return len(tests)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, default=Path("tests/prototypes/acf_core_suite_applied.ace_test"), nargs="?")
    parser.add_argument("--registry", type=Path, default=Path("tests/prototypes/ace_core_fixture_registry.json"))
    parser.add_argument("--actions", type=Path, default=Path("tests/prototypes/ace_test_action_registry.json"))
    parser.add_argument("--output", type=Path, default=Path("lua/tests/ace/generated_core_validation.lua"))
    args = parser.parse_args()
    count = compile_suite(args.source, args.registry, args.output, args.actions)
    print(f"compiled {count} ACE DSL test(s) -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
