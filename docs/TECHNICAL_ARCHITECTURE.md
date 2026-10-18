# TECHNICAL_ARCHITECTURE — MMORPG Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · See also [[GAME_DESIGN]], [[PROJECT_STATUS]]
Last updated: 2026-10-17 (Phase 1). **Status: server side implemented and tested (Phase 1); client side not implemented.** Sections that changed during implementation are marked *(Phase 1)*.

> **2026-10-17 revision:** the game is moving to a **hub place + per-world place** design with persistent, visitable worlds. See **§12**, which supersedes §5 and §9 and the single-server assumptions in §2 and §7. §12 is a plan: not implemented, not tested.
>
> **Phase 2 (persistent worlds) implemented:** see **§13** for what was actually built, the saved format, failure handling, concurrency status and test results.

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

---

## 12. Hub-and-World architecture (revision 2026-10-17) — the plan. **Implemented in §13 (Phase 2) and §14 (Phase 3)**; differences are listed there

This section supersedes §5 (data ownership, for Cash and placed objects), §9 (persistence) and the single-server parts of §2 and §7. Everything else (grid, rules, placement workflow, remotes, rate limiting) carries over unchanged into the World place.

API facts below were checked against the official Roblox docs on 2026-10-17 (TeleportService, TeleportOptions, DataModel, Player, "Teleport between places", DataStore limits).

### 12.1 Places and experience setup
| | Hub place (start place) | World place |
|---|---|---|
| Source | the current place, `MMORPG TYCOON.rbxl` | new place added to the same experience |
| Servers | normal public servers | **reserved servers only**: one access code per world |
| Max Players | 6 (one hub plot each) | proposed 12 (owner + visitors) |
| Building | none | owner only |
| Rojo project | `hub.project.json` | `world.project.json` |

Experience settings (Creator Dashboard):
- **Access Control for Places → "Secure within universe only"** so the World place can only be entered by a server-initiated teleport from inside our experience, never by a direct join or client teleport.
- **Enable Studio Access to API Services** (DataStores in Studio).
- The experience must be **published** before any of this exists. TeleportService **does not work in Studio playtests**, so travel can only be tested in the live Roblox client (private/unlisted is fine).

### 12.2 Sessions: one reserved server per world (no MemoryStore needed)
Key facts from the Roblox docs:
- `TeleportService:ReserveServerAsync(placeId)` returns an **access code** and a **PrivateServerId**.
- Access codes **stay valid indefinitely**. Teleporting with a code when no server is running **starts a new server** for it.
- **Only one server instance can run at a time for a given private/reserved server.** `game.PrivateServerId` stays the same across all of its instances; `JobId` differs per instance.
- Reserved servers are **not** kept alive. They shut down when empty, like any server.

**Design:** each world gets **exactly one access code, created once and stored** in its metadata. Everyone who opens that world (owner or visitor) is teleported with the **same** code, so:
- if the world is running, they **join the existing session** (no duplicates are possible, because Roblox only runs one instance per code);
- if it isn't, Roblox **starts a fresh session**, which loads the world from the DataStore.

This meets "join existing / start new / avoid duplicates" **without MemoryStoreService, MessagingService or a custom registry.** Those stay out until a real need appears, for example a global list of *currently active* worlds (§12.10).

Known edge: **a full world.** If the reserved server is at Max Players, the teleport fails (TeleportInitFailed). The hub shows "That world is full" and leaves the player in the hub.

### 12.3 World identity (where the server learns whose world it is)
The World server **never trusts the client or teleport data** to tell it which world to load. TeleportData is sent through the client unencrypted (Roblox docs).
1. When the access code is created (hub), the hub writes an index entry `WorldIndex_v1 / ps_<PrivateServerId> = ownerUserId`.
2. When a World server starts, it reads `game.PrivateServerId`, looks up the index, and gets the owner's UserId from our own DataStore.
3. If `PrivateServerId == ""` (not a reserved server) or the lookup fails:
   - **live:** the server is invalid. Teleport everyone to the hub, load nothing.
   - **Studio only** (`RunService:IsStudio()`): **dev mode** loads the local tester's own world (`w_<theirUserId>`) so loading and saving can be tested without teleports.

### 12.4 Data model (DataStores)
Three stores. Each key holds one small, versioned, JSON-safe table. Workspace instances are **never** serialized.

**A. `WorldMeta_v1` / `w_<ownerUserId>`** (small; read by hub and world)
```lua
{
  v = 1,
  ownerId = 123,
  name = "Sterling's World",       -- filtered with TextService before display to others
  visibility = "Public",           -- "Public" | "Friends" | "Private"
  accessCode = "<reserved code>",  -- server-only, never sent to clients
  privateServerId = "<id>",
  createdAt = 1760000000,
  updatedAt = 1760000000,
  stats = { objects = 42 },        -- for hub display; no layout data
}
```

