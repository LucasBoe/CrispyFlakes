# CrispyFlakes — Saloon Tycoon

A Western-themed tycoon/management simulation game built in Godot 4.5 (GDScript, GL Compatibility renderer). Internal resolution 640x360, displayed at 1280x720.

## Project Structure

```
scripts/          # Main GDScript gameplay and runtime logic
  autoloads/      # Core global handlers used by the project
  npc/
    behaviours/   # NPC state/behavior scripts
    modules/      # Composable NPC capability modules
    needs/        # Guest need definitions
  ui/             # UI-specific scripts
  items/          # Item system
  resources/      # Runtime resource handlers
scenes/           # Godot .tscn files
assets/
  sprites/        # Pixel art and UI sprites, imported via AsepriteWizard
  resources/      # Room data definitions (`room_*.tres`)
  shaders/        # Outline and NPC customization shaders
addons/           # Project addons such as AsepriteWizard, console, debugdraw2d, Todo Manager
docs/             # Project-specific implementation guides
```

## Key Systems

### Autoloads (global singletons and scene singletons)
The project currently registers 29 autoloads in `project.godot`, mixing handler scripts and scene singletons.

Key gameplay-facing autoloads include:
- **ResourceHandler** — global resource totals and money change signaling
- **MoneyHandler** — per-room cash storage, collection targets, and capacity-aware spending
- **JobHandler** — worker-to-job assignments
- **BountyHandler** — sheriff bounties and fight fines
- **FightHandler** — drunk NPC combat and fight resolution support
- **DirtHandler / PuddleHandler** — floor mess spawning and cleanup hooks
- **PlacementHandler** — room placement flow and validation
- **TutorialHandler** — sequential tutorial milestones
- **HoverHandler / MouseInputHandler** — click and hover interactions
- **GlobalEventHandler / NPCEventHandler** — cross-system event signaling
- **RoomStatusHandler** — room state/status support
- **SoundPlayer** — centralized audio playback with pitch variation
- **TimeHandler** — time scale control via `TimeHandler.set_time(t)` (0 = paused, 1 = normal); do not use `get_tree().paused` or `Engine.time_scale` directly
- **StartupCoordinator** — initial world setup
- **Building / Camera** — scene autoloads for world access

### Room System
Rooms are data-driven through `RoomData` `.tres` resources in `assets/resources/`. Buildable room resources currently include:

`aging_cellar`, `bar`, `bath`, `bed`, `bouncer`, `bounty_board`, `brewery`, `broom_closet`, `destillery`, `empty`, `entertainment`, `gambling`, `horse_post`, `junk`, `outhouse`, `prison`, `safe`, `stairs`, `storage`, `table`, `toilet`, `water_tower`, `well`.

Buildable infrastructure resources are separate from rooms. The current infrastructure buildable is `infrastructure_water_pipe`, which places `Water Pipe` cells for the water-service network.

Each placed room is backed by a scene and usually a matching `room_<name>.gd` script.

`building.gd` owns the `floors` dictionary, instantiates room scenes from `RoomData`, and coordinates wall/roof rendering plus room queries through helper classes.

#### Floor index convention
- `Building.floors` is a `Dictionary` keyed by `int` y_idx, then by `int` x_idx.
- **Above-ground floors: y_idx > 0** (global_pos.y = y_idx × −48, i.e. higher on screen).
- **Ground floor: y_idx = 0** (global_pos.y = 0).
- **Basement floors: y_idx < 0** (global_pos.y = y_idx × −48 → positive world y, lower on screen).
- `round_room_index_from_global_position` does **not** offset for the Building node's own position; it divides raw global coords by ±48.
- When scanning for rooms by floor, always derive the range from `Building.floors.keys()` rather than hardcoding bounds — the basement can be arbitrarily deep and hardcoded limits will silently miss valid floors.

#### Water infrastructure
- `Building.infrastructure` is a `BuildingInfrastructure` `TileMapLayer` that currently manages the `water` service layer.
- `Water Pipe` is infrastructure, not a room. Pipe placement must extend from an existing horizontal network or provider, must stay locally supported by rooms/pipe below, and disconnected or unsupported cells are pruned when rooms are removed.
- `RoomWaterTower` is the current water-layer provider. It exposes `get_provided_infrastructure_layers() -> [&"water"]`, stores up to 96 water, starts empty, and is refilled by `JobWaterTowerBehaviour` in 8-unit pumps.
- `RoomWell` does **not** provide the water infrastructure layer. It produces `WATER_BUCKET`s, refills slowly over time, and can be dug deeper to raise capacity; `JobWellBehaviour` queues workers at the well and stocks bucket water into storage.
- Connected water service is resolved through the laid pipe network via `BuildingInfrastructure.get_connected_provider()`, not by simple room adjacency.
- Current piped consumers are `RoomToilet`, `RoomBath`, `RoomBrewery`, `RoomDestillery`, and `RoomBar` when the active purchased module serves water.
- Worker behaviors for bath, brewery, destillery, and water-serving bars can fall back to fetching `WATER_BUCKET`s if no tower service is available. `RoomToilet` is stricter: it needs both a placed pipe and a connected `RoomWaterTower`, and each stall use consumes tower water directly.

