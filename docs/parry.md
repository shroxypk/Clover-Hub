# Auto Parry: timing model and evidence

This is the technical note behind the Auto Parry toggle. It exists so the claims
in `README.md` can be checked instead of trusted, and so nobody has to reverse
engineer the reasoning later.

## The mechanic, measured

From the game's own state machine (`StateManager`, `CastFn_Counter`) and live
probes:

| Quantity | Value | How it was obtained |
| --- | --- | --- |
| Granted parry window | `0.25 s` (`StateDuration_Parrying`) | constant across every grant observed |
| Send to grant (`outbound`) | `0.056 - 0.073 s` | `StateEnd_Parrying - StateDuration_Parrying - GetServerTimeNow()` sampled at send |
| Grant visible on client | `0.150 - 0.236 s` | attribute replication, i.e. `outbound` plus the inbound leg |
| Lockout after a whiff | `0.93 - 0.97 s` to `CanParry` again | measured `sentToCanParry` |
| Successful parry | removes `ParryCooldown`, adds `APF` 0.5 s + `ParriedAttack` 0.25 s | `CastFn_Counter` |

`End Block` does not cancel a granted window (11 of 12 measured), so a press is a
short pulse, not a hold. Pressing again while a window is open cannot extend it.

## Why the press is centred where it is

The animation track is itself delayed by the inbound leg, so an impact authored
at marker time `m` lands on this client's clock at `trackStart + m`: the inbound
delay cancels. A press sent at local time `S` opens the parry at `S + outbound`.
The impact therefore has to fall in `[S + outbound, S + outbound + 0.25]`, which
puts the ideal press at:

```
S = impact - outbound - 0.125
```

The pre-fix code used the *observed* grant lag (`0.15 s`) as the lead, pressing
about 90 ms too early. `tests/runtime/verify_parry_coverage.lua` quantifies that
mistake: it misses 972 of the residuals the current build covers.

## Marker accuracy was measured, not assumed

`tests/data/parry_marker_residuals.json` holds real impacts from replicated
fights, recorded without moving or attacking (`tools/observe_parry.lua`, reduced
by `tools/summarise_parry_obs.py`). Each sample pairs the attacking animation,
the marker the profile schedules on, and the moment damage actually landed.
Only hostile-NPC to player melee inside 8 studs is kept, because that is exactly
the case the scheduler predicts; player swings carry their own combo semantics
and pollute the timing.

Six clean samples: residual `impact - marker` = `+0.001 ... +0.037 s`, median
`+0.020 s`, stdev `0.013 s`. The band asserted by
`tests/unit/test_parry_marker_residuals.py` is wider than that.

## Coverage proof

`tests/runtime/verify_parry_coverage.lua` runs the shipped `parry_math` against
every residual in `[-0.100, +0.130] s` for markers between `0.30 s` and `0.90 s`,
on 60 Hz frames, and asserts that one centred press covers all of them. It also
asserts the window is centred on the marker within a frame.

Markers earlier than `outbound + window/2` leave no room for a centred
press from animation start. A later, off-centre press may still cover the hit
if the input arrives in time. Feint gates beyond that arrival deadline are
rejected rather than extending the deadline artificially.

## What the scheduler refuses to do

Each of these exists because the alternative costs the ~1 s lockout:

- no press while `ParryCooldown`, `Attacking`, `Parried`, `Ragdoll`, `Occupied`,
  `Dodging`, `Blocking` or `UsingSkill` is active;
- no press during the `APF` grace after a successful parry (hits are negated
  already);
- no press in `InSafezone` (damage is discarded there);
- no press for an attacker that is stunned, parried or downed mid-swing;
- no press when the attacker is out of range, above/below the character, or
  facing away (dot product below `0.25`), unless the swing starts inside 8 studs
  where spin attacks make facing meaningless;
- sending a press does not discard other pending attacks: the server may reject
  the input. State and cooldown gates regulate subsequent presses.

## Learning rules

- **Health changes are diagnostic only.** They do not identify an attacker or
  distinguish melee damage from periodic effects, so they never update `bias`
  automatically. Clean offline observations can still supply a baked `offset`.
- **Damage near a predicted impact** is ambiguous even after a grant. Damage
  replication and nearby attacks prevent reliable attribution. These events
  remain diagnostic counts (`unparryable`, a legacy field name), but no longer
  blacklist an animation or update its timing bias.
- **Cooldown expiry** comes from `StateEnd_ParryCooldown` when present, because
  the replicated flag clears one inbound leg late and waiting for it moves the
  next press ~0.1 s too late.
  Anticipating expiry never relaxes the other `CanParry` predicates (blocking,
  incapacitation, dodging, parrying, skills, flying, occupation, or attacking).
- **Calibration is optional.** Pending attacks continue through the scheduler
  while it waits, and a real press cancels the idle calibration pulse.

## Honest ceiling

A parry cannot be held, and a whiff costs about four times the window, so
continuous protection is impossible by design; the ceiling is roughly 26%
uptime. What is achievable, and is what this build does, is putting the 0.25 s
you do get exactly on the impact, and not spending it on attacks that cannot be
parried. There is no client-side path to forging the server's parry resolution,
and this project does not attempt one.

## Live diagnostics

Fresh stationary calibration on 2026-10-27 confirmed
`StateDuration_Parrying = 0.25`, `StateDuration_ParryCooldown = 0.8`, and a
numeric `StateEnd_ParryCooldown`. The grant became visible after 0.148 s.
These are one-session measurements, not combat success-rate evidence.
The interface lifecycle test also passed against the loaded 165-profile build.

`getgenv().VeyraParry` exposes:

`status`, `profiles`, `attempts`, `grants`, `confirmed`, `damageEvents`,
`covered`, `missed`, `lead`, `grantLag`, `bias`, `hitResiduals`, `unparryable`,
`unparryableSkips`, `unobservedGrants`, `successByAsset`, `cooldownWait`, `unknownAssets`, and a bounded `log`.

`range` defaults to 14 studs, `leadOffset` is an optional manual seconds
adjustment (default 0). Confirmed counts are local deflection signals and nearby
animation attribution is approximate.

## Reproducing the dataset

```sh
# harvest markers from every animation in the game (needs the executor)
#   -> Veyra_parry_assets_full.json
python tools/import_parry_assets.py path/to/parry_assets_full.json \
    tests/data/parry_marker_residuals.json

# reduce a passive recording into the residual dataset
python tools/summarise_parry_obs.py path/to/Veyra_parry_obs.json

python -m unittest discover -s tests/unit
```

## Verified outcome counters

The calibration pulse is not marked successful until the client observes a
server-issued `State_Parrying` grant and reads its timing metadata. A sent
`Block Input` alone cannot establish calibration. `unobservedGrants` counts
ordinary parry attempts whose session expires without a visible grant; this is
not proof of server rejection. `successByAsset` counts confirmed local
`State_ParriedAttack` events attributed to the last scheduled attack. Where
multiple enemies overlap, asset attribution is approximate.
