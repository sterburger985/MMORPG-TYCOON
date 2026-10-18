# DEVELOPMENT_LOG — MMORPG Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · Newest entry at the top.

---

## 2026-10-17 — Phase 0: Inspection & architecture

### Files and systems inspected
- **Roblox Studio (through the connector):** instance list (`Place1`, the only open Studio). Studio state was Edit mode. Explored the full DataModel tree. Ran a read-only Luau inventory of Workspace, ReplicatedStorage, ReplicatedFirst, ServerScriptService, ServerStorage, StarterGui, StarterPack, StarterPlayer, Lighting, SoundService, Teams and MaterialService. Searched the tree for Rojo, Argon, Wally and sync instances. Took a viewport screenshot.
- **GitHub:** `sterburger985/MMORPG-TYCOON` cloned; it is empty (no commits).
- **Reference project:** `sterburger985/RoCiv`. Read `default.project.json`, `README.md`, `.gitignore` and `tools/StudioSync.lua` to copy the established workflow.
- **Obsidian vault `C:\Roblox Dev`:** `Home.md`, `Welcome.md`, `Reference/Roblox Gotchas.md`, `RoCiv/RoCiv.md`, `RoCiv/RoCiv Decisions.md`, `RoCiv/Phases/Phase 1 - Procedural Map.md`.
- **Research:** a summary of MMORPG Tycoon 2's gameplay (for inspiration only), plus the official Roblox docs for DataStore limits and UnreliableRemoteEvent payload limits.

### Findings
- The place is the untouched Baseplate template: 0 scripts, no UI, no assets, unsaved and unpublished. StreamingEnabled is on.
- No sync tooling is in the place.
- See [[PROJECT_STATUS]] for the full table.

### Decisions made
Also recorded in [[MMORPG Tycoon Decisions]].
1. **Workflow:** Rojo-layout GitHub repo as the source of truth (same as RoCiv). Code goes into Studio through the Studio connector, with StudioSync as the fallback.
2. **Architecture:** plain ModuleScript services and controllers with `Init`/`Start`, plus a single bootstrap per side. No framework.
3. **Pure shared logic** (`GridMath`, `PlacementRules`) so validation is unit-testable and shared with the client preview. The server re-validates everything.
4. **Purchase happens at placement:** one atomic `RequestPlace`, no separate buy remote.
5. **Two placement layers** (Floor and Object) so paths and plazas can sit under props.
6. **Grid:** 4-stud cells, 64 × 64 cell plots, rotation in 90° steps. Up to 6 plots per server (proposed; Sterling to confirm).
7. **Replication:** Cash and plot assignment through player attributes; world through instance replication.
8. **Persistence later:** `UpdateAsync` with a session lock, one key per player, compact `placed[]` format. ProfileStore to be evaluated at that point.
9. **Asset quality rule:** no unvetted Toolbox models. Assets come from connector generation, Blender or hand-building.

### Files created or modified
| File | Action |
|---|---|
| `C:\Roblox Dev\MMORPG Tycoon\MMORPG Tycoon.md` | created (project hub) |
| `C:\Roblox Dev\MMORPG Tycoon\GAME_DESIGN.md` | created |
| `C:\Roblox Dev\MMORPG Tycoon\TECHNICAL_ARCHITECTURE.md` | created |
| `C:\Roblox Dev\MMORPG Tycoon\PROJECT_STATUS.md` | created |
| `C:\Roblox Dev\MMORPG Tycoon\DEVELOPMENT_LOG.md` | created |
| `C:\Roblox Dev\MMORPG Tycoon\MMORPG Tycoon Decisions.md` | created |
| `C:\Roblox Dev\MMORPG Tycoon\Phases\Phase 0 - Architecture.md` | created |
| `C:\Roblox Dev\Home.md` | modified (added the project link; nothing removed) |
| `C:\Roblox Dev\Reference\Roblox Gotchas.md` | modified (added one gotcha) |
| Roblox Studio place | **not modified** |
| claude.ai Project "Roblox MMORPG TYCOON" | added copies of GAME_DESIGN, TECHNICAL_ARCHITECTURE, PROJECT_STATUS |
| GitHub repo | scaffold prepared locally (README, `.gitignore`, `default.project.json`, `docs/`); **not pushed** |

### Problems discovered
- The place is unsaved and unpublished (see setup requirements in [[PROJECT_STATUS]]).
- Connector gotcha: Luau run through the Studio connector lacks RobloxScript capability, so some properties (for example `Lighting.Technology`) throw on read. Logged in [[Roblox Gotchas]].

### Testing performed
- None of the gameplay was tested, because no gameplay exists. Only read-only inspection queries were run.

### Testing that remains necessary
- Everything in the TECHNICAL_ARCHITECTURE §11 test plan, starting in Phase 1.

### Next: Phase 1 outline (pending approval)
**Goal:** a working, server-authoritative build core that can be exercised without UI.
1. Save the place; add `default.project.json` and the folder skeleton.
2. Shared: `Config`, `GridMath`, `ItemCatalog` (3–4 placeholder items made of simple, cleanly built parts), `PlacementRules`, `Net`.
3. Server: `PlayerDataService` (in memory), `PlotService` (6 plot tiles built in code, assign on join, free on leave, spawn the owner on their plot), `EconomyService`, `PlacementService` with the full TECHNICAL_ARCHITECTURE §7 validation chain and remotes.
4. Unit tests: GridMath, PlacementRules, Economy, rate limiter.
5. Integration and security tests through the connector (forged remote calls).
6. A minimal dev-only test hook (Studio only) so placement can be triggered before the UI exists.
7. Update PROJECT_STATUS and DEVELOPMENT_LOG with honest per-feature status.

**Out of scope for Phase 1:** build-mode UI, ghost preview, final art and persistence (Phase 2 = client build mode, Phase 3 = assets and polish, Phase 4 = persistence).
