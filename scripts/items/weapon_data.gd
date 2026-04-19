class_name WeaponData

var weapon_name: String = ""
var range_rooms: int = 1
var accuracy: float = 0.5
var fire_rate: int = 0
var single_handed: bool = true

static func get_definitions() -> Array:
	return [
		_make("Colt 22",             1, 0.30, Enum.FireRate.SLOW,   true),
		_make("The Peacemaker",      2, 0.40, Enum.FireRate.SLOW,   true),
		_make("Colt Double-Action",  2, 0.40, Enum.FireRate.MEDIUM, true),
		_make("Winchester",          4, 0.60, Enum.FireRate.FAST,   false),
		_make("Sharps Old Reliable", 5, 0.70, Enum.FireRate.MEDIUM, false),
		_make("Springfield Allin",   6, 0.70, Enum.FireRate.SLOW,   false),
		_make("Messenger Shotgun",   3, 0.80, Enum.FireRate.SLOW,   false),
	]

static func _make(p_name: String, p_range: int, p_accuracy: float, p_fire_rate: int, p_single: bool) -> WeaponData:
	var d := WeaponData.new()
	d.weapon_name = p_name
	d.range_rooms = p_range
	d.accuracy = p_accuracy
	d.fire_rate = p_fire_rate
	d.single_handed = p_single
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
