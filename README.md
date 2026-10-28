# Veyra

A small Luau panel for the Clover RPG client: **Auto Minigames**, adjustable **Broom Speed**, **Quest Assistance**, **Boss Attack Alerts**, and experimental **Auto Parry** (hidden from the panel pending reliability work).

All controls appear in one scrollable panel, grouped under **Automation**, **Guidance**, and **Movement** headings.

Every feature starts disabled. Broom speed defaults to 1x, which is a complete no-op. The quest HUD stays visible when enabled even without an active quest. Drag its title area to reposition it, use minus/plus to collapse or expand details, and use **PINS** to cycle through **NEAR** (one nearby target per type), **ALL** (up to six nearby markers), and **OFF** (no world markers).

## Load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/main.lua"))()
```

**Controls:** Right Ctrl shows/hides the panel, Delete minimizes it, Insert switches size presets. Drag the header to move the panel (including while minimized), or drag its edges/corner to resize. **Unload** disconnects everything. The panel and quest HUD are independent overlays.

## Features

| Feature | What it does | Limit |
| --- | --- | --- |
| Auto Minigames | Reads the game's own round data and presses Space / moves the mouse at the right moment. Play normally; every harvest and mining game is solved for you. | Solver thread only runs while a minigame is open. |
| Broom Speed | Requests a 1x to 3x horizontal flight-velocity multiplier in 0.25 steps, capped client-side at 240 studs/s. | Only while mounted; the game/server may enforce a lower movement cap. Vertical velocity is untouched. |
| Quest Assistance | Draggable, compact quest card with progress, direction/distance, stable objective selection, and NEAR/ALL/OFF marker visibility. | Only uses visible/replicated progress; the world must stream targets to locate them. |
| Boss Attack Alerts | Adaptive warning countdown for profiled boss animation markers: respects playback speed, measured profile offsets, distance-dependent display lead, and multi-hit sequences. | Markers are candidates, not confirmed impacts; unsupported attacks, range and server timing cannot be predicted reliably. No parry or gameplay input is sent. |
| Auto Parry | Arms a single parry per predicted melee impact, timed from the attacking animation and the server's own grant timing. | See [docs/parry.md](docs/parry.md); a parry cannot be held. |

Auto Parry never moves the character, never teleports, and never sends anything but the same `BlockInput` packet the game's own block key sends.

## Feature interaction

The modules share one panel, one cursor and (for some of them) one mouse button, so each boundary is explicit:

* **One owner per input.** Auto Minigames only moves the mouse and taps Space, and only while a round is live. Auto Parry only sends `BlockInput`, plus a mouse-button release/resume that exists purely because a held attack blocks parrying; that release is skipped while a minigame round is live, and the button is handed straight back if a round starts. Nothing else synthesises input.
* **Panel hover pauses automation.** While the pointer is over the panel or a drag is in progress, Auto Minigames is paused so a stray cursor cannot operate a minigame for you, and the panel's cursor takes over `MouseIconEnabled` only for that hover, restoring the previous value on exit.
* **Stacked UI by layer.** Panel `10000`, quest guide `9998`, boss alerts `10001`; the boss alert card is non-interactive and cannot swallow clicks meant for the panel.
* **Independent lifecycles.** Every module has its own `stop()`; unloading or reloading the hub stops them all and clears their GUIs, and a reload also releases any leftover button held by an older build.
* **No writes to game-owned state.** The hub never touches game settings, remotes, character attributes, `WalkSpeed` or other modules' instances; Broom Speed only scales the flight `LinearVelocity` the game's own controller wrote, once per write.

## Auto Parry in one paragraph

The game grants a 0.25 s parry window per press and then locks you out for about 0.95 s, so the only way to make it useful is to press at the right moment and never press wrong. Veyra derives that moment from the attacker's animation markers, the measured send-to-grant latency of your machine, and the server's own cooldown timestamp. `docs/parry.md` has the measurements, the coverage proof, and the honest ceiling.

## Repository layout

```
main.lua              generated single-file release (do not edit)
src/                  runtime, panel, minigames, broom, quest guide, boss alerts, auto parry
src/parry_profiles.lua  165 generated impact profiles from animation markers
tools/                build, publish, profile importer, passive timing observer
tools/diagnostics/    optional read-only inspection scripts
tests/unit/           offline tests (build integrity, importer rules, timing claims)
tests/runtime/        Luau checks (timing math, press coverage, interface lifecycle)
docs/                 technical notes
```

## Development

```sh
python tools/build.py                       # rebuild main.lua
python tools/build.py --check               # fail if main.lua is stale
python -m unittest discover -s tests/unit   # offline tests
luau tests/runtime/verify_parry_math.lua    # timing math
luau tests/runtime/verify_parry_coverage.lua  # press-coverage guarantee
```

Edit `src/`, never `main.lua`. The release is regenerated by `tools/build.py` and published by `tools/publish.py`, which refuses to publish a stale build. Boss profiles are embedded into the standalone release (like Auto Parry's dependencies); `main.lua` does not require separate local source files.

**In-game verification:** Enable Quest Assistance, track and untrack a quest, cycle all three pin modes, drag and repeatedly collapse the card, then respawn. For Boss Attack Alerts, test a known profiled boss at different distances and animation speeds. Verify warnings stop when the boss dies or leaves range. A clean offline build cannot establish in-game animation timing or server hit accuracy.

Optional read-only diagnostics (no remotes, no progress changes), including a one-shot smoke test, are listed in [docs/diagnostics.md](docs/diagnostics.md).
