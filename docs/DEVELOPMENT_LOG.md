# DEVELOPMENT_LOG — MMORPG Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · Newest entry at the top.

---

## 2026-10-17 (late) — Phase 2: Persistent worlds and world loading

### Inspection (before any change)
| Question | Finding |
|---|---|
| Phase 0 docs | All four exist (GAME_DESIGN, PROJECT_STATUS, TECHNICAL_ARCHITECTURE, DEVELOPMENT_LOG) and were read |
| Plots work? | Yes (tested in Phase 1), created at runtime by the hub PlotService |
| Building and placement | Server side yes (`PlacementService`, tested); **no client build UI** |
| Place and remove | Yes, through remotes (tested in Phase 1) |
| Economy | Yes, in-memory Cash (`EconomyService`) |
| Player data saved? | **No.** In memory only |
| Sync workflow | Rojo-layout repo + Studio connector writes + checksum check; Rojo not running locally |
| World place exists? | **No.** One place only; **unpublished** (PlaceId 0, GameId 0). DataStore probe: *"You must publish this place to the web to access DataStore."* |
| Reusable scripts | Shared modules, PlacementService, EconomyService, RateLimiter, test harness |
| Phase 1 enough? | Yes for the server side. The missing client UI doesn't block persistence. |
Sterling was in a playtest in the hub throughout, so the hub was inspected read-only and **not modified**.

### What was built
- Repo restructured for two places: `src/shared` (both), `src/common/server` (PlacementService, EconomyService, RateLimiter: both), `src/hub/server`, `src/world/server`; `hub.project.json`, `world.project.json`. Hub instance paths are unchanged.
- World place server: `WorldConfig`, `WorldSchema` (format v1 + validation + migration hook), `WorldStore` (UpdateAsync, session lock, bounded retries, size/encode checks), `WorldLoader`, `WorldSessionService`, `OwnerResolver`, `WorldState`, world `PlotService` and `PlayerDataService` adapters, `StudioDevStore` (Studio-only test store), `Main`.
- Shared/common, additive only: `Net` (+`Visibility`, `RequestSetVisibility`, `NotReady`/`ReadOnly` reasons, `SettingsResult`), `PlacementService` (+`restore`, +`onChanged`).
- Tests: `WorldSchema_Test` (12), `WorldStore_Test` (17), `WorldLoader_Test` (9).
- Tools: `tools/check.sh` (Rojo build + luau-lsp type check per place), `tools/run-tests.luau` (runs the real test suites outside Studio with Lune 0.8.9).

### Decisions
- One record per world (settings + objects + Cash + lock); the hub-written Meta key waits for the travel phase. *Why:* single writer in Phase 2, fully atomic.
- Grid-native object format (cell + quarter turns), matching the placement system.
- Persist Cash with the objects. *Why:* otherwise rejoining would hand out free money (refunds on persisted objects).
- Invalid saved objects are quarantined, not deleted.
- Studio uses the `StudioTest_*` DataStore namespace, or the in-place dev store, so testing can never touch live data.
- Live World servers fail closed until the hub writes the reserved-server index (travel phase).

### Problems found and fixed
- Type checker: `Player:LoadCharacter` is deprecated → switched to `LoadCharacterAsync` (pcall-wrapped).
- Test bug: a `{ Version = nil }` override doesn't remove a key in a Lua table constructor → the test now sets `record.Version = nil` explicitly.
- Local runner needed engine datatypes (`CFrame`, `Vector3`) injected → added.
- Self-review: with `CharacterAutoLoads` off, players would never respawn after dying in a world → added an explicit respawn after `Players.RespawnTime` (only while the world is live). Not tested in Studio yet.

### Testing performed
- `tools/check.sh`: **Hub and World build OK, 0 type errors.**
- Local Luau runtime (Lune), real modules from the Rojo-built places, fake DataStore: **World 72/72 passed; Hub 34/34 passed** (ItemAssets suite skipped locally; it needs engine model APIs and passed in Studio in Phase 1).
- These cover Phase 2 Tests **A** (new world), **B/E** (save → new session → identical), **C** (invalid data quarantined), **D** (outage → failed, nothing written), **F** (two owners isolated), plus lock contention, stale-lock takeover, wrong owner, future version, corrupt record, oversized and unencodable saves.

### Testing still required
- **Everything in Studio** (blocked: no World place, unpublished): run all suites in Studio; session-level A–F using the dev store (new world → place → save → copy saved JSON into Edit → Play → identical; invalid JSON; `FailMode=all`; `OwnerOverride`); real-DataStore pass in the `StudioTest_*` namespace after publishing.
- **Test G (missing World place):** documented the manual setup (TECHNICAL_ARCHITECTURE §13.10). The multi-place workflow is **not** tested.
- Sync the additive `Net`/`PlacementService` changes into the hub and re-run hub tests in Studio.

---

## 2026-10-17 (evening) — Architecture revision: persistent player worlds (inspect and plan only)

### Request
Sterling changed the multiplayer design: persistent, UserId-owned worlds that players can visit, with the current map becoming the central **Hub place** and a separate **World place**. The task was to inspect and plan only: no rebuild, no map replacement, no travel implementation.

