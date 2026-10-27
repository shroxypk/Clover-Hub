"""Regression checks for Veyra's standalone release."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import build as builder


class BuildTests(unittest.TestCase):
    def test_reproducible_build_and_stale_detection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            src = root / "src"
            src.mkdir()
            (src / "runtime.lua").write_text(
                'loadstring(readfile("Veyra/src/minigames.lua"),"minigames.lua")()\n',
                encoding="utf-8",
            )
            (src / "minigames.lua").write_bytes(b"return {}\r\n")
            with patch.object(builder, "ROOT", root):
                builder.build()
                original = (root / "main.lua").read_bytes()
                self.assertNotIn(b"\r", original)
                builder.build(check=True)
                (src / "minigames.lua").write_text("return {changed=true}\n", encoding="utf-8")
                with self.assertRaises(SystemExit):
                    builder.build(check=True)
                self.assertEqual((root / "main.lua").read_bytes(), original)
                builder.build()
                builder.build(check=True)
                self.assertNotEqual((root / "main.lua").read_bytes(), original)

    def test_release_has_only_retained_features(self):
        source = (builder.ROOT / "src/runtime.lua").read_text(encoding="utf-8")
        release = (builder.ROOT / "main.lua").read_text(encoding="utf-8")
        for feature in ("Auto Minigames", "Broom Speed", "VeyraCursor", "Quest Assistance"):
            self.assertIn(feature, source)
            self.assertIn(feature, release)
        for removed in ("Auto Parry", "BlockInput", "CanParry", "State_Parrying",
                        "attack_catalog", "attack_seed", "parry_learning",
                        "attack_inference", "parry_timing", "StateManager"):
            self.assertNotIn(removed, source)
            self.assertNotIn(removed, release)
        self.assertEqual(release.count("function __startQuestAssist()"), 1)
        self.assertIn("VeyraQuestAnchors", release)
        quest = (builder.ROOT / "src/quest_assist.lua").read_text(encoding="utf-8")
        for capability in ("trackedQuest()", "HintQuest", "HintTask",
                           "Track a quest", "VeyraQuestGuide"):
            self.assertIn(capability, quest)
        self.assertIn("o:GetAttribute(\"Gathered\")~=true", quest)
        self.assertIn("state.generation~=generation", quest)
        self.assertNotIn("local function availableQuests()", quest)
        self.assertNotIn("state.cycle", quest)
        self.assertIn("state.selected=nil", quest)
        self.assertIn('FindFirstChild("QuestIndicators")', quest)
        self.assertIn('indicator:GetAttribute("status")', quest)
        self.assertIn("if hasStatus then return nil end", quest)
        self.assertIn("if active and active~=quest then return nil end", quest)
        self.assertEqual(release.count("function mine()"), 1)
        self.assertEqual(release.count("function harvest()"), 1)


if __name__ == "__main__":
    unittest.main()
