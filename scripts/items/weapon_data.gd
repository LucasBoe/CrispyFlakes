class_name WeaponData

var weapon_name: String = ""
var range_rooms: int = 1
var accuracy: float = 0.5
var fire_rate: int = 0
var single_handed: bool = true
var sprite_path: String = ""

static func get_definitions() -> Array:
	return [
		_make("Colt 22",             1, 0.30, Enum.FireRate.SLOW,   true,  "res://assets/sprites/weapon_colt22.png"),
		_make("The Peacemaker",      2, 0.40, Enum.FireRate.SLOW,   true,  "res://assets/sprites/weapon_peacemaker.png"),
		_make("Colt Double-Action",  2, 0.40, Enum.FireRate.MEDIUM, true,  "res://assets/sprites/weapon_colts_double_action.png"),
		_make("Winchester",          4, 0.60, Enum.FireRate.FAST,   false, "res://assets/sprites/weapon_winchester.png"),
		_make("Sharps Old Reliable", 5, 0.70, Enum.FireRate.MEDIUM, false, "res://assets/sprites/weapon_sharps_old_reliable.png"),
		_make("Springfield Allin",   6, 0.70, Enum.FireRate.SLOW,   false, "res://assets/sprites/weapon_springfield_allin.png"),
		_make("Messenger Shotgun",   3, 0.80, Enum.FireRate.SLOW,   false, "res://assets/sprites/weapon_messenger_shotgun.png"),
	]

static func _make(p_name: String, p_range: int, p_accuracy: float, p_fire_rate: int, p_single: bool, p_sprite: String) -> WeaponData:
	var d := WeaponData.new()
	d.weapon_name = p_name
	d.range_rooms = p_range
	d.accuracy = p_accuracy
	d.fire_rate = p_fire_rate
	d.single_handed = p_single
	d.sprite_path = p_sprite
	return d

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
