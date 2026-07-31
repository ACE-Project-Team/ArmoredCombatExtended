"""Static integrity checks for the ACE addon layout and load-time references."""

from pathlib import Path
import re
import unittest


REPO = Path(__file__).resolve().parents[2]
LUA_ROOT = REPO / "lua"
ENTITY_ROOT = LUA_ROOT / "entities"


class RepositoryStructureTests(unittest.TestCase):
    def test_entity_directories_have_the_standard_file_set(self):
        entity_dirs = sorted(
            path
            for path in ENTITY_ROOT.iterdir()
            if path.is_dir() and path.name != "gmod_wire_expression2"
        )

        self.assertTrue(entity_dirs, "no ACE/ACF entity directories were found")
        for entity_dir in entity_dirs:
            with self.subTest(entity=entity_dir.name):
                self.assertTrue((entity_dir / "init.lua").is_file())
                self.assertTrue((entity_dir / "shared.lua").is_file())
                self.assertTrue((entity_dir / "cl_init.lua").is_file())

    def test_entity_initializers_send_shared_and_client_code(self):
        for entity_dir in sorted(ENTITY_ROOT.iterdir()):
            if not entity_dir.is_dir() or entity_dir.name == "gmod_wire_expression2":
                continue

            source = (entity_dir / "init.lua").read_text(encoding="utf-8")
            with self.subTest(entity=entity_dir.name):
                self.assertRegex(source, r"AddCSLuaFile\s*\(\s*[\"']shared\.lua")
                self.assertRegex(source, r"AddCSLuaFile\s*\(\s*[\"']cl_init\.lua")

    def test_duplicator_entity_class_registrations_are_unique_and_mounted(self):
        pattern = re.compile(
            r"duplicator\.RegisterEntityClass\s*\(\s*[\"']([^\"']+)[\"']"
        )
        registrations = []
        for path in LUA_ROOT.rglob("*.lua"):
            source = path.read_text(encoding="utf-8", errors="replace")
            registrations.extend((match, path) for match in pattern.finditer(source))

        classes = [match.group(1) for match, _ in registrations]
        self.assertTrue(classes, "no duplicator entity classes were registered")
        self.assertEqual(len(classes), len(set(classes)), "duplicate duplicator class IDs")

        for class_name, path in ((match.group(1), path) for match, path in registrations):
            with self.subTest(class_name=class_name, source=path):
                self.assertTrue(
                    (ENTITY_ROOT / class_name).is_dir(),
                    f"{class_name} is registered but has no entity directory",
                )

    def test_direct_addcslua_file_references_resolve(self):
        pattern = re.compile(r"AddCSLuaFile\s*\(\s*[\"']([^\"']+)[\"']")
        missing = []

        for source_path in LUA_ROOT.rglob("*.lua"):
            source = source_path.read_text(encoding="utf-8", errors="replace")
            for match in pattern.finditer(source):
                # The loader also passes directory prefixes before concatenating a
                # discovered filename; those are not file references to resolve.
                if match.group(1).endswith("/"):
                    continue
                relative = Path(match.group(1).replace("/", "/"))
                if len(relative.parts) == 1:
                    target = source_path.parent / relative
                else:
                    target = LUA_ROOT.joinpath(*relative.parts)

                if not target.is_file():
                    missing.append(f"{source_path.relative_to(REPO)} -> {match.group(1)}")

        self.assertEqual([], missing, "direct AddCSLuaFile references do not resolve: " + ", ".join(missing))

    def test_loader_declared_shared_folders_exist(self):
        loader = (LUA_ROOT / "acf" / "shared" / "sh_ace_loader.lua").read_text(
            encoding="utf-8"
        )
        folders = re.findall(r"^\s*\"([a-z]+)\",\s*$", loader, re.MULTILINE)
        self.assertTrue(folders, "the shared loader declared no source folders")

        for folder in folders:
            with self.subTest(folder=folder):
                directory = LUA_ROOT / "acf" / "shared" / folder
                self.assertTrue(directory.is_dir())
                self.assertTrue(list(directory.glob("*.lua")))


if __name__ == "__main__":
    unittest.main()
