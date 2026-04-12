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

var puddle_instances: Array[ColorRect] = []

func create(world_position: Vector2, type: Type) -> void:
	var rect := ColorRect.new()
	rect.color = COLORS[type]
	rect.size = Vector2(START_SIZE, 2)
	rect.position = world_position - rect.size * 0.5
	rect.z_index = 100
	add_child(rect)
	puddle_instances.append(rect)
	_fade(rect)

func get_closest_to(global_pos: Vector2) -> ColorRect:
	var closest: ColorRect = null
	var best_dist := INF

	for i in range(puddle_instances.size() - 1, -1, -1):
		var puddle := puddle_instances[i]
		if not is_instance_valid(puddle):
			puddle_instances.remove_at(i)
			continue

		var puddle_center := puddle.global_position + puddle.size * 0.5
		var d := puddle_center.distance_squared_to(global_pos)
		if d < best_dist:
			best_dist = d
			closest = puddle

	return closest

func clean_puddle(puddle) -> void:
	if puddle_instances.has(puddle):
		puddle_instances.erase(puddle)
	if is_instance_valid(puddle):
		puddle.queue_free()

func _fade(rect: ColorRect) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	#tween.tween_property(rect, "size", Vector2(END_SIZE, END_SIZE), FADE_DURATION)
	tween.tween_property(rect, "color:a", 0.0, FADE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(clean_puddle.bind(rect))
