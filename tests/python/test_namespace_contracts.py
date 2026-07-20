"""General namespace contracts for ACE's shared Lua globals."""

from pathlib import Path
import unittest

from ace_static.namespace import (
    find_mutable_filter_aliases,
    find_namespace_collisions,
    find_repo_namespace_collisions,
)


REPO = Path(__file__).resolve().parents[2]


class NamespaceContractTests(unittest.TestCase):
    def test_cross_file_function_table_collision_is_blocking(self):
        collisions = find_namespace_collisions(
            {
                "lua/server/functions.lua": "function ACE.Spall() end\n",
                "lua/server/storage.lua": "ACE.Spall[1] = {}\n",
            }
        )

        self.assertEqual(1, len(collisions))
        self.assertEqual("Spall", collisions[0].name)
        self.assertEqual("lua/server/functions.lua", collisions[0].function_path)
        self.assertEqual("lua/server/storage.lua", collisions[0].indexed_path)

    def test_strings_and_comments_do_not_create_collisions(self):
        collisions = find_namespace_collisions(
            {
                "lua/server/one.lua": "-- function ACE.Spall()\nlocal text = 'ACE.Spall[1]'\n",
                "lua/server/two.lua": "ACE.Other[1] = {}\n",
            }
        )

        self.assertEqual([], collisions)

    def test_current_repository_has_no_function_table_collisions(self):
        collisions = find_repo_namespace_collisions(REPO)
        self.assertEqual([], collisions, "ACE namespace collisions: %s" % collisions)

    def test_mutable_filter_alias_contract_catches_caller_mutation(self):
        findings = find_mutable_filter_aliases(
            {"lua/server/bad.lua": "local copy = Filter\ntable.Add(copy, entities)\n"}
        )

        self.assertEqual(1, len(findings))
        self.assertEqual("copy", findings[0].alias)

    def test_private_filter_copy_is_the_general_safe_shape(self):
        findings = find_mutable_filter_aliases(
            {"lua/server/good.lua": "local copy = table.Copy(Filter)\ntable.Add(copy, entities)\n"}
        )

        self.assertEqual([], findings)

    def test_repository_has_no_caller_filter_alias_mutations(self):
        sources = {
            path.relative_to(REPO).as_posix(): path.read_text(encoding="utf-8", errors="replace")
            for path in (REPO / "lua").rglob("*.lua")
        }
        findings = find_mutable_filter_aliases(sources)
        self.assertEqual([], findings, "caller-owned filter aliases: %s" % findings)


if __name__ == "__main__":
    unittest.main()