**B. `WorldData_v1` / `w_<ownerUserId>`** (the world itself; written only by that world's server)
```lua
{
  v = 1,
  ownerId = 123,
  lock = { job = "<JobId>", t = 1760000000 },   -- session lock (12.6)
  savedAt = 1760000000,
  saveCount = 17,
  economy = { cash = 2000 },
  progression = { level = 1, xp = 0, unlocks = {} },
  nextId = 43,
  placed = {                        -- compact array; ids are strings "p<n>"
    { id = "p1", i = "oak_tree", x = 10, z = 10, r = 0 },
    { id = "p2", i = "cottage",  x = 20, z = 10, r = 1 },
  },
  npcs = {}, monsters = {}, quests = {},  -- reserved for future systems (validated as empty in v1)
}
```

**C. `WorldIndex_v1` / `ps_<PrivateServerId>`** → `ownerUserId` (written once per world)

**Size budget:** about 45 bytes of JSON per placed object. A cap of **2,000 objects per world** is about 90 KB, far under the **4 MB per-key** limit. The save code measures `#HttpService:JSONEncode(data)` before writing and refuses (keeping the old save) above a safety threshold of 3 MB.

**Why split Meta and Data:** settings changes (name, visibility) and access code creation never compete with the big world save, and the hub never has to read or lock the world's layout.

### 12.5 Loading a world (World server)
1. Resolve the owner (12.3).
2. `UpdateAsync(WorldData, w_<owner>)` **acquires the session lock**: take it if it's absent, ours, or stale (older than 10 minutes); otherwise retry for about 30 seconds, then open **read-only** with a warning.
3. **Distinguish "no save yet" from "load failed".** `nil` → create the default world. A DataStore error → retry with backoff; if it still fails, open **read-only** and **never overwrite** with defaults.
4. **Migrate** (`v` → current) and **validate** every entry with a pure, unit-tested `WorldSchema` module: known item id (ItemCatalog), integer cells, rot 0–3, in bounds, no same-layer overlap (PlacementRules), cap respected, ids unique. Invalid entries are **dropped and logged**, never trusted.
5. Rebuild the world with the same server spawn function PlacementService uses. The load path never goes through the remote, so it can't bypass or double-charge.

### 12.6 Saving and concurrency rules (must hold)
| Rule | Why |
|---|---|
| Only the World server **holding the lock** writes `WorldData`. Every write is `UpdateAsync` that checks `lock.job == game.JobId` and aborts otherwise. | Overlap risk: an old instance still saving in `BindToClose` while a new instance starts (Roblox runs one instance per code, but shutdown and startup can overlap by seconds). |
| The lock is refreshed on every save (`t = os.time()`), released (set to nil) on the final save. Stale after 10 minutes. | A crashed server can't block the world forever. |
| `WorldMeta` is changed only with `UpdateAsync` that edits **single fields** and keeps the rest. | The hub (creating the access code) and the world (changing settings) can touch Meta without clobbering each other. |
| Access code creation uses `UpdateAsync` and **keeps an existing code** if one appears first. The losing reservation is discarded. | Two hub servers can't give one world two codes. |
| Saves happen: on every change marked dirty, batched by an **autosave every 60 s**; when the **owner leaves**; and in **`game:BindToClose`** (30-second window). Saves are skipped when nothing changed. | Stays well under the write budget (60 + 40 × players per minute per server). |
| A failed save keeps `dirty = true` and retries with backoff. The previous good save is untouched because `UpdateAsync` is atomic per key. | No partial or corrupt saves. |
| Visitors never cause writes. | Read-only. |

### 12.7 Travel
**Hub → own world:** client → `RequestEnterMyWorld` (no arguments). The server ensures Meta exists, creates the access code if missing (`ReserveServerAsync(WORLD_PLACE_ID)` + index entry), then `TeleportAsync(WORLD_PLACE_ID, {player}, options{ReservedServerAccessCode})`, wrapped in a **SafeTeleport** helper (pcall + retries; `TeleportInitFailed` handling; user-facing error).

**Hub → visit:** client → `RequestVisitWorld(ownerUserId)`. The server validates: the argument is a positive integer; the target is **a player currently in this hub server** (Milestone 3 scope; friends-online later); Meta exists; access is allowed (12.8). Then it teleports with the **target world's** code. The client never sees or supplies codes.

**World → hub:** client → `RequestReturnToHub`. The server calls `TeleportAsync(HUB_PLACE_ID, {player})` into a public hub server.

**Teleport data:** cosmetic only (for example "came from the hub"). Never used for identity or permissions.

### 12.8 Access control (server-enforced twice)
Pure function `AccessPolicy.canVisit(visibility, isOwner, isFriend) -> boolean`, unit-tested:
- Owner → always allowed.
- Public → allowed.
- Friends → `visitor:IsFriendsWithAsync(ownerId)` on the **server** (pcall; an error means **deny**, so it fails closed).
- Private → denied.

Checked **in the hub before teleporting** (for a friendly error message) **and again in the World server on `PlayerAdded`** (authoritative). A non-allowed player is teleported back to the hub immediately and never receives world data. Because the World place is "Secure within universe only", the only way in is our own server teleport.

**Changing settings:** only from inside your own world (the owner is in that server), via `RequestSetVisibility(v)` / `RequestRenameWorld(name)`. The server validates the enum and length and **filters names with `TextService:FilterStringAsync`**. After a visibility change, the server **re-checks every visitor present** and sends now-unauthorized ones to the hub. Because changes only happen in the world's own server, no cross-server messaging is needed.

**Building:** PlacementService's existing `canBuild` choke point becomes `player.UserId == worldOwnerId and not readOnly`.

**Information exposure:** the hub shows a world's name, owner and visibility badge. It never sends layout data, access codes or PrivateServerIds to clients.

### 12.9 Code layout (proposed)
```
src/shared/              (unchanged) Config, Net, GridMath, ItemCatalog, PlacementRules
                         + AccessPolicy, WorldSchema (pure, unit-tested)
src/server/common/       WorldStore (DataStore wrapper: meta, data, index, lock, retries),
                         SafeTeleport, RateLimiter (moved from Util)
src/server/hub/          Main.server, HubPlotService (= today's PlotService), TravelService
src/server/world/        Main.server, WorldSessionService (owner, lock, access gate),
                         WorldDataService (load/validate/save), WorldPlotService (single plot),
                         PlacementService, EconomyService (existing, re-pointed)
src/client/hub/ , src/client/world/   (UI, Phase 2 work lands in world/)
hub.project.json, world.project.json  (each maps shared + common + its own folders)
tests/                    + WorldSchema_Test, AccessPolicy_Test, WorldStore_Test (fake DataStore)
```

### 12.10 Deliberately deferred
- **MemoryStoreService:** only when we want a live list of active worlds or visitor counts across hub servers.
- **MessagingService:** only when settings must change from outside the world (for example from the hub) while the world is running.
- **ProfileStore:** reconsider if the hand-written lock in 12.6 proves fragile in live tests.
- **Global public-world browser:** needs an OrderedDataStore or MemoryStore index. It comes after Milestone 3.

---

## 13. Phase 2 implementation: persistent worlds (2026-10-17)

**Status legend:** ✅ tested successfully · 🧪 tested by unit tests only (real code, local Luau runtime, fake DataStore) · 🟡 implemented, not tested in Roblox Studio · ⬜ not implemented.

### 13.1 What changed from the §12 plan, and why
- **One record per world instead of separate Meta and Data stores.** In Phase 2 the only writer is the World server holding the lock, and settings are only changed from inside the world. A single record is simpler and fully atomic. A small separate Meta key (for the hub to write the reserved-server access code) will be added in the travel phase, as planned in §12.4. 🟡
- **Visibility values are `Public`, `FriendsOnly`, `Private`** (Phase 2 brief), not "Friends".
- The World place reuses the hub's `PlacementService` and `EconomyService` **unchanged in behaviour**, through world versions of `PlotService` and `PlayerDataService` with the same interface. `PlacementService` gained two additive functions (`restore`, `onChanged`).

### 13.2 Code map
| File (repo) | Instance in place | Place |
|---|---|---|
| `src/shared/*` | `ReplicatedStorage.Shared.*` | Hub + World |
| `src/common/server/Services/{PlacementService,EconomyService}.luau` | `ServerScriptService.Server.Services.*` | Hub + World |
| `src/common/server/Util/RateLimiter.luau` | `ServerScriptService.Server.Util.RateLimiter` | Hub + World |
| `src/hub/server/Main.server.luau`, `Services/{PlotService,PlayerDataService}.luau` | `ServerScriptService.Server.*` | Hub |
| `src/world/server/Main.server.luau` | `ServerScriptService.Server.Main` | World |
| `src/world/server/Services/WorldConfig.luau` | settings: store names (Studio namespace), intervals, limits | World |
| `…/WorldSchema.luau` | saved format v1, validation, migration hook, profile conversion | World |
| `…/WorldStore.luau` | DataStore access: `UpdateAsync`, session lock, retries, size check | World |
| `…/WorldLoader.luau` | load decision: ready / readonly / failed | World |
| `…/WorldSessionService.luau` | owner → load → rebuild → spawn → autosave → shutdown save; visibility remote | World |
| `…/OwnerResolver.luau` | whose world (reserved server index live; first player in Studio) | World |
| `…/WorldState.luau` | this server's world state (owner, status, profile, dirty counter) | World |
| `…/PlotService.luau`, `…/PlayerDataService.luau` | world versions of the hub interfaces | World |
| `…/StudioDevStore.luau` | **Studio-only** stand-in DataStore (`ServerStorage.WorldDevStore`) | World |
| `tests/common/*`, `tests/world/*` | `ServerStorage.UnitTest.Cases.*` | Hub: common; World: common + world |
| `hub.project.json`, `world.project.json` | Rojo projects, one per place | — |
| `tools/check.sh`, `tools/run-tests.luau` | per-place build + type check; local Luau test runner (Lune) | dev |

### 13.3 Saved world format (version 1) 🧪
Key: `world_<OwnerUserId>` in DataStore `Worlds_v1` (live) or `StudioTest_Worlds_v1` (Studio, so tests never touch live data).
```lua
{
  Version = 1,
  OwnerUserId = 1586031803,
  WorldName = "My MMORPG",                  -- 1..50 chars; default when unset or invalid
  Settings = { Visibility = "Public" },     -- Public | FriendsOnly | Private
  Economy = { Cash = 2000 },                -- persisted so Cash and objects stay consistent
  Objects = {                               -- grid-native: same data the placement system uses
    { Id = "p1", Type = "oak_tree", X = 10, Z = 10, Rot = 0 },  -- X/Z cells 0..63, Rot quarter turns 0..3
  },
  NextObjectId = 2,
  CreatedAt = 1760745600,
  Quarantine = { { Reason = "unknown_type", Data = { Id = "p9", Type = "old_item" } } },
  -- managed by WorldStore:
  Session = { Id = "<GUID>", Time = 1760745660 },   -- the session lock (nil when released)
  SaveCount = 17,
  UpdatedAt = 1760745660,
}
```
- **Position and rotation** are stored as grid cell + quarter turns, not studs or degrees. The world position is always computed by `GridMath`, so a save can't place anything off-grid or off the plot.
- **Approved assets only:** `Type` must be an `ItemCatalog` id; the model comes from `ReplicatedStorage.Assets.Items`. Saved data can never name an asset id or code.
- **Unknown fields** are ignored and not re-saved. **Invalid objects** go to `Quarantine` (bounded to 100, primitives only) and are never built. They aren't silently erased, so a future fix can recover them.
- **Versioning:** a record with a higher `Version` than the code knows is refused (never overwritten). Older versions pass through `migrate()` steps (only v1 exists today).
- **Size:** about 45 bytes per object. The object cap is 400 (`Config.MAX_PLACED_PER_PLOT`), roughly 18 KB. Saves above 3 MB are refused (hard limit 4 MB).

### 13.4 Ownership 🧪 / 🟡
- The owner is a **UserId** resolved on the server by `OwnerResolver`. Clients have no way to choose it.
  - **Live:** the World place must run as a reserved server. The owner comes from `WorldIndex_v1/ps_<PrivateServerId>`, written by the hub in the travel phase. Missing or invalid → **no world loads** (fail closed). 🟡 *(the hub side doesn't exist yet, so live World servers currently refuse to load: intended)*
  - **Studio:** the first player to join is the owner, or `ServerStorage.WorldDevStore.OwnerOverride` (server-only attribute) for testing other owners. 🟡
- `WorldSchema.decode` refuses a record whose `OwnerUserId` differs from the resolved owner, and `WorldStore` won't even lock such a record. One player's data **can't** be loaded into another's world. 🧪

### 13.5 Loading workflow 🧪 (logic) / 🟡 (in-game)
1. `Players.CharacterAutoLoads = false`, so nobody spawns early.
2. Resolve and validate the owner.
3. `WorldStore:load` via `UpdateAsync`: **nil** → create the default world and take the lock (`new`); valid record → take the lock (`loaded`); fresh lock held by someone else → `locked`; wrong owner or newer version → `unsafe` (nothing written); throw → retried with backoff 1/2/4 s, then `error`.
4. `WorldLoader`: if `locked`, wait up to 35 s (an old server may be finishing its shutdown save). Then decide: **ready** (lock held), **readonly** (valid but locked elsewhere), or **failed** (error/unsafe/corrupt; our lock released, record untouched).
5. Rebuild objects on the starter plot with `PlacementService.restore` (placement rules re-checked; nothing charged).
6. Mark the world live, set public plot attributes (`OwnerUserId`, `WorldName`, `Visibility`, `WorldStatus`), then spawn players. **Failed** → players are kicked with a "nothing was lost, try again" message and nothing is saved.
7. Runs **once** per server. There's no reload path, so no duplicate objects.

### 13.6 Saving workflow 🧪 (store) / 🟡 (session)
- **Dirty tracking:** `PlacementService.onChanged` and visibility changes bump `WorldState.changeCount`; a save records the count it captured.
- **When:** autosave check every **60 s** (writes only if dirty, or to refresh the lock every 120 s); when the **owner leaves**; on **`BindToClose`** (final save that **releases the lock**). Visitors never cause writes. At most about 1 write per minute per world, far inside the DataStore budget (60 + 40 × players per minute per server).
- **How:** `UpdateAsync` that writes only if **we still hold the lock** and the owner matches; refreshes the lock; `SaveCount += 1`.
- **Failure handling:**

| Situation | Behaviour |
|---|---|
| DataStore error on load | retried; then world **fails to open**, players told to retry, **nothing saved** |
| Record belongs to another owner / newer version / corrupt | world fails to open; record **untouched** (lock released if we took it) |
| Another live session holds the lock | wait up to 35 s; then open **read-only** (no saves, no building) |
| Some saved objects invalid | world opens; bad objects quarantined, logged, not built; the cleaned world is saved |
| DataStore error on save | retried; then logged, **stays dirty**, next autosave tries again; the last good save remains |
| Lock lost / record deleted during the session | save refused; world switches to **read-only** |
| Record won't serialize or exceeds 3 MB | save refused before any DataStore call; logged; stays dirty |
| Server shutting down | final save inside the 30-second `BindToClose` window; if it fails, the last good save stands |

### 13.7 Concurrency: what is and isn't handled
| Scenario | Status |
|---|---|
| Two sessions load the same world | **Handled:** the second gets `locked` → waits → read-only. Unit tested 🧪. In production, reserved servers make this rare (Roblox runs one instance per access code); it mainly happens during shutdown/startup overlap. |
| Two sessions save the same world | **Handled:** only the lock holder's `UpdateAsync` writes; the other gets `lock_lost` and goes read-only 🧪 |
| Server closes mid-save | **Partly:** `UpdateAsync` is atomic per key (all or nothing). The final save runs in `BindToClose`. A crash before it means changes since the last save (≤ 60 s) are lost, and the lock stays until it goes stale (5 min), during which a new session opens read-only. |
| Player enters a world that's already active | **Implemented in Phase 3 (§14):** every trip to a world uses its one stored access code, and Roblox runs one instance per code, so they join the running session. 🟡 needs a live test with 2 accounts. |
| Clock skew between servers | lock staleness uses `os.time()`; minutes-level tolerance makes small skew harmless. Not tested. |

### 13.8 Visibility ✅ (Studio)
Stored in `Settings.Visibility` (default **Public**). Changed only via `RequestSetVisibility` (RemoteFunction, World place). The server checks rate limit → world live → caller is owner → world writable → value is one of the three. Enforced on entry since Phase 3 (§14.4).

### 13.9 Current limits
- 1 world per server, one 64 × 64-cell plot, max 400 objects.
- World names can't be changed yet (no rename remote; it needs TextService filtering).
- Not yet verified with real DataStores (experience unpublished). Travel, visitors and live owner resolution: see §14.

### 13.10 Manual setup required (Sterling)
1. **Publish the hub:** open `MMORPG TYCOON.rbxl` → File → Publish to Roblox → create the experience (keep it private). It becomes the start place.
2. **Enable Studio API access:** Home → Game Settings → Security → **Enable Studio Access to API Services** → Save.
3. **Create the World place:** Creator Dashboard → your experience → **Places** → **Add Place** (or in Studio: View → Asset Manager → Places → right-click → Add New Place). Name it **World**. Open it in Studio (double-click in Asset Manager) and keep that Studio window open.
   - *Before publishing, as a stop-gap:* File → New → Baseplate, save as `MMORPG TYCOON World.rbxl`, keep it open. Claude can build and test everything except real DataStores and teleports there, then you publish it into the experience as the World place.
4. **Access control:** Creator Dashboard → experience → Access Settings → **Access Control for Places** → *Secure within universe only* (needed before travel).
5. Max Players: Hub 6; World 12 (proposed).
6. Once steps 1–3 are done, Claude syncs the World scripts and assets into the World place, switches `STUDIO_STORE_MODE` to `"DataStore"` for a real-DataStore pass (namespace `StudioTest_*`), and runs the Studio tests in §13.11.

### 13.11 Testing
- **Studio, 2026-10-18 (World place copy, Studio dev store):** World suites **105/105** on the Studio server (ItemAssets included). Session Tests: **A** new world → `world ready (new)`; **B/E** 4 objects placed through the real remote, autosaved (397 bytes), saved JSON put back into Edit, fresh Play → `4 objects rebuilt, 0 dropped`, same ids/types/cells/rotations, Cash 1,690 and visibility restored; **C** a record with 4 bad objects → `2 objects rebuilt, 4 dropped` (unknown_type, blocked, outofbounds, bad_transform, all kept in quarantine); **D** `FailMode=all` → 4 load attempts, `load FAILED … Nothing will be saved`, player sent away with "Nothing was lost", record byte-identical afterwards; **F** `OwnerOverride=4242` → a separate `world_4242` created, `world_1586031803` untouched. Visitor build/remove/settings remotes → `NotOwner`. Shutdown save releases the lock.
- **Done earlier (local):** type check of both places (0 errors); Rojo build of both places; **72/72 unit tests** in a local Luau runtime (Lune) against the Rojo-built World place, and 34/34 for the Hub (the engine-dependent ItemAssets suite is skipped locally; it passed in Studio in Phase 1). These cover Tests A–F at the store/loader level with a fake DataStore.
- **Still not done:** real DataStore pass (needs publishing + API access); live reserved-server owner resolution (needs publishing; see §14.8).

---

## 14. Phase 3 implementation: travel and visiting (2026-10-18)

Status legend as in PROJECT_STATUS: ✅ tested in Studio · 🧪 unit-tested · 🟡 implemented, not testable until the experience is published (teleports and DataStores) · ⬜ not built.

### 14.1 What changed from the §12 plan, and why
- **Access codes live in a small `WorldMeta` record** (`meta_<UserId>`: `OwnerUserId`, `AccessCode`, `PrivateServerId`), written by the hub only. The big world record stays a single writer (the World server). *Why:* the hub never touches world saves, and the code is created once and reused forever.
- **The index is written before the code is stored** (`ps_<PrivateServerId>` → UserId, then the meta). *Why:* if the hub crashes in between, the worst case is an unused reserved server, never a World server that can't find its owner.
- **Place ids are found at runtime** (`AssetService:GetGamePlacesAsync`: the place whose name contains "world" is the World place, the other is the Hub), with `Config.HUB_PLACE_ID` / `WORLD_PLACE_ID` as overrides. *Why:* nothing hard-coded before the places exist.
- **Visiting starts from a player's World Gate in the hub, and the owner must be in the same hub server.** A global browser comes later (as planned).
- **A non-Public world's name is never replicated.** Plot attributes reach every client in the server, including a visitor who is about to be refused, so for FriendsOnly/Private worlds the name is sent only to admitted players (`Notify` kind `worldname`). Found and fixed during Studio testing.

### 14.2 Code map (new or changed in Phase 3)
| Module | Place | Role |
|---|---|---|
| `src/shared/AccessPolicy.luau` | both | Pure rule: `decide(visibility, isOwner, isFriend)` → `allowed` / `private` / `friends_only` / `invalid`; unknown values deny. 🧪 |
| `src/common/server/Travel/DataKeys.luau` | both | Store names (`WORLDS`, `WORLD_META`, `WORLD_INDEX`, Studio prefix `StudioTest_`) and key builders. |
| `src/common/server/Travel/WorldDirectory.luau` | hub | `peek(owner)` (read-only summary; refuses another owner's record), `ensureAccessCode(owner)` (reserve once, index first, keep the first code on a race, repair a missing index). Dependencies injected, so it is unit-tested with fakes. 🧪 |
| `src/common/server/Travel/Places.luau` | both | Finds the Hub and World place ids. `pick` 🧪 |
| `src/common/server/Travel/SafeTeleport.luau` | both | `TeleportAsync` with 3 tries, `isAvailable()` (false in Studio / PlaceId 0), `TeleportInitFailed` → listener. 🟡 |
| `src/common/server/Util/Remotes.luau` | both | Creates remotes; `notify(player, kind, text, title)` (toast / travel screen / `worldname`). ✅ |
| `src/common/server/Util/Decor.luau`, `LightingPreset.luau` | both | Shared scenery kit (parts, discs, lamps, props from item models, glowing gates, stud-sized labels) and the lighting look. ✅ |
| `src/hub/server/Services/TravelService.luau` | hub | World Gate on every plot (ProximityPrompt), world info on the plot (name, badge, object count; private worlds show no details), travel checks, `RequestEnterMyWorld`. ✅ (Studio paths) / 🟡 (teleport) |
| `src/hub/server/Services/HubEnvironment.luau` | hub | Grass ground, cobblestone avenue/streets/ring road with kerbs that stop at crossings and the plaza, central plaza with rune ring, fountains at crossings, lamps, forest ring, lighting. ✅ |
| `src/world/server/Services/PlotService.luau` | world | + golden Hub Gate south of the tile, rim lamps, terrain carve-out under/around the tile (see §14.6). ✅ |
| `src/world/server/Services/WorldDecor.luau` | world | Tree and rock ring raycast onto the ground; lighting. ✅ |
| `src/world/server/Services/WorldSessionService.luau` | world | + arrival access gate, private name grant, visitor recheck after a visibility change, `RequestReturnToHub` (owner saves first), Hub Gate prompt, teleport-failure messages, manual respawn. ✅ / 🟡 (teleport) |
| `src/client/common/UI.luau` | both | Theme, panels, buttons, chips, toasts, travel screen (also used as the teleport loading screen). ✅ |
| `src/client/hub/HubHud.client.luau` | hub | World card (name, visibility, object count), ⚔ ENTER MY WORLD button. ✅ |
| `src/client/world/WorldHud.client.luau` | world | Banner (name, YOUR WORLD / VISITING · by owner, visibility), owner Cash chip, WORLD SETTINGS pills, ⟵ RETURN TO HUB. ✅ |

### 14.3 Travel flow (hub → world)
1. A player uses **ENTER MY WORLD** or a plot's **World Gate** prompt. The client sends only "I want to go" (or triggers the prompt); it never names a code, place or UserId.
2. Hub `travel(player, owner)`: already travelling? → rate limit (≈1 per 2 s) → owner still in this hub with a plot → `SafeTeleport.isAvailable()` → World place found.
3. Visitor only: `peek(owner)` → friendship via `Player:IsFriendsWithAsync` (errors count as "not a friend") → `AccessPolicy`. Denied → toast with the reason; nothing reserved.
4. `ensureAccessCode(owner)` → the world's one code (reserved on the very first trip).
5. `notify(player, "travel", …)` shows the travel screen; `TeleportAsync(worldPlaceId, {player}, TeleportOptions{ ReservedServerAccessCode = code })`. Failures (here or `TeleportInitFailed`) → error toast and the travel screen closes.
- Teleport data is **not used** for anything; the World server works out everything itself.

### 14.4 Arrival (World server)
- Owner resolution: `game.PrivateServerId` → `ps_<id>` index → owner UserId (Phase 2 `OwnerResolver`). No index → fail closed.
- Every non-owner is checked again on arrival with the same `AccessPolicy` and a fresh friends check. Refused → "That world is private." / "…owner's friends only." → sent to the hub (kicked in Studio, where teleports don't work).
- Admitted visitors get a welcome toast and the world's name; they are view-only (all build/remove/settings remotes return `NotOwner`).
- The owner changes visibility in WORLD SETTINGS → saved → every visitor is rechecked and anyone no longer allowed is sent to the hub.
- Owner leaves → world saved at once; visitors may stay; the server closes when empty (GAME_DESIGN §5).
- **Joining a running world:** same code → same server instance. 🟡 live test pending.

### 14.5 Return (world → hub)
`RequestReturnToHub` or the Hub Gate prompt: rate limit → the owner's world is saved first → teleport to the Hub place (a normal public server). If teleports are unavailable: a clear toast. If the World server must remove someone and can't teleport, it kicks with the message (never leaves them stuck).

### 14.6 Look and feel (Phase 3 "make it look cool" pass)
- Shared lighting preset in both places (afternoon sun, atmosphere, bloom, colour grade, sun rays).
- Hub: roads, plaza, fountains, lamps, forest ring and purple World Gates with portal glow; gold ENTER button and dark-glass panels; toasts and a travel screen.
- World: grass tile with stone rim, rim lamps, ring of trees and rocks, golden Hub Gate; banner, Cash chip, settings panel.
- **Terrain handling:** the World place has terrain, which buried the tile and grew grass through it. The tile now carves terrain out above it, fills Ground (no grass decoration) underneath, and refills a Grass verge around the rim, leaving the gate step's footprint clear.
- **UI gotcha found:** a `UIGradient` tints a button's *text* too, which made dark buttons' labels invisible. Buttons now use a neutral white→grey shading gradient over a solid colour.

### 14.7 Security summary (Phase 3)
- The client can't choose a destination, code, place or owner; prompts are handled on the server.
- Access is checked in the hub **and** on arrival; friendship errors deny; unknown visibility denies.
- Access codes never leave the server (not in attributes, remotes or teleport data).
- `GetDataStore` itself can throw (unpublished place / API access off); every store access is guarded, and the hub card shows "Info unavailable" instead of hanging.
- Private/FriendsOnly world names are only sent to admitted players.

### 14.8 Testing
- **Unit (local, Lune):** Hub 51/51, World 89/89 (AccessPolicy matrix 6, WorldDirectory 11: read-only peek, foreign record refused, create-once/reuse, index-before-meta order, race keeps first code, index repair, failures reported, store-access errors reported, Places.pick).
- **Studio (2026-10-18):** Hub suites 68/68 and World 105/105 on the server. Hub: environment builds, gate on every plot, world card, ENTER MY WORLD click → server checks → "Travel between places only works in the live game" toast; unpublished DataStore → "Info unavailable". World: owner HUD, visibility pill click (toast, badge, sign), RETURN TO HUB click → Studio notice; visitor admitted to a Public world (banner "VISITING · by …", no owner widgets, `NotOwner` on every write); visitor refused for Private and FriendsOnly (real `IsFriendsWithAsync`), with the name hidden.
- **Needs the published experience (🟡):** reserving and storing the access code with real DataStores, `TeleportAsync` both ways, live owner resolution from `PrivateServerId`, two players in the same running world, visitor recheck after a visibility change with a real visitor, teleport-failure handling, and the full live list in PROJECT_STATUS Milestone 3.

### 14.9 Manual setup still required (Sterling)
1. Publish the hub file (`Documents\MMORPG TYCOON.rbxl`) as a new private experience.
2. Game Settings → Security → **Enable Studio Access to API Services**.
3. Add the World place to that experience with a name containing "World", then publish `C:\Roblox Dev\MMORPG Tycoon\MMORPG TYCOON WORLD.rbxl` into it (open the file → File → Publish to Roblox As → pick the experience → the World place).
4. Access Control for Places → *Secure within universe only*. Max Players: Hub 6, World 12.
5. Then Claude runs the live travel tests with Sterling plus a second account.

---

## 15. Phase 4 implementation: build mode, blue UI, publishing (2026-10-18)

### 15.1 Build mode (client: `src/client/world/BuildMode.client.luau`)
- **Preview only.** The client mirrors the server's occupancy from the replicated `WorldPlot.Placed` models (`ItemId`, `CellX`, `CellZ`, `Rot` attributes) into a `PlacementRules` plot state, so the preview tint and reason match what the server will answer. Every change is still a `RequestPlace` / `RequestRemove` call that runs the full server rule chain.
- **Pointer → cell:** raycast against `WorldPlot.Base` only → `GridMath.worldToCell` → `anchorForCursor` (centres the rotated footprint on the cursor) → clamped inside the plot → `PlacementRules.check(…, cash, …)`.
- **Ghost:** a clone of the item model (translucent, non-colliding, lights and particles removed) with a `Highlight`, lerped towards the snapped `GridMath.footprintCFrame`; a Neon footprint plate (cyan valid / red invalid) and an always-on-top tag (price, or the `Net.Message` reason).
- **Controls:** click place · R rotate · X remove mode · Q/Esc cancel. Touch: tap to aim, then ✅ PLACE / 🔄 ROTATE buttons (placed clear of the thumbstick and jump button); the dock scales to the viewport.
- **Remove mode:** raycast against `Placed`, red highlight, tag with name and refund, click to remove.
- **Feedback:** burst ring + sparkles on place/remove, a short pop-in scale on new objects (client-only), Cash chip bump, error toasts from server reasons.
- **Roles:** only the owner of a `ready` world sees build tools; visitors see "VISITING · LOOK AROUND" and the HUB button.

### 15.2 Items
`ItemCatalog` has 10 items in 5 categories (Buildings, Nature, Ground, Decor, Magic). The 6 new models (Arcane Crystal, Lantern Post, Wooden Fence, Stone Well, Market Stall, Mage Tower) are built by `tools/BuildPlaceholderAssets*` in the same code-built style and checked by `ItemAssets_Test` (footprint, pivot, hitbox) in Studio.

### 15.3 UI theme ("magic-fantasy blue")
`UI.Colors`: sapphire panel gradient (28,62,136 → 12,26,64), cyan rim (120,220,255), azure primary (46,156,255), ink outline (8,24,70), gold (255,206,92) reserved for money. `UI.heading` gives white Fredoka text with a dark-blue outline (the reference images' title style). Button styles: blue / gold / dark / danger / ghost. Hub gates and the plaza rune ring use the same arcane blue.

### 15.4 Config and limits
`GAME_TITLE = "MMO Tycoon"`, `DEFAULT_WORLD_NAME = "My MMO"`, `MAX_VISITORS = 4` (World server refuses a 5th visitor; World place Max Players should be 5 so the owner always fits), `HUB_PLACE_ID = 78195623283467`, `WORLD_PLACE_ID = 86431904123318`, `WorldConfig.STUDIO_STORE_MODE = "DataStore"` (Studio uses the `StudioTest_*` stores).

### 15.5 Testing
- Studio server suites: Hub **92/92**, World **130/130**. Local Lune: Hub 51/51, World 89/89.
- Real DataStores (`StudioTest_Worlds_v1`): new world → 17 objects placed → autosave 1,121 bytes → new session → 17 rebuilt, 0 dropped, Cash 549 restored.
- Build mode by real clicks: tray, ghost, rotate, place (Cash −250), occupied spot shows the server's reason, remove (refund +250), settings pop-out.
- Not tested: touch input, visitor dock with a real visitor, visitor cap, live teleports (now possible: the experience is published).

### 15.6 Tooling
`tools/make-install-model.py hub|world OUT.rbxm` builds the Studio install model straight from the place's Rojo project (so new scripts are never missed). Install steps: `tools/INSTALL-from-rbxm.md`.
