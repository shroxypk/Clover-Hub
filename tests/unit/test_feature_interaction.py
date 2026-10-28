"""Cross-feature contracts: the modules must not fight each other or the game."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(name):
    return (ROOT / name).read_text(encoding="utf-8")


class FeatureInteractionTests(unittest.TestCase):
    def test_modules_shipped(self):
        runtime = read("src/runtime.lua")
        for name in ("minigames", "quest assist", "boss alerts", "auto parry"):
            self.assertIn(f'startModule("{name}"', runtime)
        # The removed aura must not come back through a module start.
        self.assertNotIn("kill_aura", runtime)
        self.assertNotIn("startModule(\"kill aura\"", runtime)
        self.assertFalse((ROOT / "src/kill_aura.lua").exists())
        # The build advisor was removed at the user's request; it must not return.
        self.assertNotIn("build_advisor", runtime)
        self.assertNotIn("Build Advisor", runtime)
        self.assertFalse((ROOT / "src/build_advisor.lua").exists())

    def test_only_minigames_send_key_and_move_input(self):
        owners = {}
        for path in (ROOT / "src").glob("*.lua"):
            text = path.read_text(encoding="utf-8")
            if "SendMouseMoveEvent" in text or "SendKeyEvent" in text:
                owners[path.name] = True
        self.assertEqual(sorted(owners), ["minigames.lua"])
        # Space taps happen only while a round is live and never while typing.
        mg = read("src/minigames.lua")
        self.assertIn("if not state.enabled or state.paused or UIS:GetFocusedTextBox() or not state.active then", mg)

    def test_parry_does_not_steal_input_during_a_minigame(self):
        parry = read("src/auto_parry.lua")
        self.assertIn("local minigames=G.VeyraMinigames", parry)
        self.assertIn("minigames.active==true or minigames.round~=nil", parry)
        self.assertIn("not wasAttacking and manager and myRoot and not busy", parry)
        # The button is handed straight back when a round starts.
        self.assertIn("if wasAttacking and (busy or (now>=resumeAt and not nearestInbound)) then", parry)

    def test_cursor_is_owned_by_one_module(self):
        for path in (ROOT / "src").glob("*.lua"):
            text = path.read_text(encoding="utf-8")
            if "MouseIconEnabled" in text:
                self.assertEqual(path.name, "runtime.lua", "MouseIconEnabled touched outside the panel")
        runtime = read("src/runtime.lua")
        # Saved and restored, never forced on permanently.
        self.assertIn("savedCursor=UIS.MouseIconEnabled", runtime)
        self.assertIn("UIS.MouseIconEnabled=savedCursor", runtime)

    def test_panel_never_takes_input_during_gameplay(self):
        runtime = read("src/runtime.lua")
        # A locked mouse belongs to the game. Touching Modal or the cursor while
        # it is locked makes the game drop character movement, so hover handling
        # must be gated on a free cursor and only fire on transitions.
        self.assertIn("UIS.MouseBehavior~=Enum.MouseBehavior.LockCenter", runtime)
        self.assertNotIn("header.Modal=inside", runtime)
        self.assertIn("if want~=hovering then", runtime)
        self.assertIn("header.Modal=want", runtime)
        # The hover flag must be cleared when the panel hides or the cursor goes.
        self.assertIn("hovering=false", runtime)

    def test_panel_hover_pauses_automation_only(self):
        runtime = read("src/runtime.lua")
        self.assertIn("if MG then MG.paused=true end", runtime)
        self.assertIn("if MG then MG.paused=false end", runtime)
        # No module may be paused from anywhere else.
        for name in ("minigames.lua", "quest_assist.lua", "boss_alerts.lua", "auto_parry.lua"):
            self.assertNotIn("MG.paused", read("src/" + name))

    def test_gui_layers_are_distinct(self):
        orders = {}
        for match in re.finditer(r"DisplayOrder[=:]\s*(\d+)", read("src/boss_alerts.lua")):
            orders["boss_alerts"] = match.group(1)
        for match in re.finditer(r"DisplayOrder[=:]\s*(\d+)", read("src/quest_assist.lua")):
            orders["quest_assist"] = match.group(1)
        for match in re.finditer(r"DisplayOrder[=:]\s*(\d+)", read("src/runtime.lua")):
            orders["runtime"] = match.group(1)
        self.assertEqual(sorted(orders), ["boss_alerts", "quest_assist", "runtime"])
        self.assertEqual(len(set(orders.values())), 3, "UI layers collide")

    def test_no_module_edits_game_owned_state(self):
        forbidden = ("WalkSpeed=", "JumpPower=", "AutoRotate=", "Settings.")
        for path in (ROOT / "src").glob("*.lua"):
            text = path.read_text(encoding="utf-8")
            for needle in forbidden:
                self.assertNotIn(needle, text, f"{path.name} writes game-owned state via {needle}")

    def test_broom_scaling_cannot_compound(self):
        runtime = read("src/runtime.lua")
        self.assertIn("if lastWritten and (raw-lastWritten).Magnitude<=0.001 then return false end", runtime)
        self.assertEqual(runtime.count("lv.VectorVelocity=boosted"), 1, "more than one velocity writer")
        self.assertIn("lastWritten=nil", runtime)

    def test_every_module_has_a_teardown(self):
        runtime = read("src/runtime.lua")
        for name in ("MG", "QA", "BA", "AP"):
            self.assertIn(f"if {name} and {name}.stop then {name}.stop() end", runtime)
        for path in (ROOT / "src").glob("*.lua"):
            text = path.read_text(encoding="utf-8")
            if path.name == "runtime.lua" or "G.Veyra" not in text or "function state.stop()" in text:
                continue
            self.fail(path.name + " registers a module without a stop()")


if __name__ == "__main__":
    unittest.main()
