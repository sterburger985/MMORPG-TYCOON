# MMORPG Tycoon (working title)

A Roblox game where every player builds and runs their own MMORPG world, inspired by the management and world-building of MMORPG Tycoon 2 (general ideas only, no copied content). It's being built in small, tested phases.

**Current state:** Phase 2 (persistent worlds) is code complete and unit-tested: versioned world saves keyed by UserId, safe DataStore loading and saving with a session lock, and validated rebuilding in a separate World place. Studio verification is waiting on publishing and creating the World place. Phase 1 (plots, grid, server-validated placement) is tested in Studio.

- [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): concept, loop, MVP scope, exclusions
- [docs/TECHNICAL_ARCHITECTURE.md](docs/TECHNICAL_ARCHITECTURE.md): hierarchy, services, remotes, security, persistence, tests
- [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md): what exists and works right now
- [docs/DEVELOPMENT_LOG.md](docs/DEVELOPMENT_LOG.md): dated phase log

Canonical notes live in the Obsidian vault (`C:\Roblox Dev\MMORPG Tycoon`). The `docs/` folder holds copies.

## Layout (one Rojo project per place)

```
src/shared/          -> ReplicatedStorage.Shared                  (both places)
src/common/server/   -> ServerScriptService.Server.{Services,Util} (both: PlacementService, EconomyService, RateLimiter)
src/hub/server/      -> ServerScriptService.Server                 (Hub: Main, PlotService, PlayerDataService)
src/world/server/    -> ServerScriptService.Server                 (World: Main, World* services, adapters)
tests/common, tests/world -> ServerStorage.UnitTest.Cases
hub.project.json, world.project.json
tools/check.sh        build + type-check both places (rojo, luau-lsp)
tools/run-tests.luau  run the unit tests outside Studio (lune run tools/run-tests.luau <built place>)
```

Item models live in each place file under `ReplicatedStorage.Assets.Items` and are rebuilt by `tools/BuildPlaceholderAssets.lua`.

## Testing

In Studio, press Play, then run this from the command bar (server):

```lua
require(game.ServerStorage.UnitTest.RunUnitTest)()
```

Locally: `tools/check.sh`, then `rojo build world.project.json -o world.rbxl && lune run tools/run-tests.luau world.rbxl`.
