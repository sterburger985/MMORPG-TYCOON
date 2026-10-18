# TECHNICAL_ARCHITECTURE — MMORPG Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · See also [[GAME_DESIGN]], [[PROJECT_STATUS]]
Last updated: 2026-10-17 (Phase 1). **Status: server side implemented and tested (Phase 1); client side not implemented.** Sections that changed during implementation are marked *(Phase 1)*.

---

## 0. Principles

- **Server-authoritative.** The client asks; the server decides. The client never sends a CFrame, price, owner or balance.
- **Plain ModuleScripts, no framework.** Each service is a module with `Init()` (wire up, no yielding) and `Start()` (begin work). One bootstrap Script per side requires and starts them in a fixed order. No Knit or similar.
- **Pure logic is separated from Roblox I/O.** Grid math and placement rules are pure functions in shared modules, so they can be unit-tested without Play mode quirks and reused by the client preview (the client checks for UX only; the server re-checks for real).
- **One source of truth per piece of data** (§5).
- **Small files.** Target < 300 lines per module; split when a module takes on a second responsibility.

## 1. Development workflow

Mirrors the proven RoCiv setup.

| Piece | Choice |
|---|---|
| Source of truth | GitHub repo `sterburger985/MMORPG-TYCOON` (currently empty), Rojo-compatible layout |
| Language | Luau with `--!strict` on shared/pure modules; `--!nonstrict` allowed on UI glue |
| Mapping | `default.project.json` (Rojo format) |
| Getting code into Studio | Primary: Claude writes scripts straight into the open place through the Roblox Studio connector, then verifies they match the repo. Fallback: a `tools/StudioSync.lua` command-bar helper (as in RoCiv) that pulls `src/` from a GitHub commit. Optional: Sterling runs `rojo serve` locally if he installs Rojo. |
| Place file | `MMORPGTycoon.rbxl`, saved locally by Sterling (the current place is unsaved `Place1`) |
| Notes | Obsidian vault `C:\Roblox Dev\MMORPG Tycoon\` (canonical design notes); repo `docs/` holds copies |
| Testing | Built-in unit-test harness (ServerStorage.UnitTest), Studio playtests driven via the connector (play/stop, console, screenshots, simulated input) |
| Static checks *(Phase 1)* | `rojo build` + `luau-lsp analyze` with Roblox type definitions (run by Claude in the cloud workspace); `tools/checksums.py` compares repo scripts with the place |
| Assets | Studio connector generation (procedural model, mesh, material, texture), Blender connector, hand-built parts. No unvetted Toolbox models. |

### Repo layout (proposed)

```
default.project.json
src/
  shared/                 -> ReplicatedStorage.Shared
    Config.luau             tunables (grid size, plot size, limits, start cash)
    GridMath.luau           pure: world<->cell, rotation, footprint cells
    ItemCatalog.luau        item definitions (id, name, price, footprint, layer, category, model)
    PlacementRules.luau     pure: canPlace(state, request) -> ok, reasonCode
    Net.luau                remote names + reason codes (shared enum)
  server/                 -> ServerScriptService.Server
    Main.server.luau        bootstrap: Init all, then Start all
    Util/RateLimiter.luau   token bucket (Phase 1)
    Services/
      PlayerDataService.luau
      PlotService.luau
      EconomyService.luau
      PlacementService.luau
  client/                 -> StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau        bootstrap
    Controllers/
      BuildingController.luau
      PlacementController.luau
    UI/                     build-mode UI components (Phase 2)
assets/                   -> notes on asset sources; models live in the place file
tests/                    -> ServerStorage.UnitTest (RunUnitTest + Cases/)
docs/                     -> copies of the vault docs
tools/BuildPlaceholderAssets.lua   rebuilds the placeholder item models (Phase 1)
tools/checksums.py                repo-vs-place script check (Phase 1)
tools/StudioSync.lua              (fallback, not written yet)
```

*(Phase 1)* `src/client/` and its Rojo mapping are added in Phase 2.

Models (item templates and plot base) live in the **place file**, not the repo, under `ReplicatedStorage.Assets` (§2). The repo documents their names and expected structure.

## 2. Roblox instance hierarchy (proposed)

```
Workspace
  Plots (Folder)
    Plot_1 … Plot_6 (Model)        attrs: PlotId, OwnerUserId (0 = free)
      Base (Part, anchored)          the world tile; defines origin + bounds
      SpawnPad (Part; the owner is teleported here on spawn, with an OwnerSign billboard) (Phase 1)
      Rim1..4 (decor)
      Placed (Folder)                server-created item instances
        <placedId> (Model)           attrs: ItemId, PlacedId, CellX, CellZ, Rot
  Hub (Model)                       neutral ground between plots (optional, later)

