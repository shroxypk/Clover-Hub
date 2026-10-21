# Clover Hub

Luau project for Clover Hub, developed and tested against the user's Roblox experience.

## Status

Repository initialized. The previously prepared v3.2 script has **not** been published here yet. Do not run a loadstring until a verified `main.lua` build is committed.

## Planned layout

- `main.lua`: self-contained executable release
- `src/`: maintained core, farming, combat, movement, and UI modules
- `diagnostics/`: test utilities and observation reports
- `docs/`: changelogs and development notes

## Development principles

- Validate remote-call success separately from observed gameplay effects.
- Cap background tasks and remote requests; clean up connections on reload.
- Preserve original character and lighting settings when disabling controls.
- Avoid including secrets in public source code.
