class_name WeaponData
extends Resource

@export var weapon_name: String = ""
@export var range_rooms: int = 1
@export var accuracy: float = 0.5
@export var fire_rate: int = 0
@export var single_handed: bool = true
@export var sprite: Texture2D
@export var equiped_overlay_texture : Texture2D

func get_fire_rate_label() -> String:
	match fire_rate:
		Enum.FireRate.SLOW:   return "slow"
		Enum.FireRate.MEDIUM: return "med"
		Enum.FireRate.FAST:   return "fast"
	return "?"

func get_compact_stats() -> String:
	return "%dr  %d%%  %s  %s" % [
		range_rooms,
		int(accuracy * 100),
		get_fire_rate_label(),
		"1H" if single_handed else "2H",
	]
