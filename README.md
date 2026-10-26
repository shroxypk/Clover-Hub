# Clover Hub

Combat assist + Auto Minigames hub with drag, resize, minimize, and unload.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Clover-Hub/main/main.lua"))()
```

`main.lua` bundles the runtime modules and animation timing catalog; no local source installation is needed.
Madium filesystem functions store learned timings in `CloverRPG/parry_learning_<placeid>.json`.
Rerun the loader to fetch the latest published version.

## Combat controls

- **Auto Parry**: timed block pulses for predicted incoming windows. **Off by default.**
- **Auto Minigames**: mining and harvesting automation. **Off by default.**
- **Broom Speed**: flight velocity multiplier (1x-3x, 0.25 steps); 1x is untouched game behavior.

Everything starts off: enable what you want after loading. Nothing activates
on its own.

Keys: `RightCtrl` hide panel, `Delete` minimize, drag header to move, drag the
bottom/right edges or corner grip to resize.

That is the entire control surface. Dodge and block fallbacks were removed:
when `CanParry` is false (cooldown, attacking, stunned), the assist waits
instead of substituting another defense. Parry requires an equipped combat
weapon and respects the game's action/cooldown gates.
Broom speed scales the client-owned flight `LinearVelocity` after the game's
own PreSimulation write each frame, so climb, ceiling, stall, and no-fly-zone
behavior stay with the game; the scaler disconnects entirely at 1x.
Minigame automation is event-driven: remote Open events wake a worker
connection, Close events (or a 2-second GUI-missing safety net) put it back to
sleep. Between minigames no worker connection runs at all - the
"Waiting for minigame" label is idle, not polling.
The game may naturally grant a parry when a block pulse begins.
Manual attacks and roll presses receive a brief input-priority gap while their
states replicate. The assist yields to your configured Block binding, text input,
and hub interaction; it does not cancel attacks to force a defensive action.
Missed parries do not classify attacks as unparryable.
A menu opened mid-swing hands the swing back for re-evaluation after the pause;
already-playing attacks are inspected when a mob is first watched, including
mid-swing streaming; passed hit windows are still rejected.

## Development

- `00_hub.lua`: UI and parry engine.
- `03_minigames_fix.lua`: harvest and mining automation.
- `06_parry_learning.lua`: persistent timing estimator.
- `07_attack_catalog.lua`: read-only animation asset discovery and disk cache.
- `08_parry_timing.lua`: animation-speed-aware hit-window scheduling.
- `09_attack_inference.lua`: prior timing estimates based on known attack windows.
- `attack_seed.lua`: 360 inspected animation assets, including 145 with explicit HitWindow markers.
- `export_seed.py`: rebuild the seed from the executor's captured catalog.
- `build.py`: regenerate `main.lua` with `python build.py`, or run `python build.py --check` to verify it without changing files.
- `publish.py`: after build and verification, publish with `python publish.py` (requires authenticated GitHub CLI; refuses a stale bundle).
- `test_parry_learning.luau`: estimator tests using the Luau CLI.
- `test_parry_timing.luau`: speed, late-window, and multi-hit scheduling checks.
- `verify_hub.lua`: in-game UI and lifecycle verification.
- `verify_defense.lua`: actual scheduler replay with recorded block outputs.
- `verify_catalog.lua`: deterministic asset retry, classification, and cache-precedence replay.

The hub uses PlayerGui so ordinary event callbacks can access its UI without
Plugin capability errors. Unloading or reloading saves the latest bounded combat
diagnostics to `CloverRPG/parry_diagnostics_<placeid>.json`, including state-gated
attempts and missed scheduling windows.

The catalog covers shared weapon animations, mobs, bosses, and skills without
requiring a fight against each enemy. New animation assets are inspected automatically.
Explicit HitWindow markers take priority over learned/default timings. Multiple
markers are scheduled separately, with the game's CanParry state gate and one
Block Input per session. Other contact-like markers are labeled estimates.
Newly inspected hit markers replace provisional timing for still-active swings
before a defense has been requested. Asset failures receive at most three attempts
per session; stale cached estimates cannot replace explicit bundled markers.

GitHub Actions checks Python syntax, verifies the generated bundle, compiles the
maintained Luau modules, and runs the pure Luau tests on pushes and pull requests.
These automated checks do not replace executor-specific or in-game verification.

Parry reliability is still under development. Compilation and UI checks do not
establish combat accuracy across all mobs. A marker does not establish parryability
or projectile arrival time. Unknown attack timings remain estimates, and cooldowns,
server-only logic, and latency can prevent a parry.

## Reliability notes

When an exact HitWindow is unavailable, the hub uses learned timing, known
contact markers, and an animation-category prior derived from known HitWindow
timestamps. Newly available clip lengths trigger rescheduling of pending swings.
Both Humanoid and Animator playback events are watched; listeners and streamed
NPC models are cleaned up promptly. Replaced Humanoids/Animators, departed
players, and removed NPC containers release their obsolete listeners.
The hub avoids unnecessary container scans and redundant catalog cache writes.
New animation assets under NPCs are indexed.
The modern AnimationClipProvider is preferred with a compatible legacy fallback.
Network RTT is sampled at low frequency and live parry-state acknowledgements
use bounded median smoothing. Unload and respawn both clean old character listeners.
A completed unknown animation may be extracted again once when it becomes an
active attack; in-flight and permanently failed requests remain bounded.

These adjustments are code-level improvements, not a measured perfect-parry rate.
The script cannot guarantee that a third-party game won't detect automation,
nor override authoritative cooldown, distance, or anti-cheat decisions.
Captured game sources and session data are local development inputs, not release files.
