"""Contracts for the auto gather dropdown: natural movement, real node data."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class AutoGatherTests(unittest.TestCase):
    def setUp(self):
        self.text = (ROOT / "src/auto_gather.lua").read_text(encoding="utf-8")

    def test_reads_the_games_node_registry(self):
        for needle in ("ProfessionNodes", 'GetAttribute("Position")', 'GetAttribute("Kind")',
                       'GetAttribute("Available")'):
            self.assertIn(needle, self.text)

    def test_moves_by_walking_not_by_teleport_or_speed(self):
        self.assertIn("humanoid:MoveTo(", self.text)
        for forbidden in ("WalkSpeed", "JumpPower", "JumpHeight", "CFrame=",
                          "PivotTo", "SetPrimaryPartCFrame", "LinearVelocity",
                          "PlatformStand", "MoveDirection="):
            self.assertNotIn(forbidden, self.text, f"Auto gather touches {forbidden}")

    def test_opens_the_games_own_prompt(self):
        self.assertIn("ProximityPrompt", self.text)
        self.assertIn("prompt:InputHoldBegin()", self.text)
        self.assertIn("prompt:InputHoldEnd()", self.text)
        # No remote calls of its own.
        for forbidden in ("FireServer", "InvokeServer", "SetAttribute(", "FireAllClients"):
            self.assertNotIn(forbidden, self.text, f"Auto gather touches {forbidden}")

    def test_waits_for_despawned_nodes_instead_of_spinning(self):
        self.assertIn('"Waiting for respawn', self.text)
        self.assertIn('GetAttribute("Available")==true', self.text)
        self.assertIn("blacklist", self.text)
        # It must also notice a node that is already picked clean.
        self.assertIn("GetAttribute(\"Gathered\")==true", self.text)

    def test_hands_over_to_the_solver_and_yields_to_the_player(self):
        self.assertIn("solverBusy()", self.text)
        self.assertIn("solver.isWorking()", self.text)
        self.assertIn("state.manualUntil", self.text)
        self.assertIn("UIS:IsKeyDown(", self.text)
        self.assertIn("playerSteering(", self.text)
        self.assertIn("GetFocusedTextBox", self.text)

    def test_teardown_releases_everything(self):
        self.assertIn("function state.stop()", self.text)
        self.assertIn("G.VeyraAutoGather=nil", self.text)
        self.assertIn("connection:Disconnect()", self.text)

    def test_dropdown_is_wired_into_the_panel(self):
        runtime = (ROOT / "src/runtime.lua").read_text(encoding="utf-8")
        self.assertIn('startModule("auto gather"', runtime)
        self.assertIn("H.gather=G.VeyraAutoGather", runtime)
        # Auto Minigames stays its own toggle; gathering is two dropdowns.
        self.assertIn('toggle("Auto Minigames"', runtime)
        self.assertIn('gatherToggle("harvest","Auto Harvest"', runtime)
        self.assertIn('gatherToggle("ore","Auto Mine"', runtime)
        self.assertIn("if H.gather and H.gather.stop then H.gather.stop() end", runtime)
        self.assertIn('H.gather.setMode(kind,on)', runtime)

    def test_picks_the_best_node_the_gear_can_clear(self):
        # Tool power comes from the game's own registries.
        for needle in ("SickleRegistry", "PickaxeRegistry", "CropRegistry", "OreRegistry"):
            self.assertIn(needle, self.text)
        # Highest power wins, distance only breaks ties.
        self.assertIn("power>bestPower", self.text)
        self.assertIn("power==bestPower and distance<bestDistance", self.text)
        # Nodes above the tool's power are never selected.
        self.assertIn("node.power>cap", self.text)

    def test_walks_around_obstacles(self):
        self.assertIn("workspace:Raycast(", self.text)
        self.assertIn("navigate(", self.text)
        self.assertIn("nav.detourUntil", self.text)
        self.assertIn("humanoid.Jump=true", self.text)
        # Body-height fan probe plus a real hop test, not a single flat ray.
        self.assertIn("local FAN={0,12,-12,24,-24", self.text)
        self.assertIn("local BODY={0.2,1.3,2.4}", self.text)
        self.assertIn("local function headroom(", self.text)
        self.assertIn("local function obstacleTop(", self.text)
        self.assertIn("local function hop(", self.text)
        # Rooms and corridors need a real route, not just a local fan.
        self.assertIn("PathfindingService", self.text)
        self.assertIn(":ComputeAsync(", self.text)
        self.assertIn("local function followPath(", self.text)
        self.assertIn("nav.points=nil", self.text)
        # Cave tunnels are tighter than the map: slim the agent before giving up.
        self.assertIn("local PATH_RADII={1.6,1.1,0.8}", self.text)
        # A prompt already in range is pressed instead of walking further.
        self.assertIn("local canPress=", self.text)
        self.assertIn("if distance>STOP and not canPress then", self.text)

    def test_waits_for_the_games_own_respawn_timer(self):
        self.assertIn("config:GetAttribute(\"RespawnAt\")", self.text)
        self.assertIn("workspace:GetServerTimeNow()", self.text)
        self.assertIn("local function respawnIn(", self.text)
        self.assertIn("Waiting · %s respawning %ds", self.text)

    def test_types_can_be_selected_per_profession(self):
        self.assertIn("function state.catalog(", self.text)
        self.assertIn("function state.setType(", self.text)
        self.assertIn("function state.isTypeOn(", self.text)
        self.assertIn("typeEnabled(kind,node.item)", self.text)
        runtime = (ROOT / "src/runtime.lua").read_text(encoding="utf-8")
        self.assertIn("typePicker(options,kind,1", runtime)
        self.assertIn("H.gather.setType(kind,entry.name", runtime)


if __name__ == "__main__":
    unittest.main()
