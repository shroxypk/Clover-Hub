"""Ensure real broom speed scaling follows the game's velocity writes."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
class BroomRuntimeTests(unittest.TestCase):
 def test_velocity_listener_guard_and_lifecycle(self):
  for name in ("src/runtime.lua","main.lua"):
   src=(ROOT/name).read_text(encoding="utf-8")
   self.assertIn('GetPropertyChangedSignal("VectorVelocity")',src)
   self.assertIn("lastWritten=boosted",src)
   self.assertIn("(raw-lastWritten).Magnitude<=0.001",src)
   self.assertIn("detachBroomVelocity()",src)
   self.assertIn("H.testBroomWatcher=",src)
   self.assertIn("H.broomDebug.appliedWrites+=1",src)
 def test_diagnostic_exposes_actual_writes(self):
  src=(ROOT/"tools/diagnostics/broom_speed_probe.lua").read_text(encoding="utf-8")
  for key in ("watcherAttached","observedWrites","appliedWrites","lastBase","lastBoost"):
   self.assertIn("row."+key,src)
if __name__=="__main__":
 unittest.main()
