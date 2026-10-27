"""Generate candidate melee parry profiles from the bulk animation asset dump.

Usage: python tools/import_parry_assets.py path/to/parry_assets.json [residuals.json]

The input is produced by inspecting ``Animation`` assets through
``KeyframeSequenceProvider``. Markers are animation-authored cues, not proof
that an attack is parryable or that its timing matches server resolution.
The optional residuals file (``tools/summarise_parry_obs.py`` output) bakes a
per-asset scheduling shift measured from real impacts.
"""
import json
import statistics
import sys
from pathlib import Path

# Markers that denote a physical impact frame. Ambiguous cues such as Charge,
# WindUp, Velocity, CriticalIndicator, SwingWindow, DoSkill, Action and Release
# are deliberately excluded: they mark windups, movement or warnings.
IMPACT = {
    "HitWindow", "HitWindow2", "HitWindow3", "Hit", "SlamHit", "SlamWindow",
    "Slam", "Strike", "FinalStrike", "Attack", "Attack1", "Attack2", "Attack3",
    "Attack4", "Kick", "Throw", "ShootWindow", "Impact", "Palm", "Slash",
    "Slashes", "Slash_Upward", "Explosion", "Explode", "Fling",
}
# Cues that must never be treated as an incoming hit.
IGNORE = {
    "GrabWindow", "PullOut", "CriticalIndicator", "Release", "Charge", "WindUp",
    "Windup", "StartWindup", "Velocity", "EndVelocity", "SwingWindow",
    "Swing", "DoSkill", "Action", "ActionFrame", "ValidEnd", "AnimationEnd",
    "End", "Ended", "Window", "Down", "Start", "StartSpin", "SweepStarted",
    "SlamStart", "SpinWindow", "SpinWindow2", "SpinEnded", "Jump", "Leap",
    "Rise", "Fall", "Land", "Descent", "FrameBeforeImpact", "Dash", "Snap",
    "Beam", "Fire", "Summon", "Charge", "Charged", "Heal", "VFX", "Orb", "Hand",
    "Roar", "Spark", "MagicCircle", "BowSummon", "Shoot", "Disperse", "Launch",
    "Non_Release", "LegUp", "StartLunge", "BeginRelease", "Start_Effects",
}
FEINT_OPEN, FEINT_CLOSE = "OpenFeint", "CloseFeint"
# Class names that carry no meaning when a dump only exposes the asset class.
GENERIC_NAMES = {"KeyframeSequence", "Imported Animation Clip", "Animation"}
# Animation sets that never represent an incoming hostile melee swing.
SKIP_PATH = ("Animations.Movement.", "Animations.Misc.", "Animations.Grimoire")
SKIP_NAME = ("idle", "equip", "sheathe", "death", "downed", "stagger",
             "victim", "walk", "run", "spawn", "block", "parry", "carry")
MERGE_SECONDS = 0.08
MIN_LEAD_TIME = 0.04
MIN_OFFSET_SAMPLES = 6
MIN_OFFSET = 0.005


def merge(times):
    out = []
    for value in sorted(times):
        if not out or value - out[-1] > MERGE_SECONDS:
            out.append(value)
    return out


def offsets(path):
    """Per-asset scheduling shift from passive impact observations.

    A sample's ``delta`` is ``impact - marker``: positive means the real impact
    lands *after* the authored marker, so the press has to move later, i.e. the
    lead shrinks. The stored field is therefore ``-median(delta)``.
    """
    if not path:
        return {}
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    groups = {}
    for sample in data.get("samples", []):
        value = sample.get("delta")
        if isinstance(value, (int, float)):
            groups.setdefault(str(sample.get("asset")), []).append(float(value))
    result = {}
    for asset, values in groups.items():
        if len(values) < MIN_OFFSET_SAMPLES:
            continue
        shift = -statistics.median(values)
        if abs(shift) >= MIN_OFFSET:
            result[asset] = shift
    return result


def classify(record):
    path = record.get("path", "")
    name = record.get("name", "")
    if any(fragment in path for fragment in SKIP_PATH):
        return None
    if any(word in name.lower() for word in SKIP_NAME):
        return None
    if name in GENERIC_NAMES and path:
        # Asset dumps often only expose the class name; the instance name in the
        # path is the readable one.
        name = path.rsplit(".", 1)[-1] or name
    markers = record.get("markers") or []
    hits, gate = [], None
    for marker in markers:
        label, time = marker.get("n"), float(marker.get("t", -1))
        if label in IMPACT and time >= 0:
            hits.append(time)
        elif label == FEINT_CLOSE:
            gate = time
    # A marker pinned to 0.0 is how root-level markers come back from the
    # provider; it marks the clip start, not an impact.
    positive = [value for value in hits if value > 0]
    if positive:
        hits = positive
    hits = merge(hits)
    if not hits:
        return None
    length = float(record.get("length") or 0)
    if length <= 0:
        return None
    # A hit outside the clip cannot be scheduled from the playhead.
    hits = [value for value in hits if value <= length + 0.05]
    if not hits:
        return None
    # Feint windows are cancellable: never press before the feint closes.
    if gate is not None and gate >= hits[-1] - MIN_LEAD_TIME:
        gate = None
    return name, length, hits, gate


def build(data, shifts=None):
    lines, skipped = [], 0
    shifts = shifts or {}
    for record in data.get("records", []):
        result = classify(record)
        if result is None:
            skipped += 1
            continue
        name, length, hits, gate = result
        fields = [
            f'name="{name}"',
            f"length={length:.6f}",
            "hits={" + ",".join(f"{value:.6f}" for value in hits) + "}",
        ]
        if gate is not None:
            fields.append(f"gate={gate:.6f}")
        shift = shifts.get(str(record["id"]))
        if shift is not None:
            fields.append(f"offset={shift:.6f}")
        lines.append(f' ["{record["id"]}"]={{' + ",".join(fields) + "},")
    if not lines:
        raise ValueError("No impact markers found in asset dump")
    lines.sort()
    header = (
        "-- Generated by tools/import_parry_assets.py from animation markers.\n"
        "-- Candidate impact times only: not proof of parryability.\n"
        "-- `offset` is a measured scheduling shift in seconds: positive means\n"
        "-- the real impact lands before the marker, so the press moves earlier.\n"
        "return {\n"
    )
    return header + "\n".join(lines) + "\n}\n", len(lines), skipped


if __name__ == "__main__":
    source = Path(sys.argv[1])
    shift_source = sys.argv[2] if len(sys.argv) > 2 else None
    data = json.loads(source.read_text(encoding="utf-8"))
    text, kept, skipped = build(data, offsets(shift_source))
    output = Path(__file__).resolve().parents[1] / "src/parry_profiles.lua"
    output.write_text(text, encoding="utf-8")
    print(f"wrote {kept} profiles ({skipped} records without impact markers)")
