# GAME_DESIGN — MMORPG Tycoon (Roblox)

Part of [[MMORPG Tycoon]] · Working title, final name TBD by Sterling.
Last updated: 2026-10-18 (Phase 3: travel and visiting implemented; see TECHNICAL_ARCHITECTURE §14)

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
- **Implemented look (Phase 3):** warm afternoon lighting with atmosphere, bloom and sun rays in both places. The hub has cobblestone roads, a central plaza with a glowing rune ring, fountains, iron lamps, a forest ring and a glowing purple **World Gate** on every plot. Worlds have a grass tile with a stone rim and lamps, a ring of trees and rocks, and a golden **Hub Gate**. UI: dark-glass panels with gold trim, a gold primary button, coloured visibility chips, toasts and a full-screen travel screen.

## 5. Multiplayer design (revised 2026-10-17: persistent worlds)

> **Changed.** The original design was "one server, six plots, everyone builds side by side, nothing saved". Sterling replaced it with **persistent, visitable player worlds**. The original text is kept at the end of this section for reference.

**Every player owns one persistent MMORPG world, tied to their Roblox UserId.** The world is not tied to any server; it lives in saved data and is rebuilt whenever someone opens it.

The game becomes **one Roblox experience with two places**:

| Place | What it is | What players do there |
|---|---|---|
| **Hub** (the current map) | A shared social space. Each player in the server gets a plot that acts as their **world's showcase and portal**: sign with owner + world name, visibility badge, and an entrance. | Meet people, see whose worlds are around, **enter their own world**, **visit someone else's world**. No building in the hub. |
| **World** | One server per active world, running that owner's saved world. | The **owner** builds and manages. **Visitors** walk around read-only. Changes are saved to the owner's world. |

**Player journey**
1. Join the game → arrive in the Hub (a normal public server). Your plot shows your world's name.
2. Use your plot's portal (or the "My World" button) → you're teleported into **your** world, rebuilt from your save.
3. Build. Your changes save automatically and when you leave.
4. "Return to Hub" → back to a hub server.
5. In the hub, pick another player's plot or world card → "Visit". If their world allows you, you're teleported in. If the world is already running (the owner or other visitors are there), **you join that same session**.

*Phase 3 status:* steps 2, 4 and 5 are built (World Gates, ENTER MY WORLD, RETURN TO HUB, visibility checks in the hub and on arrival). They're tested in Studio up to the teleport, which needs the published experience.

**Visibility (owner-controlled, enforced by servers only)**
- **Public:** anyone can visit.
- **FriendsOnly:** only the owner's Roblox friends, checked by the server with Roblox's friends API.
- **Private:** only the owner.
- Visitors are **read-only** at first: they can walk and look, but can't build, remove, buy or change settings.
- **Default for new worlds: Public** (confirmed by the Phase 2 brief). New worlds are named "My MMORPG" until renaming exists.

**When the owner leaves their world:** the world is saved immediately. Visitors already inside **may stay and keep exploring** (read-only), and the server closes when the last person leaves. New visitors can still enter while it's running, subject to visibility. *(Alternative Sterling may prefer: send visitors back to the hub when the owner leaves.)*

**What a world saves (Phase 2):** owner, world name, visibility, placed objects (type, grid cell, rotation), and Cash. Cash is saved with the objects so spending and refunds can't be exploited by rejoining. Progression and future NPCs, monsters and quests get their own fields when those systems exist.

**What's deliberately simple at first**
- Visiting is started from the hub, by choosing **players in the same hub server** (and later, online friends). A global "browse all public worlds" list comes later.
- No co-builders, no visitor interactions with objects, no likes or ratings yet.

<details><summary>Original single-server design (superseded)</summary>

- One server = several players, each with an individual plot (up to 6 players and 6 plots per server).
- Plots are spatially separated. Players can walk onto other plots and look, but only the owner can build on a plot (server-enforced).
- No player can affect another player's Cash or objects.
</details>

## 6. MVP scope (first playable version)

> **Revised 2026-10-17.** Items 1–12 still hold, but building (items 4–10) now happens in **the owner's World place**, not on the hub plot. Two items move into the MVP because the new design needs them: **13. the world saves and reloads**, and **14. owners can enter and leave their world** (hub ↔ world travel). Visiting other worlds and visibility settings are the next step after the MVP (Milestone 3).

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

1. **Persistence + world travel + visiting:** now the core of the design. See Milestones 1–3 in [[PROJECT_STATUS]] and TECHNICAL_ARCHITECTURE §12.
2. **World expansion:** buy additional plot area or unlock new biomes.
3. **Content objects with function:** monster spawners (level, density), quest-giver NPCs, dungeon entrances, shops, respawn points.
4. **Simulated subscribers:** NPC adventurers with class, level, goals and satisfaction. They path through your world, fight spawned monsters, take quests and leave feedback.
5. **Revenue model inside the sim:** subscription income per active subscriber per in-game day, plus upkeep costs.
6. **Feedback feed:** subscriber chat bubbles and a complaints panel that tell you what to fix.
7. **Progression:** developer level, object tiers and unlocks.
8. **World discovery:** a browsable list of public worlds, friend worlds, ratings and leaderboards (needs a global index; see TECHNICAL_ARCHITECTURE §12.10).
9. **Monetization (real Robux):** cosmetic or convenience only, never pay-to-win. Designed late and deliberately.

## 8. Explicitly excluded from the MVP

- Terrain editing (sculpting, painting Roblox Terrain)
- Combat, monsters and player stats
- Quests and NPCs of any kind
- Subscriber simulation and revenue/income ticks
- Global public-world browser, ratings, likes (visiting players from the same hub server comes in Milestone 3)
- Co-builders or visitor permissions beyond read-only
- Monetization (game passes, developer products)
- Object stacking or multi-storey building (MVP has a floor layer and an object layer only)
- Free-form (off-grid) placement or non-90° rotation

## 9. Open design questions (need Sterling's call)

| # | Question | Proposed default |
|---|----------|------------------|
| 1 | Players per server | 6 |
| 2 | Plot size | 64 × 64 cells (256 × 256 studs) |
| 3 | Currency name | "Cash" (shown as `$`) |
| 4 | Starting Cash | 2,000 |
| 5 | Refund on removal | 100% during the MVP (encourages experimenting); revisit once income exists |
| 6 | Persistence in the MVP? | **Resolved 2026-10-17: yes.** Persistent worlds are now core. |
| 7 | Touch controls in the MVP? | Yes (most Roblox players are on mobile) |
| 8 | Game title | TBD (must not use "MMORPG Tycoon" branding for release) |
| 9 | Default visibility for new worlds | **Resolved: Public** (Phase 2 brief) |
| 10 | What happens to visitors when the owner leaves | They may stay until the world empties (alternative: send them to the hub) |
| 11 | What's on a hub plot now that building moves to the World place | **Built (Phase 3):** a World Gate showing the world name, owner and visibility (Private worlds show no details). Later maybe a live preview of the world. |
| 12 | Max visitors per world | Same as World place Max Players (proposed 12) |
