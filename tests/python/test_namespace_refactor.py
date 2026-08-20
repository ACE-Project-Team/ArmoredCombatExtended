"""Regression checks for the non-entity ACE namespace migration."""

from pathlib import Path
import re
import unittest

from lua_source import (
    IDENTIFIER,
    code_without_comments_and_strings,
    skip_string_or_comment,
)


REPO = Path(__file__).resolve().parents[2]
LUA_ROOT = REPO / "lua"
ENTITY_ROOT = LUA_ROOT / "entities"
STARFALL_ROOT = LUA_ROOT / "starfall"
LEGACY_TOOL_BRIDGE = LUA_ROOT / "autorun" / "ace_legacy_tools.lua"
ACE_CONVARS = (
    "enable_dp",
    "kepush",
    "hepush",
    "recoilpush",
    "healthmod",
    "armormod",
    "ammomod",
    "gunfire",
    "debris_lifetime",
    "debris_children",
    "spalling",
    "spalling_multiplier",
    "explosions_scaled_he_max",
    "explosions_scaled_ents_max",
    "wind",
    "legacyrecoil",
)


def non_entity_sources():
    for path in LUA_ROOT.rglob("*.lua"):
        if ENTITY_ROOT in path.parents or STARFALL_ROOT in path.parents:
            continue
        yield path


def ace_owned_sources():
    for path in LUA_ROOT.rglob("*.lua"):
        if STARFALL_ROOT in path.parents or (LUA_ROOT / "entities" / "gmod_wire_expression2") in path.parents:
            continue
        if path == LUA_ROOT / "autorun" / "acf_globals.lua":
            continue
        yield path


def backend_symbol_sources():
    for path in LUA_ROOT.rglob("*.lua"):
        if STARFALL_ROOT in path.parents or (LUA_ROOT / "entities" / "gmod_wire_expression2") in path.parents:
            continue
        yield path


def skip_namespace_space(source, start):
    index = start
    while index < len(source):
        if source[index].isspace():
            index += 1
        elif source.startswith("--", index):
            index = skip_string_or_comment(source, index)
        elif source.startswith("//", index):
            newline = source.find("\n", index + 2)
            index = len(source) if newline < 0 else newline + 1
        elif source.startswith("/*", index):
            end = source.find("*/", index + 2)
            index = len(source) if end < 0 else end + 2
        else:
            break
    return index


def skip_namespace_wrappers(source, start):
    index = skip_namespace_space(source, start)
    if index < len(source) and source[index] == ")":
        index = skip_namespace_space(source, index + 1)
    return index


def read_namespace_string(source, start):
    if start < len(source) and source[start] in "'\"":
        quote = source[start]
        value = []
        index = start + 1
        while index < len(source):
            char = source[index]
            if char == quote:
                return "".join(value), index + 1
            if char == "\\" and index + 1 < len(source):
                index += 1
                if source[index].isdigit():
                    end = index
                    while end < len(source) and end < index + 3 and source[end].isdigit():
                        end += 1
                    value.append(chr(int(source[index:end])))
                    index = end
                elif source[index] == "x" and index + 2 < len(source):
                    digits = source[index + 1 : index + 3]
                    if re.fullmatch(r"[0-9A-Fa-f]{2}", digits):
                        value.append(chr(int(digits, 16)))
                        index += 3
                    else:
                        value.append(source[index])
                        index += 1
                else:
                    value.append({
                        "a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r",
                        "t": "\t", "v": "\v", "\\": "\\", "\"": "\"", "'": "'",
                    }.get(source[index], source[index]))
                    index += 1
            else:
                value.append(char)
                index += 1
        return None, len(source)

    match = re.match(r"\[(=*)\[", source[start:])
    if not match:
        return None, start

    closing = "]" + match.group(1) + "]"
    content_start = start + match.end()
    content_end = source.find(closing, content_start)
    if content_end < 0:
        return None, len(source)
    value = source[content_start:content_end]
    if value.startswith("\r\n"):
        value = value[2:]
    elif value.startswith(("\r", "\n")):
        value = value[1:]
    return value, content_end + len(closing)


