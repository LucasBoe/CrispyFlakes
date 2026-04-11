# Room Setup Guideline

This guide documents how a new room is wired into Saloon Tycoon today, based on the current codebase.

It covers:

- the files a room usually needs
- how the room becomes buildable from the UI
- how placement validation works
- how jobs are attached to rooms
- how room-specific modules work
- how upgrades currently fit into the project

## 1. Room Checklist

For a normal new room, expect to touch these files:

- `assets/resources/room_<name>.tres`
- `scripts/room_<name>.gd`
- `scenes/rooms/room_<name>.tscn`
- `assets/sprites/ui/room_<name>_icon.png`
- `assets/sprites/ui/room_<name>_preview.png`

You will usually also update:

- `scripts/building.gd`
- `scripts/ui/build_ui_handler.gd`

You may additionally need to update:

- `scripts/global_enums.gd`
- `scripts/npc/behaviours/job_<name>_behaviour.gd`
- `scripts/startup_coordinator.gd`
- room-specific selection UI in `scripts/ui_selection_panel.gd`

## 2. Core Room Files

### `assets/resources/room_<name>.tres`

This is the room's build-time data source. `RoomData` is what the build UI reads and what `Building.set_room()` uses to know which scene to instantiate.

The main exported fields live in [scripts/room_data.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_data.gd:1):

- `packed_scene`: the `.tscn` that becomes the placed room
- `room_name`
- `room_desc`
- `room_icon`: used by the build menu button
- `room_preview`: used by the build hover card
- `construction_price`
- `tier`: controls which unlock tier it appears in
- `is_outdoor`: changes placement rules
- production/consumption fields like `has_consumed_item`, `produces_item`, `produces_money`
- `room_upgrades`: resource list for the older upgrade path

Examples:

- [assets/resources/room_bar.tres](/Users/lucasbodeker/CrispyFlakes/assets/resources/room_bar.tres:1)
- [assets/resources/room_brewery.tres](/Users/lucasbodeker/CrispyFlakes/assets/resources/room_brewery.tres:1)
- [assets/resources/room_well.tres](/Users/lucasbodeker/CrispyFlakes/assets/resources/room_well.tres:1)

### `scripts/room_<name>.gd`

This is the room's runtime logic. Most rooms extend one of these bases:

- [scripts/room_base.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_base.gd:1) for normal indoor rooms
- [scripts/room_outside_base.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_outside_base.gd:1) for outdoor rooms on `y == 0`
- [scripts/room_storage_base.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_storage_base.gd:1) for item-storage rooms

Common setup pattern:

```gdscript
extends RoomBase
class_name RoomExample

@onready var progress_bar: TextureProgressBar = $ProgressBar

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.EXAMPLE
	progress_bar.visible = false
```

What usually belongs here:

- assigning `associated_job`
- room occupancy and interaction logic
- module hookup from `ModulesRoot`
- visual refresh logic
- room-specific helper methods used by behaviours or UI

Examples:

- [scripts/room_bar.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_bar.gd:1)
- [scripts/room_brewery.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_brewery.gd:1)
- [scripts/room_well.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_well.gd:1)
- [scripts/room_stairs.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_stairs.gd:1)

### `scenes/rooms/room_<name>.tscn`

This is the visual and node structure that actually gets instantiated when the room is placed.

Typical indoor structure:

- root `Node2D` with the room script
- `Back-wall`
- `Outline`
- optional `ProgressBar`
- optional room content sprites/nodes
- optional `ModulesRoot`

Typical outdoor structure:

- root `Node2D` with an outside-room material
- main room art
- `Outline`
- optional `ProgressBar`
- optional extra underground or overlay nodes

Examples:

- [scenes/rooms/room_bar.tscn](/Users/lucasbodeker/CrispyFlakes/scenes/rooms/room_bar.tscn:1)
- [scenes/rooms/room_table.tscn](/Users/lucasbodeker/CrispyFlakes/scenes/rooms/room_table.tscn:1)
- [scenes/rooms/room_well.tscn](/Users/lucasbodeker/CrispyFlakes/scenes/rooms/room_well.tscn:1)

