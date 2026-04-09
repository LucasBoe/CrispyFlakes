extends Node

enum Type { PEE, BLOOD, PUKE }

const COLORS = {
	Type.PEE:   Color(0.85, 0.78, 0.1, 1.0),
	Type.BLOOD: Color(0.55, 0.05, 0.05, 1.0),
	Type.PUKE:  Color(0.35, 0.45, 0.1, 1.0),
}

const START_SIZE  = 8.0
const END_SIZE    = 1.0
const FADE_DURATION = 90.0  # seconds until fully gone

func create(world_position: Vector2, type: Type) -> void:
	var rect := ColorRect.new()
	rect.color = COLORS[type]
	rect.size = Vector2(START_SIZE, 2)
	rect.position = world_position - rect.size * 0.5
	rect.z_index = 100
	add_child(rect)
	_fade(rect)

func _fade(rect: ColorRect) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	#tween.tween_property(rect, "size", Vector2(END_SIZE, END_SIZE), FADE_DURATION)
	tween.tween_property(rect, "color:a", 0.0, FADE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(rect.queue_free)
