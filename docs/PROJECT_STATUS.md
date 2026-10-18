# PROJECT_STATUS — MMORPG Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · Last updated: 2026-10-17

## Current phase
**Phase 0 — Inspection & architecture: complete, awaiting Sterling's review.**
Phase 1 must not start until Phase 0 is approved.

## Current project condition
The project is a **blank slate**. No gameplay exists yet.

### What was discovered (verified 2026-10-17 through the Roblox Studio connector)
| Item | Finding |
|---|---|
| Studio place | One open instance named `Place1`, in Edit mode. **Unsaved and unpublished** (PlaceId 0, GameId 0). |
| Template | Default Baseplate: `Workspace.Baseplate` (2048 × 16 × 2048), `SpawnLocation`, `Camera`, `Terrain` (empty) |
| Scripts | **0** scripts in Workspace, ReplicatedStorage, ReplicatedFirst, ServerScriptService, ServerStorage, StarterGui, StarterPack and StarterPlayer |
| UI | None (StarterGui empty) |
| Models / assets | None beyond the template |
| Lighting | Default template set: Sky, SunRays, Atmosphere, Bloom, DepthOfField; ClockTime 14.5 |
| Streaming | `Workspace.StreamingEnabled = true` |
| Config files | None in the place |
| Sync tooling | No Rojo, Argon or Wally found in the place. Rojo is not running (no local project folder connected). |
| GitHub repo | `sterburger985/MMORPG-TYCOON` exists and is **empty** (no commits) |
| Docs | None existed before Phase 0 |
| Obsidian vault | `C:\Roblox Dev` has Home and RoCiv notes; no MMORPG Tycoon folder before this phase |
| Reference workflow | RoCiv repo uses a Rojo `default.project.json` + `tools/StudioSync.lua`. MMORPG Tycoon adopts the same approach. |

## Feature status
| Feature (MVP) | Status |
|---|---|
| 1. Players join a server | Engine default only; no game logic. **Not implemented** |
| 2. Individual plot per player | **Not implemented** |
| 3. Walk around plot | Default character only; no plot exists. **Not implemented** |
| 4. Basic building interface | **Not implemented** |
| 5. Select an object | **Not implemented** |
| 6. Placement preview | **Not implemented** |
| 7. Grid placement | **Not implemented** |
| 8. Rotation before placement | **Not implemented** |
| 9. Remove objects | **Not implemented** |
| 10. Purchase with in-game currency | **Not implemented** |
| 11. Server ownership and purchase validation | **Not implemented** |
| 12. Multiplayer building without interference | **Not implemented** |
| Persistence (post-MVP) | **Not implemented** |

## Completed work
- Inspected the Studio place, the GitHub repo, the Obsidian vault and the RoCiv reference workflow.
- Wrote GAME_DESIGN, TECHNICAL_ARCHITECTURE, PROJECT_STATUS and DEVELOPMENT_LOG.
- Created the vault project folder, hub note, decisions log and Phase 0 note.

## Incomplete work
- All gameplay systems (by design; Phase 0 is documentation only).
- Repo scaffold (`default.project.json`, `.gitignore`, README, `docs/`) is prepared but **not pushed** until Sterling OKs pushing.
- Open design questions in [[GAME_DESIGN]] §9 still need answers. Proposed defaults are used unless Sterling changes them.

## Known problems / risks
- **The place is unsaved.** If Studio closes, the place is lost. It's only a blank template today, but it must be saved before Phase 1.
- **The place is unpublished.** DataStores (persistence) can't be tested until it's published and API access is enabled. Not needed until the persistence phase.
- **No Rojo:** code reaches Studio through the Studio connector or StudioSync, so repo and place can drift. Mitigation: after each sync, verify the scripts in the place match the repo commit.
- **Multi-client testing:** the connector drives one client. Multi-player checks need Sterling to run *Test → Clients and Servers*.
- **Name and IP:** "MMORPG Tycoon" is an existing commercial title. Choose an original name before publishing publicly.

## Setup requirements (Roblox Studio)
Before Phase 1:
1. **File → Save to File As…** → `MMORPGTycoon.rbxl` (any folder; suggested `C:\Roblox Dev\MMORPG Tycoon\Place\` or next to the repo).
2. Keep the place open in Studio with the MCP / Assistant connector enabled when asking Claude to work.

Later (persistence phase):
3. **File → Publish to Roblox** (can stay private).
4. **Game Settings → Security → Enable Studio Access to API Services.**

Optional:
5. Install Rojo (VS Code extension + Studio plugin) if you want live file sync on your PC.

## Next implementation task
**Phase 1 — Server foundation: plots, grid and authoritative placement** (outline in [[DEVELOPMENT_LOG]]; a Phase 1 note will be created when it starts).
