# GAME_DESIGN — MMORPG Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · Working title, final name TBD by Sterling.
Last updated: 2026-10-17 (Phase 0)

> Inspiration: the management and world-building loop of *MMORPG Tycoon 2* (Lazy Bear Games / Pat Wilson). We borrow **general gameplay ideas only** — no assets, code, UI layouts, names, or other protected content.

---

## 1. Concept

You are the developer of your own fantasy MMORPG. You walk around inside your game world as its creator, place towns, roads, forests, dungeons and monster camps, and watch simulated "subscribers" log in, adventure and complain. Their subscription money funds a bigger, better world.

On Roblox it becomes a **social** version of that fantasy: every player in the server is building their own MMO next door, and you can walk over and see how theirs is doing.

**One-line pitch:** *Build your own MMO, then watch fake players play it.*

## 2. Core gameplay loop

**MVP loop (building only):**
1. Spawn on your plot with starting Cash.
2. Open Build Mode → pick an object from the catalog.
3. Preview it on the grid, rotate it, place it (Cash deducted).
4. Walk around your world and admire it, or remove and rearrange objects (refund).

**Full loop (post-MVP target):**
```
Build content ──► Subscribers arrive ──► They explore / fight / quest
     ▲                                         │
     │                                         ▼
Reinvest Cash ◄── Subscription revenue ◄── Satisfaction & feedback
```
- **Short loop (seconds):** place → instant visual payoff.
- **Mid loop (minutes):** fix subscriber complaints ("not enough monsters at level 5", "town is too far from the dungeon") to raise satisfaction.
- **Long loop (sessions):** unlock new biomes, object tiers, world expansions and features.

## 3. Target experience

- **Creative ownership:** "This is *my* MMO." Every world looks different.
- **Readable cause → effect:** the world changes the moment you act, and later the subscribers react visibly to what you built.
- **Low-friction building:** placing 20 objects in a minute should feel smooth on PC and on mobile.
- **Gentle humour:** subscriber chatter and MMO-industry jokes, in an original voice.
- **Session length:** satisfying in 10 minutes, rewarding over weeks.

## 4. Visual direction

- **Style:** stylized, low-poly fantasy that reads as "an MMO diorama". Chunky, readable silhouettes, saturated but harmonious palette, soft lighting. Roblox-native, not realistic.
- **Grid-friendly assets:** every object's footprint snaps cleanly to the 4-stud grid. Bases are flat and sit flush on the ground.
- **Cohesion over quantity:** one consistent palette and material set, locked in during the asset phase (Phase 3). Ten polished objects beat fifty mismatched ones.
- **Asset sources (quality bar):** custom-built assets only, made with Studio's procedural/mesh generation, Blender (Blender connector available), or hand-built parts. **No unvetted Toolbox free models**, which bring inconsistent style, hidden scripts and backdoors.
- **World framing:** each plot is a raised "world tile" with a clear edge and a distinct ground biome, so a server reads as a row of separate MMO worlds.

## 5. Multiplayer design

- **One server = several players, each with an individual plot** (proposed: up to 6 players and 6 plots per server).
- Plots are spatially separated. Players can walk onto other plots and look, but **only the owner can build** on a plot (server-enforced).
- No player can affect another player's Cash or objects.
- **Future:** visiting permissions (public / friends / private), likes or ratings, and loading an *offline* friend's saved world into a free plot or a reserved server.

## 6. MVP scope (first playable version)

1. Players join a server.
2. Each player receives an individual plot.
3. Players walk around their plot.
4. A basic building interface.
5. Selecting an available object from a catalog.
6. Previewing an object before placement (green = valid, red = invalid).
7. Placing objects on a grid.
8. Rotating objects before placement (90° steps).
9. Removing objects.
10. Purchasing objects with in-game currency (charged on placement).
11. Server-side ownership and purchase validation.
12. Multiple players building at once without interfering with one another.

**MVP content:** about 10–12 cohesive objects in 3 categories:
- **Ground:** grass tile, stone path, dirt road, plaza tile
- **Nature:** tree, pine, rock, bush
- **Buildings:** small house, tavern, fence segment, lamp post

**MVP quality bar ("not slop"):**
- Every action gives feedback: preview tint, placement sound and a short pop tween, an error toast that names the reason ("Not enough Cash", "Blocked", "Not your plot").
- No silent failures. Every rejected request returns a reason code that the UI shows.
- Works on keyboard and mouse **and** touch. Gamepad is nice to have.
- Stable 60 FPS on a mid-range phone with 6 full plots (TECHNICAL_ARCHITECTURE §10).
- No console errors during a normal session.

## 7. Planned future systems (post-MVP, rough order)

1. **Persistence:** save and load Cash and placed objects (strongly recommended immediately after the MVP; see open questions).
2. **World expansion:** buy additional plot area or unlock new biomes.
3. **Content objects with function:** monster spawners (level, density), quest-giver NPCs, dungeon entrances, shops, respawn points.
4. **Simulated subscribers:** NPC adventurers with class, level, goals and satisfaction. They path through your world, fight spawned monsters, take quests and leave feedback.
5. **Revenue model inside the sim:** subscription income per active subscriber per in-game day, plus upkeep costs.
6. **Feedback feed:** subscriber chat bubbles and a complaints panel that tell you what to fix.
7. **Progression:** developer level, object tiers and unlocks.
8. **World visiting:** visit permissions, friend worlds, ratings and leaderboards.
9. **Monetization (real Robux):** cosmetic or convenience only, never pay-to-win. Designed late and deliberately.

## 8. Explicitly excluded from the MVP

- Terrain editing (sculpting, painting Roblox Terrain)
- Combat, monsters and player stats
- Quests and NPCs of any kind
- Subscriber simulation and revenue/income ticks
- Visiting other servers' or offline players' worlds
- Monetization (game passes, developer products)
- Object stacking or multi-storey building (MVP has a floor layer and an object layer only)
- Free-form (off-grid) placement or non-90° rotation
- Persistence (unless Sterling pulls it into the MVP; see open questions)

## 9. Open design questions (need Sterling's call)

| # | Question | Proposed default |
|---|----------|------------------|
| 1 | Players per server | 6 |
| 2 | Plot size | 64 × 64 cells (256 × 256 studs) |
| 3 | Currency name | "Cash" (shown as `$`) |
| 4 | Starting Cash | 2,000 |
| 5 | Refund on removal | 100% during the MVP (encourages experimenting); revisit once income exists |
| 6 | Persistence in the MVP? | Recommend making it the phase right after the core MVP |
| 7 | Touch controls in the MVP? | Yes (most Roblox players are on mobile) |
| 8 | Game title | TBD (must not use "MMORPG Tycoon" branding for release) |
