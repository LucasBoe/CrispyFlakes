class_name EquipmentData
extends Resource

@export var equipment_name: String = ""
@export var icon: Texture2D
@export var equiped_overlay_texture: Texture2D
## The carried Item type this equipment reskins (e.g. PICKAXE) while it's
## equipped. Only consumed by behaviours that hold that specific item type,
## so unrelated held items (e.g. a broom) are never affected.
@export var carried_item_type: Enum.Items
@export var carried_item_override: Texture2D
@export var work_duration_multiplier: float = 1.0

func get_compact_stats() -> String:
	return ""

func get_display_icon() -> Texture2D:
	return carried_item_override if carried_item_override != null else icon
