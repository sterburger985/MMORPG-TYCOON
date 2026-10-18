# MMORPG Tycoon (working title)

A Roblox game where every player builds and runs their own MMORPG world, inspired by the management and world-building of MMORPG Tycoon 2 (general ideas only, no copied content). It's being built in small, tested phases.

**Current state:** Phase 1 (server foundation) is complete and tested in Studio: 6 plots per server, a 4-stud grid, Cash, and server-validated placement and removal with rate limiting. There's no build UI yet; that's Phase 2.

- [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): concept, loop, MVP scope, exclusions
- [docs/TECHNICAL_ARCHITECTURE.md](docs/TECHNICAL_ARCHITECTURE.md): hierarchy, services, remotes, security, persistence, tests
- [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md): what exists and works right now
- [docs/DEVELOPMENT_LOG.md](docs/DEVELOPMENT_LOG.md): dated phase log

Canonical notes live in the Obsidian vault (`C:\Roblox Dev\MMORPG Tycoon`). The `docs/` folder holds copies.

## Layout (Rojo, `default.project.json`)

```
src/shared/  -> ReplicatedStorage.Shared              (Config, Net, GridMath, ItemCatalog, PlacementRules)
src/server/  -> ServerScriptService.Server           (Main bootstrap, Services/, Util/)
tests/       -> ServerStorage.UnitTest               (RunUnitTest + Cases/)
tools/       -> dev helpers (BuildPlaceholderAssets.lua, checksums.py); not synced
```

Item models live in the place file under `ReplicatedStorage.Assets.Items` and are rebuilt by `tools/BuildPlaceholderAssets.lua`.

## Testing

In Studio, press Play, then run this from the command bar (server):

```lua
require(game.ServerStorage.UnitTest.RunUnitTest)()
```

Expected output: `[SUMMARY] 51 run, 51 passed, 0 failed`.