## 3. Registering the Room in Building

`Building` does not auto-discover room resources. New buildable rooms must be preloaded in [scripts/building.gd](/Users/lucasbodeker/CrispyFlakes/scripts/building.gd:10).

Pattern:

```gdscript
const room_data_example := preload("res://assets/resources/room_example.tres")
```

Why this matters:

- the build menu references `Building.room_data_*`
- startup layout code can place rooms using these constants
- other systems often compare against these constants directly

If the room should appear in a starting layout or a scripted setup, also wire it into [scripts/startup_coordinator.gd](/Users/lucasbodeker/CrispyFlakes/scripts/startup_coordinator.gd:10).

## 4. Making the Room Buildable from the UI

The build menu is manually assembled in [scripts/ui/build_ui_handler.gd](/Users/lucasbodeker/CrispyFlakes/scripts/ui/build_ui_handler.gd:1).

Each room gets a button through:

```gdscript
create_button(group, Building.room_data_example)
```

If the room needs custom placement validation:

```gdscript
create_button(group, Building.room_data_example, RoomExample.custom_placement_check)
```

The button uses `RoomData` for:

- icon
- price
- description
- preview image
- production/consumption display
- tier grouping

Important detail: the build menu is currently not data-driven across all resources. Adding the `.tres` alone is not enough; you must also add the button call in `build_ui_handler.gd`.

## 5. Placement Flow

Room placement is handled centrally by [scripts/placement_handler.gd](/Users/lucasbodeker/CrispyFlakes/scripts/placement_handler.gd:1).

Flow:

1. Build UI calls `PlacementHandler.start_building(data, custom_check)`.
2. Placement handler tracks mouse position and computes a target room index.
3. It validates money, occupancy, adjacency, outdoor rules, and optional custom checks.
4. On left click, it calls `Building.set_room(building_data, location.x, location.y)`.
5. It updates foreground tiles and charges money.

### Default placement rules

Indoor above-ground rooms:

- use "tetris gravity" and snap to the lowest free `y` in the chosen column
- must be empty
- must connect to something above or below, or be on ground floor
- cannot be placed in a column whose ground-floor slot is an outdoor room

Basement indoor rooms:

- use the raw clicked location
- must be empty
- must have at least one adjacent room in the four cardinal directions

Outdoor rooms:

- use the raw clicked location
- typically rely on `RoomOutsideBase.custom_placement_check()` to force `y == 0`

### Custom placement checks

Use a static function on the room script when default rules are not enough.

Examples:

- [scripts/room_stairs.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_stairs.gd:31)
  Stairs require either an empty new column or connection to existing stairs above/below.
- [scripts/room_outside_base.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_outside_base.gd:18)
  Outdoor rooms are restricted to `y == 0`.

Recommended pattern:

```gdscript
static func custom_placement_check(location: Vector2i) -> bool:
	# add extra room-specific constraints here
	return true
```

Use this for rules like:

- "must be on ground floor"
- "must be above/below matching room"
- "must be adjacent to storage"
- "only one per floor"
- "cannot be next to outdoor rooms"

## 6. Room Scripts and Base Classes

### `RoomBase`

The shared runtime properties are in [scripts/room_base.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_base.gd:1):

- grid coordinates `x` and `y`
- `data: RoomData`
- `associated_job`
- `worker`
- `has_upgrades`

`init_room()` is where coordinates are assigned and back-wall visuals are finalized.

### `RoomOutsideBase`

Use this when the room lives outside the saloon footprint. It:

- sets `is_outside_room = true`
- duplicates the outline shader material
- overrides outline behavior to use shader parameters
- supplies a default `custom_placement_check()` that restricts placement to `y == 0`

### `RoomStorageBase`

Use this for rooms that physically receive and hold `Item` nodes. It already handles:

- slot arrays
- item reparenting
- slot positioning
- `try_receive()`
- `take()`
- `has()`

If your room stores only some item types, override `try_receive()` like [scripts/room_storage.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_storage.gd:1).

