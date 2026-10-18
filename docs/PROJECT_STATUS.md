# PROJECT_STATUS — MMORPG Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · Last updated: 2026-10-17 (persistent-worlds planning)

## Current phase
**Architecture revision: persistent, visitable player worlds (planning done, awaiting approval).**
Sterling changed the multiplayer design on 2026-10-17: every player owns a persistent world, and the game becomes a **Hub place** (the current map) plus a **World place** (one server per active world). The plan is in TECHNICAL_ARCHITECTURE §12 and the milestones below. **Nothing in this revision is implemented or tested yet.**

Phase 1 (server foundation) is complete and tested. The planned "Phase 2 — client build mode" is **paused** and will be built in the World place after Milestone 2.

## Current project condition
The server side of building works and has been tested in Studio: plots, the grid, Cash, and server-validated placement and removal. **There is no player-facing build UI yet.** Players get a plot and walk around it, but the only way to place objects right now is to call the remotes directly (the Studio connector does this for testing). The UI arrives in Phase 2.

| Item | State |
|---|---|
| Place file | `MMORPG TYCOON.rbxl`, saved by Sterling, unpublished (PlaceId 0). **Contains unsaved Phase 1 changes. Press Ctrl+S.** |
| Scripts in place | 16 (11 game scripts + 5 test modules). All 16 match the repo byte-for-byte (checksum verified). |
| Repo | `sterburger985/MMORPG-TYCOON`. Phase 0 and 1 work is committed in Claude's workspace but **not pushed**. |
| Type check | `luau-lsp analyze` with Roblox definitions: **0 errors** on all source and test files |
| Unit tests | **51 / 51 passing** in Studio Play |

## Feature status
Legend: ✅ tested successfully in Studio · 🟡 implemented, not tested in Studio · ⬜ not implemented

| MVP feature | Status | Evidence / notes |
|---|---|---|
| 1. Players join a server | ✅ | Join creates a profile, sets Cash and assigns a plot |
| 2. Individual plot per player | ✅ | 6 plots built at runtime; the player got Plot_1 with an owner sign. Release on leave was tested by kicking the player: owner reset, objects cleared, sign hidden. |
| 3. Walk around your plot | ✅ (partly) | The character is teleported to its plot's spawn pad and stands on the plot (Y 5.4). Respawn re-teleport is wired up but untested. |
| 4. Basic building interface | ⬜ | Phase 2 |
| 5. Select an object | ⬜ | Phase 2 (catalog data exists: `ItemCatalog.all()`) |
| 6. Placement preview | ⬜ | Phase 2 (`PlacementRules` and `GridMath.anchorForCursor` are ready for it) |
| 7. Grid placement | ✅ (server) | Positions match `GridMath` exactly (max error 0.00000 studs); every object's base sits on the plot surface (Y 2.00) |
| 8. Rotation | ✅ (server) | Rot 0–3 accepted; a rotated cottage occupies the swapped footprint. The rotate *control* is Phase 2. |
| 9. Remove objects | ✅ (server) | Refund applied, cells freed (re-placing on the same spot works), double-remove → `NotFound` |
| 10. Buy with in-game currency | ✅ (server) | Price deducted on place; ran out of Cash → `InsufficientFunds`; exact-amount purchase allowed (unit test) |
| 11. Server ownership and purchase validation | ✅ | 23 forged or invalid remote calls tested (see [[DEVELOPMENT_LOG]]); all rejected with the right reason and no state change. A client faking its Cash attribute had no effect. |
| 12. Multiple players without interference | 🟡 | By design the plot comes from the server, so a client can't name another plot, and remove only searches the caller's own records. Other plots stayed empty while Plot_1 was built on. **Not yet tested with 2+ real clients.** |
| Persistence (post-MVP) | ⬜ | Phase 4 |

