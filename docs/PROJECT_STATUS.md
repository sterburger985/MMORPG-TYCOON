# PROJECT_STATUS — MMO Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · Last updated: 2026-10-19 (Phase 5b buildable sections and natural borders published)

## Current phase
**Phase 5b: Buildable sections and natural borders. The continent is divided into 57 named sections with biome-specific raised borders and entrances. Built, tested in Studio and published (World place v18, 2026-10-19). Awaiting review.**

- **57 sections** (4–8 per region, sized by geography), e.g. Greenhaven: Starting Meadow (your plot), Elder Oak Hill, North Fields, Silverrun Bend, Mirrormere Shore, South Downs. Ids are stable (`GH_StartingMeadow` …) for a future unlock system.
- **Borders are additive:** the continent's terrain maths is untouched (fingerprint still 13736.985). Borders are low terrain embankments, 3–9 studs depending on the biome, built from a contrasting bank material (earth, rock, sandstone, pale stone, violet stone, basalt…), plus half-buried edge stones and biome props:
  - Greenhaven: fences
  - Whisperwood and Verdantwild: dense tree lines
  - Sunscar: sandstone walls
  - Mirehollow: walkways
  - Frostpeak: stone walls
  - Glacial: ice spikes
  - Ashenreach and Dragon's End: basalt spires and monumental dark walls
  - Starfall: crystals and leaning arches
- **Existing slopes, crests, rivers, lakes and the coast are used as borders** instead of building on top of them (1,507 border points are left natural, 120 are water).
- **Entrances:**
  - 43 road gateways: a tall pair of lantern waystones in the region's colour
  - 70 trail entrances: a gap in the bank with two waystones and a worn path, or a plank walkway in the swamp
  - Every pair of neighbouring sections is connected (road 40, trail 71, open 21, mountain pass 9).
- **HUD:** walking into a new section shows "◆ North Fields ◆" under the region banner.
- **Build mode, persistence, ownership:** unchanged. Building is still only allowed on your plot; sections are visual for now.
- **Backup:** `backups/World-before-borders-2026-10-19.rbxl`, plus `BorderBuilder.remove()` restores the original terrain exactly.

