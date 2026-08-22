import unittest

from ace_test_support.snapshots import (
    SnapshotSpec,
    compare_snapshot,
    project_snapshot,
    snapshot_failure,
)


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.spec = SnapshotSpec(
            name="round schema remains compatible",
            fields=("Type", "NetID", "Caliber", "Guidance"),
            tolerances={"Caliber": 0.01},
        )

    def test_projection_ignores_runtime_and_incidental_fields(self):
        observed = {
            "Type": "AP",
            "NetID": 7,
            "Caliber": 120.004,
            "Guidance": "",
            "Entity": object(),
            "Cache": {"last_updated": 123},
        }

        self.assertEqual(
            {
                "Type": "AP",
                "NetID": 7,
                "Caliber": 120.004,
                "Guidance": "",
            },
            project_snapshot(observed, self.spec),
        )

    def test_tolerance_accepts_small_calculation_difference(self):
        expected = {"Type": "AP", "NetID": 7, "Caliber": 120.0, "Guidance": ""}
        observed = {"Type": "AP", "NetID": 7, "Caliber": 120.006, "Guidance": ""}

        self.assertEqual([], compare_snapshot(expected, observed, self.spec))

    def test_public_schema_difference_is_reported(self):
        expected = {"Type": "AP", "NetID": 7, "Caliber": 120.0, "Guidance": ""}
        observed = {"Type": "APFSDS", "NetID": 8, "Caliber": 120.0, "Guidance": ""}

        differences = compare_snapshot(expected, observed, self.spec)

        self.assertEqual(2, len(differences))
        self.assertIn("Type", differences[0])
        self.assertIn("NetID", differences[1])

    def test_missing_public_field_fails_loudly(self):
        with self.assertRaisesRegex(KeyError, "NetID"):
            project_snapshot({"Type": "AP", "Caliber": 120.0, "Guidance": ""}, self.spec)

    def test_failure_output_does_not_dump_unrelated_state(self):
        message = snapshot_failure(self.spec, ["NetID: expected 7, observed 8"])

        self.assertIn("Snapshot failed: round schema remains compatible", message)
        self.assertIn("NetID", message)
        self.assertNotIn("Entity", message)


if __name__ == "__main__":
    unittest.main()
