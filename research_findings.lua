-- Source review: supplied CloverParry files, Crimson, and FxkeDex.
-- This file is documentation only; it installs no hooks.
return {
    crimson = {
        value = "Animation identity, speed, playhead and actor inspection; mostly duplicates the existing catalog.",
        limit = "Animation playback alone does not establish impact or server acceptance.",
        compatibility = "Not executed or compatibility-tested. SafeMode contains self-kick conditions; external dependencies remain.",
    },
    fxkedex = {
        value = "RemoteSpy connects incoming RemoteEvent and UnreliableRemoteEvent signals; useful beyond outgoing Hydroxide capture.",
        evidence = "RemoteSpy.ensureIncomingHooks and hookIncomingSignal in inspected source.",
        limit = "Incoming buffers still need packet decoding and correlation. Callback remotes are not covered by those signal listeners.",
        compatibility = "Source inspected only; full explorer and external Nebula dependency have not been compatibility-tested.",
    },
    state_manager = {
        evidence = "1_StateManager.lua:688-768; 12_CombatClient.lua:277-315",
        finding = "CanParry, CanBlock and CanDash have distinct gates. CombatClient observes replicated defense states.",
        existing_coverage = "Hub already invokes all three eligibility methods rather than assuming cooldown alone determines availability.",
    },
    block_rules = {
        evidence = "5_FigureIsBlocking.lua:107-151",
        finding = "BlockDisabled rejects blocking; typed blocking normally needs facing dot > -0.1, with THREESIXTY exemption. BLOCKBREAK or full Resolve breaks guard.",
        limit = "These attack arguments are not demonstrated to be replicated or mapped to animation IDs. They do not establish parry immunity.",
    },
    counter = {
        evidence = "6_Counter.lua:108-110,337-403",
        finding = "Counter reads attack.Parry, DisableAPF and APF_TIME; successful branches remove ParryCooldown.",
        limit = "Nested/decompiled branches require caller and live validation. Do not label moves unparryable from the field name or a missed attempt.",
    },
    ranged_slash = {
        evidence = "8_RangedSlash.lua:19-35",
        finding = "Projectile visuals use a server-time endpoint and initial/target transforms.",
        limit = "Visual tween completion is not a verified damage-arrival contract, especially for interception before the endpoint.",
    },
    conclusion = "Useful additional evidence, especially incoming events and replicated states; no verified new attack-to-defense mapping and no basis for claiming perfect defense.",
}