## 7. Linking a Room to a Worker Job

Jobs are linked from the room script, not from `RoomData`.

The key line is:

```gdscript
associated_job = Enum.Jobs.EXAMPLE
```

This is what `JobHandler` counts when determining worker capacity in [scripts/autoloads/job_handler.gd](/Users/lucasbodeker/CrispyFlakes/scripts/autoloads/job_handler.gd:60).

### Full job setup checklist

If the room should employ a worker, wire all of these:

1. Add a new enum value in [scripts/global_enums.gd](/Users/lucasbodeker/CrispyFlakes/scripts/global_enums.gd:23) if one does not already exist.
2. Map that enum to a behaviour in `job_to_behaviour()` in the same file.
3. Create a behaviour script such as `scripts/npc/behaviours/job_example_behaviour.gd`.
4. Set `associated_job` in the room's `init_room()`.

### How workers find rooms

There are two ways jobs get linked at runtime:

- `JobHandler.count_rooms_for(job)` counts all placed rooms whose `associated_job` matches
- workers can be drag-assigned to a room, and `NPCWorker.try_change_job_based_on_room()` reads `room.associated_job`

That means a room becomes a valid workplace as soon as:

- it is placed
- it has `associated_job`
- the job exists in the enums/behaviour mapping

Examples:

- [scripts/room_bar.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_bar.gd:16)
- [scripts/room_brewery.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_brewery.gd:8)
- [scripts/room_well.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_well.gd:20)
- [scripts/room_bed.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_bed.gd:14)

## 8. Room Modules

Modules are the more complete and actively used in-room upgrade/customization system right now.

The reusable module script is [scripts/room_module.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_module.gd:1).

A module exports values like:

- `icon`
- `price`
- `module_name`
- `describtion`
- `item_cost`
- `max_guests`
- `seat_positions`
- `brew_duration`
- `effect_interval`
- `satisfaction_boost`
- `bought`

### Scene structure for modules

Modules live under a room-local `ModulesRoot`.

Typical shape:

```text
ModulesRoot
  Drinks
    Water
    Beer
    Whiskey
```

or

```text
ModulesRoot
  Tables
    TableSmall
    TableBig
```

Each child in a branch is a mutually exclusive option. The UI assumes:

- each branch is one vertical chain
- only one module in a branch should be active at a time
- buying one deactivates previously bought modules in the same branch

Examples:

- [scenes/rooms/room_bar.tscn](/Users/lucasbodeker/CrispyFlakes/scenes/rooms/room_bar.tscn:35)
- [scenes/rooms/room_brewery.tscn](/Users/lucasbodeker/CrispyFlakes/scenes/rooms/room_brewery.tscn:39)
- [scenes/rooms/room_table.tscn](/Users/lucasbodeker/CrispyFlakes/scenes/rooms/room_table.tscn:29)

### Runtime module hookup

The room script is responsible for discovering and reacting to modules.

Common pattern:

```gdscript
var current_module = null

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)

	var modules_root = get_node_or_null("ModulesRoot")
	if modules_root:
		for group in modules_root.get_children():
			for module in group.get_children():
				module.bought_changed.connect(_on_module_bought)
				if module.bought:
					current_module = module
```

Then `_on_module_bought()` updates the room's runtime behavior.

Examples:

- bar changes the served drink type: [scripts/room_bar.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_bar.gd:30)
- brewery changes brew speed: [scripts/room_brewery.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_brewery.gd:21)
- table changes seat count and seat positions: [scripts/room_table.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_table.gd:25)
- entertainment changes range effects: [scripts/room_entertainment.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_entertainment.gd:27)

### Module selection UI

The room selection panel reads `ModulesRoot` using [scripts/ui/selection_room_module_ui.gd](/Users/lucasbodeker/CrispyFlakes/scripts/ui/selection_room_module_ui.gd:1).

It expects:

- a `ModulesRoot` node on the room
- groups as direct children of `ModulesRoot`
- modules as children of each group
- modules to expose `bought`, `price`, `icon`, `module_name`, and `describtion`

