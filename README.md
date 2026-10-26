# Veyra

A lightweight Luau utility panel with optional combat timing assistance, mining/harvesting minigames, and broom speed controls.

**All features start disabled.** Use the panel to enable them. Right Ctrl hides the UI, Delete minimizes it, and Insert cycles window sizes. Drag the header or edges to move and resize. Use **Unload** to stop the script.

## Start

Run the bundled [main.lua](main.lua) in a compatible environment. The direct loader below uses the repository's current GitHub URL (update it if the repository is renamed):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Clover-Hub/main/main.lua"))()
```

## Layout

- `src/` — maintained Luau modules and animation data
- `main.lua` — generated single-file release
- `tools/` — build, publishing, and metadata export
- `tests/unit/` — offline unit and build tests
- `tests/runtime/` — optional in-game verification scripts
- `docs/` — research notes

Build with `python tools/build.py` and check with `python tools/build.py --check`. GitHub Actions runs build, compilation, and unit checks.

Learned settings and diagnostics are stored under `Veyra/` when filesystem access is available. Timing estimates and offline tests **do not guarantee** successful defenses or anti-cheat compatibility.