For the current end-to-end workflow for adding rooms, see [docs/room_setup_guideline.md](/Users/lucasbodeker/CrispyFlakes/docs/room_setup_guideline.md:1).

### NPC Architecture (module-based)
- **npc.gd** — shared NPC base class
- **npc_worker.gd** — salary, drag-and-drop assignment, worker behavior entry
- **npc_guest.gd** — needs simulation, dirtiness, stay/satisfaction logic, and guest-specific state

Current NPC modules include:
`AnimationModule`, `BehaviourModule`, `EscortChain`, `GuestVisualModule`, `ItemModule`, `NavigationModule`, `NeedsModule`, `TintModule`.

### Behavior AI
NPC logic is organized as behavior scripts in `scripts/npc/behaviours/`, using a state-machine-style flow with transitions, interrupts, and forced behavior changes.

Representative guest behaviors:
- `IdleBehaviour`
- `NeedLeaveBehaviour`
- `FightBehaviour`
- `ArestedBehaviour`

Representative worker behaviors:
- `JobBarBehaviour`
- `JobBreweryBehaviour`
- `JobPrisonBehaviour`
- `StopFightBehaviour`
- `CollectBountiesBehaviour`

### Special Encounters
One-off events where a named NPC visits and presents the player with a dialogue choice (money delta + Callable effects).

**Data flow:** `NPCSpawner.spawn_special_encounter(id)` → `SpecialNPC` (with encounter data) → `SpecialNPCEncounterBehaviour` navigates NPC, shows a question-mark marker, waits for click → `Global.UI.encounter.start_encounter(context)` → `UIEncounter` shows typewriter dialogue + choice buttons → applies `money_delta` and fires `effects: Array[Callable]` → outcome text → NPC leaves.

Key files: `scripts/encounters/encounter_catalog.gd` (all definitions), `scripts/npc/npc_special.gd`, `scripts/npc/behaviours/special_npc_encounter_behaviour.gd`, `scripts/ui/ui_encounter.gd`, `scripts/npc_spawner.gd`.

`EncounterContext` (inner class of `EncounterCatalog`) packages `{ npc, encounter, choice }` and is passed to every effect Callable.

To add a new encounter: add an entry in `EncounterCatalog.load_entries()` using `_encounter()` / `_choice()`. No scene or NPC class changes required.

Auto-spawn fires every `SPECIAL_ENCOUNTER_DAYS = 4.0` in-game days; requires ≥10 active guests. Dev-console commands: `encounter <id>`, `special_npc`.

### Economy
- Room construction costs come from `RoomData` resources
- Worker salaries are deducted automatically each in-game day
- Money is split between global resource totals and room-based storage/capacity via `MoneyHandler`
- Some rooms produce, consume, or store resources and cash directly through room data and room logic
- `RoomModule` is the active in-room variant/customization system

## Active Development Areas (updated 2026-04-17)
Recent changes since setup have concentrated around:
- Bounty, sheriff, and arrest flow polish
- Outside/outdoor room rules and inside/outside traversal
- Stairs and multi-floor navigation reliability
- Guest appearance and escort visuals
- Prisoner handling and prison UI
- Room economy readability, including stored room cash

## Development Tools
- Built-in developer console addon
- DebugDraw2D for visualization
- Todo Manager addons in `addons/`
- Verified Godot executable: `/Applications/Godot.app/Contents/MacOS/Godot`
- Verified Godot version: `4.5.stable.official.876b29033`

## Shaders

### Outline shader (`assets/shaders/outline_size.gdshader`)
- Supports `outline_size` (float, 1–16) and `corner_pixel` (bool) uniforms in addition to `outline_color`
- **No vertex expansion** — outline is sampled purely in the fragment stage using `TEXTURE_PIXEL_SIZE * outline_size` steps
- Works correctly on both `Sprite2D` and `NinePatchRect` (vertex expansion breaks 9-slice UV layout, fragment-only does not)
- Outline renders within the existing texture/canvas-item bounds; source texture needs enough transparent padding for the outline to be visible

## Conventions
- Signals are a primary communication mechanism between systems
- New rooms usually require a `.tres` resource, `.gd` script, `.tscn` scene, and build-menu registration
- Buildable rooms are not fully auto-discovered; `building.gd` and `build_ui_handler.gd` usually need updates
- New NPC capabilities should be added as modules in `scripts/npc/modules/`
- New behaviors should extend the `Behaviour` base class and live in `scripts/npc/behaviours/`
- Prefer simple logic over defensive handling for impossible internal states unless a system genuinely needs the guard