ReplicatedStorage
  Shared (Folder)                  ← src/shared
  Assets (Folder)
    Items (Folder)                 one Model per catalog item; PrimaryPart = invisible "Hitbox" (footprint × height,
                                   the only CanQuery part); pivot = bottom centre via Hitbox.PivotOffset (Phase 1)
  Remotes (Folder)                 created by the server at startup (not hand-made)

ServerScriptService
  Server (Folder)                  ← src/server

ServerStorage
  UnitTest (Folder)                test harness + cases (never replicated)

StarterPlayer.StarterPlayerScripts
  Client (Folder)                  ← src/client

StarterGui                         build UI is created by code or stored as ScreenGui templates (Phase 2 decision)
```

Why item models live in ReplicatedStorage: the client needs them for the ghost preview. That is safe because the server still decides what is spawned and where.

## 3. Client / server responsibilities

| Concern | Server | Client |
|---|---|---|
| Plot assignment | Assigns, records owner, frees on leave | Reads `PlotId` attribute |
| Cash | Owns the balance; the only writer | Displays the `Cash` attribute |
| Item catalog | Authoritative prices and footprints | Same module, for UI and preview only |
| Placement validity | **Decides** (bounds, ownership, occupancy, funds, limits) | Predicts for the green/red preview |
| Spawning objects | Clones template, positions from the cell, parents to `Placed` | Shows ghost only (local, never replicated) |
| Removal | Verifies owner and that the object exists; refunds | Hover highlight, sends `placedId` |
| Rate limiting | Per-player token bucket | Debounces input |
| Input / camera / UI | – | All of it |

## 4. Planned services and controllers

### Shared modules
- **Config:** constants only. Cell = 4 studs; plot = 64 × 64 cells; max placed objects per plot = 400 (tunable); start Cash = 2000; refund rate = 1.0; rate limit = 8 requests/sec, burst 12.
- **GridMath (pure):** `cellToWorld(plotCFrame, x, z, footprint, rot)`, `worldToCell(plotCFrame, pos)`, `rotatedFootprint(w, d, rot)`, `footprintCells(x, z, w, d, rot)`, `inBounds(...)`.
- **ItemCatalog:** `[itemId] = { name, price, size = {w, d}, layer = "Floor" | "Object", category, model }`. The server validates that `itemId` is a known key.
- **PlacementRules (pure):** `check(plotState, itemDef, x, z, rot) -> (true) | (false, reason)`. Reasons: `OutOfBounds`, `Blocked`, `LimitReached`, `InsufficientFunds`, `BadItem`, `BadArgs`. Used by both server (authoritative) and client (preview).
- **Net:** remote names and the reason-code enum, so client and server can't drift.

### Server services

| Service | Responsibility | Depends on |
|---|---|---|
| **PlayerDataService** | Per-player session data (`cash`, `placed[]`, schema `version`). Creates defaults on join, exposes get/mutate API, fires `Changed`. Persistence is added here later; no other service talks to DataStores. | Config |
| **PlotService** | Owns plot slots: assign on join (first free), free on leave (clear `Placed`), teleport owner to plot, `getPlotOf(player)`, `getOwner(plot)`, `isOwner(player, plot)`. Holds each plot's occupancy grid (two layers: Floor and Object). | Config, GridMath |
| **EconomyService** | Only API that changes Cash: `canAfford`, `charge(player, amount, reason)`, `grant(...)`. Mirrors the balance to the player's `Cash` attribute. Integer-only, never negative. | PlayerDataService |
| **PlacementService** | Handles `RequestPlace` and `RequestRemove`: validates args, rate-limits, runs PlacementRules, charges or refunds through EconomyService, spawns or destroys instances, updates occupancy and `placed[]`. Single place where the world changes. | PlotService, EconomyService, PlayerDataService, ItemCatalog, PlacementRules, GridMath |

Bootstrap order: PlayerDataService → PlotService → EconomyService → PlacementService (Init all, then Start all).

### Client controllers

| Controller | Responsibility | Depends on |
|---|---|---|
| **BuildingController** | Build-mode state machine (`Idle` → `Placing(itemId)` / `Removing`), catalog UI, Cash display, error toasts, key, touch and gamepad bindings via ContextActionService. | Net, ItemCatalog, PlacementController |
| **PlacementController** | Ghost preview: mouse or touch raycast → cell snap via GridMath, rotation (R / button), tint valid or invalid via PlacementRules on a client mirror of occupancy, sends requests, hover highlight in remove mode. | GridMath, PlacementRules, ItemCatalog, Net |

Client occupancy mirror: built from the replicated `Placed` children's attributes (`CellX`, `CellZ`, `Rot`, `ItemId`). It is never sent to the server.

## 5. Data ownership

| Data | Owner (writer) | Readers | Replicated how |
|---|---|---|---|
| Cash | EconomyService | everyone (own UI) | `player:SetAttribute("Cash")` |
| Plot assignment | PlotService | all | `player:SetAttribute("PlotId")`, plot `OwnerUserId` attribute |
| Occupancy grid | PlotService (mutated only via PlacementService) | PlacementService | not replicated; client rebuilds a mirror |
| Placed object list (save format) | PlayerDataService (mutated only via PlacementService) | Persistence (later) | not replicated |
| Placed instances | PlacementService | everyone | normal instance replication |
| Item catalog | repo (static) | both sides | shared ModuleScript |

## 6. Communication

Remotes live in `ReplicatedStorage.Remotes` and are created by the server at startup.

| Remote | Type | Client → Server payload | Server reply |
|---|---|---|---|
| `RequestPlace` | RemoteFunction | `(itemId: string, cellX: number, cellZ: number, rot: number)` | `{ ok: boolean, reason: string?, placedId: string? }` |
| `RequestRemove` | RemoteFunction | `(placedId: string)` | `{ ok: boolean, reason: string?, refund: number? }` |
| `Notify` | RemoteEvent (S→C) | – | toasts or server messages (later) |

- **Client → Server RemoteFunction is acceptable**: the server never invokes the client, which would be the dangerous direction. Every handler is wrapped in `pcall` and always returns a table.
- **Purchase = placement.** There is no separate "buy" remote in the MVP. The price is charged atomically inside `RequestPlace`, so you can't buy without placing or place without paying.
- State (Cash, plot) flows down through attributes; the world flows down through instance replication. No custom sync protocol is needed.

## 7. Security and validation rules

Every request goes through all of these checks, in order. The first failure returns a reason code.

1. **Rate limit:** per-player token bucket (8/s, burst 12). Excess → `RateLimited`, request dropped.
2. **Type and shape checks:** `typeof(itemId) == "string"`, length ≤ 32; cell and rotation values are `number`, finite (not NaN or inf), integers (`x == math.floor(x)`); `rot ∈ {0,1,2,3}`; `placedId` is a string ≤ 40 chars. → `BadArgs`.
3. **Known item:** `ItemCatalog[itemId]` exists and is unlocked for the player (unlocks come later). → `BadItem`.
4. **Ownership:** the player has a plot, and the target plot is *their* plot. The server derives the plot from the player; the client never names a plot. Removal: `placedId` exists in *that player's* `placed` table. → `NotOwner` / `NotFound`.
5. **Bounds:** every footprint cell is inside 0..63. → `OutOfBounds`.
6. **Occupancy:** no footprint cell is taken on the item's layer. Object-layer items may sit on Floor-layer cells. → `Blocked`.
7. **Limits:** placed count < max per plot. → `LimitReached`.
8. **Funds:** `cash >= price` (server price from the catalog, never from the client). → `InsufficientFunds`.
9. **Commit atomically:** charge → mark occupancy → record in `placed` → spawn instance. If spawning errors, roll back the occupancy and refund.

Other rules:
- **Future world access:** a `PlotService:canBuild(player, plot)` and `canVisit(...)` choke point exists from day one, so permissions (friends or co-builders) slot in later without touching PlacementService.
- **Physics:** placed instances are anchored. The server sets network ownership to none implicitly by anchoring. Players can't move other players' objects.
- **Sanity:** Cash is clamped to an integer ≥ 0; all money math uses integers only.
- **Exploit tests:** run from the Client datamodel through the connector with forged args: wrong types, NaN, a huge cell, another plot's `placedId`, spam (§10).

## 8. Object placement workflow

```
CLIENT                                         SERVER
──────                                         ──────
Pick item in catalog → Placing(itemId)
Each frame: raycast → worldToCell → snap ghost
  tint = PlacementRules.check(mirror) (UX only)
