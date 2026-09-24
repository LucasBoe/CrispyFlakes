class_name ScenarioData
extends Resource

@export var scenario_id: String
@export var display_name: String
@export_multiline var description: String

## Shown as 0-5 stars (half steps) on the campaign selection screen.
@export_range(0.0, 5.0, 0.5) var difficulty: float = 1.0

@export var starting_money: int

@export var use_default_starting_layout: bool = true
@export var starting_rooms: Array[ScenarioRoomPlacement] = []

@export var starting_item_stacks: Array[ScenarioItemStack] = []

@export var starting_bounty_count: int

@export var starting_worker_count: int

@export var starting_guest_count: int

@export var use_default_unlocks: bool = true
@export var unlocked_rooms: Array[RoomData] = []

## FeatureGateHandler.Feature (int) -> bool, applied via FeatureGateHandler.set_enabled() per entry.
@export var feature_overrides: Dictionary = {}

@export var robber_spawn_chance: float = 0.1

## Balancing.GUEST_SPAWN_BASE_RATE for this scenario: 4 easy, 2 normal, 1 hard.
@export_range(0.5, 8.0, 0.5) var guest_spawn_base_rate: float = 2.0

@export var is_campaign: bool = false

## Not exposed in the sandbox config UI - controls whether the basic
## controls hint (Global.UI.controls) is shown on scenario start.
@export var show_basic_controls_ui: bool = false

## Restricts which NPC archetypes (NPCLookInfo.body_type) can spawn as
## guests/workers/bounties in this scenario. Empty means unrestricted -
## all of NPCLookInfo's default candidate types remain available.
## Also the guest-type icons (NPCArchetype.icon) on the campaign selection screen.
@export var allowed_npc_archetypes: Array[NPCArchetype] = []

## Campaign selection's in-world preview only: how many of each archetype to
## show, matched by index with allowed_npc_archetypes (missing entries = 1).
@export var preview_guest_counts: PackedInt32Array = PackedInt32Array()
