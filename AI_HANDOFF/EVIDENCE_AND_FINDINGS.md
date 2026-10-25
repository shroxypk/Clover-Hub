# Evidence ledger and confidence

## Inspected concrete sources
1. `combat_collector.json` / `CloverRPG_Combat_1792869280.json`: same or similar capture content; count confirmed from attached original as **2,297 events**: 1,223 animation_stop, 733 sample, 256 animation_start, 45 health, 35 key_up, 4 actor_seen and 1 end. Main observed actor Wolf; other actor names and local player may appear. A high number of animation_stop events are duplicate callbacks from old collector, **not independent attacks**. Capture duration ~80.5s.
2. `cast.zip`: 29 files, including `CombatClient.lua`, `StateManager.lua`, `Packets.lua`, `CastFn_FigureIsBlocking.lua`, `CastFn_StatusCombat.lua`, `CastFn_Counter.lua`, `CastFn_HandleFlinching.lua`, `CastFn_ApplyStatus.lua`, `SCAN_ReplicatedFirst_Services_Cast.lua`.
3. `impo.zip`: 805 extracted script files; contains both relevant combat/client scripts and unrelated framework/UI code. Some script names are nonunique; match by parent path or hash where available.
4. `CloverRPG_CombatScripts.rbxlx`: Fishilizer export of client-visible scripts. Rough counts: 805 script instances, 613 ModuleScripts, 116 LocalScripts, 76 server Script stubs; server script source is **not** recovered.
5. `CloverRPG.zip`, `clover_rpg.zip`: older local working folders containing probes, diagnostics, decomp, minigame experiments, images, script versions and partial recordings. Very large; not production-ready directly.
6. `CloverHub_Reviewed_v4_1.zip` and `CloverHub_Ultimate_v5.zip`: assistant-generated reviewed builds; static/offline verification reported, not full in-game accuracy.
7. `CloverRPG_Passive_Intelligence.lua`: read-only scanning collector; **not a completed evidence capture**.

## Observations supported by client files
- `CombatClient` repeatedly sends combat BlockInput during held F, then sends End Block. This justifies matching the normal packet behavior while enforcing timeouts.
- `StateManager` has a CanParry gate and distinct parry/blocking/cooldown combat states. Requires state-aware scheduling.
- Parry feedback attributes `State_Parrying` and `State_ParriedAttack` can help infer whether a parry grant and successful defense happened, but replication introduces latency and does not expose every server calculation.
- Prior collector showed an approximate **0.9s** delay between some Wolf animation starts and player damage. Candidate IDs included `125957249913572` and `73807165586659`; attribution remains uncertain. Other animation IDs `100970712574451`, `130310470361406` were considered possible hit reactions, not proven.
- Game may use animation markers, effect spawning, physical hitboxes and server private logic not visible in client dump. Need independently substantiate each.

## Explicitly NOT established
- Any complete verified mob-to-attack timing database.
- 100% parry success against every mob/boss/ranged/skill attack.
- Exact server acceptance windows for all attacks.
- That every animation labeled Action is an incoming hostile attack.
- That block packets cause a valid parry just because no health was lost.
- That an unrelated ScriptBlox listing's claim of 182+ timings is true or accessible.
- That the Luarmor loadstring exposes readable source or a reusable timing database.
- That passive scanning alone can calibrate an attack never observed in-game.

## Safety and attribution
No need to repost raw game decompilation sources in a public repository. The evidence files may contain account/session names and third-party script content. Preserve user ownership and private material; publish metadata, reproducible analysis, and synthetic fixtures instead.
