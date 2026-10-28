"""Publish checked Veyra sources through the authenticated GitHub CLI."""
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess

from build import build

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    ".gitignore", "README.md", "main.lua", ".github/workflows/verify.yml",
    "docs/parry.md", "docs/diagnostics.md",
    "src/runtime.lua", "src/minigames.lua", "src/quest_assist.lua",
    "src/auto_parry.lua", "src/parry_math.lua", "src/parry_profiles.lua",
    "src/boss_alerts.lua", "src/auto_gather.lua",
    "tools/build.py", "tools/publish.py", "tools/import_parry_assets.py",
    "tools/check_glyphs.py", "tools/fix_glyphs.py",
    "tools/observe_parry.lua", "tools/summarise_parry_obs.py",
    "tools/diagnostics/character_diagnostic.lua",
    "tools/diagnostics/deep_diagnostic.lua",
    "tools/diagnostics/parry_state_probe.lua",
    "tools/diagnostics/profession_snapshot.lua",
    "tools/diagnostics/quest_diagnostic.lua",
    "tools/diagnostics/quest_tracking_diagnostic.lua",
    "tools/diagnostics/xp_lab.lua",
    "tests/data/parry_marker_residuals.json",
    "tests/unit/test_build.py", "tests/unit/test_import_parry_assets.py",
    "tests/unit/test_parry_marker_residuals.py",
    "tests/runtime/verify_parry_math.lua", "tests/runtime/verify_parry_coverage.lua",
    "tests/runtime/verify_interface.lua", "tests/runtime/verify_broom.lua",
    "tests/unit/test_broom_runtime.py", "tests/unit/test_broom_speed_probe.py",
    "tests/unit/test_feature_safety.py", "tests/unit/test_mechanics_probe.py",
    "tests/unit/test_minigame_startup.py", "tests/unit/test_parry_diagnostics.py",
    "tests/unit/test_feature_interaction.py", "tests/unit/test_auto_gather.py",
    "tools/diagnostics/broom_speed_probe.lua", "tools/diagnostics/mechanics_probe.lua",
    "tools/diagnostics/smoke_test.lua",
)
# Dropped release files are deleted from the remote tree, not just skipped.
REMOVED = (
    "tools/character_diagnostic.lua", "tools/deep_diagnostic.lua",
    "tools/profession_snapshot.lua", "tools/quest_diagnostic.lua",
    "tools/quest_tracking_diagnostic.lua", "tools/xp_lab.lua",
)
GH = shutil.which("gh")
if not GH and os.name == "nt":
    candidates = [Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "GitHub CLI/gh.exe"]
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        candidates.append(
            Path(local_app_data) / "Microsoft/WinGet/Links/gh.exe")
        candidates.append(
            Path(local_app_data) / "Microsoft/WinGet/Packages"
            / "GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe/bin/gh.exe")
    for candidate in candidates:
        if candidate.is_file():
            GH = str(candidate)
            break


def command(args, payload=None):
    result = subprocess.run(
        [GH, *args],
        input=json.dumps(payload) if payload is not None else None,
        text=True, encoding="utf-8", capture_output=True, check=True, cwd=ROOT,
    )
    return result.stdout


def publish():
    build(check=True)
    if not GH:
        raise RuntimeError("GitHub CLI (gh) is required.")
    missing = [path for path in FILES if not (ROOT / path).is_file()]
    if missing:
        raise FileNotFoundError(f"Missing release files: {missing}")
    repo = os.environ.get("VEYRA_REPO") or command(
        ["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]
    ).strip()
    if not repo or "/" not in repo:
        raise ValueError("Cannot resolve the GitHub repository.")
    def api(path, payload=None):
        args = ["api", f"repos/{repo}/{path}"]
        if payload is not None:
            args.extend(["--input", "-"])
        return json.loads(command(args, payload))
    parent = api("git/ref/heads/main")["object"]["sha"]
    expected = os.environ.get("VEYRA_EXPECTED_PARENT")
    if expected and parent != expected:
        raise RuntimeError("Remote moved since review; re-sync before publishing.")
    commit = api(f"git/commits/{parent}")
    existing = api(f"git/trees/{commit['tree']['sha']}?recursive=1")["tree"]
    entries = []
    for path in FILES:
        blob = api("git/blobs", {
            "content": base64.b64encode((ROOT / path).read_bytes()).decode("ascii"),
            "encoding": "base64",
        })
        entries.append({"path": path, "mode": "100644", "type": "blob", "sha": blob["sha"]})
    # A file dropped from FILES must disappear remotely, not linger in the tree.
    for path in REMOVED:
        if any(entry["path"] == path for entry in existing):
            entries.append({"path": path, "mode": "100644", "type": "blob", "sha": None})
    # GitHub refuses tree writes under .github/workflows unless the token carries
    # the `workflow` scope, and reports it as a bare 404. Keep the local file in
    # the manifest but skip that entry instead of failing the whole release.
    workflow = [entry for entry in entries if entry["path"].startswith(".github/workflows/")]
    try:
        tree = api("git/trees", {"base_tree": commit["tree"]["sha"], "tree": entries})
    except subprocess.CalledProcessError:
        if not workflow:
            raise
        print("warning: token lacks the workflow scope; skipping "
              + ", ".join(entry["path"] for entry in workflow))
        entries = [entry for entry in entries if entry not in workflow]
        tree = api("git/trees", {"base_tree": commit["tree"]["sha"], "tree": entries})
    new_commit = api("git/commits", {
        "message": "Publish Veyra", "tree": tree["sha"], "parents": [parent],
    })
    command(["api", f"repos/{repo}/git/refs/heads/main", "--method", "PATCH", "--input", "-"],
            {"sha": new_commit["sha"], "force": False})
    print(new_commit["sha"])


if __name__ == "__main__":
    publish()