### Inspected
- Studio place (Sterling was playtesting, so the inspection was read-only on the Server datamodel; nothing was stopped or changed). Workspace contains the template Baseplate and SpawnLocation; `Plots` with 6 runtime-built plots (Base, Rim1–4, SpawnPad with OwnerSign, Placed); Sterling's character on Plot_1. 16 game/test scripts as of Phase 1 (plus Roblox's default player scripts). `ReplicatedStorage`: Assets, Shared, Remotes. No terrain. PlaceId 0 / GameId 0 (unpublished).
- The repo code paths for plot building, assignment, spawning and the sign (PlotService) and data (PlayerDataService, in memory only).
- **The screenshot mentioned in the brief wasn't attached** (only the text file arrived). The description (grassy plots, roads, spawn on the plot, owner label) matches what the code builds: the "roads" are the bare Baseplate walkways between plots.
- Official Roblox docs: TeleportService (ReserveServerAsync, TeleportAsync), TeleportOptions, "Teleport between places" (Studio limitation, secure access control, teleport data is unencrypted and visible to the client, failure handling), DataModel (PrivateServerId, one running instance per private server, BindToClose 30 s), Player (IsFriendsWithAsync), DataStore limits.

### Findings
- The map is generated by code, not hand-built, so it can be kept exactly as-is in the Hub by keeping PlotService's layout.
- No saving or loading exists, and the project has only one place.
- Key platform fact: a reserved-server access code is valid indefinitely and Roblox runs at most one instance per code. So **one stored code per world** gives "join the running session, or start a new one" with no duplicates and no MemoryStore.

### Decisions (proposed, awaiting approval)
- Two places in one experience: Hub (public servers) + World (reserved servers, one code per world).
- World identity comes from `PrivateServerId` → our own DataStore index, never from teleport data.
- DataStores: `WorldMeta_v1` (settings, code), `WorldData_v1` (layout, economy, progression; session-locked), `WorldIndex_v1` (PrivateServerId → owner).
- Access is checked in the hub and again in the world; friends are checked server-side and fail closed. Settings change only inside your own world, so no MessagingService.
- Building moves to the World place. Hub plots become showcases and portals.
- Defer MemoryStore, MessagingService, ProfileStore and a global world browser until needed.

### Files changed
| File | Change |
|---|---|
| `GAME_DESIGN.md` | §5 rewritten for hub + persistent worlds (old design kept collapsed); §6, §7, §8 adjusted; §9 questions 6 resolved, 9–12 added |
| `TECHNICAL_ARCHITECTURE.md` | header note; new **§12 Hub-and-World architecture** (places, sessions, identity, data model, load, save and concurrency rules, travel, access control, code layout, deferrals) |
| `PROJECT_STATUS.md` | current phase, map inspection findings, Milestones 1–3 with files, dependencies, security, tests, acceptance |
| `DEVELOPMENT_LOG.md` | this entry |
| `MMORPG Tycoon Decisions.md`, `MMORPG Tycoon.md` | decisions and status updated |
| Studio place / repo code | **not changed** |

### Testing
- None. This was a planning task. **Nothing in the hub-and-world design has been implemented or tested in Studio or live.**

### Open questions for Sterling
GAME_DESIGN §9 rows 9–12: default visibility, visitors after the owner leaves, what hub plots show, max visitors per world. Also: please re-attach the map screenshot if it shows anything the code doesn't build.

---

## 2026-10-17 — Phase 1: Server foundation (plots, grid, authoritative placement)

### Inspected before changing anything
- Studio place `MMORPG TYCOON.rbxl` (saved by Sterling): still the bare template with 0 scripts. It was in **Play mode** when work began, so Claude stopped the playtest (nothing in Edit mode was affected).
- Vault notes: no changes since Phase 0, so the GAME_DESIGN §9 proposed defaults stand.
- Repo: Phase 0 commit present in Claude's workspace.

### Plan followed
Shared pure logic first (type-checked), then services, then reproducible placeholder assets, then sync into Studio, unit tests, and integration and security tests through the connector.

### Files created (repo → place)
| Repo file | Place instance |
|---|---|
| `src/shared/Config.luau` | `ReplicatedStorage.Shared.Config` |
| `src/shared/Net.luau` | `ReplicatedStorage.Shared.Net` |
| `src/shared/GridMath.luau` | `ReplicatedStorage.Shared.GridMath` |
| `src/shared/ItemCatalog.luau` | `ReplicatedStorage.Shared.ItemCatalog` |
| `src/shared/PlacementRules.luau` | `ReplicatedStorage.Shared.PlacementRules` |
| `src/server/Main.server.luau` | `ServerScriptService.Server.Main` (Script) |
| `src/server/Util/RateLimiter.luau` | `ServerScriptService.Server.Util.RateLimiter` |
| `src/server/Services/PlayerDataService.luau` | `…Server.Services.PlayerDataService` |
| `src/server/Services/PlotService.luau` | `…Server.Services.PlotService` |
| `src/server/Services/EconomyService.luau` | `…Server.Services.EconomyService` |
| `src/server/Services/PlacementService.luau` | `…Server.Services.PlacementService` |
| `tests/RunUnitTest.luau` | `ServerStorage.UnitTest.RunUnitTest` |
| `tests/Cases/{GridMath,PlacementRules,RateLimiter,ItemAssets}_Test.luau` | `ServerStorage.UnitTest.Cases.*` |
| `tools/BuildPlaceholderAssets.lua` | built `ReplicatedStorage.Assets.Items.{StonePath, Boulder, OakTree, Cottage}` |
| `tools/checksums.py` | dev helper: compares repo scripts with the place |

