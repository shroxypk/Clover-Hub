# Individually published extracted files

These are **actual separate text/Lua files** committed into GitHub, copied from the user's supplied `impo.zip` and `cast.zip` exports rather than ZIP wrappers.

## Published in this batch (2026-10-25)
- `cast/`: **10** focused readable client/cast source files (for example HandleFlinching, ApplyStatus, CanForce, GetKeybind).
- `impo/`: **95** files, consisting of **20** readable Lua modules and **75** exact server-script **placeholder** files.
- Total: **105 individual extracted files** in the EXTRACTED tree.

### Critical limitation — server-script placeholders
The 75 files that look like `impo/100_PropTag.lua` contain only the Fishilizer extraction notice:
```
-- Serverscripts are almost IMPOSSIBLE to save without additional requirements in every serverscript
```
Their original server source was not recovered. They are included because the user asked for every original text/Lua file, **not because they provide parry code**. Another AI should ignore those for runtime mechanics.

## Files still not published
The remainder of `impo.zip` (805 total extracted entries), `cast.zip` (29 entries), historical CloverRPG source folders, screenshots, large binary exports and raw player-identifying combat captures have not been uploaded individually. These remain in the local source archives and must not be described as already present on GitHub. See [../DATA_MANIFEST.md](../DATA_MANIFEST.md).

## Notes for future analysis
These are historical decompiler output, not necessarily runnable scripts. Do not execute them in the game or attribute authority to server placeholders. Prefer reading the checked-in `PROJECT_FILES/v5` runtime code alongside real `cast/` client mechanics.
