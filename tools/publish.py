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
    "src/runtime.lua", "src/minigames.lua", "src/quest_assist.lua",
    "tools/build.py", "tools/publish.py",
    "tools/character_diagnostic.lua", "tools/deep_diagnostic.lua",
    "tools/profession_snapshot.lua", "tools/quest_diagnostic.lua",
    "tools/quest_tracking_diagnostic.lua", "tools/xp_lab.lua",
    "tests/unit/test_build.py",
    "tests/runtime/verify_interface.lua", "tests/runtime/verify_broom.lua",
)
# Dropped release files are deleted from the remote tree, not just skipped.
REMOVED = ()
GH = shutil.which("gh")
if not GH and os.name == "nt":
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        candidate = Path(local_app_data) / "Microsoft/WinGet/Packages" / "GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe/bin/gh.exe"
        if candidate.is_file():
            GH = str(candidate)


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
    tree = api("git/trees", {"base_tree": commit["tree"]["sha"], "tree": entries})
    new_commit = api("git/commits", {
        "message": "Publish Veyra", "tree": tree["sha"], "parents": [parent],
    })
    command(["api", f"repos/{repo}/git/refs/heads/main", "--method", "PATCH", "--input", "-"],
            {"sha": new_commit["sha"], "force": False})
    print(new_commit["sha"])


if __name__ == "__main__":
    publish()
