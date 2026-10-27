# Veyra

A lightweight Luau utility panel for **Auto Minigames** (mining and harvesting), adjustable **Broom Speed**, and optional **Quest Assistance**. Auto Parry has been removed.

Every feature starts disabled; **1× broom speed** leaves normal movement unchanged.

## Load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/main.lua"))()
```

**Controls:** Right Ctrl shows/hides the panel, Delete minimizes it, Insert changes its size. Drag the header or edges to move/resize. **Unload** disconnects the script.

## Features

- **Auto Minigames** — reads the game's own round data and presses Space / moves the mouse at the right moment. The solver thread exists only while a minigame session is open; idle cost is zero.
- **Broom Speed** — 1×–3× horizontal multiplier in 0.25 steps, capped at 240 studs/s, vertical velocity untouched. The scaler connects only while mounted and re-arms after the game's own flight step on every mount, so it is never overridden. 1× disconnects completely.
- **Quest Assistance** — a small lower-right HUD plus world markers for the quest the game itself tracks. See below.

## Quest Assistance

Toggle **Quest Assistance** to follow the quest the game tracks. It reads `PlayerGui.QuestIndicators` status flags (confirmed in an in-game diagnostic) and switches guidance when tracking changes; it never picks an arbitrary unfinished quest and never cycles quests. It reads quest-provided positions, exact loaded world-object/NPC matches, `HintQuest`/`HintTask` markers, and the visible quest HUD for phase and progress. Return flags switch the guide to the quest giver. At most four markers (two labels) are drawn, refreshed every 0.75 s.

Objective types are labelled: collect/gather, crafting (nearest cauldron for brewing), delivery/visit, and combat. Combat objectives mark the **actual nearby mobs** — up to two, coloured orange, with distance — and only living Humanoid models, so map props that share a mob's name are ignored. Plural and adjective names are resolved ("Hunt wild wolves" → `Wolf`, "Exterminate Mushknights" → `Mushknight`, "Eliminate thieves" → `Thief`). Unknown or streamed-out locations are reported in the HUD instead of guessed. A tracked flag the game leaves on a finished quest is ignored, and the HUD says to track another quest. It never completes quests, fires remotes, or writes game state. Disable the toggle or Unload to remove all markers and indexing.

No universal quest coverage or anti-cheat guarantee is possible; the world must stream the target for it to be found.

## Development

- `src/` — interface, broom scaling, minigame, and quest-guide logic
- `main.lua` — generated single-file release
- `tools/` — build, publish, and optional read-only diagnostics
- `tests/` — build regression tests and optional in-game checks

Rebuild with `python tools/build.py`, verify with `python tools/build.py --check`, run offline tests with `python -m unittest discover -s tests/unit`.

## Diagnostics (optional, read-only)

These one-shot scripts never fire remotes, change progress, or upload anything. They save a JSON report in the executor workspace (or copy it to the clipboard). Review any report before sharing it.

| Script | Purpose |
| --- | --- |
| `tools/quest_diagnostic.lua` | Quest records, HUD text, and matching loaded world objects |
| `tools/quest_tracking_diagnostic.lua` | Which quest the game actually tracks (indicator flags, UI hierarchy) |
| `tools/character_diagnostic.lua` | Client-visible character stats, equipped tools, tracked-quest phase |
| `tools/profession_snapshot.lua` | Before/after profession XP snapshots |
| `tools/xp_lab.lua` | Marks actions, records profession XP changes over a session |
| `tools/deep_diagnostic.lua` | One 30-second combined profession/progression capture |

Run any of them with:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/tools/quest_diagnostic.lua"))()
```