R / button → rot = (rot+1) % 4
Click / tap "Place" ──RequestPlace(id,x,z,rot)──► rate limit → validate args → known item
                                                   → owner plot (derived) → bounds → occupancy
                                                   → limit → funds
                                                   → charge, occupy, record, spawn Model
                                                     at GridMath.cellToWorld(plot, x,z,size,rot)
                   ◄──── {ok=true, placedId} ──────
Play place SFX/tween; stay in Placing mode
(new Model replicates under Plot.Placed → mirror updated via ChildAdded)

Remove mode: hover highlights own objects
Click ──────────RequestRemove(placedId)─────────► rate limit → validate → owns it?
                                                   → free cells, delete record, destroy, refund
                   ◄──── {ok=true, refund} ────────
On {ok=false, reason} → red flash + toast with reason text
```

## 9. Future persistence strategy (not in Phase 1)

- **Store:** one DataStore `PlayerData_v1`, key `u_<UserId>`. A single compact record per player:
  ```
  { v = 1, cash = 2000, placed = { {i="tree", x=10, z=4, r=1, id="p17"}, … }, nextId = 18, stats = {…} }
  ```
  Estimated size: about 40 bytes per object, so 400 objects ≈ 16 KB, far under the 4 MB per-key limit.
- **Writes:** `UpdateAsync` only (never blind `SetAsync`), with a **session lock** (`lock = {job = game.JobId, t = os.time()}`) to prevent two servers overwriting each other. Stale locks (> 30 min old) can be stolen.
- **When:** load on join (block building until loaded; kick with a message if loading fails after retries), autosave every ~5 min if dirty, save on `PlayerRemoving`, and flush everything in `game:BindToClose`.
- **Budget:** per-server write budget is 60 + 40 × players per minute (Roblox docs). This design uses well under 1 write per player per minute.
- **Schema migration:** a `v` field plus ordered migration functions in PlayerDataService.
- **Alternative to evaluate in that phase:** the community ProfileStore module (handles session locking for us) versus a small hand-rolled wrapper. Decide when the persistence phase starts.
- **Prerequisites:** the place must be **published**, and *Game Settings → Security → Enable Studio Access to API Services* must be on to test DataStores in Studio.
- Rebuilding a world on load replays `placed[]` through the same spawn function (not the remote path), so loading can't bypass or duplicate validation.

## 10. Performance considerations

- `Workspace.StreamingEnabled` is **already on** in the place. Keep it, and set item Models to `ModelStreamingMode = Atomic` so objects never half-stream.
- Placed parts: `Anchored = true`; `CanTouch = false` and `CanQuery = false` on decorative parts (keep query on a single hitbox per Model so remove-mode raycasts work); `CastShadow = false` on small props; `CollisionFidelity = Box` on meshes.
- Prefer one MeshPart per small object over many Parts. Budget is about 1–8 parts per object, so 6 plots × 400 objects stays within a mid-range-phone budget. Verify with the `rbx-scene-analysis` and `rbx-perf-profiling` tools at the end of the asset phase.
- Ghost preview: a single cloned model per selection, reused while moving (no clone per frame); cell snapping happens in `RenderStepped` but only re-tints when the cell or rotation changes.
- Occupancy lookups are O(footprint) through a flat array indexed `z * 64 + x + 1` per layer. No spatial queries are needed for validation.
- Remote traffic is event-driven only (no per-frame remotes).

## 11. Testing strategy

| Level | What | How |
|---|---|---|
| Unit | GridMath, PlacementRules, EconomyService math, rate limiter | Built-in harness `ServerStorage.UnitTest` run in Play through the connector; contract-first cases including boundaries (edge cells, odd footprints rotated, NaN, negative, exactly-enough Cash) |
| Integration | Join → plot assigned; place → Cash down, instance at the right CFrame; remove → refund; leave → plot freed | Server-side Luau through the connector during Play; assert on attributes and instances |
| Security | Forged remote calls (bad types, NaN, other player's `placedId`, out-of-bounds, spam) | Client-datamodel Luau through the connector calling `InvokeServer` directly; expect the right reason codes and no state change |
| Multiplayer | 2–3 players building at once, no interference | Studio *Test → Clients and Servers* (Sterling runs this manually; the connector drives a single client) |
| UX / visual | Preview tint, rotation, toasts, mobile layout | Screenshots plus simulated input through the connector; device simulator for phone and tablet |
| Performance | 6 plots filled to the limit | Fill script + scene analysis + MicroProfiler |

Status labels used in all docs: **Not implemented** · **Implemented, not tested in Studio** · **Implemented and tested successfully** · **Known broken**.
