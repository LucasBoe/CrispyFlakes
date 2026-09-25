extends Node

enum Type { PEE, BLOOD, PUKE }

const COLORS = {
	Type.PEE:   Color(0.85, 0.78, 0.1, 1.0),
	Type.BLOOD: Color(0.55, 0.05, 0.05, 1.0),
	Type.PUKE:  Color(0.35, 0.45, 0.1, 1.0),
}

const START_SIZE  = 8.0
const END_SIZE    = 1.0
const FADE_DURATION = 180.0  # seconds until fully gone
const FRONT_FLOOR_Z_INDEX := Enum.ZLayer.NPC_DEFAULT + 2

var puddle_instances: Array[Polygon2D] = []

func create(world_position: Vector2, type: Type) -> void:
	var puddle := Polygon2D.new()
	puddle.color = COLORS[type]
	puddle.polygon = PackedVector2Array([
		Vector2(-START_SIZE * 0.5, -1.0),
		Vector2(START_SIZE * 0.5, -1.0),
		Vector2(START_SIZE * 0.5, 1.0),
		Vector2(-START_SIZE * 0.5, 1.0),
	])
	puddle.position = world_position
	puddle.z_index = FRONT_FLOOR_Z_INDEX
	add_child(puddle)
	puddle_instances.append(puddle)
	_fade(puddle)

func get_closest_to(global_pos: Vector2) -> Polygon2D:
	var closest: Polygon2D = null
	var best_dist := INF

	for i in range(puddle_instances.size() - 1, -1, -1):
		var puddle := puddle_instances[i]
		if not is_instance_valid(puddle):
			puddle_instances.remove_at(i)
			continue

		var d := puddle.global_position.distance_squared_to(global_pos)
		if d < best_dist:
			best_dist = d
			closest = puddle

	return closest

func get_all_in_range(global_pos: Vector2, range: float) -> Array[Polygon2D]:
	var puddles_in_range: Array[Polygon2D] = []
	var range_squared := range * range

	for i in range(puddle_instances.size() - 1, -1, -1):
		var puddle := puddle_instances[i]
		if not is_instance_valid(puddle):
			puddle_instances.remove_at(i)
			continue

		if puddle.global_position.distance_squared_to(global_pos) <= range_squared:
			puddles_in_range.append(puddle)

	return puddles_in_range

func clean_puddle(puddle) -> void:
	if puddle_instances.has(puddle):
		puddle_instances.erase(puddle)
	if is_instance_valid(puddle):
		puddle.queue_free()

func _fade(puddle: Polygon2D) -> void:
	var tween = puddle.create_tween()
	tween.set_parallel(true)
	#tween.tween_property(puddle, "scale", Vector2(END_SIZE / START_SIZE, END_SIZE / START_SIZE), FADE_DURATION)
	tween.tween_property(puddle, "color:a", 0.0, FADE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(clean_puddle.bind(puddle))