def has_namespace_receiver_dot(source, start):
    prefix = backend_code_without_ignored_text(source[:start]).rstrip()
    if not prefix.endswith(".") or prefix.endswith(".."):
        return False
    receiver = prefix[:-1].rstrip()
    return not re.search(r"(?:^|[^A-Za-z0-9_])\d+(?:\.\d*)?$", receiver)


def namespace_grouping_depth(source, start):
    prefix = backend_code_without_ignored_text(source[:start]).rstrip()
    depth = len(prefix) - len(prefix.rstrip("("))
    if not depth:
        return 0
    before_open = prefix[:-depth].rstrip()
    token = re.search(r"([A-Za-z_][A-Za-z0-9_]*|\S)\s*$", before_open)
    if token and token.group(1) == ")" and re.search(
        r"\bfunction(?:\s+[A-Za-z_][A-Za-z0-9_]*(?:[.:][A-Za-z_][A-Za-z0-9_]*)*)?\s*\([^()]*\)$",
        before_open,
    ):
        return depth
    if before_open.endswith(".."):
        return depth
    grouping_tokens = {
        "and", "do", "elseif", "end", "for", "if", "in", "local", "not", "or", "repeat",
        "return", "then", "until", "while", "(", "[", "{", ":", ",", ";", "=", "+",
        "-", "*", "/", "%", "^", "<", ">", "~", "&", "|", "#", "!",
    }
    if token and token.group(1) == ")":
        return max(depth - 1, 0)
    return max(depth - 1, 0) if token and token.group(1) not in grouping_tokens else depth


def contains_bracket_field_access(source, table_name, field_name):
    index = 0
    while index < len(source):
        if (
            source.startswith("--", index)
            or source.startswith("//", index)
            or source.startswith("/*", index)
            or source[index] in "'\"["
        ):
            if source.startswith("//", index):
                newline = source.find("\n", index + 2)
                index = len(source) if newline < 0 else newline + 1
                continue
            if source.startswith("/*", index):
                end = source.find("*/", index + 2)
                index = len(source) if end < 0 else end + 2
                continue
            index = skip_string_or_comment(source, index)
            continue

        match = IDENTIFIER.match(source, index)
        if not match:
            index += 1
            continue

        index = match.end()
        if match.group(0) != table_name:
            continue
        if has_namespace_receiver_dot(source, match.start()):
            continue

        grouping_depth = namespace_grouping_depth(source, match.start())
        bracket = skip_namespace_space(source, index)
        if grouping_depth:
            for _ in range(grouping_depth):
                bracket = skip_namespace_wrappers(source, bracket)
        if bracket >= len(source) or source[bracket] != "[":
            continue

        value_start = skip_namespace_space(source, bracket + 1)
        wrapped_value_depth = 0
        while value_start < len(source) and source[value_start] == "(":
            wrapped_value_depth += 1
            value_start = skip_namespace_space(source, value_start + 1)
        value, after_value = read_namespace_string(source, value_start)
        if value != field_name:
            continue

        closing = skip_namespace_space(source, after_value)
        while wrapped_value_depth and closing < len(source) and source[closing] == ")":
            wrapped_value_depth -= 1
            closing = skip_namespace_space(source, closing + 1)
        if closing < len(source) and source[closing] == "]":
            return True

    return False


