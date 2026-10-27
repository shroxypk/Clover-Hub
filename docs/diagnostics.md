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
