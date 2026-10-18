# MMORPG Tycoon (working title)

A Roblox game where every player builds and runs their own MMORPG world, inspired by the management and world-building of MMORPG Tycoon 2 (general ideas only, no copied content). It's being built in small, tested phases.

**Current state:** Phase 0 (inspection and architecture) is complete. No gameplay code exists yet.

- [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): concept, loop, MVP scope, exclusions
- [docs/TECHNICAL_ARCHITECTURE.md](docs/TECHNICAL_ARCHITECTURE.md): hierarchy, services, remotes, security, persistence, tests
- [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md): what exists and works right now
- [docs/DEVELOPMENT_LOG.md](docs/DEVELOPMENT_LOG.md): dated phase log

Canonical notes live in the Obsidian vault (`C:\Roblox Dev\MMORPG Tycoon`). The `docs/` folder holds copies.

## Layout (Rojo, `default.project.json`)

```
src/shared/  -> ReplicatedStorage.Shared
src/server/  -> ServerScriptService.Server
src/client/  -> StarterPlayer.StarterPlayerScripts.Client
```
