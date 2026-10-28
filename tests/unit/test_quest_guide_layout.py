"""Quest HUD layout and lifecycle contracts for the persistent tracker."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

class QuestGuideLayoutTests(unittest.TestCase):
    def test_persistent_tracker_and_collapsible_card(self):
        for path in ("src/quest_assist.lua", "main.lua"):
            source = (ROOT / path).read_text(encoding="utf-8")
            self.assertIn('Name="Collapse"', source)
            self.assertIn('Name="ProgressTrack"', source)
            self.assertIn('Name="Direction"', source)
            self.assertIn("local function clearMarkers()", source)
            self.assertIn("local function renderGuide(info)", source)
            self.assertIn("if state.selected then clearMarkers() end", source)
            self.assertIn("local fraction,progressCaption=questProgress(selected,screenProgress,returning)",source)
            self.assertIn('stage=stale and "DONE" or "IDLE"', source)
            self.assertIn("objective=nearest.label", source)
            self.assertIn("return a.distance<b.distance", source)
            self.assertNotIn("if not selected then\n  state.selected=nil\n  state.phase=nil\n  useQuestTextRoot(nil)\n  clearVisuals()",source)

    def test_progress_uses_task_attributes(self):
        source = (ROOT / "src/quest_assist.lua").read_text(encoding="utf-8")
        self.assertIn('t:GetAttribute("TaskMax")',source)
        self.assertIn('t:GetAttribute("TaskProgress")',source)
        self.assertIn("if returning then fraction=1 end",source)
        self.assertIn("if progressTween then progressTween:Cancel() end",source)

    def test_broom_limit_does_not_rearm(self):
        source = (ROOT / "src/runtime.lua").read_text(encoding="utf-8")
        self.assertIn("if nextValue==value then return end",source)

if __name__ == "__main__":
    unittest.main()
