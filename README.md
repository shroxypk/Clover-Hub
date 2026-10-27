# Veyra

A lightweight Luau utility panel for **Auto Minigames**, adjustable **Broom Speed**, **Quest Assistance**, and experimental **Auto Parry**.

Every feature starts disabled; **1× broom speed** leaves normal movement unchanged.

## Load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Veyra/main/main.lua"))()
```

**Controls:** Right Ctrl shows/hides the panel, Delete minimizes it, Insert changes its size. Drag the header or edges to move/resize. **Unload** disconnects the script.

## Features

- **Auto Minigames** — reads the game's own round data and presses Space / moves the mouse at the right moment. The solver thread exists only while a minigame session is open.
- **Broom Speed** — 1×–3× horizontal multiplier in 0.25 steps, capped at 240 studs/s, vertical velocity untouched. The scaler connects only while mounted and re-arms after a mount delay; ordering against the game's writer is not guaranteed. 1× disconnects completely.
- **Quest Assistance** — a small lower-right HUD plus world markers for the quest the game itself tracks. See below.
- **Auto Parry (experimental)** — equip a combat weapon and enable the toggle. Uses 165 candidate melee impact profiles taken from the real animation markers of every animation shipped in the game. Tracks animation speed/playhead, centres each press on the measured send→grant lag, filters range/facing, ignores grabs, movement and warning cues, skips interrupted attackers, presses once per predicted impact (one press covers every impact that lands inside its window), blocks presses until a feint window closes, cancels stopped/stale tracks, and respects the game's `CanParry` gate plus the post-parry grace period. No movement or teleporting. Disabled by default; disconnects on disable/unload and rebinds on respawn.

## Auto Parry validation

The catalog contains candidate impact timings extracted from animation markers, not verified parryable attacks. `HitWindow`, `SlamHit`, `Strike`, `Attack`, `Kick`, `Throw`, `Slash` and similar markers are treated as impacts; `GrabWindow`, `WindUp`, `Charge`, `Velocity`, `CriticalIndicator`, `SwingWindow`, `DoSkill` and `Release` are not. Unknown attacks, projectiles, grabs and many boss skills are unsupported. Cooldown, attacking, and other combat states can prevent a parry, and a press is only worth making while the character can actually parry.

**Timing model.** A press sent at local time `S` opens the parry at `S + outbound` for `0.25 s` (`StateDuration_Parrying` = 0.25 every time). Because the animation track is itself delayed by the inbound leg, an impact authored at marker time `m` lands, on this client's clock, exactly at `trackStart + m` — the inbound delay cancels. So the press must be sent `outbound` to `outbound + 0.25 s` before the impact, and is centred at `outbound + 0.125 s`.

`outbound` is measured exactly, with no clock-sync assumption: on the grant the client reads `StateEnd_Parrying` and `StateDuration_Parrying`, so `grant = StateEnd − StateDuration`, and `outbound = grant − workspace:GetServerTimeNow()` sampled at the send. Eight consecutive calibration pulses on this machine gave `outbound = 0.056…0.073 s`; the *observed* grant latency (which also carries the inbound leg) was `0.150…0.236 s`, and that second number is only used to keep the block session open long enough to see the grant.

**Marker accuracy was measured, not assumed.** `tests/data/parry_marker_residuals.json` holds 62 impacts from replicated fights, collected by only watching (no movement, no player attacks): for each impact it records the attacking animation, the marker the profile schedules on, and when the damage actually landed. Residual `impact − marker`: median `+0.002 s`, mean `+0.023 s`, stdev `0.089 s`, p10/p90 `−0.033 / +0.129 s`. `tests/unit/test_parry_marker_residuals.py` enforces those bounds, so a bad profile regeneration fails offline.

With a `0.25 s` window centred on a prediction whose residual is ~0, the theoretical margin is `±0.125 s` per press. That is the honest ceiling for one press: the parry cannot be held, so **perfect uptime is impossible** — after a whiff the game applies `ParryCooldown` for ~`0.95 s` (measured `sentToCanParry` 0.93–0.97 s). A *successful* parry instead removes `ParryCooldown` and adds `APF` (0.5 s) + `ParriedAttack` (0.25 s), which is why successful chains are free and whiffs are expensive. The script therefore skips presses during `APF`, during `InSafezone`, and while the attacker is stunned/parried, and it learns a per-asset shift from the residual of any hit it does eat (`lead`, `grantLag`, `bias`, `hitResiduals` on the object below).

Live testing recorded 8 submitted inputs, 7 observed parry-window grants, and 6 `State_ParriedAttack` deflection signals during a mixed encounter with Nightcharmer animations. Damage also occurred. This is evidence of real deflections, **not a success-rate benchmark or perfect protection**.

Diagnostics: `getgenv().VeyraParry` exposes `status`, `profiles`, `attempts`, `grants`, `confirmed`, `damageEvents`, `covered`, `missed`, `lead`, `grantLag`, `bias`, `hitResiduals`, `unknownAssets`, and a bounded `log`. Confirmed counts are local-character server-replicated deflection signals; nearby animation attribution is approximate and manual parries can also contribute. `range` defaults to 14 studs; `leadOffset` is an optional seconds adjustment (default 0). Regenerate profiles with `python tools/import_parry_assets.py path/to/parry_assets.json`.

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
