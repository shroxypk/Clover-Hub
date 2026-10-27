"""Regression checks for safer parry calibration and outcomes."""
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

class ParryDiagnosticTests(unittest.TestCase):
    def test_observed_grant_required_for_calibration(self):
        for path in ("src/auto_parry.lua","main.lua"):
            code=(ROOT/path).read_text(encoding="utf-8")
            self.assertIn("calibration pulse; waiting for grant",code)
            self.assertIn("state.lead=lead state.learned+=1 state.calibrated=true",code)
            self.assertIn("state.unobservedGrants+=1",code)
            self.assertIn("activeAttempt.granted==true",code)
            self.assertIn("state.successByAsset[id]",code)
            self.assertNotIn("state.bias[activeAttempt.asset]=",code)

if __name__=="__main__":
    unittest.main()
