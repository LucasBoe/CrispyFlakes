class_name ScenarioData
extends Resource

@export var scenario_id: String
@export var display_name: String
@export_multiline var description: String

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

@export var is_campaign: bool = false

## Not exposed in the sandbox config UI - controls whether the basic
## controls hint (Global.UI.controls) is shown on scenario start.
@export var show_basic_controls_ui: bool = false
