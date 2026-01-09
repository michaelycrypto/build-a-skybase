# Skyblox — Game Identity Document

---

## The Pitch

> **"Build your Realm. Visit your friends. Grow stronger together."**

**Skyblox** is a fantasy medieval survival game where players create their own **Realm**, progress through crafting tiers, command **Golems** to automate gathering, and connect with friends through **Portals** to visit each other's Realms or explore shared Resource Worlds.

---

## Core Identity

| Element | Definition |
|---------|------------|
| **Genre** | Fantasy Medieval Survival / Building |
| **Setting** | Multiverse of player-owned Realms |
| **Core Loop** | Mine → Craft → Build → Automate → Expand |
| **Social Hook** | Visit friend Realms, build together |
| **Tone** | Adventurous, social, rewarding progression |

---

## The World Structure

```
┌─────────────────────────────────────────────────────────────┐
│                     THE MULTIVERSE                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   🌀 THE NEXUS                                              │
│   The crossroads of all realms. Meet friends,               │
│   claim rewards, step through portals.                      │
│                                                             │
│   ─────────────────── PORTALS ───────────────────           │
│                                                             │
│   🏰 YOUR REALM                                             │
│   Your personal kingdom. Build, automate, create.           │
│                                                             │
│   🏰 FRIENDS' REALMS                                        │
│   Visit friends through portals.                            │
│   Help them build. Show off your progress.                  │
│                                                             │
│   ─────────────────── PORTALS ───────────────────           │
│                                                             │
│   ⛏️ RESOURCE WORLDS                                        │
│   Shared dimensions with specific resources.                │
│   Everyone can access. Competitive gathering.               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### The Nexus (Hub)
- Central hub connecting all Realms
- Where players spawn initially
- Social gathering space
- Access to all portal types
- "The crossroads of all realms"

### Your Realm
- Every player gets their own Realm
- Persistent—saves between sessions
- Full creative control
- Can invite friends to visit
- Spawn point, home base, personal kingdom

### Friends' Realms
- Visit through portal system
- See what friends have built
- Collaborate on builds
- Trade resources (if implemented)

### Resource Worlds
- Shared public dimensions
- Each has unique resources/biomes
- Resets periodically (optional)
- More dangerous, more rewarding
- Social competition for rare materials

---

## Progression System

### Material Tiers

| Tier | Material | Color | Tool Requirement |
|------|----------|-------|------------------|
| 1 | **Copper** | Warm orange | Entry level |
| 2 | **Iron** | Cool gray | Copper tools |
| 3 | **Steel** | Polished silver | Iron tools |
| 4 | **Bluesteel** | Glowing blue | Steel tools |
| 5 | **Tungsten** | Deep gray-white | Bluesteel tools |
| 6 | **Titanium** | Iridescent cyan | Tungsten tools |

### The Three Ages

Players experience progression as three distinct phases:

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  🔧 PIONEER AGE         ⚒️ BUILDER AGE        👑 RULER AGE  │
│  (Copper + Iron)        (Steel + Bluesteel)   (Tung + Titan)│
│                                                             │
│  • Survival basics      • Golems unlocked     • Mastery     │
│  • Manual gathering     • Automation begins   • Full auto   │
│  • First shelter        • Expanding realm     • Grand builds│
│  • Learning the ropes   • Visiting friends    • Legacy      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Golems (Automation System)

### What Are Golems?
Golems are **elementals** — magical constructs tied to natural resources. Players craft them from materials, place them in their Realm, and they automatically generate their bound resource over time.

### Golem Philosophy
- **Elementals** — Each Golem is bound to a natural resource (stone, earth, ore, sand)
- **Crafted, not summoned** — You build them from materials
- **Loyal workers** — They serve only their creator
- **Upgradeable** — Level up for efficiency
- **Visible** — Walking around your Realm, working

### Current Golem Types

| Golem | Function | Materials |
|-------|----------|-----------|
| **Stone Golem** | Generates cobblestone | Cobblestone + Core |
| **Earth Golem** | Generates dirt | Dirt + Core |

### Future Golem Types (Planned)

| Golem | Function | Unlock |
|-------|----------|--------|
| **Coal Golem** | Generates coal | Early game |
| **Sand Golem** | Generates sand | Early game |
| **Copper Golem** | Generates copper ore | Mid game |
| **Iron Golem** | Generates iron ore | Mid game (requires Steel) |

### Golem Progression

```
Level 1: 1 slot,  15 second interval
Level 2: 2 slots, 14 second interval (32 materials to upgrade)
Level 3: 3 slots, 13 second interval (64 materials to upgrade)
Level 4: 4 slots, 12 second interval (128 materials to upgrade)
```

### Golem Visual Identity
- Made of their primary material (stone golem = stone body)
- Simple, blocky design fitting voxel aesthetic
- Idle animation: standing, looking around
- Working animation: mining/gathering motion
- Subtle magical glow indicating they're active

---

## Creatures & Combat

### Passive Creatures (Animals)

| Creature | Drops | Found In |
|----------|-------|----------|
| **Sheep** | Wool, Mutton | Realms, Plains |
| **Cow** | Leather, Beef | Realms, Plains |
| **Chicken** | Feathers, Chicken | Realms, Farms |
| **Pig** | Porkchop | Realms, Forests |

### Hostile Creatures (Monsters)

| Creature | Danger | Drops | Spawns |
|----------|--------|-------|--------|
| **Goblin** | Low | Coins, Scraps | Night, Caves |
| **Skeleton** | Medium | Bones, Arrows | Night, Dungeons |
| **Zombie** | Medium | Rotten Flesh | Night |
| **Slime** | Low | Slimeballs | Caves, Swamps |
| **Spider** | Medium | String, Eyes | Night, Caves |
| **Wolf** | Medium | Fur | Forests (hostile if provoked) |

### Combat Design
- **Not the focus** — Building and progression are primary
- **Threatening but fair** — Players should feel danger, not frustration
- **Night cycle** — Hostile mobs spawn at night, safe during day
- **Realm safety** — Players can light up their Realm to prevent spawns

---

## The Portal System

### Portal Types

| Portal | Destination | Cost | Permanence |
|--------|-------------|------|------------|
| **Realm Portal** | Your home Realm | Free | Always available |
| **Friend Portal** | Specific friend's Realm | Portal frame + activation | Linked until broken |
| **World Portal** | Resource World | Portal frame + key item | Temporary access |

### Portal Mechanics
- **Crafted frames** — Build a portal structure
- **Activation** — Different items activate different destinations
- **Visual feedback** — Swirling magical effect when active
- **Loading transition** — Brief transition screen between worlds

### Visiting Friend Realms
1. Friend shares their Realm code/invite
2. You activate a portal to their Realm
3. You appear at their portal location
4. You can explore, help build, trade
5. Return through any Realm Portal

---

## Social Features

### Building Together
- **Realm permissions** — Owner controls who can build
- **Visitor mode** — Look but don't touch (default)
- **Builder mode** — Trusted friends can place/break blocks
- **Co-owner mode** — Full access (future feature)

### Showing Progress
- **Realm visits** — See what friends have built
- **Golem count** — Status symbol for automation
- **Gear display** — Armor visually shows progression
- **Build showcases** — Screenshot-worthy creations

### Social Moments to Design For
```
"Come check out my new castle!"
"I finally got Titanium, want to see?"
"Let's build a town together in my Realm"
"I found a crazy cave in the Mining World"
"How did you get so many Golems?!"
```

---

## Tone & Atmosphere

### Visual Style
- **Voxel/blocky** — Consistent with existing systems
- **Warm fantasy palette** — Greens, browns, warm stone
- **Magical accents** — Glowing portals, golem eyes, ore veins
- **Cozy but grand** — Feels like a place you want to live

### Audio Direction
- **Ambient music** — Calm, medieval-inspired
- **Day/night shift** — Peaceful day, mysterious night
- **Satisfying SFX** — Mining, crafting, golem footsteps
- **Social cues** — Friend joins, portal activates

### The Feeling
```
When playing Skyblox, players should feel:

