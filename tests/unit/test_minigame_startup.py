"""Remote availability must not block other Veyra features."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
class StartupTests(unittest.TestCase):
 def test_remote_waits_are_isolated(self):
  for path in ("src/minigames.lua","main.lua"):
   source=(ROOT/path).read_text(encoding="utf-8")
   self.assertIn('local remotes=storage:WaitForChild("Remotes",15)',source)
   self.assertIn('task.spawn(function()',source)
   self.assertIn("if not state.alive then return end",source)
   self.assertNotIn('local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")',source)
if __name__=="__main__":
 unittest.main()