def contains_dotted_field_access(source, table_name, field_name):
    index = 0
    while index < len(source):
        if (
            source.startswith("--", index)
            or source.startswith("//", index)
            or source.startswith("/*", index)
            or source[index] in "'\"["
        ):
            if source.startswith("//", index):
                newline = source.find("\n", index + 2)
                index = len(source) if newline < 0 else newline + 1
            elif source.startswith("/*", index):
                end = source.find("*/", index + 2)
                index = len(source) if end < 0 else end + 2
            else:
                index = skip_string_or_comment(source, index)
            continue

        match = IDENTIFIER.match(source, index)
        if not match:
            index += 1
            continue

        index = match.end()
        if match.group(0) != table_name:
            continue
        if has_namespace_receiver_dot(source, match.start()):
            continue

        grouping_depth = namespace_grouping_depth(source, match.start())
        dot = skip_namespace_space(source, index)
        if grouping_depth:
            for _ in range(grouping_depth):
                dot = skip_namespace_wrappers(source, dot)
        if dot >= len(source) or source[dot] not in ".:":
            continue
        field = IDENTIFIER.match(source, skip_namespace_space(source, dot + 1))
        if field and field.group(0) == field_name:
            return True

    return False


def backend_code_without_ignored_text(source):
    """Blank GLua comments and strings without treating comment markers in strings as code."""

    result = list(source)
    index = 0
    while index < len(source):
        if source.startswith(("--", "//", "/*"), index):
            if source.startswith("--", index):
                end = skip_string_or_comment(source, index)
            elif source.startswith("//", index):
                newline = source.find("\n", index + 2)
                end = len(source) if newline < 0 else newline + 1
            else:
                close = source.find("*/", index + 2)
                end = len(source) if close < 0 else close + 2
            for position in range(index, end):
                if result[position] not in "\r\n":
                    result[position] = " "
            index = end
        elif source[index] in "'\"" or source[index] == "[":
            end = skip_string_or_comment(source, index)
            for position in range(index, end):
                if result[position] not in "\r\n":
                    result[position] = " "
            index = end
        else:
            index += 1
    return "".join(result)