If a room should have selectable in-room upgrades, this is the path that is currently most complete.

## 9. Room Upgrades

There is also a separate `RoomUpgrade` resource type in [scripts/room_upgrade.gd](/Users/lucasbodeker/CrispyFlakes/scripts/room_upgrade.gd:1).

Those resources are referenced from `RoomData.room_upgrades`, for example:

- [assets/resources/room_bar.tres](/Users/lucasbodeker/CrispyFlakes/assets/resources/room_bar.tres:10)
- [assets/resources/room_bar_water.tres](/Users/lucasbodeker/CrispyFlakes/assets/resources/room_bar_water.tres:1)

The selection panel also contains UI for `room.upgrades`, `room.current_upgrade`, and `room.try_set_upgrade()` in [scripts/ui_selection_panel.gd](/Users/lucasbodeker/CrispyFlakes/scripts/ui_selection_panel.gd:399).

Important current-state note:

- `RoomUpgrade` resources exist
- `RoomData.room_upgrades` exists
- the selection UI references runtime room upgrade fields
- but the room runtime base classes in this repo do not currently define `upgrades`, `current_upgrade`, or `try_set_upgrade()`

So today this looks like a partial or older upgrade path, while `RoomModule` is the path that is visibly implemented and used by multiple rooms.

### Recommendation

For a new room, choose one of these intentionally:

- use `RoomModule` if the room needs active, visible, in-room variants or upgrades
- extend the `RoomUpgrade` runtime path first if you want resource-driven upgrade cards from `RoomData`

Do not assume that filling `room_upgrades` in the `.tres` is enough by itself.

## 10. Suggested Setup Order for a New Room

Use this order to avoid missing one of the manual registration steps:

1. Create the room scene in `scenes/rooms/room_<name>.tscn`.
2. Create the room script in `scripts/room_<name>.gd`.
3. Create `assets/resources/room_<name>.tres` and point `packed_scene` at the scene.
4. Add build icon and preview art.
5. Register the room resource in `scripts/building.gd`.
6. Add a build button in `scripts/ui/build_ui_handler.gd`.
7. Add custom placement validation if needed.
8. If the room has a worker, wire `associated_job`, enum entry, and behaviour mapping.
9. If the room has in-room variants, add `ModulesRoot` and connect module logic in the room script.
10. If the room needs custom selection-panel info, extend `scripts/ui_selection_panel.gd`.
11. Optionally add it to the startup layout for quick testing.

## 11. Practical Template

### Minimal indoor room

```gdscript
extends RoomBase
class_name RoomExample

@onready var progress_bar: TextureProgressBar = $ProgressBar

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	progress_bar.visible = false
```

### Minimal outdoor room

```gdscript
extends RoomOutsideBase
class_name RoomExampleOutside

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
```

### Room with a worker job

```gdscript
extends RoomBase
class_name RoomExample

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.EXAMPLE
```

### Room with custom placement

```gdscript
static func custom_placement_check(location: Vector2i) -> bool:
	return location.y == 0
```

## 12. Pitfalls to Watch For

- Adding a `.tres` resource does not automatically make the room buildable.
- Adding a room to `Building` does not automatically create a build-menu button.
- Jobs are not declared in `RoomData`; they live on the room instance via `associated_job`.
- Outdoor placement and indoor placement follow different rules.
- `ModulesRoot` is UI-driven by scene structure, so node hierarchy matters.
- `RoomUpgrade` resources are not currently a complete runtime setup on their own.

## 13. Recommended Convention Going Forward

For consistency, new rooms should follow this mental model:

- `RoomData` answers: how do I build this room?
- `RoomBase` subclass answers: how does this room behave once placed?
- `associated_job` answers: can a worker be assigned here?
- `ModulesRoot` answers: what mutually exclusive in-room upgrades or variants does this room support?
- custom placement check answers: where is this room allowed to exist?

If we want, the next step can be turning this into a stricter "new room template" with copy-paste starter files for indoor, outdoor, worker, and module-based rooms.
