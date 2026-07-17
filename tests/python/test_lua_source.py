"""Regression tests for the comment/string-aware Lua source helpers."""

import unittest

from lua_source import (
    code_without_comments_and_strings,
    find_call_table,
    find_matching_brace,
    iter_named_calls,
    iter_qualified_string_assignments,
)


class LuaSourceHelperTests(unittest.TestCase):
    def test_code_view_preserves_positions_and_hides_ignored_text(self):
        source = 'call("real") -- fake("comment")\nlocal long = [[fake("long")]]\n'
        code = code_without_comments_and_strings(source)

        self.assertEqual(len(source), len(code))
        self.assertIn("call(      )", code)
        self.assertNotIn("fake", code)
        self.assertEqual(source.index("call"), code.index("call"))

    def test_named_calls_ignore_comments_strings_and_dotted_members(self):
        source = """
        -- ACF_defineGun(\"fake-comment\")
        local text = 'ACF_defineGun(\\\"fake-string\\\")'
        ACF_defineGun("real")
        object.ACF_defineGun("not-a-global-call")
        """

        self.assertEqual(
            [(value, start) for value, start, _ in iter_named_calls(source, "ACF_defineGun")],
            [("real", source.index('ACF_defineGun("real")'))],
        )

    def test_named_calls_support_dotted_names(self):
        source = """
        -- ACE.DefineMine(\"fake-comment\")
        local text = 'ACE.DefineMine(\\\"fake-string\\\")'
        object.ACE.DefineMine(\"not-a-global-call\")
        object . ACE.DefineMine(\"also-not-a-global-call\")
        ACE . DefineMine(\"real\")
        """

        self.assertEqual(
            ["real"],
            [
                identifier
                for identifier, _, _ in iter_named_calls(source, "ACE.DefineMine")
            ],
        )

    def test_qualified_assignments_require_code_and_exact_name(self):
        source = """
        -- ACE.Value = \"comment\"
        local text = 'ACE.Value = "string"'
        ACE.Value = "real"
        ACE.ValueExtra = "wrong-name"
        Other.Value = "wrong-root"
        """

        self.assertEqual(
            [(value, start) for value, start in iter_qualified_string_assignments(source, "ACE.Value")],
            [("real", source.index('ACE.Value = "real"'))],
        )

    def test_call_table_matches_nested_tables_and_quoted_braces(self):
        source = 'register("id", { outer = { value = 1 }, text = "}" })'
        call_start = source.index("register")
        argument_end = source.index('"id"') + len('"id"')

        table = find_call_table(source, argument_end)

        self.assertEqual(' outer = { value = 1 }, text = "}" ', table)
        self.assertEqual(source.rindex("}"), find_matching_brace(source, source.index("{")))

    def test_missing_or_malformed_tables_return_none(self):
        self.assertIsNone(find_call_table('register("id", value)', len('register("id"')))
        self.assertIsNone(find_matching_brace("{ nested", 0))


if __name__ == "__main__":
    unittest.main()
