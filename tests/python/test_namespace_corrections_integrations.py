"""Regression coverage for the source-derived ACE adapter manifest."""

import hashlib
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))
from namespace_corrections_integrations import build_manifest  # noqa: E402


class IntegrationManifestTests(unittest.TestCase):
    def test_manifest_covers_current_e2_and_starfall_adapter_sources(self):
        manifest = build_manifest(REPO)
        self.assertEqual(manifest["schema"], 1)
        self.assertEqual(manifest["e2"]["declarations"], 116)
        self.assertEqual(len(manifest["e2"]["names"]), 112)
        self.assertEqual(len(manifest["starfall"]["library_functions"]), 14)
        self.assertEqual(len(manifest["starfall"]["entity_methods"]), 103)
        self.assertIn("acfIsRadar", manifest["e2"]["names"])
        self.assertIn("acfRadarData", manifest["e2"]["names"])
        self.assertIn("acfRadarData", manifest["starfall"]["entity_methods"])
        self.assertEqual(
            manifest["sources"]["e2"]["file"],
            "lua/entities/gmod_wire_expression2/core/custom/acf.lua",
        )
        self.assertEqual(manifest["sources"]["starfall"]["file"], "lua/starfall/libs_sv/acf.lua")

    def test_manifest_source_metadata_is_source_bound(self):
        manifest = build_manifest(REPO)

        for source in manifest["sources"].values():
            path = REPO / source["file"]
            self.assertTrue(path.is_file())

        self.assertEqual(
            manifest["sources"]["e2"]["sha256"],
            hashlib.sha256(
                (REPO / manifest["sources"]["e2"]["file"]).read_bytes()
            ).hexdigest(),
        )
        self.assertEqual(
            manifest["sources"]["starfall"]["sha256"],
            hashlib.sha256(
                (REPO / manifest["sources"]["starfall"]["file"]).read_bytes()
            ).hexdigest(),
        )


if __name__ == "__main__":
    unittest.main()
