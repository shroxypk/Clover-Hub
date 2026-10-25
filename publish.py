"""Publish the maintained release atomically through an authenticated GitHub CLI."""
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
REPO = "shroxypk/Clover-Hub"
FILES = (
    ".gitignore", "README.md", "main.lua", "build.py", "publish.py",
    "00_hub.lua", "03_minigames_fix.lua", "06_parry_learning.lua",
    "test_parry_learning.luau", "verify_hub.lua",
    "07_attack_catalog.lua", "08_parry_timing.lua", "attack_seed.lua",
    "export_seed.py", "test_parry_timing.luau", "verify_dodge.lua", "verify_defense.lua",
)
GH = shutil.which("gh") or str(
    Path(os.environ["LOCALAPPDATA"]) / "Microsoft/WinGet/Packages"
    / "GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe/bin/gh.exe"
)


def api(path, payload=None):
    args = [GH, "api", f"repos/{REPO}/{path}"]
    if payload is not None:
        args += ["--input", "-"]
    result = subprocess.run(
        args, input=json.dumps(payload) if payload is not None else None,
        text=True, encoding="utf-8", capture_output=True, check=True,
    )
    return json.loads(result.stdout)


def publish():
    parent = api("git/ref/heads/main")["object"]["sha"]
    commit = api(f"git/commits/{parent}")
    tree = []
    for name in FILES:
        content = (ROOT / name).read_bytes()
        blob = api("git/blobs", {
            "content": base64.b64encode(content).decode("ascii"), "encoding": "base64",
        })
        tree.append({"path": name, "mode": "100644", "type": "blob", "sha": blob["sha"]})
    existing = api(f"git/trees/{commit['tree']['sha']}?recursive=1")["tree"]
    # Remove only the reviewed legacy previews and diagnostics, preserving other files.
    for name in (
        "diagnostics/passive_environment.lua", "diagnostics/tempo_ui_observer.lua",
        "diagnostics/ui_dropdown_test.lua", "ui/quest_tracker_v4_3.lua", "ui/v3_3_preview.lua",
    ):
        if any(entry["path"] == name for entry in existing):
            tree.append({"path": name, "mode": "100644", "type": "blob", "sha": None})
    new_tree = api("git/trees", {"base_tree": commit["tree"]["sha"], "tree": tree})
    new_commit = api("git/commits", {
        "message": "Update bundled hub, animation timing catalog, sources, and verification",
        "tree": new_tree["sha"], "parents": [parent],
    })
    # A concurrent update must never be overwritten.
    result = subprocess.run(
        [GH, "api", f"repos/{REPO}/git/refs/heads/main", "--method", "PATCH", "--input", "-"],
        input=json.dumps({"sha": new_commit["sha"], "force": False}),
        text=True, encoding="utf-8", capture_output=True, check=True,
    )
    print(json.loads(result.stdout)["object"]["sha"])


if __name__ == "__main__":
    publish()
