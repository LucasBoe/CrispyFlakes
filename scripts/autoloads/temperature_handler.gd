extends Node

var _sources: Array = []

func register_source(source) -> void:
	if source == null or _sources.has(source):
		return
	_sources.append(source)

func unregister_source(source) -> void:
	_sources.erase(source)

func get_temperature_at_global_position(global_pos: Vector2) -> float:
	var total := 0.0
	for source in _sources.duplicate():
		if not is_instance_valid(source):
			_sources.erase(source)
			continue
		if not source.has_method("get_temperature_range") or not source.has_method("get_temperature_strength"):
			continue
		var range_value: float = maxf(0.0, float(source.get_temperature_range()))
		if range_value <= 0.0:
			continue
		var strength: float = maxf(0.0, float(source.get_temperature_strength()))
		if strength <= 0.0:
			continue
		var distance_ratio := clampf(source.global_position.distance_to(global_pos) / range_value, 0.0, 1.0)
		total += strength * (1.0 - distance_ratio)
	return total

func get_temperature_for_room(room: RoomBase) -> float:
	if room == null or room.data == null:
		return 0.0

	var total := 0.0
	var sample_count := 0
	for col in room.data.width:
		for row in room.data.height:
			var sample_index := Vector2i(room.x + col, room.y + row)
			total += get_temperature_at_global_position(Building.global_position_from_room_index(sample_index) + Vector2(0, -24))
			sample_count += 1

	if sample_count <= 0:
		return 0.0
	return total / float(sample_count)

func is_room_heated(room: RoomBase, threshold: float = 0.3) -> bool:
	return get_temperature_for_room(room) >= threshold
