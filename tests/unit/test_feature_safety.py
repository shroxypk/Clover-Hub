"""Regression guards for quest identity and minigame reparenting."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
class FeatureSafetyTests(unittest.TestCase):
 def test_quest_selection_uses_game_tracking_key(self):
  for name in ("src/quest_assist.lua","main.lua"):
   text=(ROOT/name).read_text(encoding="utf-8")
   self.assertIn('local tracking=folder:GetAttribute("Tracking")',text)
   self.assertIn("local quest=known[norm(tracking)]",text)
 def test_mining_fallback_resets_between_reused_sessions(self):
  for name in ("src/minigames.lua","main.lua"):
   text=(ROOT/name).read_text(encoding="utf-8")
   self.assertEqual(text.count("resetMineTiming()"),3)
   self.assertIn('if kind == "mine" then state.round = nil resetMineTiming()',text)
 def test_return_indicator_is_actual_match(self):
  for name in ("src/quest_assist.lua","main.lua"):
   text=(ROOT/name).read_text(encoding="utf-8")
   self.assertIn("activeIndicator=indicator",text)
   self.assertIn("return active,activeIndicator",text)
   self.assertNotIn("local activeIndicator=indicators:FindFirstChild(active.Name)",text)
 def test_stale_gui_children_are_not_used(self):
  for name in ("src/minigames.lua","main.lua"):
   text=(ROOT/name).read_text(encoding="utf-8")
   self.assertIn("if not ring then return true end",text)
   self.assertIn("if not arena then return true end",text)
   self.assertIn("cache.spinner=nil",text)
   self.assertIn("cache.basin=nil",text)
   self.assertIn("and 10 or 2",text)
if __name__=="__main__":
 unittest.main()