## Completed work (Phase 1)
- Shared modules: `Config`, `Net`, `GridMath`, `ItemCatalog`, `PlacementRules`.
- Server: `RateLimiter`, `PlayerDataService`, `PlotService`, `EconomyService`, `PlacementService`, `Main` bootstrap.
- Four placeholder item models (Stone Path, Boulder, Oak Tree, Cottage), built by the reproducible `tools/BuildPlaceholderAssets.lua`.
- Unit-test harness + 4 suites (GridMath, PlacementRules, RateLimiter, ItemAssets): 51 tests.
- Toolchain: Rojo 7.4.4 (build and sourcemap), luau-lsp type checking, script checksum sync check (`tools/checksums.py`).

## Incomplete work
- Build-mode UI, ghost preview and input (Phase 2).
- Final art and sounds (Phase 3). Current models are clean placeholders.
- Persistence (Phase 4).
- Visual check of the plots and models. Studio screenshots came back blank (the window was probably hidden), so the look hasn't been reviewed by eye yet.

## Known problems / risks
- **Publishing required:** DataStores need a published experience; teleports only work in the live Roblox client, not in Studio playtests. Milestones 2–3 need live testing with at least two accounts.
- **Phase 1 assumptions now partly obsolete:** building on hub plots, Cash in PlayerDataService. These move to the World place in M1–M2.
- **No UI yet:** a player who joins sees their plot but can't build. Expected until Phase 2.
- **Multi-client behaviour untested.** Needs *Test → Clients and Servers* (2–3 players).
- **Max Players not set:** the server kicks a 7th player ("server full"). Set Game Settings → Places → Max Players = 6 once published.
- **Unsaved place:** the Phase 1 changes are in the open Studio session. Save with Ctrl+S.
- **Repo not pushed:** the code lives in the place and in Claude's workspace until it's pushed to GitHub.

## Setup requirements (Roblox Studio)
1. **Save the place now** (Ctrl+S) to keep the Phase 1 scripts and models.
2. Keep Studio open, **visible** (not minimised) and with the MCP connector on while Claude works.
3. Later: publish, set Max Players = 6, and enable Studio Access to API Services (needed for persistence).

## What the current map is (inspected 2026-10-17, during Sterling's playtest)
- **Saved in the place:** only the template `Baseplate` (2048×2048, grey grid), the default `SpawnLocation` at the origin, `Lighting` and the placeholder item models in `ReplicatedStorage.Assets.Items`.
- **Created by code at runtime (PlotService):** `Workspace.Plots.Plot_1…6`. Each has a grass `Base` (256×256 studs), a cobblestone rim, a `SpawnPad` and an `OwnerSign` billboard ("<DisplayName>'s World"). They're laid out 3 × 2 with **48-stud walkways of bare Baseplate** between them; these are the "roads". There are no road parts and no terrain.
- **Plot assignment:** first free plot on join (PlotService.assign); freed and cleared on leave.
- **Spawning:** the character spawns at the default SpawnLocation, then the server moves it to its plot's `SpawnPad` (on every respawn).
- **Label:** `OwnerSign` BillboardGui on the SpawnPad, text set by PlotService.
- **Saving/loading:** none. Data is in memory only.
- **Places:** one place, unpublished (PlaceId 0), so no multi-place setup and no DataStore access yet.
- **Sync:** the repo (Rojo layout) is the source of truth; scripts are written into Studio through the connector and checksum-verified. Rojo isn't running locally.

## Milestones for persistent worlds (proposed, awaiting approval)

