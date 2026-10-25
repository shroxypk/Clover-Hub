# All files — actual evidence, not just documentation

The user specifically requested **every available useful file**, including original captures and historical experiments, to be accessible to future AIs.

## What was assembled
A full local archive named `Clover_AI_ALL_FILES_Complete.zip` containing **911 entries** from:
- all original and recovered cast/client source exports (`cast.zip` and `impo.zip`), also extracted individually;
- `CloverRPG_CombatScripts.rbxlx` and `Fishilizer(1).log`;
- original combat telemetry, plus older scripts and probes;
- both historical Clover directories (`clover_rpg.zip` ~140 MB and `CloverRPG.zip` ~4 MB);
- v4/v4.1/v5 source and bundled script outputs;
- passive collector, older Wolf/general auto-parry prototypes, build/tests/publishing tools;
- markdown entrypoint and cryptographic manifest.

The local complete ZIP is ~148 MB and too large for one normal GitHub blob. It also contains captured player names and third-party decompiled client scripts. **The ZIP is not automatically published here** simply because the user asked for a complete handoff; publishing raw captures to a *public* repository has additional disclosure consequences.

## To add the actual bytes to this directory
1. Download `Clover_AI_ALL_FILES_Complete.zip` from the chat artifact.
2. Review/remove any content that should not become publicly accessible (identities, private logs, third-party sources you cannot distribute). A private repository is preferable for unredacted originals.
3. Clone the GitHub repository and run:
   ```sh
   python AI_HANDOFF/import_full_evidence.py "/path/to/Clover_AI_ALL_FILES_Complete.zip" --confirm-public
   ```
4. The importer creates `AI_HANDOFF/RAW_EVIDENCE/complete_evidence.part001`, etc., writes a SHA-256 manifest, commits and pushes, so each file stays below GitHub's 100 MB hard limit.

The uploader does **not** decrypt, repackage, redact or assess copyright; only run it after explicit public-sharing review. No secrets are required in this script; authenticate your local Git setup normally.

## Reconstruction after publication
```python - <<'PY'
from pathlib import Path
import json,hashlib
d=Path("AI_HANDOFF/RAW_EVIDENCE")
m=json.loads((d/"MANIFEST.json").read_text())
with open("Clover_AI_ALL_FILES_Complete.zip","wb") as out:
    for part in m["parts"]:
        data=(d/part["name"]).read_bytes()
        assert hashlib.sha256(data).hexdigest()==part["sha256"]
        out.write(data)
assert hashlib.sha256(Path("Clover_AI_ALL_FILES_Complete.zip").read_bytes()).hexdigest()==m["sha256"]
print("Archive reconstructed and verified")
PY
```

## Why this is not marked "already uploaded"
The model's GitHub connector can write repository text and Git objects, but does not directly ingest the binary files mounted in the analysis runtime. Pretending the 148 MB archive is on GitHub would be misleading. This page and the importer are committed; binary parts will only appear after an explicit import.

See [DATA_MANIFEST.md](DATA_MANIFEST.md) for evidence references and [README.md](README.md) for the AI handoff.
