# Individually browsable project files

This directory contains **real standalone source files committed directly to GitHub**, not ZIP parts or generated summaries.

## v5 — newer local reviewed build
- [main.lua](v5/main.lua) — actual v5 standalone entrypoint
- [00_hub.lua](v5/00_hub.lua) — recovered standalone v5 UI/parry source from the published local bundle
- [03_minigames_fix.lua](v5/03_minigames_fix.lua) — recovered v5 mining and harvesting module
- [06_parry_learning.lua](v5/06_parry_learning.lua) — recovered v5 parry timing learner

**Note:** v5 component files were recovered from the embedded modules inside the v5 bundled `main.lua`. The root-level `main.lua` in the repository may still use the v4 code. Use the v5 subdirectory to inspect the new build; don't assume its extracted sources have been runtime-tested or rebundled.

## v4 — original maintained sources
- [00_hub.lua](v4/00_hub.lua)
- [03_minigames_fix.lua](v4/03_minigames_fix.lua)
- [06_parry_learning.lua](v4/06_parry_learning.lua)
- [test_parry_learning.luau](v4/test_parry_learning.luau)
- [verify_hub.lua](v4/verify_hub.lua)
- [build.py](v4/build.py)
- [publish.py](v4/publish.py)
- [README.md](v4/README.md)

## Utilities
- [CloverRPG_Passive_Intelligence.lua](collectors/CloverRPG_Passive_Intelligence.lua) — static/passive client metadata collector
- [extract_capture.py](tools/extract_capture.py) — historical Fishilizer extraction helper

## Still not directly committed (critical to be transparent)
The **805 files in `impo.zip`**, **29 files in `cast.zip`**, and historical `clover_rpg.zip`/`CloverRPG.zip` archive contents have **not** been individually uploaded by this session. Full captures may include personally identifying details and third-party decompiled script content, and the available GitHub connector cannot read archive entries from the mounted filesystem to submit them as GitHub blobs automatically. `combat_collector.json` is also not published raw because it includes player/session identifiers.

To continue an analysis that depends on one of those missing sources, obtain that exact file from the user's private original archive; see [../DATA_MANIFEST.md](../DATA_MANIFEST.md). Do **not** claim the full evidence is already browsable on GitHub.

All files listed in the first three sections are actual code/text and can be opened in the GitHub UI.