### Phase 5b test results (brief's tests A–K)
| Test | Result | Evidence |
|---|---|---|
| A — continent intact | ✅ | Terrain fingerprint unchanged (test + Studio); all ten regions, landmarks, rivers, coast as before |
| B — irregular sections | ✅ | `Sections_Test`: no section fills more than 85% of its bounding box; sizes vary more than 2.5×; each section is one piece of land |
| C — border appearance | ✅ (visual) | Toured all ten biomes in Studio from several angles; reworked twice (grass-on-grass banks were unreadable, narrow banks rendered as sharp roofs) |
| D — entrances | ✅ | Every neighbouring pair connected (test); gaps verified clear of banks; walked a character across a border |
| E — terrain fit | ✅ | Automated check of all 2,382 props: 0 floating, 0 hidden. Found and fixed a ray-origin bug that buried 113 stones on high ground |
| F — build mode | ✅ | Build HUD (categories, rotate, remove, HUB) present; region and section banners work |
| G — placement | ✅ | Real remotes: place −$5, remove +$5 refund, outside the plot → `OutOfBounds` |
| H — removal | ✅ | `RequestRemove` with border prop names → `NotFound`; border parts are not queryable (remove-mode raycast can't hit them) |
| I — persistence / no duplicates | ✅ | Saved world reloaded identically (18 and 37 objects); rebuilding the borders leaves one `SectionBorders` folder |
| J — performance | ✅ / 🟡 | 6,197 border parts (budget 6,500), all anchored, no touch/query; 60 fps on this PC with streaming; not measured on a phone |
| K — one connected world | ✅ (visual) | See `docs/images/section-map.png` and the Studio tour |

### Unit tests
Local (Lune): World 112/112, Hub 73/73. Studio (World place): **153/153**. Type check: 0 errors.

### Pre-existing issues found during the tour (not caused by the borders; left alone per the brief)
- The Marsh Path / Pilgrim's Road causeway through Mirehollow renders as large ridged plank wedges (a narrow raised WoodPlanks strip at 4-stud voxels).
- Most swamp pools don't appear in Studio: the swamp water level (1.6) sits below the 4-stud voxel centre, so only deeper pools show.
- Suggested fix for both (needs a small continent change, so not done without approval): widen and flatten the swamp causeway, and raise `SWAMP_LEVEL` to ~2.2.

### Phase 5 (2026-10-18): the continent
Ten organic regions Lv 1–100, landmarks, roads, rivers, lakes, region HUD, $5,000 start, "My World" default. Details below.

### Phase 5 test results (brief's tests A–L)
| Test | Result | Evidence |
|---|---|---|
| A — ten regions, ids and levels | ✅ | `Continent_Test` (Lune + Studio) |
| B — organic borders, no rectangles | ✅ | Fill-ratio test; aerial screenshots; labelled map |
| C — declared neighbours = real map | ✅ | Adjacency test samples a 32-stud grid |
| D — plot flat, dry, Greenhaven | ✅ | Test; walked in play mode |
| E — landmarks and sites in their own region | ✅ | Test; region tour |
| F — roads walkable, lead through all ten in order | ✅ | Grade/water test; order test |
| G — region query (levels, transitions, buildable) | ✅ | Test; HUD banners in play mode for all ten regions |
| H — build mode, persistence, ownership | ✅ / 🟡 | Placed a Stone Path (Cash 549 → 544); shutdown save of 18 objects; reload clean. Visitor/ownership not re-run (unchanged code) |
| I — deterministic, matches Lune | ✅ | Studio fingerprint 13736.985 = Lune |
| J — rebuild doesn't duplicate | ✅ | Second build → `continents: 1` |
| K — visitors / Hub | 🟡 | Hub reinstalled (r10) and published; visitor flow not re-tested this phase |
| L — performance | 🟡 | 6,212 parts plus terrain; fine on this PC in Studio; no phone test |

### Unit tests
Local (Lune): World 102/102, Hub 63/63. Studio server (World place, after the build): **143/143**. Type check: 0 errors.

### Phase 4 feature status (2026-10-18 afternoon)
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
Both places are published with the latest code. The World place is the fantasy continent; owners build on their plot in Greenhaven. Sterling confirmed the live hub → world teleport works.

| Item | State |
|---|---|
| Experience | **MMO Tycoon**, private (Playtesters), Team Create on. Open it from Studio's home page; the World place is under Asset Manager → Places in Experience ("sterburger985's Place"). |
| Hub place | 78195623283467 — 30 scripts, build r10, published |
| World place | 86431904123318 — 52 scripts, build r19, continent + section borders built in edit mode and saved, published v18 |
| Local `.rbxl` files | Superseded by the published places (kept, not needed) |
| Install models | `C:\Roblox Dev\MMORPG Tycoon\build\hub-install-r10.rbxm`, `world-install-r19.rbxm` (latest); older ones can be deleted. Generated by `tools/make-install-model.py`. |
| Repo | `github.com/sterburger985/MMORPG-TYCOON`: Phases 0–5b pushed (`main`) |
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
- **Border edits:** change `RegionConfig.SECTIONS` / `BORDER_STYLES`, install, then in edit mode run `local BB = require(game.ServerStorage.WorldTools.BorderBuilder); BB.remove(); BB.build()` (about 45 s), then publish.
- **Team Create drops:** Studio lost its Team Create connection twice during testing (reconnect worked; edits were kept). Publish after big edits.
- **Continent edits:** terrain is prebuilt and saved in the place. To change the map, edit `RegionConfig`, install the new build, then run `require(game.ServerStorage.WorldTools.ContinentBuilder).build()` in edit mode (about 15 s), then publish.
- **Ocean edge:** from very high up, the square edge of the sea terrain is visible. Normal play heights don't show it.
- **Performance on phones** not measured yet (6,212 scenery parts plus terrain).

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
**Phase 6: the tycoon loop (approved).** NPC adventurers spawn in Greenhaven, walk the roads to regions that match their level, and pay you for the things you build (inns, shops, quest boards, dungeons). Use `Continent.regionAt` for routing and levels, and the region `sites` as spawn and quest locations.
