# Clover Hub — AI Handoff / Complete Project Context

**START HERE if you are another AI.** This directory is the handoff for continuing the user's Clover RPG Roblox project. It is **not executable code** and should not be treated as verified game behavior.

## Primary user goal (highest priority)
Make a beautiful, fast, stable, highly accurate, general-purpose auto-parry system for **Clover RPG**, Roblox experience **8248164019**, running through the user's **Madium** executor. It should work against as many mobs, bosses, players, skills, and attack types as technically possible **without forcing the user to fight every single mob to collect samples**. The user wants an "ultimate/perfect" parry, but do not claim 100% accuracy absent measured success. The user also wants polished smooth UI and working auto-mining/harvesting minigames preserved.

### Explicit user preferences
- Minimize manual labor and repeated requests for captures. Automate passive discovery and calibration as far as possible.
- Prefer a **standalone loadstring-friendly `main.lua`**, with readable maintained sources and easy packaging.
- Keep existing minigame features, drag/resize/minimize/unload, toggles and status metrics.
- Deliver actual reviewed code and tests where practical, not only plans.
- Avoid guessing facts, inventing attack tables, or treating generic animations as proven attacks.
- Clearly separate static verification from real live combat validation.
- Do not publish credentials, keys, session identities, full user-specific captures, or proprietary extracted game source.

## Repository and versions
Repo: https://github.com/shroxypk/Clover-Hub
Normal loader:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/shroxypk/Clover-Hub/main/main.lua"))()
```
At time of handoff, GitHub main had a **v4** generated `main.lua` (plus `00_hub.lua`, `03_minigames_fix.lua`, `06_parry_learning.lua`, `build.py`, `test_parry_learning.luau`, `verify_hub.lua`, `publish.py`). Newer **v4.1** and **v5** reviewed builds exist as local generated ZIPs but were **not yet published to main**. **Do not assume the GitHub loader runs v5**. A separate project upgrade needs to merge newer code deliberately, regenerate, test, and publish.

## Navigate this handoff
1. [GOALS_AND_HISTORY.md](GOALS_AND_HISTORY.md) — user intent and chronological history.
2. [ARCHITECTURE.md](ARCHITECTURE.md) — runtime structure, parry logic, UI and minigames.
3. [EVIDENCE_AND_FINDINGS.md](EVIDENCE_AND_FINDINGS.md) — what was actually established, what is uncertain.
4. [DATA_MANIFEST.md](DATA_MANIFEST.md) — exact names, sizes, SHA-256 checksums of user-provided artifacts; some are deliberately **not** hosted publicly.
5. [OPEN_ISSUES_AND_ROADMAP.md](OPEN_ISSUES_AND_ROADMAP.md) — concrete bugs, validation plan, and priorities.
6. [AI_AGENT_BRIEF.md](AI_AGENT_BRIEF.md) — copy/paste instructions for continuing assistants.

## Truthfulness / source boundaries
Distinguish: **(A)** user intent, **(B)** inspected client source and telemetry, **(C)** inference, **(D)** untested implementation, and **(E)** observed in-game outcome. A local decompiled source is not authoritative server source. No extracted files have proved 100%-accurate parries for every enemy.

## Why evidence isn't all checked into GitHub
Local user captures include potentially private session data and decompiled third-party scripts; huge archives include images and resources not needed to compile the hub. This public repository therefore contains **the indexed handoff and source pointers**, rather than republishing all captures. Ask for **only the specific missing artifact** if you cannot access the original session attachments. Source hashes allow identity checks. See DATA_MANIFEST.md.


## Complete raw-file bundle

The user also requested all underlying files, not just a documentation summary. See **[ALL_FILES.md](ALL_FILES.md)** for the full ~148 MB, 911-entry local evidence bundle and **[import_full_evidence.py](import_full_evidence.py)** for importing its split binary parts after reviewing the public-disclosure risk. The large raw binaries are **not yet pushed to GitHub**. Treat the documentation here as contextual guidance until those actual artifacts are supplied.


## Directly browsable source files

See **[PROJECT_FILES/README.md](PROJECT_FILES/README.md)** for individual v4/v5 `.lua`, `.luau`, and utility files committed directly to GitHub. This is separate from archived evidence; large third-party extracted archives are not yet individually published.


## Actual extracted Lua sources

**[EXTRACTED/README.md](EXTRACTED/README.md)** indexes 105 individually committed files from the user's source archives; 75 are original server-source-unavailable placeholder files, not gameplay logic. The remaining hundreds are not yet on GitHub.
