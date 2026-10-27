"""Broom speed investigation stays read-only."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
class BroomProbeTests(unittest.TestCase):
 def test_passive_probe(self):
  source=(ROOT/"tools/diagnostics/broom_speed_probe.lua").read_text(encoding="utf-8")
  for token in ("RunService.PreSimulation","RunService.PostSimulation",
                "h.broomSpeed","testBroomConn","linearVelocityFound",
                "Veyra_broom_speed_probe_","meanRequested","meanActual"):
   self.assertIn(token,source)
  for forbidden in (":FireServer(",":InvokeServer(","VectorVelocity=","h.broomSpeed=",
                    "SetAttribute(","SendKeyEvent("):
   self.assertNotIn(forbidden,source)
if __name__=="__main__":
 unittest.main()
