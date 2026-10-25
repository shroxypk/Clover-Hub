# Technical issues, implementation roadmap and validation

## Priority 0 — correctness/safety
1. **No stuck block:** every automatic Block Input sequence must have an unconditional stop deadline; on unload, disable, manual intervention, death, target invalidation, network exception and respawn, send safe release as permitted. v5 local build added hard timeout/failure handling; audit actual scheduling and manual F interference.
2. **Combat-state parity:** compare client's `StateManager.CanParry` semantics against each check in hub; avoid attempting an action in invalid states or suppressing valid ones.
3. **Attack-tracking lifecycle:** `watch()` formerly cleared all `recentAttacks`, causing learning loss; v4.1 removed. Guard duplicate tracks and connections, adopt currently-playing animations, clean stale refs on stream-out/death/unload.
4. **Never confuse a block with a successful parry:** require reliable `State_ParriedAttack` feedback or other proved signal. Attribute latency and multiple attackers make naive attribution dangerous.
5. **No executor API assumptions:** guard `isfile`, `readfile`, `writefile`, `makefolder`, `gethui`, packet type; degrade gracefully.

## Priority 1 — universal attack inference
- Derive attack classification from replicated animation catalogs, priorities, names, sound/effect/hitbox events, range, facing, target states and tracking.
- Use **confidence tiers**: verified animation/impact, candidate, unknown. Unknown skills/delayed/boss/ranged/multi-hit attacks should not silently inherit "verified" predictions.
- Capture animation markers and playback positions where available; derive impact lead from a **shared mechanism** if evidence supports it. Distinguish per NPC/weapon/skill context even when IDs collide.
- Handle multiple simultaneous threats and multi-hit phases with independent scheduler entries; prevent one discarded track clearing unrelated threats.
- Measure actual block grant delay from replicated `State_Parrying`; account for packet and replication latency, not just arbitrary lead.
- Avoid expensive full-workspace rescans every frame; event-driven discovery + controlled stale cleanup.

## Priority 2 — learning and diagnostics
- Current learner: rolling seven samples, median agreement >=70%, agreement tolerance ~80ms, max update 40ms, saved JSON v1. Review sampling bias and persistent confidence; reject ambiguous overlapping events rather than training on them.
- Observations of damage may be fall damage/DOT/third-party attacks; only label with independently attributable sources.
- Logs should be bounded and concise; allow export and privacy scrub; no repeat animation_stop connections.
- Allow passive data collection and simulation-based unit tests without manual fighting. Distinguish what can only be measured during real combat from static extraction.

## Priority 3 — UI, build hygiene, usability
- Preserve v5 dark modern visual style with smooth animation, responsive toggles, drag/resize/minimize, live status, accessible fonts/colors, minimized performance load.
- Keep minigames behavior intact and independently unloadable.
- Keep source modules authoritative; regenerate `main.lua` with `python build.py`; don't manually patch the generated bundle.
- Test input ownership: do not release a manually held F, press F while typing, or leave a stuck synthetic key.
- Add regression tests for scheduling, overlapping attacks, cancel/release, respawn, duplicated registration, skill unknowns, and persistence corruption.
- Publish only after reviewing diffs; verify branch head and avoid overwriting unrelated changes.

## Definition of done
- Static Luau and bundle checks pass.
- Simulated scenarios pass: repeated attack, late-loaded NPC, multi-threat, interruption, respawn, stale target, file failures.
- In-game state / input behavior independently verified with Madium.
- Measured parry success stratified by attack identity, latency and context. **Never promise 100% before this.**

## Avoid unnecessary extra work for user
Do all static mining and offline source analysis using existing files first. A passive collector may observe other people fighting, but cannot establish server-only timing absent accessible events. Ask user to run a single script or provide focused logs **only when technically required**, not to fight every NPC one at a time.
