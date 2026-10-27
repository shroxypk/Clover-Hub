"""Turn raw passive-observer records into the parry marker-residual dataset.

Usage: python tools/summarise_parry_obs.py path/to/Veyra_parry_obs.json

The raw file comes from ``tools/observe_parry.lua``: one record per replicated
damage event, each with every nearby attack animation that could explain it.
We keep only unambiguous attributions and write ``tests/data`` so the offline
test suite can enforce the timing assumption on real data.
"""
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tests/data/parry_marker_residuals.json"
MAX_RESIDUAL = 0.35
AMBIGUITY = 0.02


def numeric(value):
    return isinstance(value, (int, float))


def attribute(record):
    entries = record.get("candidates") or record.get("cands") or []
    candidates = [
        candidate for candidate in entries
        if numeric(candidate.get("delta")) and abs(candidate["delta"]) <= MAX_RESIDUAL
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
        "speed": round(best.get("speed", 1), 4),
        "marker": round(best["marker"], 4),
        "elapsed": round(best["elapsed"], 4),
        "delta": round(best["delta"], 4),
    }


def main(path):
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    samples = [sample for sample in map(attribute, raw["records"]) if sample]
    if not samples:
        raise SystemExit("no attributable impacts in that recording")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "note": ("passive observation of replicated fights; no movement, no attacks. "
                 "marker is wall-clock time; marker*speed is animation time."),
        "samples": samples,
    }, indent=1), encoding="utf-8")
    residuals = [sample["delta"] for sample in samples]
    ordered = sorted(abs(value) for value in residuals)
    print(f"records {len(raw['records'])} -> samples {len(samples)}")
    print("mean %+.3f median %+.3f stdev %.3f p90|d| %.3f" % (
        statistics.mean(residuals), statistics.median(residuals),
        statistics.pstdev(residuals), ordered[int(len(ordered) * 0.9) - 1]))
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
