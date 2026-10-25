#!/usr/bin/env python3
"""Upload a complete Clover AI handoff archive into this GitHub repo.

Usage:
  python AI_HANDOFF/import_full_evidence.py /path/to/Clover_AI_ALL_FILES_Complete.zip

This DOES NOT run automatically. It intentionally requires --confirm-public
because Clover-Hub is a public repo, and game exports / logs may contain
third-party code or personal session information.

Requires: git, authenticated push access, Python 3.9+.
Run from a clone of https://github.com/shroxypk/Clover-Hub .
"""
from __future__ import annotations
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = HERE / "RAW_EVIDENCE"
CHUNK = 40 * 1024 * 1024

def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("archive", type=pathlib.Path)
    ap.add_argument("--confirm-public", action="store_true",
                    help="I reviewed the archive and explicitly authorize public GitHub publication")
    ap.add_argument("--commit-only", action="store_true",
                    help="Commit prepared evidence, do not push automatically")
    args = ap.parse_args()
    if not args.confirm_public:
        ap.error("Refusing to publish potentially sensitive raw captures without --confirm-public")
    archive = args.archive.expanduser().resolve()
    if not archive.is_file():
        ap.error("archive not found: " + str(archive))
    run("git", "rev-parse", "--show-toplevel")
    OUT.mkdir(parents=True, exist_ok=True)
    sha = hashlib.sha256()
    manifest = {"source": archive.name, "parts": [], "chunk_bytes": CHUNK}
    with archive.open("rb") as src:
        i = 0
        while True:
            data = src.read(CHUNK)
            if not data:
                break
            i += 1
            name = f"complete_evidence.part{i:03d}"
            dest = OUT / name
            dest.write_bytes(data)
            sha.update(data)
            manifest["parts"].append({
                "name": name, "size": len(data),
                "sha256": hashlib.sha256(data).hexdigest()
            })
    manifest["sha256"] = sha.hexdigest()
    (OUT / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    run("git", "add", "--", "AI_HANDOFF/RAW_EVIDENCE")
    run("git", "commit", "-m", "evidence: add complete AI handoff archive in safe-size parts")
    if not args.commit_only:
        run("git", "push", "origin", "HEAD")
    print("Published", len(manifest["parts"]), "parts; full archive SHA-256:", manifest["sha256"])
    print("Reconstruct by concatenating parts in MANIFEST.json order.")

if __name__ == "__main__":
    main()
