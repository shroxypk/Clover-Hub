# Veyra

A lightweight Luau utility panel for **Auto Minigames** (mining and harvesting), adjustable **Broom Speed**, and optional **Quest Assistance**. Auto Parry has been removed.

All automated and guidance options start disabled; **1× broom speed** leaves normal movement unchanged.

## Load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/main.lua"))()
```

**Controls:** Right Ctrl shows/hides the panel, Delete minimizes it, Insert changes its size. Drag the header or edges to move/resize. **Unload** disconnects the script.

## Development

- `src/` — maintained interface, broom scaling, and minigame logic
- `main.lua` — generated single-file release
- `tools/` — build and publishing
- `tests/` — build tests and optional in-game checks

Rebuild with `python tools/build.py`, verify with `python tools/build.py --check`, and run offline tests with `python -m unittest discover -s tests/unit`.

The minigame worker is active only during sessions, and broom scaling only runs above 1×. Automated tests do not replace checking behavior in the game.

## Quest Assistance

Toggle **Quest Assistance** for a small lower-right guidance HUD. It **only follows quests explicitly tracked in the game** and automatically switches guidance when the tracked quest changes. There is no fallback to unrelated unfinished quests and no manual quest cycling. When tracking cannot be identified, the guide draws no markers and displays a status in Veyra rather than guessing. It uses quest-provided positions, exact loaded NPC/item matches, and optional HintQuest/HintTask markers. Up to four world markers (two labels) are shown for **only the tracked quest**. Combat objectives get area guidance when available; crafting uses known stations. Unknown locations are explicitly reported rather than guessed. Streaming or unnamed objectives may not be locatable. No quest is auto-completed. Disable the toggle or Unload to remove markers and indexing connections.

## Quest compatibility diagnostics

The guide supports client-visible incomplete quests when the game exposes objective names, hints or positions. An October 2026 Madium diagnostic demonstrated 36 local quest records but **no tracked quest UI rows**. Because arbitrary-quest guidance is unwanted, the guide waits for a verifiable tracked quest instead of selecting any unfinished quest. Not every quest exposes both, and client-side streaming can hide faraway NPCs/items. **No universal quest-coverage or anti-cheat guarantee is possible without in-game verification.**

To capture a read-only report for a problematic quest, track it in the journal and run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/tools/quest_diagnostic.lua"))()
```

The diagnostic uses available client quest records, tracking UI labels, and matching loaded world objects. It does not fire remotes, modify progress, or upload anything. When supported by the executor, it saves `Veyra_quest_diagnostic.json` in the executor workspace; otherwise it copies JSON to the clipboard or prints chunks. Send the JSON file to the maintainer with the quest tracked. Capture separate reports for unusual quest types (collection, NPC search, delivery, combat, crafting, multi-object search), ideally before and after objective completion. The report contains in-game quest names, objective progress, and world coordinates; review it before sharing.

### Diagnose the tracked-quest selection

If the guide says to track a quest even when one is clearly tracked in the game's journal, run this **while a single quest is actively tracked** (then close J):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/tools/quest_tracking_diagnostic.lua"))()
```

Upload `Veyra_tracking_diagnostic.json`. This read-only snapshot includes **quest-related interface names/text, selection flags and UI hierarchy** to identify the actual tracker location. It does not read chat messages, send data, fire remotes or change progress. Review the file before sharing.
