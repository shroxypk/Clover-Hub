"""Checks the animation-marker importer's classification rules."""
import unittest

from tools import import_parry_assets as importer


def record(asset, name, path, markers, length=1.0):
    return {
        "id": asset, "name": name, "path": path, "length": length,
        "markers": [{"n": marker, "t": time} for marker, time in markers],
    }


class ImportTests(unittest.TestCase):
    def test_impact_markers_only(self):
        data = {"records": [
            record("1", "Wolf1", "ReplicatedStorage.Animations.Server.Wolf1",
                    [("Velocity", 0.5), ("HitWindow", 0.9)], 1.2),
            record("2", "Walk", "ReplicatedStorage.Animations.Movement.Walk",
                    [("LeftFootDown", 0.5)], 1.0),
            record("3", "ChargeOnly", "ReplicatedStorage.Animations.Server.ChargeOnly",
                    [("Charge", 0.5), ("WindUp", 0.8)], 1.0),
            record("4", "Staggered", "ReplicatedStorage.Animations.NPCS.AlkeBoss.Staggered",
                    [("Window", 1.6)], 2.0),
        ]}
        text, kept, skipped = importer.build(data)
        self.assertEqual((kept, skipped), (1, 3))
        self.assertIn('["1"]={name="Wolf1",length=1.200000,hits={0.900000}}', text)
        self.assertNotIn("readfile", text)

    def test_feint_gate_and_merging(self):
        data = {"records": [
            record("1", "Sword1", "ReplicatedStorage.Animations.Server.Sword1",
                    [("OpenFeint", 0.1), ("CloseFeint", 0.4), ("HitWindow", 0.45),
                     ("AnimationEnd", 0.6)], 0.7),
            record("2", "HeavyStaff", "ReplicatedStorage.Animations.Server.HeavyStaff",
                    [("Swept", 0.4), ("HitWindow", 1.233), ("SlamHit", 1.3)], 1.6),
            record("3", "Grab", "ReplicatedStorage.Animations.Server.HeavyTrident",
                    [("GrabWindow", 1.1), ("SlamWindow", 2.7)], 3.5),
        ]}
        text, kept, _ = importer.build(data)
        self.assertEqual(kept, 3)
        self.assertIn('gate=0.400000', text)
        # Impact markers within the merge window collapse to one press.
        self.assertIn('hits={1.233000}', text)
        # Grab windows are never treated as hits; the slam still is.
        self.assertIn('name="Grab",length=3.500000,hits={2.700000}', text)

    def test_rejects_records_without_hits(self):
        with self.assertRaises(ValueError):
            importer.build({"records": [
                record("1", "Idle", "ReplicatedStorage.Animations.Server.Idle",
                       [("HitWindow", 0.5)], 1.0),
            ]})


if __name__ == "__main__":
    unittest.main()
