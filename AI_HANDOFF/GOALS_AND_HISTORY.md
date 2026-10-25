# Goals, history and decisions

## User's exact practical objectives
1. An extremely consistent **all-mob**, preferably all combat encounter, **auto-parry for Clover RPG**. Avoid requiring the user to manually fight and measure every mob.
2. An elegant, clean, responsive dark UI with smooth hover/toggle transitions; drag, resize, minimize, unload, clear controls, and live parry data.
3. Preserve working auto-mining and harvesting minigame automation.
4. Reduce CPU/network overhead, avoid persistent F/block hangs, and keep Madium compatibility.
5. Have self-contained downloadable builds and understandable, editable project source.
6. Provide enough information for another AI to resume work without reconstructing months of chats or repeating questions.

## Timeline (summarized, factual)
- Initial general animation-triggered auto-parry and Wolf-only prototype, using `Animator.AnimationPlayed`, proximity/facing filters, key F simulation.
- User provided a combat telemetry capture: ~80.5 s, 2,297 events, mostly a Wolf battle. Potential Wolf impact-associated animation IDs were noted, **not verified**.
- Archived client/game modules were inspected: `CombatClient`, `StateManager`, `Packets`, `CastFn_FigureIsBlocking`, NPC and other Cast modules. The game exposes client-side BlockInput packet conventions and replicated combat state attributes.
- User used Civilation/Fishilizer to export accessible scripts. 4,970,863-byte `.rbxlx` export; serializer scanned 166,647 instances, attempted 729 decompilations. An associated log said 'Data API unreachable'. This is not server source.
- Research found an external ScriptBlox listing **claiming** 182+ Clover RPG attack timings; the Luarmor v4 loadstring was supplied but its timing DB/payload was **not recovered** or verified. Never claim the timing database is in our possession. Never attempt license/auth bypass.
- Repo `shroxypk/Clover-Hub` was reviewed: v4 with standalone generated runtime, `00_hub.lua` UI/parry, `03_minigames_fix.lua`, `06_parry_learning.lua`.
- v4.1 reviewed ZIP built locally: lifecycle repairs, currently-playing track adoption, duplicate guarding, more robust state/persistence checks. This was offline/static reviewed.
- v5 local ZIP built: UI visual overhaul, live stats, hard block timeout, failure recovery. This also was **not tested in Roblox** and not automatically committed to GitHub.
- Passive intelligence collector script provided for Madium. It scans accessible game data without moving/attacking/parrying and periodically saves JSON. This collects relevant *accessible* metadata, but cannot prove hidden server hit windows. No resulting passive JSON was supplied yet.
- User now requests a durable GitHub-based AI handoff of all context and evidence.

## Non-goals / avoid mistakes
- Do not portray unrelated TempoHub VM reverse engineering as already solving Clover RPG.
- Do not say "perfect" is verified when only syntax/static checks were run.
- Do not replace game's observed BlockInput repetition with an unverified generic one-packet assumption.
- Do not assume a single `Action` priority or fixed 0.40s windup identifies all attacks.
- Do not silently promote casual damage correlations to ground truth.