Modified: `default.project.json` (added `ServerStorage.UnitTest ← tests`; the client mapping was removed until Phase 2 creates `src/client`).
Created at runtime, not saved in the place: `Workspace.Plots.Plot_1…6` and `ReplicatedStorage.Remotes.{RequestPlace, RequestRemove}`.

### Decisions
- **Plots are generated at runtime** by PlotService if they're missing. This keeps the repo as the source of truth. Hand-made plot models with the same names (`Base`, `Placed`, `SpawnPad`) will be picked up instead later.
- **No in-game dev hook was added.** The Studio connector calls the remotes directly from the Client datamodel, which tests the real network path. This avoids shipping throwaway debug code.
- **Remove uses only the caller's own records**, so another player's object id returns `NotFound` (this leaks no information).
- Item models pivot on `Hitbox.PivotOffset` (see the bug below).

### Problems found and fixed
1. **Type errors** (luau-lsp): a layer-type mismatch between ItemCatalog and PlacementRules, `pcall` typing on a no-return function, and the service list type in Main. All fixed; the type check is clean.
2. **Objects sank into the ground by half their height.** Integration tests showed hitbox bottoms at Y −5 / −4.5 instead of 2. Cause: a Model with a `PrimaryPart` pivots on `PrimaryPart.PivotOffset`, and `WorldPivot` is ignored. A new `ItemAssets_Test` suite reproduced it (4 failures). The builder was fixed (`PivotOffset`) and the templates patched; the test then passed and every object's base measured exactly 2.00. Logged in [[Roblox Gotchas]].
3. Test-script slip: a funds-drain loop hit an existing boulder (`Blocked`); the test was re-run on empty cells.

### Testing performed (Studio Play, single client, through the connector)
- **Type check:** 0 errors (luau-lsp + Roblox definitions). **Rojo build:** OK.
- **Sync check:** all 16 scripts in the place match the repo (checksums).
- **Unit tests:** 51/51 pass (GridMath 13, PlacementRules 15, RateLimiter 6, ItemAssets 17).
- **Join:** 6 plots built; the player got Plot_1 with Cash 2000, PlotId 1, an owner sign, and a character standing on the spawn pad.
- **Placement / removal (all correct):** valid place → ok and Cash deducted; same spot / overlap → `Blocked`; adjacent → ok; Floor under Object → ok; rotated cottage flush in the far corner → ok; unrotated → `OutOfBounds`; negative or huge cell → `OutOfBounds`; NaN / fraction / inf / string coordinates, rot 7, table id, no args → `BadArgs`; unknown item → `BadItem`; extra args ignored; remove → refund; double remove or unknown id → `NotFound`; number or 5000-char id → `BadArgs`; re-place on a freed spot → ok.
- **Economy:** drained Cash with cottages → `InsufficientFunds` at $135 left. The client set its own Cash attribute to 999999 and the server ignored it.
- **Rate limit:** 30 back-to-back requests → 7 `RateLimited`.
- **World check:** 13 placed models. Position error vs GridMath 0.00000; all parts anchored; no same-layer overlap; other plots untouched.
- **Leave:** kicking the player freed Plot_1 (owner 0, 0 objects, sign hidden).
- **Console:** no errors or warnings from game code (only Roblox CoreGui UIBlox warnings).

### Testing that remains necessary
- 2–3 real clients (Studio *Clients and Servers*): parallel building, no interference, plot release when one player leaves.
- Respawn after death re-teleports to the plot.
- A visual review of plots and models (screenshots came back blank because the Studio window was likely hidden).
- Performance with full plots (Phase 3).

### Next: Phase 2 outline (pending approval)
**Goal:** a player can build their world with mouse or touch, with no command-bar help.
1. `src/client`: `Main.client`, `BuildingController` (mode state machine, ContextActionService bindings: B = build, R = rotate, X = remove, Esc/Q = cancel, plus touch buttons).
2. `PlacementController`: ghost preview (reused clone, translucent), mouse or touch raycast onto your plot, snapping via `GridMath.anchorForCursor`, green/red tint via `PlacementRules` on a client occupancy mirror built from `Placed` attributes, a grid overlay shown only in build mode.
3. Build UI: Cash display, a catalog bar grouped by category with prices (greyed out when unaffordable), error toasts using `Net.Message`, remove-mode hover highlight.
4. Feedback: placement pop tween and sound, a red flash on rejection.
5. Tests: client logic kept in testable modules; connector-driven input simulation and screenshots; device-simulator check for phone layout.

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
