# PROJECT_STATUS — MMO Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · Last updated: 2026-10-18 (Phase 4 build mode and blue UI live in the published experience; real DataStores verified)

## Current phase
**Phase 4: Build mode + magic-fantasy blue UI. Built, tested in Studio against real DataStores, and published to the private experience. Awaiting review.**

- **Published:** experience **"MMO Tycoon"** (GameId 10771780924, private/Playtesters). Hub place 78195623283467, World place 86431904123318, both updated and published 2026-10-18.
- **Real DataStores verified** (Studio, `StudioTest_*` stores): new world, autosave of 17 objects (1,121 bytes), fresh session → `17 objects rebuilt, 0 dropped`, Cash restored. This closes the last Phase 2 item.
- **Build mode delivered:** bottom dock (HUB, 5 category tabs, rotate, remove, cancel), item tray with live 3D previews and prices, ghost preview that snaps to the grid with a cyan/red footprint plate and a price/reason tag, R to rotate, click to place, X for remove mode with refund tag, Q/Esc to cancel, a placement burst effect, and touch controls (tap, then ✅ PLACE / 🔄 ROTATE). The server still decides everything.
- **10 items** (6 new: Arcane Crystal, Lantern Post, Wooden Fence, Stone Well, Market Stall, Mage Tower), built by code in one style.
- **UI restyle:** deep sapphire glass panels, luminous cyan rims, bright azure buttons, outlined white headings, gold only for money; blue World Gates and rune ring in the hub; settings moved to a ⚙ WORLD side button.
- **Title:** "MMO Tycoon" in game and as the experience name. Visitors capped at **4** per world (the server refuses a 5th with a message).

### Phase 4 feature status
| Feature | Status | Evidence |
|---|---|---|
| Category tabs + item tray with 3D previews | ✅ | Real clicks in Studio; previews render |
| Ghost preview, grid snap, valid/invalid tint, price/reason tag | ✅ | Red "Something is already there." over an occupied spot |
| Rotate (R / button) and place (click) | ✅ | Cottage rotated and placed; Cash 2,000 → 1,750 |
| Remove mode (X / button) with hover highlight + refund | ✅ | Cottage removed; Cash back to 2,000 |
| Placement burst + pop-in animation | ✅ | Seen in Studio |
| Visitor dock ("VISITING · LOOK AROUND", no build tools) | 🟡 | Code path; visitors were tested before build mode existed |
| Touch controls | 🟡 | Built; not tested on a touch device or the emulator |
| Real DataStore save/reload | ✅ | 17 objects reloaded identically |
| Visitor cap (4) | 🟡 | Server check + GameFull message; needs 5+ players |
| Live hub ↔ world teleport | 🟡 | Published; needs a run in the Roblox app (one account is enough for your own world) |

### Unit tests
Local (Lune): Hub 51/51, World 89/89. Studio server: **Hub 92/92, World 130/130** (includes `ItemAssets_Test` for all 10 models).

### Phase 3 feature status (2026-10-18, before publishing)
Legend: ✅ tested in Studio · 🧪 unit-tested · 🟡 implemented, needs the published experience to test · ⬜ not implemented

| Feature | Status | Evidence |
|---|---|---|
| World Gate on every hub plot (prompt + label) | ✅ | Visible on all 6 plots; label personalised; prompt calls the same server function as the button (prompt itself not walked into) |
| ENTER MY WORLD button → server travel checks | ✅ | Real click → server → "Travel between places only works in the live game" toast |
| Hub world card (name, visibility, objects) | ✅ / 🟡 | Shows "Info unavailable" correctly when DataStores are off; real values need publishing |
| Access codes: reserve once, index first, race-safe | 🧪 / 🟡 | 11 WorldDirectory tests with fakes |
| `TeleportAsync` hub → world with the world's code | 🟡 | Teleports don't run in Studio |
| Visitor check in the hub (visibility + friends) | 🧪 / 🟡 | AccessPolicy matrix; hub integration needs a second player |
| Access gate on arrival (World server) | ✅ | Public visitor admitted; Private and FriendsOnly visitors refused (real `IsFriendsWithAsync`) |
| Visitors are view-only | ✅ | place / remove / set-visibility from a visitor → `NotOwner` |
| Private world names hidden from refused visitors | ✅ | Leak found in testing, fixed, re-tested |
| Visibility change → visitors rechecked | 🟡 | Code path runs on every change; needs a real visitor in the world |
| Return to hub (button + Hub Gate) | ✅ / 🟡 | Real click → owner saved → Studio notice; actual teleport needs publishing |
| Joining a world that's already running | 🟡 | Same code → same server by Roblox design; needs 2 accounts live |
| Live owner resolution from `PrivateServerId` | 🟡 | Phase 2 code; needs a reserved server |
| Teleport failure messages | 🟡 | `TeleportInitFailed` wired to an error toast |
| Visual pass: hub environment, world dressing, lighting, HUDs | ✅ | Screenshots reviewed in Studio; fixes made (terrain, kerbs, labels, button text) |

### Phase 2 verification (Studio, 2026-10-18)
| Test | Result |
|---|---|
| A — new world | ✅ `world ready (new)` |
| B/E — save, new session, identical | ✅ 4 objects placed through the real remote → autosave → saved JSON into Edit → fresh Play → `4 objects rebuilt, 0 dropped`; same ids, types, cells, rotations; Cash 1,690 and FriendsOnly restored |
| C — invalid saved data | ✅ `2 objects rebuilt, 4 dropped` (unknown_type, blocked, outofbounds, bad_transform), all quarantined |
| D — DataStore outage | ✅ 4 attempts → `load FAILED … Nothing will be saved` → "Nothing was lost" message; record byte-identical |
| F — owners isolated | ✅ `OwnerOverride=4242` created `world_4242`; the original record untouched |
| G — World place missing | Documented; the World place now exists locally |
| Real DataStores | ⬜ needs publishing + API access |
| Unit suites in Studio | ✅ World 105/105, Hub 68/68 |

