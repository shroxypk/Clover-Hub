# Clover Hub

Minimal Auto Minigames + Auto Parry hub with drag, resize, minimize, and unload.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Clover-Hub/main/main.lua"))()
```

`main.lua` bundles the runtime modules and animation timing catalog; no local source installation is needed.
Madium filesystem functions store learned timings in `CloverRPG/parry_learning_<placeid>.json`.
Rerun the loader to fetch the latest published version.

## Development

- `00_hub.lua`: UI and parry engine.
- `03_minigames_fix.lua`: harvest and mining automation.
- `06_parry_learning.lua`: persistent timing estimator.
- `07_attack_catalog.lua`: read-only animation asset discovery and disk cache.
- `08_parry_timing.lua`: animation-speed-aware hit-window scheduling.
- `attack_seed.lua`: 339 inspected animation assets, including 139 with explicit HitWindow markers.
- `export_seed.py`: rebuild the seed from the executor's captured catalog.
- `build.py`: regenerate `main.lua` with `python build.py`.
- `publish.py`: after build and verification, publish with `python publish.py` (requires authenticated GitHub CLI).
- `test_parry_learning.luau`: estimator tests using the Luau CLI.
- `test_parry_timing.luau`: speed, late-window, and multi-hit scheduling checks.
- `verify_hub.lua`: in-game UI and lifecycle verification.

The hub uses PlayerGui so ordinary event callbacks can access its UI without
Plugin capability errors. Unloading or reloading saves the latest bounded combat
diagnostics to `CloverRPG/parry_diagnostics_<placeid>.json`, including state-gated
attempts and missed scheduling windows.

The catalog covers shared weapon animations, mobs, bosses, and skills without
requiring a fight against each enemy. New animation assets are inspected automatically.
Explicit HitWindow markers take priority over learned/default timings. Multiple
markers are scheduled separately, with the game's CanParry state gate and one
Block Input per session. Other contact-like markers are labeled estimates.

Parry reliability is still under development. Compilation and UI checks do not
establish combat accuracy across all mobs. A marker does not establish parryability
or projectile arrival time. Unknown attack timings remain estimates, and cooldowns,
server-only logic, and latency can prevent a parry.
Captured game sources and session data are local development inputs, not release files.