✓ Pride in their Realm
✓ Excitement showing friends
✓ Satisfaction in progression
✓ Calm while building
✓ Anticipation for next tier
✓ Connection with friends
```

---

## What Makes Skyblox Memorable

### The Core Memory
> "Remember our Realms? Remember building that together?"

### Unique Selling Points

| Feature | Why It Matters |
|---------|----------------|
| **Your Realm** | Permanent, personal, meaningful |
| **Friend Portals** | Easy social connection |
| **Golems** | Visible, charming automation |
| **Clear Progression** | Always know what's next |
| **Fantasy Medieval** | Timeless, appealing aesthetic |

### What We're NOT
- ❌ Not a raid/dungeon game
- ❌ Not hardcore survival
- ❌ Not competitive PvP
- ❌ Not complicated magic systems
- ❌ Not a Minecraft clone with nothing new

### What We ARE
- ✅ A place to build your kingdom
- ✅ A way to play with friends
- ✅ Satisfying progression that respects your time
- ✅ Golems that make you smile
- ✅ A Realm you're proud to show off

---

## Terminology Reference

| Generic Term | Skyblox Term |
|--------------|--------------|
| Player world / Server | **Realm** |
| Hub / Lobby | **The Nexus** |
| Minion / Automation unit | **Golem** |
| Join world | **Enter Realm** |
| Shared dimension | **Resource World** |

### Internal Code vs User-Facing

The codebase uses generic terms internally (e.g., `worldId`, `MinionConfig`), but all **user-facing UI** displays the Skyblox terminology above.

---

## The 30-Second Pitch

> **Skyblox** is a fantasy survival game where you build your own **Realm**—a personal kingdom in a multiverse of player Realms. Mine resources, craft tools through six tiers of progression, and awaken **Golems** to automate your domain. Connect with friends through **The Nexus** and magical **Portals** to visit their Realms, build together, and explore shared Resource Worlds. It's not about raiding dungeons—it's about creating something you're proud to show off, and sharing it with friends.

---

*Document Version: 3.1*
*Last Updated: January 2026*
*Note: Golems are elementals (natural resources only — no wood/organic)*