<details><summary>Previous phase notes (Phase 2, architecture revision, Phase 1)</summary>

**Phase 2 (2026-10-17):** persistent world code complete and unit-tested; Studio testing was blocked by setup. Unblocked and verified on 2026-10-18 (table above).

**Architecture revision (2026-10-17):** persistent, visitable worlds; Hub place + World place. Plan in TECHNICAL_ARCHITECTURE §12.

**Phase 1:** server foundation complete and tested.

</details>

## Current project condition
Both places are published with the latest code. Owners can build with the full build-mode UI; travel works in the live game (not yet run live).

| Item | State |
|---|---|
| Experience | **MMO Tycoon**, private (Playtesters), Team Create on. Open it from Studio's home page; the World place is under Asset Manager → Places in Experience ("sterburger985's Place"). |
| Hub place | 78195623283467 — 27 scripts, build r8, published |
| World place | 86431904123318 — 41 scripts, build r9, published |
| Local `.rbxl` files | Superseded by the published places (kept, not needed) |
| Install models | `C:\Roblox Dev\MMORPG Tycoon\build\{hub,world}-install-r9.rbxm` (latest); older ones can be deleted. Generated by `tools/make-install-model.py`. |
| Repo | `github.com/sterburger985/MMORPG-TYCOON`: Phases 0–4 pushed (`main`) |
| Type check | 0 errors in both places |

### Updating a place (until the Studio connector works)
1. In Studio, open the place, then **File → Import Roblox Model** → `build\world-install-rN.rbxm` (or `hub-…`).
2. Paste the snippet from `build\INSTALL.md` into the command bar and press **Run** (click **Continue** on the Destroy warning).
3. **File → Publish to Roblox.**

## Feature status (Phase 1 building features)
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
- **Live travel testing** in the Roblox app (list in Milestone 3 below).
- Touch-device test of build mode.
- World renaming (needs TextService filtering).
- Final art and sounds. Current item models are clean placeholders; the environments are code-built scenery.

## Known problems / risks
- **Publishing required:** teleports and DataStores only work in the published experience. Phase 3 can't be fully accepted until the live tests pass with two accounts.
- **Studio file locks:** Studio kept a lock on files it had opened earlier in the same session (`.rbxl.lock`), so the World copy opened read-only. Restart Studio before opening it again.
- **Studio MCP connector:** still "no_tools" in the Claude desktop app with Studio open. Claude can't control the Claude app itself, so restarting it is a manual step (Settings → Developer / Connectors → Roblox Studio → restart, or quit and reopen the app).
- **Studio multi-client tests:** test players have negative UserIds, so the World server (correctly) won't make one an owner; use `OwnerOverride` to test visitors.
- **Multi-client behaviour untested** in both places.
- **Repo not pushed:** the code lives in the places and in Claude's workspace until it's pushed.

## Setup requirements (Roblox Studio)
Done: published, API access on, World place added. Remaining (Creator Hub): World place **Max Players = 5** (owner + 4 visitors; the server already enforces 4 visitors) and Hub Max Players = 6.

## What the current map is (inspected 2026-10-17, during Sterling's playtest)
> **Update 2026-10-18:** Phase 3 dressed the hub at runtime (`HubEnvironment`): grass ground, cobblestone roads with kerbs in the walkways, a central plaza with a rune ring, fountains at the crossings, lamps, a forest ring and a purple World Gate on every plot. The plot layout, assignment and spawning below are unchanged.

- **Saved in the place:** only the template `Baseplate` (2048×2048, grey grid), the default `SpawnLocation` at the origin, `Lighting` and the placeholder item models in `ReplicatedStorage.Assets.Items`.
- **Created by code at runtime (PlotService):** `Workspace.Plots.Plot_1…6`. Each has a grass `Base` (256×256 studs), a cobblestone rim, a `SpawnPad` and an `OwnerSign` billboard ("<DisplayName>'s World"). They're laid out 3 × 2 with **48-stud walkways of bare Baseplate** between them; these are the "roads". There are no road parts and no terrain.
- **Plot assignment:** first free plot on join (PlotService.assign); freed and cleared on leave.
- **Spawning:** the character spawns at the default SpawnLocation, then the server moves it to its plot's `SpawnPad` (on every respawn).
- **Label:** `OwnerSign` BillboardGui on the SpawnPad, text set by PlotService.
- **Saving/loading:** none. Data is in memory only.
- **Places:** one place, unpublished (PlaceId 0), so no multi-place setup and no DataStore access yet.
- **Sync:** the repo (Rojo layout) is the source of truth; scripts are written into Studio through the connector and checksum-verified. Rojo isn't running locally.

## Milestones for persistent worlds (from the planning pass; Phases 2–3 implemented Milestones 2 and 3; the live tests below are still to run)

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
1. Sterling's 1-minute live test: play the experience from the Roblox app → ENTER MY WORLD → build → RETURN TO HUB → ENTER again (same objects).
2. Proposed next phase: **the "tycoon" part** — NPC adventurers who visit your world, earn you Cash over time, and react to what you've built (the MMORPG Tycoon loop).
