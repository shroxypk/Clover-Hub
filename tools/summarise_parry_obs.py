"""Turn raw passive-observer records into the parry marker-residual dataset.

Usage: python tools/summarise_parry_obs.py path/to/Veyra_parry_obs.json [--players a,b,c]

The raw file comes from ``tools/observe_parry.lua``: one record per replicated
damage event, each with every nearby attack animation that could explain it.

Only the cases this script has to predict are kept:

* the attacker is a hostile NPC, not another player (player swings have their
  own combo/queue semantics and pollute the timing),
* the victim is a player character,
* the pair is within melee range and only one animation can explain the damage.

``--players`` supplies the session's player names for recordings made before the
observer started tagging attackers itself.
"""
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tests/data/parry_marker_residuals.json"
MAX_RESIDUAL = 0.35
AMBIGUITY = 0.02
MELEE_RANGE = 8.0


def numeric(value):
    return isinstance(value, (int, float))


def is_npc_to_player(candidate, players):
    if "attackerIsPlayer" in candidate:
        return not candidate["attackerIsPlayer"] and candidate["victimIsPlayer"]
    return candidate.get("attacker") not in players and candidate.get("victim") in players


def attribute(record, players):
    entries = record.get("candidates") or record.get("cands") or []
    candidates = [
        candidate for candidate in entries
        if numeric(candidate.get("delta")) and abs(candidate["delta"]) <= MAX_RESIDUAL
        and candidate.get("dist", 0) <= MELEE_RANGE
        and is_npc_to_player(candidate, players)
    ]
    if not candidates:
        return None
    candidates.sort(key=lambda candidate: abs(candidate["delta"]))
    best = candidates[0]
    if len(candidates) > 1:
        runner_up = candidates[1]
        close = abs(abs(best["delta"]) - abs(runner_up["delta"])) < AMBIGUITY
        if close and best["asset"] != runner_up["asset"]:
            return None
    return {
        "asset": best["asset"],
        "name": best["name"],
        "attacker": best.get("attacker"),
        "victim": best.get("victim"),
        "distance": round(best.get("dist", 0), 2),
        "speed": round(best.get("speed", 1), 4),
        "marker": round(best["marker"], 4),
        "elapsed": round(best["elapsed"], 4),
        "delta": round(best["delta"], 4),
    }


def main(path, players):
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    samples = [sample for sample in map(lambda r: attribute(r, players), raw["records"]) if sample]
    if not samples:
        raise SystemExit("no attributable NPC->player impacts in that recording")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "note": ("passive observation of replicated fights; no movement, no attacks. "
                 "npc->player melee only. marker is wall-clock time; marker*speed is "
                 "animation time. delta = impact - marker."),
        "samples": samples,
    }, indent=1), encoding="utf-8")
    residuals = sorted(sample["delta"] for sample in samples)
    absolute = sorted(abs(value) for value in residuals)
    print(f"records {len(raw['records'])} -> npc->player samples {len(samples)}")
    print("mean %+.3f median %+.3f stdev %.3f max|d| %.3f" % (
        statistics.mean(residuals), statistics.median(residuals),
        statistics.pstdev(residuals), absolute[-1]))
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    arguments = [value for value in sys.argv[1:] if not value.startswith("--")]
    names = set()
    for index, value in enumerate(sys.argv):
        if value == "--players" and index + 1 < len(sys.argv):
            names = {name.strip() for name in sys.argv[index + 1].split(",") if name.strip()}
    if not arguments:
        raise SystemExit(__doc__)
    main(arguments[0], names)
