# Optional diagnostics

Read-only inspection scripts for `tools/diagnostics/`. None of them fire a
remote, change progress, or upload anything: they read client state and print a
JSON report, which is saved in the executor workspace (or copied to the
clipboard when the executor has no filesystem).

| Script | Purpose |
| --- | --- |
| `quest_diagnostic.lua` | Quest records, HUD text, and matching loaded world objects |
| `quest_tracking_diagnostic.lua` | Which quest the game actually tracks (indicator flags, UI hierarchy) |
| `character_diagnostic.lua` | Client-visible character stats, equipped tools, tracked-quest phase |
| `profession_snapshot.lua` | Before/after profession XP snapshots |
| `xp_lab.lua` | Marks actions, records profession XP changes over a session |
| `deep_diagnostic.lua` | One 30-second combined profession/progression capture |
| `parry_state_probe.lua` | Every character attribute plus a 4 s time series of the parry/state ones |
| `smoke_test.lua` | Read-only state of all running Veyra modules, visible minigames, tracked quest flags, and recent parry diagnostics |
| `mechanics_probe.lua` | 35-second passive capture of local movement physics, combat-state attributes, stamina/mana/cooldown values, equipped tools, relevant replicated module names, and client scripts |
| `broom_speed_probe.lua` | 24-second passive A/B flight check: hub slider state, scaler armed state, PreSimulation/PostSimulation velocity, and actual horizontal speed |

Run one with:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/tools/diagnostics/quest_diagnostic.lua"))()
```

Review any report before sharing it.

`tools/observe_parry.lua` is not a diagnostic: it is the passive recorder used to
maintain the parry timing dataset. See [parry.md](parry.md).

### After loading Veyra

To check module startup and parry status without sending any game inputs, run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/tools/diagnostics/smoke_test.lua"))()
```

The output is printed and saved as `Veyra_smoke_test.json` when Madium supports `writefile`. Run it while a quest or minigame is active if that feature is the issue. It cannot prove server-side success; report only observed client state.

### Mechanics / non-autofarm research

`mechanics_probe.lua` passively records 35 seconds of client-visible state. It does not execute remotes, change character values, or invoke unknown modules. While it runs, naturally try a dash, attack, block, cast a spell, and (if desired) fly on the broom. It saves `Veyra_mechanics_probe_<timestamp>.json` if the executor provides `writefile`, or copies the final JSON when clipboard access is available. Review the file before sharing. The capture identifies possible client-side control points but does **not** establish any server vulnerability or persistent exploit.

### Broom speed verification

Load Veyra first, mount the broom, then run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/tools/diagnostics/broom_speed_probe.lua"))()
```

Stay moving on the broom at 1x for roughly 10 seconds, change **Broom Speed** to 2x using the hub's Plus button, and keep moving for the remainder of the 24-second capture. Upload `Veyra_broom_speed_probe_<timestamp>.json`. The probe only reads state; it does not change velocity or the hub setting. `PreSimulation` and `PostSimulation` comparisons help identify callback ordering or corrections. The file contains movement speeds, not world coordinates or account identifiers.

### Broom scaler correction (2026-10-27)

The original PreSimulation-only scaler stayed at the game's 80-stud/s baseline despite a working 2x slider. The updated scaler observes writes to the broom LinearVelocity and scales those writes. The probe now also logs `watcherAttached`, `observedWrites`, `appliedWrites`, `lastBase`, and `lastBoost` so real Madium results can confirm both attempted changes and actual movement. An apparent local boost does not establish server acceptance.