### Milestone 1 — Prepare the hub for persistent world ownership
- **Sterling first:** publish the experience (private is fine), enable Studio Access to API Services, set Max Players = 6. (Claude can't publish.)
- **Files / instances:** repo split into `src/server/common`, `src/server/hub`; `hub.project.json`. New `WorldStore` (DataStore wrapper: Meta + Index, retries, `UpdateAsync` field merges), pure `WorldSchema` (versioned Meta/Data defaults + validation + migration). `PlotService` → `HubPlotService`: same layout, same assignment and spawning, sign now shows the **world name** from Meta and a visibility badge, plus a **portal pad** (inactive until M2). `PlacementService` and `EconomyService` are **removed from the hub's startup** (building moves to the World place) but kept in the repo.
- **Depends on:** a published experience for real DataStore tests (unit tests don't need it).
- **Security:** Meta keyed only by `player.UserId` on the server; the client never names a UserId; no access codes exist yet.
- **Tests:** unit — WorldSchema defaults, validation and migration; WorldStore with a fake DataStore (create, read, field merge, retry, `nil` vs error). Studio (published) — join creates Meta; rejoin reads the same Meta; layout unchanged (6 plots, same positions); no build remotes in the hub.
- **Accept when:** a player's world Meta exists after first join and is unchanged after rejoining in a new server; the hub looks and behaves as today apart from the sign text and portal pad; all old and new unit tests pass.

### Milestone 2 — World place: load and save a world
- **Sterling first:** add a second place ("World") to the experience in Studio's Asset Manager and open it in Studio. Claude then fills it.
- **Files / instances:** `world.project.json`; `src/server/world/` with `WorldSessionService` (owner from PrivateServerId → index; Studio dev mode), `WorldDataService` (lock, load, validate, rebuild, autosave, owner-leave save, BindToClose), `WorldPlotService` (one plot, reusing today's plot builder), and the existing `PlacementService` / `EconomyService` pointed at the world (owner-only `canBuild`; Cash in `WorldData.economy`). Hub: `TravelService` with `RequestEnterMyWorld` (create access code + index once, SafeTeleport). World: `RequestReturnToHub`. Item models copied into the World place.
- **Depends on:** M1; the World place's PlaceId in Config.
- **Security:** owner identity from our DataStore, never from teleport data; invalid servers send players to the hub; session lock on every write; validated rebuild drops bad entries; load failure → read-only and never overwrite.
- **Tests:** unit — lock acquire/refresh/steal-stale logic, rebuild validation (unknown item, overlap, out of bounds, too many objects). Studio dev mode — place objects, stop, play again → identical world; simulated save failure keeps the old save; corrupt entry dropped. Live client — hub → my world → build → hub → my world again shows the same objects (new session); leave and rejoin the game the next day.
- **Accept when:** a world reloads exactly in a brand-new session; no save ever replaces good data with defaults; two overlapping sessions can't both write.

### Milestone 3 — Visiting, permissions, joining a running world
- **Files / instances:** pure `AccessPolicy` + tests; hub `RequestVisitWorld(ownerUserId)` (target must be in this hub server); world-side access gate on `PlayerAdded`; read-only visitors; owner settings remotes `RequestSetVisibility` / `RequestRenameWorld` (TextService filtering) with eviction of now-unauthorized visitors; hub world cards (name, owner, badge, "Visit"/"Locked"); error UI for full world, teleport failure, denied access.
- **Depends on:** M2.
- **Security:** friends checked with `IsFriendsWithAsync` on the server (fails closed); access checked in the hub **and** in the world; codes never reach clients; visitors' build, remove and settings requests rejected server-side; private worlds show no details.
- **Tests:** unit — AccessPolicy matrix, argument validation. Live client with 2–3 accounts (Sterling + alt or friend): visit a Public world; Friends-only allowed for a friend and denied for a non-friend; Private denied; two visitors land in **the same** running session; owner leaves → visitors stay read-only → world closes when empty and is still saved; owner switches to Private while a visitor is inside → visitor sent to hub; a full world shows a message.
- **Accept when:** every row of that live test list passes and no client action can enter, see or change a world it isn't allowed to.

## Next implementation task
**Milestone 1**, after Sterling approves the plan and answers the open questions in GAME_DESIGN §9 (rows 9–12), and once the experience is published.
