"""Guard the core auto-parry assumption with measured data.

`tests/data/parry_marker_residuals.json` was produced by passively watching
replicated fights in a live server (`tools/observe_parry.lua`, summarised by
`tools/summarise_parry_obs.py`): for every melee impact we recorded the
attacking animation, the marker our profile would schedule on, and the
wall-clock time the damage actually landed. No movement and no player attacks
were involved.

The residual is `impact_time - marker_time`. If the profiles are right, the
residuals are tightly centred on zero: that is what makes a 0.25s parry window
usable at all.
"""
import json
import re
import statistics
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "tests/data/parry_marker_residuals.json"
PROFILES = ROOT / "src/parry_profiles.lua"


def load_samples():
    return json.loads(DATA.read_text(encoding="utf-8"))["samples"]


def load_profiles():
    text = PROFILES.read_text(encoding="utf-8")
    table = {}
    for match in re.finditer(r'\["(\d+)"\]=\{(.*?)\},?\n', text):
        body = match.group(2)
        hits = re.search(r"hits=\{([^}]*)\}", body)
        table[match.group(1)] = [float(v) for v in hits.group(1).split(",") if v.strip()]
    return table


class MarkerResidualTest(unittest.TestCase):
    def setUp(self):
        self.samples = load_samples()
        self.profiles = load_profiles()

    def test_enough_evidence(self):
        self.assertGreaterEqual(len(self.samples), 40)

    def test_impacts_land_on_markers(self):
        residuals = [abs(s["delta"]) for s in self.samples]
        self.assertLessEqual(statistics.median(residuals), 0.05)
        ordered = sorted(residuals)
        p90 = ordered[int(len(ordered) * 0.9) - 1]
        self.assertLessEqual(p90, 0.2)
        self.assertLessEqual(max(residuals), 0.35)

    def test_observed_assets_are_covered(self):
        missing = sorted({s["asset"] for s in self.samples} - set(self.profiles))
        self.assertEqual(missing, [])

    def test_observed_marker_present_in_profile(self):
        for sample in self.samples:
            hits = self.profiles[sample["asset"]]
            # sample["marker"] is wall-clock time; profiles store animation time.
            animation_time = sample["marker"] * sample.get("speed", 1)
            closest = min(hits, key=lambda hit: abs(hit - animation_time))
            self.assertLessEqual(abs(closest - animation_time), 0.02, sample)


if __name__ == "__main__":
    unittest.main()
