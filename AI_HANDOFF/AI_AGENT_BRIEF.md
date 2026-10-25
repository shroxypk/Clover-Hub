# Copy/paste brief for another AI

You are continuing the Clover RPG Roblox **Clover Hub** project at https://github.com/shroxypk/Clover-Hub . First read *all* files under `AI_HANDOFF/`, then inspect actual maintained source `00_hub.lua`, `03_minigames_fix.lua`, `06_parry_learning.lua`, `build.py`, tests and README. **Do not assume the GitHub main branch is newer than v4; v5 currently exists separately in user-provided ZIP.**

The user wants a reliable, efficient, gorgeous and smooth standalone auto-parry hub for Roblox Clover RPG (place/experience 8248164019), running in Madium, with preserved minigame automation and little-to-no manual fighting/testing requirements. Improve **all mob** attack recognition, per-attack impact estimates, multiple threats, correct parry-state checks and input lifecycle; avoid fake "perfect parry" claims. Prefer actual corrections and reproducible tests over speculative defaults.

Read `EVIDENCE_AND_FINDINGS.md` for what is supported. In particular, game's `CombatClient` repeats Block Input during held F; `StateManager` exposes CanParry guards; old Wolf telemetry is 2,297 events with duplicate stop events and unverified attack timings. Existing learner records 7 samples with median-based consensus. Earlier code had `watch()` wiping `recentAttacks`, missed already-playing tracks, and could retain a block after threat cancellation; local v4.1/v5 work addressed portions of these.

Raw game/source captures are **not in this public GitHub directory**. `DATA_MANIFEST.md` lists filenames and SHA-256 so the user can provide specific attachments only if necessary. Do not publish private gameplay recordings or full decompiled game source.

Immediate recommended work:
1. Compare local v5 ZIP against current GitHub v4; merge v5 UI/lifecycle improvements into maintained modules.
2. Build a deterministic scheduler/learner test harness with synthetic tracks/states and edge cases.
3. Mine accessible Cast and animation module details for grounded attack signals, prioritizing passive classification.
4. Implement confidence-aware multithreat and validated per-attack timing while preserving defensive safe defaults.
5. Regenerate `main.lua`, run offline tests; if asked and authorized publish changes to the repo.

State clearly which work was actually completed, which was statically checked, and which needs Roblox runtime evidence. Never present protected Luarmor source as recovered or claim an external timing list was verified.