class NamespaceRefactorTests(unittest.TestCase):
    def test_non_entity_private_helpers_use_ace_prefix(self):
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"\b(?:local\s+)?function\s+ACF_[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_backend_private_helpers_do_not_use_flat_ace_prefix(self):
        for path in (
            LUA_ROOT / "acf" / "server" / "sv_acfballistics.lua",
            LUA_ROOT / "acf" / "server" / "sv_acfdamage.lua",
            LUA_ROOT / "acf" / "server" / "sv_contraptionlegality.lua",
        ):
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"\blocal\s+function\s+ACE_[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_ace_table_has_no_legacy_function_fallback(self):
        source = (LUA_ROOT / "autorun" / "acf_globals.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertNotIn('return rawget(_G, "ACE_" .. Key)', source)
        self.assertNotIn("setmetatable(ACE, Meta)", source)

    def test_non_entity_calls_do_not_use_legacy_acf_prefix(self):
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?<![:.])\bACF_[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_major_refactor_legacy_backend_symbols_stay_absent(self):
        """Reject compatibility names that have no ACE-side implementation."""

        forbidden_symbols = (
            ("ACF_CheckLegal", r"(?<![A-Za-z0-9_])ACF_CheckLegal(?![A-Za-z0-9_])"),
            ("ACF.Legal", r"(?<![A-Za-z0-9_.])ACF\s*\.\s*Legal\b"),
            ("ACF_BulletClient", r"(?<![A-Za-z0-9_])ACF_BulletClient(?![A-Za-z0-9_])"),
            ("ACF_RoundBaseGunpowder", r"(?<![A-Za-z0-9_])ACF_RoundBaseGunpowder(?![A-Za-z0-9_])"),
        )
        for symbol, pattern in forbidden_symbols:
            with self.subTest(symbol=symbol, synthetic=True):
                self.assertRegex(backend_code_without_ignored_text(f"{symbol}()"), pattern)
        for path in backend_symbol_sources():
            raw_source = path.read_text(encoding="utf-8", errors="replace")
            source = backend_code_without_ignored_text(raw_source)
            with self.subTest(source=path.relative_to(REPO)):
                for symbol, pattern in forbidden_symbols:
                    with self.subTest(symbol=symbol):
                        if symbol == "ACF.Legal":
                            self.assertFalse(contains_dotted_field_access(raw_source, "ACF", "Legal"))
                        else:
                            self.assertNotRegex(source, pattern)
                self.assertFalse(contains_bracket_field_access(raw_source, "ACF", "Legal"))

    def test_legacy_backend_symbol_scanner_handles_glua_forms(self):
        forbidden = (
            'ACF["Legal"]',
            "ACF[ [[Legal]] ]",
            "ACF /* comment */ [ 'Legal' ]",
            "ACF // comment\n ['Legal']",
            "ACF[ [[\nLegal]] ]",
            "local n = 1.\nACF[\"Legal\"] = value",
            'ACF["\\076egal"]',
            'ACF["\\x4cegal"]',
            'ACF[("Legal")]',
            "local x = foo[bar]\nACF[\"Legal\"] = value",
            'value .. ACF["Legal"]',
            'return (ACF)["Legal"]',
            'factory()((ACF)["Legal"])',
            'value .. (ACF)["Legal"]',
            'local function f() (ACF)["Legal"] = 1 end',
            'function T.f() (ACF)["Legal"] = 1 end',
            'function T:f() (ACF)["Legal"] = 1 end',
            'do (ACF)["Legal"] = 1 end',
            'ACF[(("Legal"))]',
            '#(ACF)["Legal"]',
            '!(ACF)["Legal"]',
        )
        allowed = (
            '"ACF[\\"Legal\\"]"',
            "/* ACF[\"Legal\"] */",
            'Other.ACF["Legal"]',
            "(Other).ACF['Legal']",
            "Other. /* comment */ ACF['Legal']",
            '"/*"; ACF_CheckLegal(); "*/"',
            "// ACF['Legal']",
            "Other. /* comment */ ACF.Legal",
            "Other. -- comment\n ACF.Legal",
            "Other. // comment\n ACF.Legal",
            "(ACF).Other.Legal",
            'factory(ACF)["Legal"]',
            'factory((ACF))["Legal"]',
            'factory()(ACF)["Legal"]',
            'function prior() end\nfactory()(ACF)["Legal"]',
            'Other1.ACF["Legal"]',
            'ACF["Leg\\al"]',
            "factory(ACF).Legal",
            "factory()(ACF).Legal",
            "function prior() end\nfactory()(ACF).Legal",
        )
        for source in forbidden:
            with self.subTest(source=source):
                self.assertTrue(contains_bracket_field_access(source, "ACF", "Legal"))
        for source in allowed:
            with self.subTest(source=source):
                self.assertFalse(contains_bracket_field_access(source, "ACF", "Legal"))

        dotted_forbidden = (
            "ACF.Legal",
            "ACF:Legal()",
            "function ACF:Legal() end",
            "ACF /* comment */ . Legal",
            "value .. ACF.Legal",
            "return (ACF).Legal",
            "value .. (ACF).Legal",
            "if (ACF).Legal then",
            "local x = (ACF).Legal",
            "sink((ACF).Legal)",
            "factory()((ACF).Legal)",
            "return (((ACF))).Legal",
            "for x in (ACF).Legal do",
            "#(ACF).Legal",
            "!(ACF).Legal",
            "local function f() (ACF).Legal = 1 end",
            "function T.f() (ACF).Legal = 1 end",
            "function T:f() (ACF).Legal = 1 end",
            "do (ACF).Legal = 1 end",
        )
        dotted_allowed = (
            "Other. /* comment */ ACF.Legal",
            "factory((ACF)).Legal",
            "Other1.ACF.Legal",
        )
        for source in dotted_forbidden:
            with self.subTest(source=source):
                self.assertTrue(contains_dotted_field_access(source, "ACF", "Legal"))
        for source in dotted_allowed:
            with self.subTest(source=source):
                self.assertFalse(contains_dotted_field_access(source, "ACF", "Legal"))

        embedded_markers = backend_code_without_ignored_text('"/*"; ACF_CheckLegal(); "*/"')
        self.assertIn("ACF_CheckLegal", embedded_markers)
        self.assertNotIn("ACF_CheckLegal", backend_code_without_ignored_text("/* ACF_CheckLegal */"))

        self.assertTrue(contains_dotted_field_access("(ACF).Legal", "ACF", "Legal"))
        self.assertTrue(contains_bracket_field_access('(ACF)["Legal"]', "ACF", "Legal"))

    def test_points_and_manufacturing_helpers_use_namespaces(self):
        points_model = (LUA_ROOT / "acf" / "shared" / "sh_ace_points_model.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        manufacturing = (LUA_ROOT / "acf" / "shared" / "sh_ace_manufacturing.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertRegex(points_model, r"function\s+ACE\.Points\.[A-Za-z_][A-Za-z0-9_]*\s*\(")
        self.assertRegex(manufacturing, r"function\s+ACE\.Manufacturing\.[A-Za-z_][A-Za-z0-9_]*\s*\(")
        self.assertNotRegex(points_model, r"function\s+ACE_Points_[A-Za-z_][A-Za-z0-9_]*\s*\(")
        self.assertNotRegex(manufacturing, r"function\s+ACE_Manu_[A-Za-z_][A-Za-z0-9_]*\s*\(")
        self.assertLess(points_model.index("ACE = ACE or {}"), points_model.index("ACE.Points = ACE.Points or {}"))
        self.assertLess(
            manufacturing.index("ACE = ACE or {}"),
            manufacturing.index("ACE.Manufacturing = ACE.Manufacturing or {}"),
        )
        self.assertNotIn("ACE_Points_BaseRoundCost = ACE.Points.BaseRoundCost", points_model)
        self.assertNotIn("ACE_Manu_EntCost = ACE.Manufacturing.EntCost", manufacturing)
        self.assertIn('cls:sub(1, 4) == "acf_"', points_model)
        self.assertIn('cls:sub(1, 4) == "ace_"', points_model)

        consumers = (
            LUA_ROOT / "acf" / "shared" / "sh_ace_functions.lua",
            LUA_ROOT / "acf" / "client" / "cl_acemenu_gui.lua",
            LUA_ROOT / "weapons" / "gmod_tool" / "stools" / "acearmorprop.lua",
        )
        for path in consumers:
            source = path.read_text(encoding="utf-8", errors="replace")
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(source, r"\bACE_(?:Points|Manu)_[A-Za-z_][A-Za-z0-9_]*\b")

    def test_ace_global_functions_are_defined_with_ace_prefix(self):
        definitions = set()
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            definitions.update(
                re.findall(
                    r"(?m)^\s*function\s+ACE\.([A-Za-z_][A-Za-z0-9_]*)\s*\(",
                    source,
                )
            )

        self.assertTrue(definitions)
        self.assertIn("DefineExplosive", definitions)
        self.assertIn("MarkArmorDirty", definitions)

    def test_non_entity_hooks_and_identifiers_use_ace_prefix(self):
        for path in non_entity_sources():
            if path == LEGACY_TOOL_BRIDGE:
                # This file deliberately publishes the old ACF tool identifiers.
                continue
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                source = source.replace("ACF_E2_LinkTables", "")
                for compatibility_name in (
                    "ACF_CalcArmor", "ACF_Check", "ACF_CheckClips",
                    "ACF_GetHitAngle", "ACF_GetLinkedWheels", "ACF_SendNotify",
                    "ACF_GetPhysicalParent", "ACF_Kinetic", "ACF_MuzzleVelocity", "ACF_HE",
                ):
                    source = source.replace(compatibility_name, "")
                self.assertNotRegex(source, r"(?<![.:])\bACF_[A-Za-z_][A-Za-z0-9_]*")
                self.assertNotRegex(source, r"\bacfmenu|\bacfsound")

    def test_ace_owned_sources_have_no_unqualified_legacy_globals(self):
        for path in ace_owned_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            ).replace("ACF_E2_LinkTables", "")
            for compatibility_name in (
                "ACF_CalcArmor", "ACF_Check", "ACF_CheckClips",
                "ACF_GetHitAngle", "ACF_GetLinkedWheels", "ACF_SendNotify",
                "ACF_GetPhysicalParent", "ACF_Kinetic", "ACF_MuzzleVelocity", "ACF_HE",
            ):
                source = source.replace(compatibility_name, "")
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(source, r"(?<![.:])\bACF_[A-Za-z_][A-Za-z0-9_]*")

    def test_globals_keep_backend_state_out_of_acf_table(self):
        raw_source = (LUA_ROOT / "autorun" / "acf_globals.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        source = code_without_comments_and_strings(raw_source)

        self.assertRegex(source, r"\bACE\.Threshold\s*=")
        self.assertRegex(source, r"\bACE\.Bullet\s*=\s*\{\}")
        self.assertNotRegex(
            source,
            r"(?m)^\s*ACF\.[A-Za-z_][A-Za-z0-9_]*\s*=\s*(?!ACF\[)"
        )
        self.assertNotRegex(source, r"ACF\s*\[\s*key\s*\]\s*=\s*ACE\[")
        self.assertNotIn("__ACECompatibilityView", raw_source)
        self.assertNotIn("ACECompatibilityView", raw_source)
        self.assertNotIn("setmetatable(ACF", raw_source)

    def test_deferred_adapters_keep_their_dotted_ace_api(self):
        globals_source = (LUA_ROOT / "autorun" / "acf_globals.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        for name in (
            "GetMaterialData", "CheckRound", "HeatFromGun", "HeatFromEngine", "MarkArmorDirty"
        ):
            with self.subTest(name=name):
                self.assertNotIn(f"ACE.{name} = ACE_{name}", globals_source)

    def test_legacy_mark_armor_dirty_wrapper_survives_compatibility_alias(self):
        source = (LUA_ROOT / "acf" / "server" / "sv_contraptionlegality.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertNotIn("ACE_MarkArmorDirtyImplementation", source)
        self.assertIn("function ACE.MarkArmorDirty(con, ent, reason)", source)

    def test_ace_does_not_auto_register_flat_function_exports(self):
        globals_source = (LUA_ROOT / "autorun" / "acf_globals.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        functions_source = (LUA_ROOT / "acf" / "shared" / "sh_ace_functions.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertNotIn("ACE[Method] = Value", globals_source)
        self.assertNotIn("ACE.IsEnt = ACE_IsEnt", functions_source)
        self.assertIn("function ACE.IsEnt", functions_source)

    def test_missile_radar_registries_are_initialized_before_scans(self):
        cm_source = (
            LUA_ROOT / "autorun" / "acf_missile" / "countermeasure" / "cm_globals.lua"
        ).read_text(encoding="utf-8", errors="replace")
        missile_source = (LUA_ROOT / "autorun" / "server" / "sv_acf_missiles.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertIn("ACE.CMTable = ACE.CMTable or {}", cm_source)
        self.assertIn("ACE.ActiveMissiles = ACE.ActiveMissiles or {}", cm_source)
        self.assertIn("ACE.ActiveMissiles = ACE.ActiveMissiles or {}", missile_source)

    def test_backend_does_not_initialize_acf_global_table(self):
        for path in ace_owned_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(source, r"(?m)^\s*(?:local\s+)?ACF\s*=\s*ACF\s+or")
                self.assertNotRegex(source, r"(?m)^\s*if\s+not\s+ACF\s+then\s+ACF\s*=")

    def test_ace_owned_translation_table_is_not_legacy_global(self):
        translation = (LUA_ROOT / "autorun" / "translation" / "ace_translationpacks.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertIn("ACE.Translation = {}", translation)
        self.assertNotIn("ACFTranslation", translation)
        for path in ace_owned_sources():
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotIn("ACFTranslation", path.read_text(encoding="utf-8", errors="replace"))

    def test_entity_dupe_factories_do_not_collide_after_global_rename(self):
        sources = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in (
                LUA_ROOT / "entities" / "ace_explosive" / "init.lua",
                LUA_ROOT / "entities" / "acf_explosive" / "init.lua",
            )
        )
        self.assertEqual(len(re.findall(r"function\s+ACE\.MakeExplosive\s*\(", sources)), 1)
        self.assertEqual(len(re.findall(r"function\s+ACE\.MakeLegacyExplosive\s*\(", sources)), 1)

    def test_non_entity_menu_sound_effect_and_tool_ids_are_ace_prefixed(self):
        expected_paths = (
            LUA_ROOT / "acf" / "client" / "cl_acemenu_gui.lua",
            LUA_ROOT / "acf" / "client" / "cl_acemenu_missileui.lua",
            REPO / "lua" / "weapons" / "gmod_tool" / "stools" / "acemenu.lua",
            REPO / "lua" / "weapons" / "gmod_tool" / "stools" / "acesound.lua",
        )
        for path in expected_paths:
            self.assertTrue(path.exists(), f"renamed non-entity asset is missing: {path}")

        for path in non_entity_sources():
            if path.name == "ace_legacy_convars.lua":
                continue
            source = path.read_text(encoding="utf-8", errors="replace")
            if path == LEGACY_TOOL_BRIDGE:
                # This file is the explicit old-name compatibility boundary.
                continue
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?i)acf/client/cl_acfmenu|\bacfmenu\b|\bacfsound\b|"
                    r"\bacfarmorprop\b|\bacfchaircam\b|\bacfcopy\b",
                )
                self.assertNotRegex(
                    source,
                    r'(?i)util\.Effect\s*\(\s*["\']acf_',
                )

        for path in ace_owned_sources():
            source = path.read_text(encoding="utf-8", errors="replace")
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r'(?i)(?:hook\.(?:Add|Run|Call)|net\.(?:Start|Receive)|'
                    r'util\.AddNetworkString)\s*\(\s*["\'](?:ACF_|acfmenu|acfsound)',
                )

        sound_tool = (REPO / "lua" / "weapons" / "gmod_tool" / "stools" / "acesound.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertIn('duplicator.RegisterEntityModifier( "ace_replacesound", ReplaceSound )', sound_tool)
        self.assertIn('duplicator.RegisterEntityModifier( "acf_replacesound", ReplaceSound )', sound_tool)
        self.assertIn('duplicator.ClearEntityModifier( Entity, "acf_replacesound" )', sound_tool)
        self.assertIn('duplicator.ClearEntityModifier( trace.Entity, "acf_replacesound" )', sound_tool)
        self.assertIn('Entity.EntityMods and Entity.EntityMods.ace_replacesound', sound_tool)

        effect_names = {
            path.name for path in (REPO / "lua" / "effects").iterdir() if path.is_dir()
        }
        for old_name in {
            "acf_ap_impact", "acf_ap_penetration", "acf_ap_ricochet", "acf_bulleteffect",
            "acf_heat_explosion", "acf_missilelaunch", "acf_muzzleflash", "acf_racklaunch",
            "acf_radar_noise", "acf_smoke",
        }:
            self.assertNotIn(old_name, effect_names)

        self.assertIn("acf_scaled_explosion", effect_names)

    def test_deferred_adapters_keep_legacy_compatibility_boundaries(self):
        for relative in (
            "lua/entities/gmod_wire_expression2/core/custom/acf.lua",
            "lua/starfall/libs_sv/acf.lua",
        ):
            source = (REPO / relative).read_text(encoding="utf-8", errors="replace")
            with self.subTest(source=relative):
                self.assertNotIn('"acemenu"', source)
            if relative.endswith("custom/acf.lua"):
                self.assertIn('"acfmenu"', source)

    def test_named_global_functions_are_namespaced_or_entity_methods(self):
        for path in LUA_ROOT.rglob("*.lua"):
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?m)^\s*function\s+(?!ACE_|ENT:|local\s)[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_ballistics_callback_assignments_match_dotted_calls(self):
        source = (LUA_ROOT / "acf" / "server" / "sv_acfballistics.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertNotIn("ACE_BulletEndFlight =", source)
        self.assertNotIn("ACE_DoOnBulletFlight =", source)
        self.assertNotIn("local ACE_BulletPropImpact", source)
        self.assertNotIn("local ACE_BulletWorldImpact", source)
        self.assertIn("ACE.BulletEndFlight =", source)
        self.assertIn("ACE.DoOnBulletFlight =", source)
        self.assertIn("ACE.BulletPropImpact =", source)
        self.assertIn("ACE.BulletWorldImpact =", source)

    def test_client_menu_uses_dotted_pose_helper_guard(self):
        source = (LUA_ROOT / "acf" / "client" / "cl_acemenu_gui.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertIn("if ACE.IsStandingPose and ACE.IsStandingPose(poseName) then", source)
        self.assertNotIn("if ACE_IsStandingPose and ACE.IsStandingPose(poseName) then", source)

    def test_entity_callers_use_the_ace_backend_prefix(self):
        self.assertTrue(any(ENTITY_ROOT.rglob("*.lua")))
        legacy_entity_calls = (
            "Activate", "BulletClient", "CalcArmor", "CalcBulletFlight", "CalcCurve",
            "CanLinkRack", "Check", "CheckClips", "CheckLegal", "Damage", "GetAllChildren",
            "GetAllPhysicalConstraints", "GetGunValue", "GetHitAngle", "GetLinkedWheels",
            "GetPhysicalParent", "GetRackValue", "HE", "HEKill", "KEShove", "Kinetic",
            "MuzzleVelocity", "PropDamage", "RackCanLoadCaliber", "RenderLight",
            "ScaledExplosion", "SendNotify",
        )
        for path in ENTITY_ROOT.rglob("*.lua"):
            if (ENTITY_ROOT / "gmod_wire_expression2") in path.parents:
                continue
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            for name in legacy_entity_calls:
                with self.subTest(source=path.relative_to(REPO), name=name):
                    self.assertNotRegex(
                        source,
                        rf"(?<!:)\bACF_{re.escape(name)}\s*\(",
                    )

    def test_entity_ace_globals_are_namespaced(self):
        for path in ENTITY_ROOT.rglob("*.lua"):
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?m)^\s*function\s+(?:Make(?:ACF|ACE)_[A-Za-z_]|ACF_[A-Za-z_])",
                )
                self.assertNotRegex(
                    source,
                    r"\bACE_Make(?!(?:Ammo|Gun)\b)[A-Za-z_][A-Za-z0-9_]*\s*=",
                )

    def test_ace_convars_use_modern_names_without_acf_aliases(self):
        globals_source = (LUA_ROOT / "autorun" / "acf_globals.lua").read_text(
            encoding="utf-8"
        )
        for name in ACE_CONVARS:
            with self.subTest(name=name):
                self.assertRegex(
                    globals_source,
                    rf'CreateConVar\(\s*"ace_{re.escape(name)}"',
                )
        for path in non_entity_sources():
            if path.name == "ace_legacy_convars.lua":
                continue
            source = path.read_text(encoding="utf-8", errors="replace")
            for name in ACE_CONVARS:
                with self.subTest(source=path.relative_to(REPO), name=name):
                    self.assertNotIn(f'"acf_{name}"', source)

    def test_entity_limits_and_cleanup_use_ace_tool_namespace(self):
        for path in ENTITY_ROOT.rglob("*.lua"):
            if (ENTITY_ROOT / "gmod_wire_expression2") in path.parents:
                continue
            source = path.read_text(encoding="utf-8", errors="replace")
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(source, r'"_acf_[A-Za-z0-9_]+"')
                self.assertNotIn('"acfmenu"', source)


if __name__ == "__main__":
    unittest.main()
