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

Toggle **Quest Assistance** for a small lower-right guidance HUD. It reads the game's currently tracked quest tasks, uses quest-provided locations and matching loaded NPCs/objects, and displays up to four nearby objective markers (two labels). Combat objectives get area guidance when available; crafting uses known stations. Unknown locations are explicitly reported rather than guessed. Streaming or unnamed objectives may not be locatable. No quest is auto-completed. Disable the toggle or Unload to remove markers and indexing connections.
