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

## 12. Hub-and-World architecture (revision 2026-10-17) — **proposed, not implemented, not tested**

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
| Player enters a world that's already active | **Not implemented** (travel phase): the plan is the same reserved-server code, so they join the running session (§12.2). |
| Clock skew between servers | lock staleness uses `os.time()`; minutes-level tolerance makes small skew harmless. Not tested. |

### 13.8 Visibility 🟡
Stored in `Settings.Visibility` (default **Public**). Changed only via `RequestSetVisibility` (RemoteFunction, World place). The server checks rate limit → world live → caller is owner → world writable → value is one of the three. Stored ≠ enforced: **nobody but the owner can enter a live World server yet** (non-owners are kicked live). Entry checks using visibility arrive with travel (§12.8).

### 13.9 Current limits
- 1 world per server, one 64 × 64-cell plot, max 400 objects.
- No hub ↔ world travel; live World servers can't learn their owner yet (by design, until travel).
- No visitors (Studio-only test visitors, view only).
- World names can't be changed yet (no rename remote; it needs TextService filtering).
- Not yet verified with real DataStores (experience unpublished).

### 13.10 Manual setup required (Sterling)
1. **Publish the hub:** open `MMORPG TYCOON.rbxl` → File → Publish to Roblox → create the experience (keep it private). It becomes the start place.
2. **Enable Studio API access:** Home → Game Settings → Security → **Enable Studio Access to API Services** → Save.
3. **Create the World place:** Creator Dashboard → your experience → **Places** → **Add Place** (or in Studio: View → Asset Manager → Places → right-click → Add New Place). Name it **World**. Open it in Studio (double-click in Asset Manager) and keep that Studio window open.
   - *Before publishing, as a stop-gap:* File → New → Baseplate, save as `MMORPG TYCOON World.rbxl`, keep it open. Claude can build and test everything except real DataStores and teleports there, then you publish it into the experience as the World place.
4. **Access control:** Creator Dashboard → experience → Access Settings → **Access Control for Places** → *Secure within universe only* (needed before travel).
5. Max Players: Hub 6; World 12 (proposed).
6. Once steps 1–3 are done, Claude syncs the World scripts and assets into the World place, switches `STUDIO_STORE_MODE` to `"DataStore"` for a real-DataStore pass (namespace `StudioTest_*`), and runs the Studio tests in §13.11.

### 13.11 Testing
- **Done:** type check of both places (0 errors); Rojo build of both places; **72/72 unit tests** in a local Luau runtime (Lune) against the Rojo-built World place, and 34/34 for the Hub (the engine-dependent ItemAssets suite is skipped locally; it passed in Studio in Phase 1). These cover Tests A–F at the store/loader level with a fake DataStore.
- **Not yet done (needs the World place open in Studio):** run the same suites inside Studio; session-level Tests A–F with the Studio dev store (new world → place → save → copy the saved JSON into Edit → Play again → identical; invalid JSON; `FailMode=all`; `OwnerOverride` for a second owner); real DataStore pass after publishing; live reserved-server owner resolution (travel phase).
