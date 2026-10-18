# PROJECT_STATUS — MMORPG Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · Last updated: 2026-10-17 (end of Phase 1)

## Current phase
**Phase 1 — Server foundation: complete, awaiting Sterling's review.**
Phase 2 (client build mode) must not start until Phase 1 is approved.

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
- **No UI yet:** a player who joins sees their plot but can't build. Expected until Phase 2.
- **Multi-client behaviour untested.** Needs *Test → Clients and Servers* (2–3 players).
- **Max Players not set:** the server kicks a 7th player ("server full"). Set Game Settings → Places → Max Players = 6 once published.
- **Unsaved place:** the Phase 1 changes are in the open Studio session. Save with Ctrl+S.
- **Repo not pushed:** the code lives in the place and in Claude's workspace until it's pushed to GitHub.

## Setup requirements (Roblox Studio)
1. **Save the place now** (Ctrl+S) to keep the Phase 1 scripts and models.
2. Keep Studio open, **visible** (not minimised) and with the MCP connector on while Claude works.
3. Later: publish, set Max Players = 6, and enable Studio Access to API Services (needed for persistence).

## Next implementation task
**Phase 2 — Client build mode.** See the outline in [[DEVELOPMENT_LOG]].
