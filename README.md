# Clover Hub

Minimal Auto Minigames + Auto Parry hub with drag, resize, minimize, and unload.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Clover-Hub/main/main.lua"))()
```

`main.lua` bundles all three runtime modules; no local source installation is needed.
Madium filesystem functions store learned timings in `CloverRPG/parry_learning_<placeid>.json`.
Rerun the loader to fetch the latest published version.

## Development

- `00_hub.lua`: UI and parry engine.
- `03_minigames_fix.lua`: harvest and mining automation.
- `06_parry_learning.lua`: persistent timing estimator.
- `build.py`: regenerate `main.lua` with `python build.py`.
- `publish.py`: after build and verification, publish with `python publish.py` (requires authenticated GitHub CLI).
- `test_parry_learning.luau`: estimator tests using the Luau CLI.
- `verify_hub.lua`: in-game UI and lifecycle verification.

Parry reliability is still under development. Compilation and UI checks do not
establish combat accuracy across all mobs. Unknown attack timings are estimates.
Captured game sources and session data are local development inputs, not release files.


## AI development handoff

To transfer **full Clover RPG project context** to another AI, start with **[AI_HANDOFF/README.md](AI_HANDOFF/README.md)**. This dedicated area includes the goal and history, verified client combat findings, current architecture, exact evidence-file manifest with hashes, known issues, priorities, and a copy/paste AI agent brief. The indexed private/game extracts are **not bundled in the public repo**; refer to the manifest when a source attachment is needed.
